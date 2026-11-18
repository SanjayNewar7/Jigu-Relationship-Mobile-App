"""Isolated live RLS check. Uses disposable auth users and deletes them."""
import json, subprocess, tempfile, uuid, urllib.request, urllib.error
from pathlib import Path

BASE='https://dtjasplpglevmtagkrfp.supabase.co/'
PUB='sb_publishable_q3BBWv0BmSRnwApM7YH99w_5gHQV7KF'
raw=subprocess.run(['supabase','projects','api-keys','--project-ref','dtjasplpglevmtagkrfp','--reveal','-o','json'],capture_output=True,text=True,check=True)
keys=json.loads(raw.stdout)
if isinstance(keys,dict): keys=keys.get('api_keys',keys.get('keys',[]))
admin=next(key['api_key'] for key in keys if key.get('name')=='service_role')
users=[]

def query(sql):
 with tempfile.TemporaryDirectory(prefix='jigu-place-qa-') as folder:
  file=Path(folder)/'query.sql';file.write_text(sql)
  process=subprocess.run(['supabase','db','query','--linked','--file',str(file)],capture_output=True,text=True,check=True)
  body=process.stdout
  return json.loads(body[body.find('{'):body.rfind('}')+1]).get('rows',[])

def api(path,method='GET',body=None,token=None):
 payload=None if body is None else json.dumps(body).encode()
 headers={'apikey':PUB,'Authorization':'Bearer '+(token or PUB),'Content-Type':'application/json','Prefer':'return=representation'}
 request=urllib.request.Request(BASE+path,data=payload,headers=headers,method=method)
 try:
  with urllib.request.urlopen(request,timeout=45) as response:
   content=response.read()
   return response.status,json.loads(content) if content else None
 except urllib.error.HTTPError as error:
  content=error.read()
  return error.code,json.loads(content) if content else None

def create_user():
 email=f'jigu-place-qa-{uuid.uuid4()}@example.invalid'
 password=f'{uuid.uuid4()}Az1!'
 status,user=api('auth/v1/admin/users','POST',{'email':email,'password':password,'email_confirm':True},admin)
 assert status in (200,201),status
 users.append(user['id'])
 status,session=api('auth/v1/token?grant_type=password','POST',{'email':email,'password':password})
 assert status==200,status
 return user['id'],session['access_token']

try:
 a,token_a=create_user();b,token_b=create_user();_,outsider=create_user()
 rows=query(f"begin;select set_config('request.jwt.claim.sub','{a}',true);select public.join_couple((select invite_code from public.profiles where id='{b}')) as couple_id;commit;")
 couple=next(row['couple_id'] for row in rows if 'couple_id' in row)
 place={'couple_id':couple,'created_by':a,'name':'Our riverside spot','address':'Near Bharatpur, Chitwan','latitude':27.683,'longitude':84.433,'category':'Riverside','source':'manual','is_favorite':True}
 status,created=api('rest/v1/date_places','POST',place,token_a)
 assert status==201,(status,created)
 identifier=created[0]['id']
 status,partner=api('rest/v1/date_places?select=id,name,is_favorite',token=token_b)
 assert status==200 and any(row['id']==identifier for row in partner),(status,partner)
 status,hidden=api('rest/v1/date_places?select=id',token=outsider)
 assert status==200 and not hidden,(status,hidden)
 status,_=api('rest/v1/date_places','POST',{**place,'created_by':users[-1]},outsider)
 assert status>=400,status
 status,_=api('rest/v1/date_places','POST',{**place,'latitude':900},token_a)
 assert status>=400,status
 status,changed=api(f'rest/v1/date_places?id=eq.{identifier}','PATCH',{'is_favorite':False},token_b)
 assert status==200 and changed[0]['is_favorite'] is False,(status,changed)
 print('Date places passed: valid save, partner visibility, outsider isolation, coordinate limit, shared favourite update.')
finally:
 for user in users:
  query(f"delete from auth.users where id='{user}' and email like 'jigu-place-qa-%@example.invalid'")
 print('Synthetic place accounts removed.')
