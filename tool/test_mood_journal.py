"""Live RLS check with disposable accounts; prints no credentials."""
import json
import subprocess
import tempfile
import uuid
import urllib.error
import urllib.request
from pathlib import Path

BASE = 'https://dtjasplpglevmtagkrfp.supabase.co/'
PUB = 'sb_publishable_q3BBWv0BmSRnwApM7YH99w_5gHQV7KF'
raw = subprocess.run(
    ['supabase', 'projects', 'api-keys', '--project-ref',
     'dtjasplpglevmtagkrfp', '--reveal', '-o', 'json'],
    capture_output=True, text=True, check=True,
)
keys = json.loads(raw.stdout)
if isinstance(keys, dict):
    keys = keys.get('api_keys', keys.get('keys', []))
admin = next(item['api_key'] for item in keys if item.get('name') == 'service_role')
users = []

def query(sql):
    with tempfile.TemporaryDirectory(prefix='jigu-mood-qa-') as folder:
        file = Path(folder) / 'query.sql'
        file.write_text(sql)
        result = subprocess.run(
            ['supabase', 'db', 'query', '--linked', '--file', str(file)],
            capture_output=True, text=True, check=True,
        )
        body = result.stdout
        return json.loads(body[body.find('{'):body.rfind('}') + 1]).get('rows', [])

def api(path, method='GET', body=None, token=None):
    payload = None if body is None else json.dumps(body).encode()
    headers = {
        'apikey': PUB,
        'Authorization': 'Bearer ' + (token or PUB),
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
    }
    request = urllib.request.Request(
        BASE + path, data=payload, headers=headers, method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()
            return response.status, json.loads(content) if content else None
    except urllib.error.HTTPError as error:
        content = error.read()
        return error.code, json.loads(content) if content else None

def create_user():
    email = f'jigu-mood-qa-{uuid.uuid4()}@example.invalid'
    password = f'{uuid.uuid4()}Az1!'
    status, user = api('auth/v1/admin/users', 'POST',
                       {'email': email, 'password': password,
                        'email_confirm': True}, admin)
    assert status in (200, 201), status
    users.append(user['id'])
    status, session = api('auth/v1/token?grant_type=password', 'POST',
                          {'email': email, 'password': password})
    assert status == 200, status
    return user['id'], session['access_token']

try:
    owner, owner_token = create_user()
    other, other_token = create_user()
    entry = {'user_id': owner, 'entry_date': '2026-11-07',
             'mood': 'misunderstood', 'journal': 'A private test note.'}
    status, created = api('rest/v1/mood_journal_entries', 'POST',
                          entry, owner_token)
    assert status == 201, (status, created)
    status, own_rows = api('rest/v1/mood_journal_entries?select=*',
                           token=owner_token)
    assert status == 200 and len(own_rows) == 1
    status, other_rows = api('rest/v1/mood_journal_entries?select=*',
                             token=other_token)
    assert status == 200 and not other_rows
    status, rejected = api('rest/v1/mood_journal_entries', 'POST',
                           {**entry, 'user_id': other}, owner_token)
    assert status >= 400, (status, rejected)
    status, updated = api(
        'rest/v1/mood_journal_entries?entry_date=eq.2026-11-07',
        'PATCH', {'journal': 'Updated private note.'}, owner_token,
    )
    assert status == 200 and updated[0]['journal'] == 'Updated private note.'
    status, preserved = api(
        'rest/v1/mood_journal_entries?entry_date=eq.2026-11-07',
        'PATCH', {'journal': None}, owner_token,
    )
    assert status == 200 and preserved[0]['journal'] is None
    assert preserved[0]['mood'] == 'misunderstood'
    status, note_only = api('rest/v1/mood_journal_entries', 'POST',
        {'user_id': owner, 'entry_date': '2026-11-06',
         'journal': 'Note only.'}, owner_token)
    assert status == 201, (status, note_only)
    status, deleted = api(
        'rest/v1/mood_journal_entries?entry_date=eq.2026-11-06',
        'DELETE', token=owner_token,
    )
    assert status == 200 and len(deleted) == 1, (status, deleted)
    print('Mood journal passed: private CRUD, note removal preserves mood, note-only row deletion.')
finally:
    for user in users:
        query(f"delete from auth.users where id='{user}' "
              "and email like 'jigu-mood-qa-%@example.invalid'")
    print('Synthetic mood accounts removed.')
