import {readFileSync} from 'node:fs';
import {Room,RoomEvent,AudioSource,AudioFrame,LocalAudioTrack,TrackPublishOptions,TrackSource,TrackKind,AudioStream,VideoSource,VideoFrame,VideoBufferType,VideoStream,LocalVideoTrack,dispose} from '../.tmp/call-test/node_modules/@livekit/rtc-node/dist/index.js';
const config=JSON.parse(readFileSync(new URL('../.tmp/call-media-qa.json',import.meta.url)));
const rooms=[new Room(),new Room()];const got=new Set();const readers=[];const tracks=[];
let success=false;
try {
 for(let i=0;i<2;i++) {
  rooms[i].on(RoomEvent.TrackSubscribed,async(track)=>{
   const audio=track.kind===TrackKind.KIND_AUDIO;
   const reader=(audio?new AudioStream(track):new VideoStream(track)).getReader();readers.push(reader);
   try {const result=await reader.read();if(!result.done)got.add(`${i}-${audio?'audio':'video'}`);}catch{}
  });
 }
 await Promise.all(rooms.map((room,i)=>room.connect(config[i].url,config[i].token,{autoSubscribe:true})));
 const sources=[];
 for(const room of rooms) {
  const audio=new AudioSource(48000,1);const video=new VideoSource(160,120);sources.push({audio,video});
  const at=LocalAudioTrack.createAudioTrack('qa-audio',audio);const vt=LocalVideoTrack.createVideoTrack('qa-video',video);tracks.push(at,vt);
  const ao=new TrackPublishOptions();ao.source=TrackSource.SOURCE_MICROPHONE;
  const vo=new TrackPublishOptions();vo.source=TrackSource.SOURCE_CAMERA;
  await room.localParticipant.publishTrack(at,ao);await room.localParticipant.publishTrack(vt,vo);
 }
 for(let n=0;n<120&&got.size<4;n++) {
  for(const source of sources) {
   const samples=new Int16Array(960);for(let j=0;j<samples.length;j++)samples[j]=Math.round(700*Math.sin(j*.06));
   await source.audio.captureFrame(new AudioFrame(samples,48000,1,960));
   const pixels=new Uint8Array(160*120*4);pixels.fill(180);
   source.video.captureFrame(new VideoFrame(pixels,160,120,VideoBufferType.RGBA));
  }
  await new Promise(resolve=>setTimeout(resolve,40));
 }
 success=got.size===4;
 console.log(success?'PASS: both participants received real audio and video frames through LiveKit.':'FAIL: media frames did not arrive in both directions.');
}catch (e) {let message=String(e?.message??e);for(const item of config)message=message.replaceAll(item.token,'[redacted]');console.log('FAIL: '+message.replace(/eyJ[\w.-]+/g,'[redacted]').slice(0,1500));}
finally {
 for(const reader of readers)await reader.cancel().catch(()=>{});
 for(const track of tracks)await track.close().catch(()=>{});
 await Promise.all(rooms.map(room=>room.disconnect().catch(()=>{})));await dispose();
}
process.exit(success?0:1);
