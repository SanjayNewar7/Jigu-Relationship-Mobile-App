"""One-time setup for the private Storage cleanup worker. Never prints secrets."""
import secrets
import subprocess
import tempfile
import urllib.request
from pathlib import Path

PROJECT = 'dtjasplpglevmtagkrfp'
ROOT = Path(__file__).resolve().parent.parent
check = subprocess.run(['supabase', 'db', 'query', '--linked',
    "select count(*) as existing from vault.secrets where name='jigu_cleanup_secret'"],
    cwd=ROOT, capture_output=True, text=True)
if check.returncode or not ('"existing": 0' in check.stdout or '"existing":0' in check.stdout):
    raise SystemExit('Cleanup is already configured or status could not be checked.')
secret = secrets.token_hex(32)
with tempfile.TemporaryDirectory(prefix='jigu-cleanup-') as folder:
    env_file = Path(folder) / '.env'
    sql_file = Path(folder) / 'schedule.sql'
    env_file.write_text(f'JIGU_CLEANUP_SECRET={secret}\n', encoding='ascii')
    sql_file.write_text(f"""
select vault.create_secret('{secret}', 'jigu_cleanup_secret');
select cron.schedule('jigu-cleanup-storage', '* * * * *', $job$
  select net.http_post(
    url := 'https://{PROJECT}.supabase.co/functions/v1/cleanup-moments',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-jigu-cleanup-secret',
      (select decrypted_secret from vault.decrypted_secrets where name='jigu_cleanup_secret')
    ),
    body := '{{}}'::jsonb
  );
$job$);
""", encoding='ascii')
    for args in [
        ['supabase', 'secrets', 'set', '--env-file', str(env_file)],
        ['supabase', 'db', 'query', '--linked', '--file', str(sql_file)],
    ]:
        result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(f'{args[1]} setup failed; inspect Supabase dashboard logs')
    request = urllib.request.Request(
        f'https://{PROJECT}.supabase.co/functions/v1/cleanup-moments',
        data=b'{}', headers={'Content-Type':'application/json','x-jigu-cleanup-secret':secret}, method='POST')
    with urllib.request.urlopen(request, timeout=20) as reply:
        print('Cleanup function responded:', reply.status)
print('Cleanup secret stored in Edge Functions and Vault; scheduled every minute.')
