import 'offline_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/core/theme/lily_theme.dart';
import 'package:jigulove/core/widgets/lily_backdrop.dart';
import 'package:jigulove/features/auth/login_page.dart';
import 'package:jigulove/features/home/views/today_view.dart';
import 'package:jigulove/features/home/views/moments_view.dart';
import 'package:jigulove/features/home/views/places_view.dart';
import 'package:jigulove/features/home/widgets/glass_tab_bar.dart';
import 'package:jigulove/features/pairing/pairing_view.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Sniglet',
    )..addFont(rootBundle.load('assets/fonts/Sniglet-Regular.ttf'))).load();
  });
  final views = <String, Widget Function()>{
    'pairing': () => PairingView(code: '123456', busy: false, onJoin: (_) {}),
    'today': () => TodayView(
      moments: const [],
      placeLabel: 'No recent location shared',
      place: null,
      busy: false,
      onUpload: () {},
      onRefresh: () async {},
    ),
    'moments': () => MomentsView(moments: const [], onRefresh: () async {}),
    'places': () => PlacesView(
      tileProvider: OfflineTiles(),
      label: 'No recent location shared',
      place: null,
      sharing: false,
      busy: false,
      onChanged: (_) {},
    ),
  };

  for (final entry in views.entries) {
    testWidgets('${entry.key} fits a small screen with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: LilyTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(body: LilyBackdrop(child: entry.value())),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pairing only submits a complete six digit code', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Scaffold(
          body: LilyBackdrop(
            child: PairingView(
              code: '654321',
              busy: false,
              onJoin: (code) => submitted = code,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '123');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    expect(submitted, '123456');
  });

  testWidgets('account form and floating tabs remain usable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: LilyTheme.light, home: const Login()),
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Let love bloom.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Scaffold(
          body: Center(
            child: GlassTabBar(
              selected: 0,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Places'));
    expect(selected, 3);
  });

  testWidgets('bottom navigation moves a single selection pill', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder: (context, setState) => GlassTabBar(
                  selected: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AnimatedPositioned), findsOneWidget);
    expect(
      tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).left,
      0,
    );
    await tester.tap(find.text('Places'));
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(find.byType(AnimatedPositioned), findsOneWidget);
    expect(
      tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).left,
      greaterThan(200),
    );
  });
}
