import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../managers/notification_manager.dart';
import '../services/notification_service.dart';
import '../services/chat_visibility.dart';
import '../services/chat_notifications.dart';

class NotificationController {
  final service = NotificationService();
  final manager = NotificationManager();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seen = {};
  bool _disposed = false;

  Future<void> start(void Function(String) onTap) async {
    if (Firebase.apps.isEmpty) return;
    await manager.initialize(() => onTap('moments'), onDestination: onTap);
    if (_disposed) return;
    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        service.register(token).catchError((_) {});
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        if (message.data['screen'] == 'chat' &&
            ChatVisibility.viewing(message.data['couple_id'])) {
          return;
        }
        if (message.data['screen'] == 'chat' &&
            message.data['messages'] != null) {
          ChatNotifications.show(message.data).catchError((_) {});
          return;
        }
        final id =
            message.data['notification_id'] ??
            message.data['moment_id'] ??
            message.messageId;
        if (id != null && _seen.add(id)) {
          manager
              .show(
                id,
                title: message.notification?.title ?? 'A little moment for you',
                body:
                    message.notification?.body ??
                    'Open Jigu to see what is waiting.',
                screen: message.data['screen'] ?? 'moments',
              )
              .catchError((_) {});
        }
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => onTap(message.data['screen'] ?? 'moments'),
      ),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (!_disposed && initial != null) {
      onTap(initial.data['screen'] ?? 'moments');
    }
    await service.enable();
  }

  Future<void> logout() async {
    try {
      if (Firebase.apps.isNotEmpty) await service.unregister();
    } catch (_) {
      /* Local logout must also work offline. */
    }
    await manager.clear();
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }
}
