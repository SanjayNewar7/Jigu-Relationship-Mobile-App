"""Send one isolated QA moment to the emulator through the real queue/worker.
Only synthetic accounts are created; no partner notification is sent.
"""
import json
import re
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

root=Path(__file__).resolve().parent.parent
token=subprocess.check_output(['adb','-s','emulator-5554','shell','run-as','com.sanjaya.jigulove','cat','files/qa-fcm-token'],text=True).strip()
if not re.fullmatch(r'[A-Za-z0-9_:\-]+',token): raise SystemExit('No valid emulator token')
a,b,m=[str(uuid.uuid4()) for _ in range(3)]
def query(sql):
    with tempfile.TemporaryDirectory(prefix='jigu-push-test-') as folder:
        file=Path(folder)/'query.sql';file.write_text(sql)
        result=subprocess.run(['supabase','db','query','--linked','--file',str(file)],cwd=root,capture_output=True,text=True)
        if result.returncode: raise RuntimeError('QA query failed (credentials and row data withheld).')
        start=result.stdout.find('{');end=result.stdout.rfind('}')
        return json.loads(result.stdout[start:end+1]).get('rows',[])
try:
    query(f"""
    begin;
    insert into auth.users(id,email,aud,role) values
      ('{a}','jigu-qa-{a}@example.invalid','authenticated','authenticated'),
      ('{b}','jigu-qa-{b}@example.invalid','authenticated','authenticated');
    select set_config('request.jwt.claim.sub','{a}',true);
    select public.join_couple((select invite_code from public.profiles where id='{b}'));
    insert into public.notification_devices(token,user_id,platform) values('{token}','{b}','android');
    insert into public.moments(id,couple_id,author_id,storage_path)
      select '{m}',couple_id,'{a}',couple_id::text||'/qa-notification-{m}.jpg' from public.profiles where id='{a}';
    commit;
    """)
    for _ in range(12):
        rows=query(f"select delivered_at is not null as delivered,attempts from public.moment_notifications where moment_id='{m}'")
        if rows and rows[0]['delivered']:
            print('Real Supabase moment trigger -> Edge worker -> FCM: delivered to emulator.');break
        time.sleep(3)
    else: raise RuntimeError('Notification did not complete in the test window.')
finally:
    query(f"delete from auth.users where id in ('{a}','{b}') and email like 'jigu-qa-%@example.invalid';")
    print('Synthetic QA accounts removed.')
