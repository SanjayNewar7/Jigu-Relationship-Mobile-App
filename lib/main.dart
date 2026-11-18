import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/chat_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (_) => const Material(
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This part of Jigu could not open. Please go back and try again.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(jiguBackgroundMessage);
  } catch (_) {
    // Jigu can still open when push messaging is temporarily unavailable.
  }
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(
        persistSession: true,
        autoRefreshToken: true,
      ),
    );
  }
  runApp(const Jigu());
}
