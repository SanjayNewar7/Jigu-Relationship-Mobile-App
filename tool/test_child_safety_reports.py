"""Verify authenticated child safety reporting and private report storage."""
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


def call(path, method='GET', body=None, token=None):
    payload = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(BASE + path, data=payload, method=method,
        headers={'apikey': PUB, 'Authorization': 'Bearer ' + (token or PUB),
                 'Content-Type': 'application/json', 'Prefer': 'return=minimal'})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()
            return response.status, json.loads(content) if content else None
    except urllib.error.HTTPError as error:
        content = error.read()
        try: detail = json.loads(content)
        except ValueError: detail = content.decode()[:200]
        return error.code, detail


email = f'jigu-safety-qa-{uuid.uuid4()}@example.invalid'
password = f'{uuid.uuid4()}Aa1!'
status, account = call('auth/v1/admin/users', 'POST',
    {'email': email, 'password': password, 'email_confirm': True}, ADMIN)
assert status in (200, 201), (status, account)
user_id = account['id']
try:
    status, session = call('auth/v1/token?grant_type=password', 'POST',
                           {'email': email, 'password': password})
    assert status == 200, status
    token = session['access_token']
    details = f'Disposable safety report test {uuid.uuid4()}.'
    report = {'reporter_id': user_id, 'category': 'child_safety', 'details': details}
    status, _ = call('rest/v1/child_safety_reports', 'POST', report, token)
    assert status == 201, status
    status, _ = call('rest/v1/child_safety_reports', 'POST', report)
    assert status >= 400, status
    status, _ = call('rest/v1/child_safety_reports', 'POST',
                     {**report, 'details': 'short'}, token)
    assert status >= 400, status
    status, _ = call('rest/v1/child_safety_reports?select=id', token=token)
    assert status >= 400, status
    status, _ = call('rest/v1/child_safety_reports?details=eq.' + details.replace(' ', '%20'),
                     'DELETE', token=ADMIN)
    assert status in (200, 204), status
    print('Passed: report accepted, anonymous and invalid submissions blocked, user cannot read reports.')
finally:
    call(f'auth/v1/admin/users/{user_id}', 'DELETE', token=ADMIN)
    print('Disposable account cleaned up.')
