-- The secret is provisioned separately in Vault by tool/configure_cleanup.py.
-- No credential is stored in this migration or in mobile code.
select cron.schedule('jigu-cleanup-storage', '* * * * *', $job$
  select net.http_post(
    url := 'https://dtjasplpglevmtagkrfp.supabase.co/functions/v1/cleanup-moments',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-jigu-cleanup-secret',
      (select decrypted_secret from vault.decrypted_secrets where name='jigu_cleanup_secret')
    ),
    body := '{}'::jsonb
  );
$job$);
