import { createClient } from 'npm:@supabase/supabase-js@2.106.1';
import { accessToken } from '../_shared/fcm.ts';
const preview = (m: {kind:string; body:string}) => m.kind === 'text'
  ? Array.from(m.body.trim()).slice(0, 100).join('')
  : ({image:'Sent a photo', video:'Sent a video', voice:'Sent a voice message', gif:'Sent a GIF'} as Record<string,string>)[m.kind] || 'Sent a message';

Deno.serve(async request => {
  const secret = Deno.env.get('JIGU_NOTIFICATION_SECRET');
  if (!secret || request.headers.get('x-jigu-notification-secret') !== secret) return new Response('Unauthorized', {status:401});
  if (request.method !== 'POST') return new Response('Method not allowed', {status:405});
  const encoded = Deno.env.get('FCM_SERVICE_ACCOUNT_B64');
  if (!encoded) return new Response('Sender not configured', {status:503});
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  try {
    const account = JSON.parse(atob(encoded));
    const token = await accessToken(account);
    const {data:jobs, error} = await db.rpc('claim_chat_notifications');
    if (error) throw error;
    const handled = new Set<string>();
    let sent = 0;
    for (const job of jobs ?? []) {
      const {data:message,error:messageError} = await db.from('chat_messages').select('couple_id,sender_id').eq('id',job.message_id).maybeSingle();
      if (messageError) throw messageError;
      if (!message) continue;
      const space = message.couple_id;
      const group = `${job.recipient_id}:${space}`;
      if (handled.has(group)) continue;
      handled.add(group);
      const {data:members,error:membersError} = await db.from('profiles').select('id,couple_id,display_name').in('id',[job.recipient_id,message.sender_id]);
      if (membersError) throw membersError;
      if (members?.length !== 2 || !members.every(p => p.couple_id === space)) {
        await db.from('chat_notifications').update({delivered_at:new Date().toISOString()}).eq('id',job.id);
        continue;
      }
      const {data:state,error:stateError} = await db.from('chat_state').select('read_at').eq('couple_id',space).eq('user_id',job.recipient_id).maybeSingle();
      if (stateError) throw stateError;
      const snapshot = new Date().toISOString();
      const {data:unread,count,error:unreadError} = await db.from('chat_messages')
        .select('id,body,kind,created_at',{count:'exact'}).eq('couple_id',space)
        .is('deleted_at',null)
        .neq('sender_id',job.recipient_id).gt('created_at',state?.read_at ?? '1970-01-01')
        .lte('created_at',snapshot).order('created_at',{ascending:false}).order('id',{ascending:false}).limit(7);
      if (unreadError) throw unreadError;
      let complete = true;
      if (unread?.length) {
        const title = members.find(p => p.id === message.sender_id)?.display_name?.trim() || 'Your person';
        const latest = unread[0];
        const rows = unread.slice().reverse().map(m => ({id:m.id,at:m.created_at,text:preview(m)}));
        while (new TextEncoder().encode(JSON.stringify(rows)).length > 2400 && rows.length > 1) rows.shift();
        const data = {screen:'chat',couple_id:space,recipient_id:job.recipient_id,
          sender_id:message.sender_id,title,message_id:latest.id,notification_id:latest.id,
          unread_count:String(count ?? rows.length),messages:JSON.stringify(rows)};
        const {data:devices,error:deviceError} = await db.from('notification_devices').select('token,platform,chat_version').eq('user_id',job.recipient_id);
        if (deviceError) throw deviceError;
        for (const device of devices ?? []) {
          const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
            method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
            body:JSON.stringify({message:{token:device.token,data,
              ...(device.platform === 'ios' || device.chat_version < 2 ? {notification:{title,body:preview(latest)}} : {}),
              android:{priority:'high',ttl:'3600s',collapse_key:`chat-${space}`,
                ...(device.chat_version < 2 ? {notification:{channel_id:'jigu_chat',tag:`chat-${space}`}} : {})},
              apns:{headers:{'apns-collapse-id':`chat-${space}`},payload:{aps:{sound:'default','thread-id':`chat-${space}`,category:'jigu_chat'}}},
            }}),
          });
          if (response.ok) { sent++; continue; }
          const failure = await response.json();
          const invalid = failure.error?.details?.some((d:{errorCode?:string}) => d.errorCode === 'UNREGISTERED');
          if (invalid) await db.from('notification_devices').delete().eq('token',device.token);
          else complete = false;
        }
      }
      if (complete) {
        // Acknowledge only claimed jobs from this same conversation.
        const {data:threadMessages,error:threadError} = await db.from('chat_messages').select('id')
          .eq('couple_id',space).in('id',(jobs ?? []).map((j:{message_id:string}) => j.message_id));
        if (threadError) throw threadError;
        const messageIds = new Set((threadMessages ?? []).map(m => m.id));
        const ids = (jobs ?? []).filter((j:{recipient_id:string;message_id:string}) => j.recipient_id === job.recipient_id && messageIds.has(j.message_id)).map((j:{id:string}) => j.id);
        await db.from('chat_notifications').update({delivered_at:new Date().toISOString()}).in('id',ids);
      }
    }
    return Response.json({processed:jobs?.length ?? 0,sent});
  } catch (_) { return new Response('Notification delivery will retry',{status:503}); }
});
