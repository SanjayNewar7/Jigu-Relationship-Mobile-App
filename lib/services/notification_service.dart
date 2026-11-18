import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

class NotificationService {
  Future<bool> enable() async {
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await register(token);
    return true;
  }

  Future<void> register(String token) async {
    if (db.auth.currentUser == null) return;
    await db.rpc(
      'register_notification_device',
      params: {
        'device_token': token,
        'device_platform': Platform.isIOS ? 'ios' : 'android',
      },
    );
    await (await SharedPreferences.getInstance()).setString(
      'jigu_notification_user',
      db.auth.currentUser!.id,
    );
    await db.rpc(
      'enable_chat_notification_v2',
      params: {'device_token': token},
    );
    await (await SharedPreferences.getInstance()).setString(
      'jigu_notification_token',
      token,
    );
  }

  Future<void> unregister() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jigu_notification_user');
    final token = prefs.getString('jigu_notification_token');
    try {
      if (token != null) {
        await db.from('notification_devices').delete().eq('token', token);
      }
    } finally {
      await FirebaseMessaging.instance.deleteToken();
      await prefs.remove('jigu_notification_token');
    }
  }
}
