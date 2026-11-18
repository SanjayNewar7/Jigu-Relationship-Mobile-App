import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jigulove/services/chat_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  final calls = <MethodCall>[];
  final active = <Map<String, dynamic>>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    active.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            calls.add(call);
            if (call.method == 'getActiveNotifications') return active;
            return null;
          },
        );
  });
  Map<String, dynamic> data(int count) => {
    'couple_id': 'space',
    'title': 'Your person',
    'sender_id': 'partner',
    'unread_count': '$count',
    'messages': jsonEncode(
      List.generate(
        count,
        (i) => {
          'id': '$i',
          'at': '2026-11-18T10:00:0${i + 1}Z',
          'text': 'Message $i',
        },
      ),
    ),
  };
  test(
    'reading after an upgrade removes old ungrouped chat cards only',
    () async {
      active.addAll([
        {'id': 123, 'channelId': 'jigu_chat'},
        {'id': 456, 'channelId': 'jigu_dates'},
      ]);
      await ChatNotifications.clearThrough('space', DateTime.now());
      final cancelled = calls
          .where((c) => c.method == 'cancel')
          .map((c) => c.arguments['id']);
      expect(cancelled, contains(123));
      expect(cancelled, isNot(contains(456)));
    },
  );
  test(
    'bursts update one card with chronological messages and actions',
    () async {
      await ChatNotifications.show(data(1));
      await ChatNotifications.show(data(3));
      final shows = calls.where((c) => c.method == 'show').toList();
      expect(shows, hasLength(2));
      expect(shows.first.arguments['id'], shows.last.arguments['id']);
      final android = shows.last.arguments['platformSpecifics'] as Map;
      expect(android['tag'], 'chat-space');
      expect(android['actions'], hasLength(2));
    },
  );
  test(
    'read cancels card and delayed pushes cannot restore read messages',
    () async {
      await ChatNotifications.show(data(3));
      await ChatNotifications.clearThrough(
        'space',
        DateTime.parse('2026-11-18T10:00:03Z'),
      );
      expect(calls.where((c) => c.method == 'cancel'), isNotEmpty);
      calls.clear();
      await ChatNotifications.show(data(2));
      expect(calls.where((c) => c.method == 'show'), isEmpty);
    },
  );
  test('acting on an older card does not dismiss a newer arrival', () async {
    await ChatNotifications.show(data(3));
    calls.clear();
    await ChatNotifications.clearThrough(
      'space',
      DateTime.parse('2026-11-18T10:00:01Z'),
    );
    expect(calls.where((c) => c.method == 'cancel'), isEmpty);
  });
}
