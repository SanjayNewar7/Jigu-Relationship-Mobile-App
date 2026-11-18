import { RoomServiceClient } from 'npm:livekit-server-sdk@2.20.0';
export function mediaConfig() {
 const url=Deno.env.get('LIVEKIT_URL'), key=Deno.env.get('LIVEKIT_API_KEY'), secret=Deno.env.get('LIVEKIT_API_SECRET');
 if(!url||!key||!secret) throw new Error('Calls are not configured yet. Please try again later.');
 if(!url.startsWith('wss://') || new URL(url).hostname==='cloud.livekit.io') throw new Error('Calls are not configured yet. The media server URL must start with wss://.');
 return {url,key,secret};
}
export const roomName=(id:string)=>`jigu-${id}`;
export async function closeRoom(id:string) {
 const c=mediaConfig();
 const rooms=new RoomServiceClient(c.url.replace('wss://','https://'),c.key,c.secret);
 try {await rooms.deleteRoom(roomName(id));} catch(e) {
  if((e as {status?:number}).status!==404 && (e as {code?:string}).code!=='not_found') throw e;
 }
}
