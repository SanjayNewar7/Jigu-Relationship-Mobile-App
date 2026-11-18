import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/auth/forgot_password_page.dart';
import 'package:jigulove/features/auth/password_page.dart';
import 'package:jigulove/features/settings/settings_page.dart';
import 'package:jigulove/features/settings/delete_account_page.dart';

void main() {
  testWidgets('settings opens the privacy policy and developer details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          email: 'person@example.com',
          sharing: false,
          paired: false,
          onSharing: (_) async {},
          onLogout: () async {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Privacy policy'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text('What Jigu is'), findsOneWidget);
    expect(find.text('Information you give us'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('About Jigu & developer'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('About Jigu & developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Jigu & developer'));
    await tester.pumpAndSettle();
    expect(find.text('Sanjaya Rajbhandari'), findsOneWidget);
    expect(find.text('sanjayarajbhandari.com.np'), findsOneWidget);
  });

  testWidgets('change password checks repeated value before calling auth', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PasswordPage(recovery: false, onFinished: () {})),
    );
    await tester.enterText(find.byType(TextField).at(0), 'old-password');
    await tester.enterText(find.byType(TextField).at(1), 'new-password-123');
    await tester.enterText(find.byType(TextField).at(2), 'another-password');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('The new passwords do not match.'), findsOneWidget);
  });

  testWidgets('forgot password validates email before sending', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('account deletion requires password and typed confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountPage(
          email: 'person@example.com',
          onDeleted: () async {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Permanently delete account'), 180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Permanently delete account'));
    await tester.pump();
    expect(
      find.text('Enter your password and type DELETE to confirm.'),
      findsOneWidget,
    );
    expect(find.textContaining('shared moments, date plans'), findsOneWidget);
  });
}
