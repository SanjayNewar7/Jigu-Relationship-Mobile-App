import { createClient } from 'npm:@supabase/supabase-js@2.106.1';
import { accessToken } from '../_shared/fcm.ts';

import messages from '../_shared/notification_copy.json' with { type: 'json' };
const copy = messages as Record<string, {title:string;body:string}>;
Deno.serve(async request => {
  const secret=Deno.env.get('JIGU_NOTIFICATION_SECRET');
  if (!secret || request.headers.get('x-jigu-notification-secret')!==secret) return new Response('Unauthorized',{status:401});
  if (request.method!=='POST') return new Response('Method not allowed',{status:405});
  const encoded=Deno.env.get('FCM_SERVICE_ACCOUNT_B64');
  if (!encoded) return new Response('Sender not configured',{status:503});
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  try {
    const account=JSON.parse(atob(encoded));
    const token=await accessToken(account);
    const {data:jobs,error}=await db.rpc('claim_date_notifications');
    if (error) throw error;
    let sent=0;
    for (const job of jobs ?? []) {
      const {data:date}=await db.from('date_invitations').select('couple_id,status,starts_at').eq('id',job.invitation_id).maybeSingle();
      const {data:members}=await db.from('profiles').select('id').eq('couple_id',date?.couple_id ?? '00000000-0000-0000-0000-000000000000');
      const response=['accepted','declined'].includes(job.kind);
      const valid=date && (response ? date.status===job.kind : ['pending','accepted'].includes(date.status) && Date.parse(date.starts_at)>Date.now()) && members?.length===2 && members.some(p=>p.id===job.recipient_id);
      if (!valid) { await db.from('date_notifications').update({delivered_at:new Date().toISOString()}).eq('id',job.id); continue; }
      const {data:devices,error:deviceError}=await db.from('notification_devices').select('token').eq('user_id',job.recipient_id);
      if (deviceError) continue;
      let complete=true;
      const ttl=response?3600:Math.max(1,Math.min(3600,Math.floor((Date.parse(date.starts_at)-Date.now())/1000)));
      for (const device of devices ?? []) {
        const response=await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token:device.token,notification:copy[`date_${job.kind}`],data:{date_id:job.invitation_id,notification_id:job.id,screen:'dates'},android:{priority:'high',ttl:`${ttl}s`,notification:{channel_id:'jigu_dates',tag:job.id}},apns:{headers:{'apns-collapse-id':job.id,'apns-expiration':String(Math.floor(Date.now()/1000)+ttl)},payload:{aps:{sound:'default'}}}}})});
        if (response.ok) {sent++;continue;}
        const failure=await response.json();
        if (failure.error?.details?.some((d:{errorCode?:string})=>d.errorCode==='UNREGISTERED')) await db.from('notification_devices').delete().eq('token',device.token);
        else complete=false;
      }
      if (complete) await db.from('date_notifications').update({delivered_at:new Date().toISOString()}).eq('id',job.id);
    }
    return Response.json({processed:jobs?.length ?? 0,sent});
  } catch { return new Response('Date delivery will retry',{status:503}); }
});
