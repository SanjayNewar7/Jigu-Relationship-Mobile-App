// Provision a dedicated FCM sender; never print credentials or API bodies.
const path = require('path');
const fs = require('fs');
const os = require('os');
const cp = require('child_process');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
const project = 'fir-faaa3';
async function main() {
  const account = auth.getGlobalDefaultAccount();
  const credentials = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  async function api(url, method='GET', body) {
    const r = await fetch(url, {method, headers:{Authorization:`Bearer ${credentials.access_token}`, 'Content-Type':'application/json'}, body:body ? JSON.stringify(body):undefined});
    const data = await r.json();
    if (!r.ok) throw new Error(`Google API ${r.status} at ${url}: ${data.error?.message || 'failed'}`);
    return data;
  }
  for (const service of ['iam.googleapis.com','fcm.googleapis.com']) {
    await api(`https://serviceusage.googleapis.com/v1/projects/816054990298/services/${service}:enable`, 'POST', {});
  }
  const email = `jigu-moment-sender@${project}.iam.gserviceaccount.com`;
  const base = `https://iam.googleapis.com/v1/projects/${project}/serviceAccounts`;
  const accounts = await api(base);
  if (!(accounts.accounts || []).some(a => a.email === email)) {
    await api(base, 'POST', {accountId:'jigu-moment-sender',serviceAccount:{displayName:'Jigu moment notifications'}});
  }
  const policyUrl = `https://cloudresourcemanager.googleapis.com/v1/projects/${project}`;
  const policy = await api(`${policyUrl}:getIamPolicy`, 'POST', {});
  policy.bindings ||= [];
  let binding = policy.bindings.find(b=>b.role==='roles/firebasecloudmessaging.admin' && !b.condition);
  if (!binding) {binding={role:'roles/firebasecloudmessaging.admin',members:[]};policy.bindings.push(binding);}
  if (!binding.members.includes(`serviceAccount:${email}`)) {
    binding.members.push(`serviceAccount:${email}`);
    await api(`${policyUrl}:setIamPolicy`, 'POST', {policy});
  }
  const existing = cp.spawnSync('supabase', ['secrets','list','--project-ref','dtjasplpglevmtagkrfp'], {encoding:'utf8'});
  if (existing.status===0 && existing.stdout.includes('FCM_SERVICE_ACCOUNT_B64')) {
    console.log('FCM sender already configured.');return;
  }
  const key = await api(`${base}/${email}/keys`, 'POST', {privateKeyType:'TYPE_GOOGLE_CREDENTIALS_FILE'});
  const folder = fs.mkdtempSync(path.join(os.tmpdir(),'jigu-fcm-'));
  const file = path.join(folder,'sender.env');
  try {
    fs.writeFileSync(file, `FCM_SERVICE_ACCOUNT_B64=${key.privateKeyData}\n`);
    const result = cp.spawnSync('supabase',['secrets','set','--project-ref','dtjasplpglevmtagkrfp','--env-file',file],{encoding:'utf8'});
    if (result.status!==0) {
      await api(`https://iam.googleapis.com/v1/${key.name}`, 'DELETE');
      throw new Error('Secret upload failed; generated key revoked');
    }
    console.log('Dedicated FCM sender configured; key stored only in Supabase Edge secrets.');
  } finally { fs.rmSync(file,{force:true});fs.rmdirSync(folder); }
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
