"""Install a private worker credential into Vault and Edge secrets, without logging it."""
import secrets
import subprocess
import tempfile
from pathlib import Path

root=Path(__file__).resolve().parent.parent
check=subprocess.run(['supabase','db','query','--linked',"select count(*) as existing from vault.secrets where name='jigu_notification_secret'"],cwd=root,capture_output=True,text=True)
if check.returncode or not ('"existing": 0' in check.stdout or '"existing":0' in check.stdout):
    raise SystemExit('Already configured, or status unavailable.')
secret=secrets.token_hex(32)
with tempfile.TemporaryDirectory(prefix='jigu-notification-') as folder:
    env=Path(folder)/'worker.env'
    sql=Path(folder)/'worker.sql'
    env.write_text(f'JIGU_NOTIFICATION_SECRET={secret}\n')
    sql.write_text(f"select vault.create_secret('{secret}','jigu_notification_secret');")
    for command in [['supabase','secrets','set','--env-file',str(env)],['supabase','db','query','--linked','--file',str(sql)]]:
        result=subprocess.run(command,cwd=root,capture_output=True,text=True)
        if result.returncode: raise SystemExit('Worker configuration failed; no secret printed.')
print('Notification worker credential installed.')
