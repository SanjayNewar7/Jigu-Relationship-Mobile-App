import '../test/offline_tiles.dart';
// Render the real UI with empty states, without a Supabase account.
// flutter test --update-goldens tool/render_design.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/core/config.dart';
import 'package:jigulove/core/theme/lily_theme.dart';
import 'package:jigulove/core/widgets/lily_backdrop.dart';
import 'package:jigulove/core/widgets/lily_bloom.dart';
import 'package:jigulove/features/auth/login_page.dart';
import 'package:jigulove/features/home/views/today_view.dart';
import 'package:jigulove/features/home/views/moments_view.dart';
import 'package:jigulove/features/home/views/places_view.dart';
import 'package:jigulove/features/home/widgets/glass_tab_bar.dart';
import 'package:jigulove/features/pairing/pairing_view.dart';
import 'package:jigulove/features/splash/splash_view.dart';

void main() {
  testWidgets('render Jigu design previews', (tester) async {
    await (FontLoader(
      'Sniglet',
    )..addFont(rootBundle.load('assets/fonts/Sniglet-Regular.ttf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pages = <String, Widget>{
      'welcome': const Login(),
      'splash': const SplashView(),
      'pairing': PairingView(code: '123456', busy: false, onJoin: (_) {}),
      'today': TodayView(
        moments: const [],
        placeLabel: 'No recent location shared',
        place: null,
        busy: false,
        onUpload: () {},
        onRefresh: () async {},
      ),
      'moments': MomentsView(moments: const [], onRefresh: () async {}),
      'places': PlacesView(
        tileProvider: OfflineTiles(),
        label: 'No recent location shared',
        place: null,
        sharing: false,
        busy: false,
        onChanged: (_) {},
      ),
    };
    for (final entry in pages.entries) {
      final direct = entry.key == 'welcome' || entry.key == 'splash';
      final selected = ['today', 'moments', 'places'].indexOf(entry.key);
      await tester.pumpWidget(
        MaterialApp(
          theme: LilyTheme.light,
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: ValueKey(entry.key),
            child: direct
                ? entry.value
                : Scaffold(
                    body: LilyBackdrop(
                      child: SafeArea(
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
                              child: Row(
                                children: [
                                  LilyBloom(size: 30),
                                  SizedBox(width: 9),
                                  Text(
                                    'jigu',
                                    style: TextStyle(fontSize: 28, color: plum),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: entry.value),
                                  if (selected >= 0)
                                    Positioned(
                                      left: 24,
                                      right: 24,
                                      bottom: 12,
                                      child: GlassTabBar(
                                        selected: selected,
                                        onChanged: (_) {},
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(ValueKey(entry.key)),
        matchesGoldenFile('../docs/design/${entry.key}.png'),
      );
    }
  });
}
