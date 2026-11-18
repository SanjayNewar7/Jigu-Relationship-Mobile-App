"""Disposable-account chat/API/storage/GIPHY smoke test; never prints secrets."""
import base64
import json
import subprocess
import tempfile
import time
import sys
import uuid
import urllib.request
import urllib.error
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE='https://dtjasplpglevmtagkrfp.supabase.co/'
PUB='sb_publishable_q3BBWv0BmSRnwApM7YH99w_5gHQV7KF'
raw=subprocess.run(['supabase','projects','api-keys','--project-ref','dtjasplpglevmtagkrfp','--reveal','-o','json'],capture_output=True,text=True,check=True)
keys=json.loads(raw.stdout)
if isinstance(keys,dict): keys=keys.get('api_keys',keys.get('keys',[]))
ADMIN=next(x['api_key'] for x in keys if x.get('name')=='service_role')
users=[]; paths=[]; space=None; credentials=[]; keep=False
def call(path,method='GET',body=None,token=None,mime='application/json'):
    payload=body if isinstance(body,bytes) else None if body is None else json.dumps(body).encode()
    req=urllib.request.Request(BASE+path,data=payload,method=method,headers={'apikey':PUB,'Authorization':'Bearer '+(token or PUB),'Content-Type':mime,'Prefer':'return=representation'})
    try:
        with urllib.request.urlopen(req,timeout=35) as r:
            data=r.read()
            try: data=json.loads(data) if data else None
            except ValueError: pass
            return r.status,data
    except urllib.error.HTTPError as e:return e.code,None
def query(sql):
    with tempfile.TemporaryDirectory() as folder:
        p=Path(folder)/'test.sql';p.write_text(sql)
        r=subprocess.run(['supabase','db','query','--linked','--project-ref','dtjasplpglevmtagkrfp','--file',str(p)],cwd=ROOT,capture_output=True,text=True)
        assert r.returncode==0,'SQL test failed'
        return json.loads(r.stdout[r.stdout.find('{'):r.stdout.rfind('}')+1]).get('rows',[])
def user():
    email=f'jigu-chat-qa-{uuid.uuid4()}@example.invalid';password=f'{uuid.uuid4()}Aa1!'
    status,account=call('auth/v1/admin/users','POST',{'email':email,'password':password,'email_confirm':True},ADMIN)
    assert status in(200,201),'Create QA user failed'
    users.append(account['id'])
    credentials.append({'email':email,'password':password})
    status,session=call('auth/v1/token?grant_type=password','POST',{'email':email,'password':password})
    assert status==200,'QA sign in failed'
    return account['id'],session['access_token']
if '--cleanup-device' in sys.argv:
    state=json.loads((ROOT/'.tmp/chat-qa.json').read_text())
    _, attachments=call(f"rest/v1/chat_messages?couple_id=eq.{state['space']}&select=storage_path",token=ADMIN)
    paths=list(set(state['paths']+[row['storage_path'] for row in (attachments or []) if row.get('storage_path')]))
    if paths:call('storage/v1/object/chat-media','DELETE',{'prefixes':paths},ADMIN)
    call(f"rest/v1/couples?id=eq.{state['space']}",'DELETE',token=ADMIN)
    for ident in state['users']:call(f'auth/v1/admin/users/{ident}','DELETE',token=ADMIN)
    (ROOT/'.tmp/chat-qa.json').unlink()
    print('Device QA accounts cleaned up.')
    sys.exit()
try:
    a,ta=user();b,tb=user();outsider,to=user()
    status,rows=call(f'rest/v1/profiles?id=eq.{a}&select=invite_code',token=ta)
    assert status==200
    status,_=call('rest/v1/rpc/join_couple_v2','POST',{'invite':rows[0]['invite_code']},tb);assert status==200
    _,rows=call(f'rest/v1/profiles?id=eq.{a}&select=couple_id',token=ta);space=rows[0]['couple_id']
    message=str(uuid.uuid4())
    status,_=call('rest/v1/chat_messages','POST',{'id':message,'couple_id':space,'kind':'text','body':'QA hello'},ta);assert status==201,'Send text failed'
    _,rows=call(f'rest/v1/chat_messages?couple_id=eq.{space}',token=tb);assert len(rows)==1,'Partner read failed'
    _,rows=call(f'rest/v1/chat_messages?couple_id=eq.{space}',token=to);assert rows==[],'Cross-space leak'
    status,_=call('rest/v1/rpc/touch_chat','POST',{'space':space,'typing':True},tb);assert status in(200,204)
    status,_=call('rest/v1/chat_preferences','POST',{'couple_id':space,'theme':'sage'},ta);assert status==201
    _,rows=call(f'rest/v1/chat_preferences?couple_id=eq.{space}',token=tb);assert rows[0]['theme']=='sage'
    print('PASS: two-way membership, text, typing/read state and shared theme.')
    media=str(uuid.uuid4());path=f'{space}/{a}/{media}';paths.append(path)
    png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')
    status,_=call('storage/v1/object/chat-media/'+path,'POST',png,ta,'image/png');assert status in(200,201),'Upload failed'
    status,_=call('rest/v1/chat_messages','POST',{'id':media,'couple_id':space,'kind':'image','storage_path':path},ta);assert status==201,'Attach failed'
    status,_=call('storage/v1/object/sign/chat-media/'+path,'POST',{'expiresIn':60},tb);assert status==200,'Partner cannot sign media'
    status,_=call('storage/v1/object/sign/chat-media/'+path,'POST',{'expiresIn':60},to);assert status>=400,'Outsider signed media'
    query(f"update storage.objects set created_at=now()-interval '31 days' where bucket_id='chat-media' and name='{path}'; update public.chat_messages set expires_at=now()-interval '1 day' where id='{media}';")
    status,_=call('storage/v1/object/sign/chat-media/'+path,'POST',{'expiresIn':60},tb);assert status>=400,'Expired attachment accessible'
    query("do $$ declare cmd text; begin select command into cmd from cron.job where jobname='jigu-chat-cleanup'; execute cmd; end $$;")
    for _ in range(8):
        rows=query(f"select media_deleted from public.chat_messages where id='{media}'")
        if rows[0]['media_deleted']:break
        time.sleep(2)
    assert rows[0]['media_deleted'],'Storage cleanup worker failed'
    print('PASS: real upload, partner-only access, expiry and scheduled file deletion.')
    status,config=call('functions/v1/giphy-config','POST',{},ta);assert status==200,'GIPHY config unavailable'
    try:
        request=urllib.request.Request('https://api.giphy.com/v1/gifs/trending?rating=pg&limit=1&api_key='+config['key'])
        with urllib.request.urlopen(request,timeout=25) as response: gifs=json.load(response)['data']
    except urllib.error.HTTPError as e:raise AssertionError(f'GIPHY upstream status {e.code}') from None
    assert gifs,'GIPHY returned no GIFs'
    status,_=call('rest/v1/chat_messages','POST',{'id':str(uuid.uuid4()),'couple_id':space,'kind':'gif','giphy_id':gifs[0]['id']},ta);assert status==201
    print('PASS: saved GIPHY key, direct search and GIF-ID messages.')
    if '--prepare-device' in sys.argv:
        call('rest/v1/chat_messages','POST',{'id':str(uuid.uuid4()),'couple_id':space,'kind':'text','body':'I saved a little hello for you.'},tb)
        (ROOT/'.tmp/chat-qa.json').write_text(json.dumps({'users':users,'paths':paths,'space':space,'credentials':credentials}))
        keep=True
        print('Disposable device QA login prepared locally.')
        sys.exit()
    status,_=call('rest/v1/rpc/leave_couple','POST',{},tb);assert status in(200,204)
    _,rows=call(f'rest/v1/chat_messages?couple_id=eq.{space}',token=tb);assert rows==[]
    print('PASS: leaving a space revokes conversation access.')
finally:
    if not keep:
        if paths:call('storage/v1/object/chat-media','DELETE',{'prefixes':paths},ADMIN)
        if space:call(f'rest/v1/couples?id=eq.{space}','DELETE',token=ADMIN)
        for ident in users:call(f'auth/v1/admin/users/{ident}','DELETE',token=ADMIN)
        print('Disposable chat accounts and media removed.')
