import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/core/theme/lily_theme.dart';
import 'package:jigulove/features/auth/login_page.dart';
import 'package:jigulove/utils/auth_error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('used confirmation links explain both recovery paths', () {
    final message = authErrorMessage(
      const AuthException('expired', code: 'otp_expired'),
    );
    expect(message, contains('sign in'));
    expect(message, contains('fresh confirmation'));
  });

  testWidgets('callback error is visible and resend validates email locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Login(
          callbackError: authErrorMessage(
            const AuthException('expired', code: 'otp_expired'),
          ),
        ),
      ),
    );
    expect(find.textContaining('This link was already used'), findsOneWidget);
    await tester.ensureVisible(find.text('Resend confirmation email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resend confirmation email'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address above first.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
