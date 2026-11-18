"""Disposable-account call lifecycle test. Never prints credentials or room tokens."""
from pathlib import Path
exec((Path(__file__).parent/'test_chat_live.py').read_text().split("if '--cleanup-device'")[0])
try:
 a,ta=user();b,tb=user();o,to=user()
 _,rows=call(f'rest/v1/profiles?id=eq.{a}&select=invite_code',token=ta)
 status,_=call('rest/v1/rpc/join_couple_v2','POST',{'invite':rows[0]['invite_code']},tb);assert status==200
 _,rows=call(f'rest/v1/profiles?id=eq.{a}&select=couple_id',token=ta);space=rows[0]['couple_id']
 status,r=call('functions/v1/partner-call','POST',{'action':'start','kind':'video'},ta)
 assert status==200,f'Call start failed (HTTP {status}); check LiveKit secrets/configuration'
 cid=r['call']['id'];assert r['call']['status']=='ringing'
 status,_=call('functions/v1/partner-call','POST',{'action':'token','call_id':cid},ta);assert status==409,'Token issued before acceptance'
 status,_=call('functions/v1/partner-call','POST',{'action':'accept','call_id':cid},to);assert status==403,'Outsider accepted call'
 status,r=call('functions/v1/partner-call','POST',{'action':'accept','call_id':cid},tb);assert status==200 and r['call']['status']=='accepted'
 tokens=[]
 for t in [ta,tb]:
  status,r=call('functions/v1/partner-call','POST',{'action':'token','call_id':cid},t);assert status==200,'Media token unavailable'
  assert r['url'].startswith('wss://') and r['token'].count('.')==2,'Invalid media configuration'
  tokens.append({'url':r['url'],'token':r['token']})
 print('PASS: configured media credentials, start/accept, room tokens and outsider denial.')
 if '--media' in sys.argv:
  p=ROOT/'.tmp/call-media-qa.json';p.write_text(json.dumps(tokens))
  try:
   result=subprocess.run(['node',str(ROOT/'tool/test_call_media.mjs')],cwd=ROOT,capture_output=True,text=True,timeout=70)
   print(result.stdout)
   assert result.returncode==0,'Live media test failed (provider/network); credentials were not printed'
  finally:p.unlink(missing_ok=True)
 status,r=call('functions/v1/partner-call','POST',{'action':'end','call_id':cid},tb);assert status==200 and r['call']['status']=='ended'
 status,_=call('functions/v1/partner-call','POST',{'action':'token','call_id':cid},ta);assert status==409,'Ended call token issued'
 print('PASS: hang-up and ended-call token denial.')
finally:
 if 'cid' in globals(): call('functions/v1/partner-call','POST',{'action':'end','call_id':cid},ta)
 if space:
  call('rest/v1/rpc/expire_partner_calls','POST',{},ADMIN)
  call(f'rest/v1/couples?id=eq.{space}','DELETE',token=ADMIN)
 for ident in users:call(f'auth/v1/admin/users/{ident}','DELETE',token=ADMIN)
 print('Disposable call accounts removed.')
