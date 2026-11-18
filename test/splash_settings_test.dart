import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/splash/splash_view.dart';
import 'package:jigulove/features/settings/settings_page.dart';
import 'package:jigulove/core/theme/lily_theme.dart';

void main() {
  testWidgets('lily appears before letters and completion waits for the hold', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashView(onComplete: () => completed++)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<Opacity>(find.byKey(const ValueKey('lily-fade'))).opacity,
      greaterThan(0),
    );
    expect(
      tester.widget<Opacity>(find.byKey(const ValueKey('letter-0'))).opacity,
      0,
    );
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(
      tester.widget<Opacity>(find.byKey(const ValueKey('letter-3'))).opacity,
      1,
    );
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 650));
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
  });
  testWidgets(
    'reduced motion shows the finished brand without waiting for movement',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SplashView(onComplete: () => completed = true),
          ),
        ),
      );
      expect(
        tester.widget<Opacity>(find.byKey(const ValueKey('lily-fade'))).opacity,
        1,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, isTrue);
    },
  );
  testWidgets('settings changes sharing and logout uses its implementation', (
    tester,
  ) async {
    bool? sharing;
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    email: 'test@example.com',
                    sharing: false,
                    paired: true,
                    onSharing: (value) async => sharing = value,
                    onLogout: () async => loggedOut = true,
                  ),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(sharing, true);
    expect(tester.widget<Switch>(find.byType(Switch)).value, true);
    await tester.scrollUntilVisible(find.text('Log out'), 300);
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(loggedOut, true);
    expect(find.text('Open settings'), findsOneWidget);
  });
  testWidgets('leaving a space never logs the person out', (tester) async {
    var left = false, loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          email: 'test@example.com',
          sharing: false,
          paired: true,
          inviteCode: '123456',
          onSharing: (_) async {},
          onLogout: () async {
            loggedOut = true;
          },
          onLeave: () async {
            left = true;
          },
        ),
      ),
    );
    await tester.ensureVisible(find.text('Leave shared space'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave shared space'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(left, false);
    await tester.tap(find.text('Leave shared space'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave space'));
    await tester.pumpAndSettle();
    expect(left, true);
    expect(loggedOut, false);
  });
}
