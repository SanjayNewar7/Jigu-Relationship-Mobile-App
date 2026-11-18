package com.sanjaya.jigu
import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.content.pm.ServiceInfo
class JiguCallService:Service() {
 override fun onBind(intent:Intent?):IBinder?=null
 override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
  val manager=getSystemService(NotificationManager::class.java)
  if(Build.VERSION.SDK_INT>=26) manager.createNotificationChannel(NotificationChannel("jigu_ongoing_call","Ongoing calls",NotificationManager.IMPORTANCE_LOW))
  val pending=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val builder=if(Build.VERSION.SDK_INT>=26) Notification.Builder(this,"jigu_ongoing_call") else Notification.Builder(this)
  val notification=builder.setContentTitle("Your Jigu call").setContentText("Tap to return to your call").setSmallIcon(R.drawable.ic_notification).setOngoing(true).setContentIntent(pending).setCategory(Notification.CATEGORY_CALL).build()
  if(Build.VERSION.SDK_INT>=30)startForeground(8712,notification,ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)else startForeground(8712,notification)
  return START_NOT_STICKY
 }
 override fun onTaskRemoved(rootIntent:Intent?) {stopSelf();super.onTaskRemoved(rootIntent)}
}
