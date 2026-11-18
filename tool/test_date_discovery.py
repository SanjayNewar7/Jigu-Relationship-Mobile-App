import json, subprocess, tempfile, uuid, urllib.request, urllib.error, sys, re
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
try:
 a,email,password=create_user();b,_,_=create_user()
 query(f"begin;select set_config('request.jwt.claim.sub','{a}',true);select public.join_couple((select invite_code from public.profiles where id='{b}'));commit;")
 status,session=api('auth/v1/token?grant_type=password',{'email':email,'password':password})
 if status!=200:raise RuntimeError(f'QA login failed: HTTP {status}')
 status,data=api('functions/v1/date-discovery',{'latitude':27.683,'longitude':84.433,'radius':int(sys.argv[1]) if len(sys.argv)>1 else 15000},session['access_token'])
 print('Discovery HTTP:',status)
 if status==200:
  print('City:',data.get('city'),'Places:',len(data.get('places',[])))
  print('Categories:',sorted(set(p['category'] for p in data['places'])))
  assert len({p['id'] for p in data['places']})==len(data['places'])
  assert all(p['distance']<=data['radius'] for p in data['places'])
  assert all(p['title'] and p['description'] for p in data['places'])
  blocked=re.compile(r'\b(gym|fitness|football|soccer|stadium|bank|atm|hospital|clinic|medical|guest\s*house|hostel|private\s*house|residence|apartment|market|bazaar|wholesale|warehouse|school|college|office|bus\s*stop|parking)\b',re.I)
  assert not [p['name'] for p in data['places'] if blocked.search(p['name'])]
  print('Maximum suggestion distance (km):',round(max((p['distance'] for p in data['places']),default=0)/1000,1))
 else:print('Search status:',data.get('error','Unavailable'))
finally:
 for uid in created: query(f"delete from auth.users where id='{uid}' and email like 'jigu-qa-%@example.invalid'")
 print('Synthetic accounts removed')
