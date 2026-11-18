// Local-only QA screen. Never included by lib/main.dart or a production build.
import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jigulove/core/config.dart';
import 'package:jigulove/features/date_planner/date_planner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jigulove/core/theme/lily_theme.dart';
import 'package:jigulove/features/moment_editor/moment_editor_page.dart';
import 'package:jigulove/managers/notification_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final folder = await getApplicationSupportDirectory();
  await Supabase.initialize(url: url, publishableKey: key);
  String? coupleId;
  final fixture = File('${folder.path}/qa-session.json');
  if (await fixture.exists()) {
    final data = jsonDecode(await fixture.readAsString());
    await db.auth.setSession(data['refresh_token']);
    coupleId = data['couple_id'];
  }
  final photo = File('${folder.path}/qa-lily.png');
  await photo.writeAsBytes(
    (await rootBundle.load('assets/jigu_logo.png')).buffer.asUint8List(),
  );
  await HomeWidget.saveWidgetData(
    'photos',
    jsonEncode([
      {
        'path': photo.path,
        'expires': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      },
    ]),
  );
  await HomeWidget.updateWidget(name: 'JiguWidgetProvider');
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    await File('${folder.path}/qa-fcm-token').writeAsString(token);
  });
  await FirebaseMessaging.instance.requestPermission();
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await File('${folder.path}/qa-fcm-token').writeAsString(token);
  }
  final notifications = NotificationManager();
  await notifications.initialize(() {});
  FirebaseMessaging.onMessage.listen(
    (message) => notifications.show(
      message.data['notification_id'] ?? message.messageId ?? 'qa',
      title: message.notification?.title ?? 'Jigu QA',
      body: message.notification?.body ?? 'QA notification',
      screen: message.data['screen'] ?? 'moments',
    ),
  );
  runApp(
    MaterialApp(
      theme: LilyTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Jigu feature preview')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.file(photo, width: 160),
                FilledButton(
                  onPressed: () async {
                    final bytes = await Navigator.push<Uint8List>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MomentEditorPage(path: photo.path),
                      ),
                    );
                    if (bytes != null && context.mounted) {
                      await File(
                        '${folder.path}/qa-edited.jpg',
                      ).writeAsBytes(bytes);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Edited photo exported'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Test camera editor'),
                ),
                if (coupleId != null)
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Date QA')),
                          body: DatePlannerPage(coupleId: coupleId!),
                        ),
                      ),
                    ),
                    child: const Text('Test date planner'),
                  ),
                TextButton(
                  onPressed: () =>
                      HomeWidget.requestPinWidget(name: 'JiguWidgetProvider'),
                  child: const Text('Test Moments widget'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
