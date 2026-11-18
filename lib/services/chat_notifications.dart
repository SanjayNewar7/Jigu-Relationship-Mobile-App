import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import 'chat_service.dart';

/// Stable across processes, unlike a per-message notification ID.
int chatNotificationId(String space) {
  var hash = 2166136261;
  for (final byte in utf8.encode('chat:$space')) {
    hash = ((hash ^ byte) * 16777619) & 0x7fffffff;
  }
  return hash;
}

class ChatNotifications {
  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void> show(Map<String, dynamic> data) async {
    final space = data['couple_id'] as String?;
    if (space == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (data['recipient_id'] != null &&
        data['recipient_id'] != prefs.getString('jigu_notification_user')) {
      return;
    }
    final read = DateTime.tryParse(prefs.getString('chat_read:$space') ?? '');
    final rows = (jsonDecode(data['messages'] as String? ?? '[]') as List)
        .cast<Map<String, dynamic>>()
        .where((m) => read == null || DateTime.parse(m['at']).isAfter(read))
        .toList();
    if (rows.isEmpty) return;
    final newest = DateTime.parse(rows.last['at']);
    final shown = DateTime.tryParse(prefs.getString('chat_shown:$space') ?? '');
    if (shown != null && newest.isBefore(shown)) return;
    await prefs.setString('chat_shown:$space', newest.toIso8601String());
    final sender = Person(
      name: data['title'] ?? 'Your person',
      key: data['sender_id'],
    );
    await plugin.show(
      id: chatNotificationId(space),
      title: sender.name,
      body: rows.last['text'],
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'jigu_chat',
          'Messages from your person',
          tag: 'chat-$space',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          number: int.tryParse(data['unread_count'] ?? '') ?? rows.length,
          styleInformation: MessagingStyleInformation(
            const Person(name: 'You'),
            groupConversation: false,
            messages: rows
                .map((m) => Message(m['text'], DateTime.parse(m['at']), sender))
                .toList(),
          ),
          actions: const [
            AndroidNotificationAction(
              'chat_reply',
              'Reply',
              inputs: [AndroidNotificationActionInput(label: 'Your message')],
              cancelNotification: false,
            ),
            AndroidNotificationAction(
              'chat_read',
              'Mark as read',
              cancelNotification: false,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: 'chat-$space',
          categoryIdentifier: 'jigu_chat',
        ),
      ),
    );
  }

  static Future<void> clearThrough(String space, DateTime cutoff) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final previous = DateTime.tryParse(
      prefs.getString('chat_read:$space') ?? '',
    );
    if (previous == null || cutoff.isAfter(previous)) {
      await prefs.setString(
        'chat_read:$space',
        cutoff.toUtc().toIso8601String(),
      );
    }
    final shown = DateTime.tryParse(prefs.getString('chat_shown:$space') ?? '');
    if (shown == null || !shown.isAfter(cutoff)) {
      await plugin.cancel(id: chatNotificationId(space), tag: 'chat-$space');
    }
    // Remove legacy FCM cards for this conversation too.
    for (final notification in await plugin.getActiveNotifications()) {
      if (notification.id != null &&
          (notification.tag == 'chat-$space' ||
              (notification.tag == null &&
                  notification.channelId == 'jigu_chat')) &&
          notification.id != chatNotificationId(space)) {
        await plugin.cancel(id: notification.id!, tag: notification.tag);
      }
    }
  }

  static Future<void> action(NotificationResponse response) async {
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    final space = data['couple_id'] as String;
    try {
      if (db.auth.currentUser?.id != data['recipient_id']) return;
      if (response.actionId == 'chat_reply') {
        final reply = response.input?.trim() ?? '';
        if (reply.isEmpty) return;
        final service = ChatService();
        // Persist one ID so an interrupted action can be retried safely.
        final prefs = await SharedPreferences.getInstance();
        final retryKey = 'chat_reply:${data['message_id']}:$reply';
        final id = prefs.getString(retryKey) ?? service.newId();
        await prefs.setString(retryKey, id);
        await service.sendText(space, reply, id, checkExisting: true);
      }
      final cutoff = await db.rpc(
        'read_chat_through',
        params: {'space': space, 'message_id': data['message_id']},
      );
      await clearThrough(space, DateTime.parse(cutoff as String));
    } catch (_) {
      await plugin.show(
        id: chatNotificationId(space),
        title: 'Could not update your chat',
        body: 'Check your connection, then open Jigu to try again.',
        payload: response.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'jigu_chat',
            'Messages from your person',
            tag: 'chat-$space',
            visibility: NotificationVisibility.private,
          ),
        ),
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> chatNotificationAction(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: url, publishableKey: key);
  await ChatNotifications.action(response);
}

@pragma('vm:entry-point')
Future<void> jiguBackgroundMessage(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  if (message.data['screen'] != 'chat' || !Platform.isAndroid) return;
  await ChatNotifications.plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    ),
    onDidReceiveBackgroundNotificationResponse: chatNotificationAction,
  );
  await ChatNotifications.show(message.data);
}
