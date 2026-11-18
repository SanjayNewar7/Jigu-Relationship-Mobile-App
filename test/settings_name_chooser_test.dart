import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/settings/settings_page.dart';

void main() {
  testWidgets('one Settings row offers both name choices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          email: 'test@example.com',
          name: 'Sanjaya',
          partnerName: 'Lily',
          sharing: false,
          paired: true,
          onSharing: (_) async {},
          onLogout: () async {},
        ),
      ),
    );
    expect(find.text('Set names'), findsOneWidget);
    expect(find.text('Your partner’s name'), findsNothing);
    await tester.tap(find.text('Set names'));
    await tester.pumpAndSettle();
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Your partner’s name'), findsOneWidget);
    await tester.tap(find.text('Your partner’s name'));
    await tester.pumpAndSettle();
    expect(find.text('What will you call your partner?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
