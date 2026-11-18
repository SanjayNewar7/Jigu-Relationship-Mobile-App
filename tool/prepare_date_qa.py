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

state=Path('tool/date-qa-state.json')
if len(sys.argv)>1 and sys.argv[1]=='cleanup':
 data=json.loads(state.read_text())
 paths=query(f"select selfie_path from public.date_invitations where couple_id='{data['couple_id']}' and selfie_path is not null")
 if paths:
  request=urllib.request.Request('https://dtjasplpglevmtagkrfp.supabase.co/storage/v1/object/date-memories',data=json.dumps({'prefixes':[p['selfie_path'] for p in paths]}).encode(),method='DELETE',headers={'apikey':admin,'Authorization':'Bearer '+admin,'Content-Type':'application/json'})
  with urllib.request.urlopen(request) as result: result.read()
 for uid in data['users']: query(f"delete from auth.users where id='{uid}' and email like 'jigu-qa-%@example.invalid'")
 print('Synthetic date accounts and photos removed.')
 sys.exit(0)
a,_,_=create_user(); b,email,password=create_user()
try:
 rows=query(f"begin;select set_config('request.jwt.claim.sub','{a}',true);select public.join_couple((select invite_code from public.profiles where id='{b}')) as couple_id;commit;")
 c=next(row['couple_id'] for row in rows if 'couple_id' in row)
 query(f"""insert into public.date_invitations(couple_id,creator_id,starts_at,venue,address,dress_style,message,latitude,longitude)
 select '{c}','{a}',now()+n*interval '1 day','Lily picnic '||n,'By the garden entrance','Matching colours','A quiet afternoon and my favourite person.',27.683,84.433 from generate_series(1,12) n;
 insert into public.date_invitations(couple_id,creator_id,starts_at,venue,address,dress_style,message,status,completed_at)
 select '{c}','{a}',now()-n*interval '1 day','Our lovely memory '||n,'','Casual','A little more us.','completed',now()-n*interval '1 day' from generate_series(1,12) n;
 insert into public.date_invitations(couple_id,creator_id,starts_at,venue,address,dress_style,message,status)
 values('{c}','{a}',now()-interval '1 hour','A selfie together','','Come as you are','Keep this little moment.','accepted');
 update public.couples set started_on='2020-12-15' where id='{c}';""")
 status,session=api('auth/v1/token?grant_type=password',{'email':email,'password':password})
 if status!=200: raise RuntimeError('QA sign-in failed')
 fixture=json.dumps({'refresh_token':session['refresh_token'],'couple_id':c})
 subprocess.run(['adb','-s','emulator-5554','shell','run-as','com.sanjaya.jigulove','tee','files/qa-session.json'],input=fixture.encode(),capture_output=True,check=True)
 state.write_text(json.dumps({'couple_id':c,'users':[a,b]}))
 print('Isolated date fixture ready: 13 plans, 12 memories.')
except:
 for uid in created: query(f"delete from auth.users where id='{uid}' and email like 'jigu-qa-%@example.invalid'")
 raise
