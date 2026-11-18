"""Verify Supabase current-password update using a disposable account."""
import json
import subprocess
import uuid
import urllib.error
import urllib.request

base = 'https://dtjasplpglevmtagkrfp.supabase.co/'
pub = 'sb_publishable_q3BBWv0BmSRnwApM7YH99w_5gHQV7KF'
raw = subprocess.run(['supabase', 'projects', 'api-keys', '--project-ref',
    'dtjasplpglevmtagkrfp', '--reveal', '-o', 'json'], capture_output=True,
    text=True, check=True)
keys = json.loads(raw.stdout)
if isinstance(keys, dict): keys = keys.get('api_keys', keys.get('keys', []))
admin = next(item['api_key'] for item in keys if item.get('name') == 'service_role')

def call(path, method, body, token):
    request = urllib.request.Request(base + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'apikey': pub, 'Authorization': 'Bearer ' + token,
                 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())

email = f'jigu-password-qa-{uuid.uuid4()}@example.invalid'
old = f'{uuid.uuid4()}Aa1!'
new = f'{uuid.uuid4()}Bb2!'
status, account = call('auth/v1/admin/users', 'POST',
    {'email': email, 'password': old, 'email_confirm': True}, admin)
assert status in (200, 201), status
try:
    status, session = call('auth/v1/token?grant_type=password', 'POST',
        {'email': email, 'password': old}, pub)
    assert status == 200, status
    token = session['access_token']
    status, rejected = call('auth/v1/token?grant_type=password', 'POST',
        {'email': email, 'password': 'wrong-password'}, pub)
    assert status >= 400, (status, rejected)
    status, changed = call('auth/v1/user', 'PUT',
        {'password': new}, token)
    assert status == 200, (status, changed)
    status, session = call('auth/v1/token?grant_type=password', 'POST',
        {'email': email, 'password': new}, pub)
    assert status == 200, status
    print('Passed: wrong current password rejected; new password signs in.')
finally:
    call(f"auth/v1/admin/users/{account['id']}", 'DELETE', None, admin)
    print('Disposable password account removed.')
