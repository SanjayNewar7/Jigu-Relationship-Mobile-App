import json, subprocess, tempfile, uuid, urllib.request, urllib.error, sys
from pathlib import Path
root=Path.cwd()
def query(sql):
 with tempfile.TemporaryDirectory(prefix='jigu-date-qa-') as d:
  f=Path(d)/'test.sql';f.write_text(sql)
  r=subprocess.run(['supabase','db','query','--linked','--file',str(f)],capture_output=True,text=True)
  if r.returncode: raise RuntimeError('QA database operation failed')
  return json.loads(r.stdout[r.stdout.find('{'):r.stdout.rfind('}')+1]).get('rows',[])
def api(path,body,token=None):
 req=urllib.request.Request('https://dtjasplpglevmtagkrfp.supabase.co/'+path,data=json.dumps(body).encode(),headers={'apikey':'sb_publishable_q3BBWv0BmSRnwApM7YH99w_5gHQV7KF','Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
 try:
  with urllib.request.urlopen(req,timeout=60) as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)

raw=subprocess.run(['supabase','projects','api-keys','--project-ref','dtjasplpglevmtagkrfp','--reveal','-o','json'],capture_output=True,text=True,check=True)
keys=json.loads(raw.stdout)
if isinstance(keys,dict): keys=keys.get('api_keys', keys.get('keys',[]))
admin=next(item['api_key'] for item in keys if item.get('name')=='service_role')
created=[]
def create_user():
 password=str(uuid.uuid4())+'aZ1!';email=f'jigu-qa-{uuid.uuid4()}@example.invalid'
 status,data=api('auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True},admin)
 if status not in (200,201): raise RuntimeError(f'QA account setup HTTP {status}')
 created.append(data['id'])
 return data['id'],email,password


import re,time
state=json.loads(Path('tool/date-qa-state.json').read_text());c=state['couple_id'];a,b=state['users'];d=str(uuid.uuid4())
token=subprocess.check_output(['adb','-s','emulator-5554','shell','run-as','com.sanjaya.jigulove','cat','files/qa-fcm-token'],text=True).strip()
if not re.fullmatch(r'[A-Za-z0-9_:\-]+',token): raise RuntimeError('Missing QA device token')
query(f"""insert into public.notification_devices(token,user_id,platform) values('{token}','{b}','android') on conflict(token) do update set user_id=excluded.user_id;
insert into public.date_invitations(id,couple_id,creator_id,starts_at,venue,address,dress_style,message) values('{d}','{c}','{a}',now()+interval '2 days','Notification test','','Casual','Just a synthetic QA invitation.');
update public.date_notifications set due_at=now()-interval '1 second' where invitation_id='{d}' and kind<>'invitation';
update public.anniversary_notifications set due_at=now()-interval '1 second' where couple_id='{c}' and recipient_id='{b}' and anniversary_date=(select min(anniversary_date) from public.anniversary_notifications where couple_id='{c}');
select private.dispatch_date_notifications();select private.dispatch_anniversary_notifications();""")
for attempt in range(20):
 rows=query(f"select (select count(*) from public.date_notifications where invitation_id='{d}' and recipient_id='{b}' and delivered_at is not null) as dates,(select count(*) from public.anniversary_notifications where couple_id='{c}' and recipient_id='{b}' and due_at<=now() and delivered_at is not null) as anniversaries")
 if rows[0]['dates']==4 and rows[0]['anniversaries']==6:
  print('FCM delivery passed: invitation + 3 date reminders + 6 anniversary reminders delivered to the emulator.');break
 time.sleep(2)
else:raise RuntimeError('Push test did not finish; inspect delivery status.')
