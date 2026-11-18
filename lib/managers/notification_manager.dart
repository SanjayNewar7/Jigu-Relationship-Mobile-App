import 'dart:convert';
import '../services/chat_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  Map<String, dynamic> messages = {};
  static String channelId(String screen) => switch (screen) {
    'calls' => 'jigu_calls',
    'chat' => 'jigu_chat',
    'dates' => 'jigu_dates',
    'anniversary' => 'jigu_anniversaries',
    _ => 'jigu_moments',
  };
  static String channelName(String screen) => switch (screen) {
    'calls' => 'Calls from your person',
    'chat' => 'Messages from your person',
    'dates' => 'Dates and invitations',
    'anniversary' => 'Our anniversaries',
    _ => 'Shared moments',
  };
  final plugin = FlutterLocalNotificationsPlugin();
  static const channel = AndroidNotificationChannel(
    'jigu_moments',
    'Shared moments',
    description: 'A new moment from your person',
    importance: Importance.high,
  );

  Future<void> initialize(
    void Function() onTap, {
    void Function(String)? onDestination,
  }) async {
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'jigu_chat',
            'Messages from your person',
            description: 'New messages in your shared space',
            importance: Importance.high,
          ),
        );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'jigu_calls',
            'Calls from your person',
            importance: Importance.max,
            description: 'Incoming voice and video calls',
          ),
        );
    messages =
        jsonDecode(
              await rootBundle.loadString(
                'supabase/functions/_shared/notification_copy.json',
              ),
            )
            as Map<String, dynamic>;
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'jigu_anniversaries',
            'Our anniversaries',
            description: 'Gentle countdowns to your day together',
            importance: Importance.high,
          ),
        );
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'chat_reply' ||
            response.actionId == 'chat_read') {
          ChatNotifications.action(response);
          return;
        }
        if (onDestination != null) {
          onDestination(
            response.payload?.startsWith('{') == true
                ? 'chat'
                : response.payload ?? 'moments',
          );
        } else {
          onTap();
        }
      },
      onDidReceiveBackgroundNotificationResponse: chatNotificationAction,
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch?.notificationResponse?.payload;
      onDestination?.call(
        payload?.startsWith('{') == true ? 'chat' : payload ?? 'moments',
      );
    }
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'jigu_dates',
            'Dates and invitations',
            description: 'Invitations and gentle date reminders',
            importance: Importance.high,
          ),
        );
  }

  Future<void> show(
    String id, {
    String title = 'A little moment for you',
    String body = 'Your person shared a photo. Open your space to see it.',
    String screen = 'moments',
  }) => plugin.show(
    id: id.hashCode & 0x7fffffff,
    title: title,
    body: body,
    payload: screen,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId(screen),
        channelName(screen),
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );

  Future<void> showTemplate(String id, String kind, {required String screen}) {
    final copy =
        messages[kind] as Map<String, dynamic>? ??
        messages['moment'] as Map<String, dynamic>?;
    return show(
      id,
      title: copy?['title'] ?? 'A little love from Jigu',
      body: copy?['body'] ?? 'Open our little space.',
      screen: screen,
    );
  }

  Future<void> clear() => plugin.cancelAll();
}
