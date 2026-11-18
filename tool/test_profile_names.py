"""Live name and pairing smoke test with disposable confirmed accounts."""
import json
import subprocess
import uuid
import urllib.error
import urllib.request

BASE = 'https://dtjasplpglevmtagkrfp.supabase.co/'
PUB = 'sb_publishable_q3BBWv0BmSRnwApM7YH99w_5gHQV7KF'
raw = subprocess.run(['supabase', 'projects', 'api-keys', '--project-ref',
                      'dtjasplpglevmtagkrfp', '--reveal', '-o', 'json'],
                     capture_output=True, text=True, check=True)
keys = json.loads(raw.stdout)
if isinstance(keys, dict):
    keys = keys.get('api_keys', keys.get('keys', []))
ADMIN = next(item['api_key'] for item in keys if item.get('name') == 'service_role')
created = []


def call(path, method='GET', body=None, token=None):
    payload = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(BASE + path, data=payload, method=method,
        headers={'apikey': PUB, 'Authorization': 'Bearer ' + (token or PUB),
                 'Content-Type': 'application/json', 'Prefer': 'return=representation'})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()
            return response.status, json.loads(content) if content else None
    except urllib.error.HTTPError as error:
        content = error.read()
        try: detail = json.loads(content)
        except ValueError: detail = content.decode()[:200]
        return error.code, detail


def user():
    email = f'jigu-name-qa-{uuid.uuid4()}@example.invalid'
    password = f'{uuid.uuid4()}Aa1!'
    status, account = call('auth/v1/admin/users', 'POST',
        {'email': email, 'password': password, 'email_confirm': True}, ADMIN)
    assert status in (200, 201), (status, account)
    created.append(account['id'])
    status, session = call('auth/v1/token?grant_type=password', 'POST',
                           {'email': email, 'password': password})
    assert status == 200, status
    return account['id'], session['access_token']


try:
    first, first_token = user()
    second, second_token = user()
    status, rows = call(f'rest/v1/profiles?id=eq.{first}&select=invite_code', token=first_token)
    assert status == 200 and len(rows) == 1, (status, rows)
    code = rows[0]['invite_code']

    for account_id, token, name in [(first, first_token, 'Sanjaya'),
                                     (second, second_token, 'Lily')]:
        status, rows = call(f'rest/v1/profiles?id=eq.{account_id}', 'PATCH',
                            {'display_name': name}, token)
        assert status == 200 and rows[0]['display_name'] == name, (status, rows)

    status, rows = call(f'rest/v1/profiles?id=eq.{first}', 'PATCH',
                        {'display_name': 'Changed'}, second_token)
    assert status == 200 and rows == [], (status, rows)

    status, result = call('rest/v1/rpc/join_couple_v2', 'POST',
                          {'invite': code}, second_token)
    assert status == 200, (status, result)
    status, rows = call(f'rest/v1/profiles?id=eq.{first}&select=display_name',
                        token=second_token)
    assert status == 200 and rows == [{'display_name': 'Sanjaya'}], (status, rows)
    status, name = call('rest/v1/rpc/rename_partner', 'POST',
                        {'partner_name': 'My Lily'}, first_token)
    assert status == 200 and name == 'My Lily', (status, name)
    status, rows = call(f'rest/v1/profiles?id=eq.{second}&select=display_name', token=second_token)
    assert status == 200 and rows == [{'display_name': 'My Lily'}], (status, rows)
    status, name = call('rest/v1/rpc/rename_partner', 'POST',
                        {'partner_name': 'My Sanjaya'}, second_token)
    assert status == 200 and name == 'My Sanjaya', (status, name)
    status, _ = call('rest/v1/rpc/rename_partner', 'POST', {'partner_name': ' '}, first_token)
    assert status >= 400, status
    status, _ = call('rest/v1/rpc/leave_couple', 'POST', {}, second_token)
    assert status in (200, 204), status
    for token in [first_token, second_token]:
        status, _ = call('rest/v1/rpc/rename_partner', 'POST', {'partner_name': 'Forbidden'}, token)
        assert status >= 400, status
    print('Passed: self names, bidirectional partner renaming, invalid names rejected, edits blocked after leaving.')
finally:
    for account_id in created:
        call(f'auth/v1/admin/users/{account_id}', 'DELETE', token=ADMIN)
    print('Disposable accounts cleaned up.')
