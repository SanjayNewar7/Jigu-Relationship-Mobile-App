"""Live account deletion smoke test using disposable confirmed users."""
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

def call(path, method='GET', body=None, token=None, prefer='return=representation'):
    payload = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(BASE + path, data=payload, method=method,
        headers={'apikey': PUB, 'Authorization': 'Bearer ' + (token or PUB),
                 'Content-Type': 'application/json', 'Prefer': prefer})
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
    email = f'jigu-delete-qa-{uuid.uuid4()}@example.invalid'
    password = f'{uuid.uuid4()}Aa1!'
    status, account = call('auth/v1/admin/users', 'POST',
        {'email': email, 'password': password, 'email_confirm': True}, ADMIN)
    assert status in (200, 201), (status, account)
    created.append(account['id'])
    status, session = call('auth/v1/token?grant_type=password', 'POST',
                           {'email': email, 'password': password})
    assert status == 200, status
    return account['id'], password, session['access_token']

def upload(path, token):
    request = urllib.request.Request(BASE + 'storage/v1/object/moments/' + path,
        data=b'jigu disposable image bytes', method='POST',
        headers={'apikey': PUB, 'Authorization': 'Bearer ' + token,
                 'Content-Type': 'image/jpeg'})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code

try:
    owner, password, owner_token = user()
    partner, _, partner_token = user()
    status, profile = call(f'rest/v1/profiles?select=invite_code&id=eq.{owner}', token=owner_token)
    assert status == 200 and len(profile) == 1, (status, profile)
    status, space = call('rest/v1/rpc/join_couple_v2', 'POST',
                         {'invite': profile[0]['invite_code']}, partner_token)
    assert status == 200, (status, space)
    status, paired = call(f'rest/v1/profiles?select=couple_id&id=eq.{owner}', token=owner_token)
    assert status == 200 and paired[0]['couple_id'], (status, paired)
    couple_id = paired[0]['couple_id']
    photo_path = f'{couple_id}/{owner}/{uuid.uuid4()}.jpg'
    assert upload(photo_path, owner_token) in (200, 201)
    status, moment = call('rest/v1/moments', 'POST',
        {'couple_id': couple_id, 'author_id': owner, 'storage_path': photo_path}, owner_token, 'return=minimal')
    assert status in (201, 204), (status, moment)
    status, _ = call('rest/v1/mood_journal_entries', 'POST',
                     {'user_id': owner, 'entry_date': '2026-11-14', 'journal': 'Disposable test note'}, owner_token)
    assert status == 201, status
    status, denied = call('functions/v1/delete-account', 'POST',
                          {'password': 'wrong-password', 'confirmation': 'DELETE'}, owner_token)
    assert status == 403, (status, denied)
    status, owner_still = call(f'rest/v1/profiles?select=id&id=eq.{owner}', token=owner_token)
    assert status == 200 and len(owner_still) == 1
    status, deleted = call('functions/v1/delete-account', 'POST',
                           {'password': password, 'confirmation': 'DELETE'}, owner_token)
    assert status == 200 and deleted.get('deleted') is True, (status, deleted)
    created.remove(owner)
    status, partner_profile = call(f'rest/v1/profiles?select=couple_id,previous_couple_id&id=eq.{partner}', token=partner_token)
    assert status == 200 and partner_profile == [{'couple_id': None, 'previous_couple_id': None}], (status, partner_profile)
    status, missing = call(f'auth/v1/admin/users/{owner}', token=ADMIN)
    assert status == 404, (status, missing)
    status, photo = call('storage/v1/object/info/moments/' + photo_path, token=ADMIN)
    assert status in (400, 404) and photo.get('code') == 'NoSuchKey', (status, photo)
    print('Passed: wrong password rejected; account, journal, space and photo removed; partner unpaired.')
finally:
    for account_id in created:
        call(f'auth/v1/admin/users/{account_id}', 'DELETE', token=ADMIN)
    print('Disposable accounts cleaned up.')
