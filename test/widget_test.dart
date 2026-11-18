import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/core/app.dart';
import 'package:jigulove/core/config.dart';
import 'package:jigulove/core/widgets/lily_bloom.dart';
import 'package:jigulove/features/home/widgets/moment_card.dart';
import 'package:jigulove/features/home/widgets/moment_carousel.dart';
import 'package:jigulove/features/home/views/moment_photo_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: url, publishableKey: key);
  });
  testWidgets('JIGU letters appear on the animated splash', (tester) async {
    await tester.pumpWidget(const Jigu());
    await tester.pump(const Duration(milliseconds: 1500));
    for (final letter in ['J', 'I', 'G', 'U']) {
      expect(find.text(letter), findsOneWidget);
    }
    expect(find.byType(LilyBloom), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a shared moment exposes like and save actions', (tester) async {
    var likes = 0, saves = 0;
    final moment = <String, dynamic>{
      'id': 'preview',
      'author_id': 'another-user',
      'storage_path': 'preview.jpg',
      'moment_likes': <Map<String, dynamic>>[],
      'expires_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentCard(
            moment: moment,
            height: 180,
            onLike: (_) async {
              likes++;
            },
            onSave: (_) async {
              saves++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Like moment'));
    await tester.pump();
    await tester.tap(find.byTooltip('Save to phone gallery'));
    await tester.pump();
    expect(likes, 1);
    expect(saves, 1);
  });

  testWidgets('Today moments move with a horizontal swipe', (tester) async {
    Map<String, dynamic> moment(String id) => {
      'id': id,
      'author_id': 'another-user',
      'storage_path': '$id.jpg',
      'moment_likes': <Map<String, dynamic>>[],
      'expires_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MomentCarousel(
              moments: [moment('one'), moment('two')],
              onLike: (_) async {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('1/2'), findsOneWidget);
    await tester.drag(find.byType(MomentCard), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('full-screen photo keeps its original proportions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MomentPhotoView(
          moments: [
            {'id': 'photo', 'storage_path': 'photo.jpg'},
          ],
        ),
      ),
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byTooltip('Close photo'), findsOneWidget);
  });

  testWidgets('full-screen photos swipe like a gallery', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MomentPhotoView(
          moments: [
            {'id': 'one', 'storage_path': 'one.jpg'},
            {'id': 'two', 'storage_path': 'two.jpg'},
          ],
        ),
      ),
    );
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('full-screen photo uses the viewport rather than image pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final file = File('${Directory.systemTemp.path}/jigu-layout-test.png');
    await tester.runAsync(() => file.writeAsBytes(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lXcAAAAASUVORK5CYII=',
    )));
    addTearDown(() => file.delete());
    await tester.pumpWidget(MaterialApp(
      home: MomentPhotoView(
        moments: const [{'id': 'one'}],
        imageLoader: (_) async => file,
      ),
    ));
    await tester.pump();
    final image = find.byType(Image);
    expect(image, findsOneWidget);
    expect(tester.getSize(image), const Size(400, 800));
  });

  testWidgets('moment actions and swipe controls fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final moment = <String, dynamic>{
      'id': 'one',
      'author_id': null,
      'storage_path': 'one.jpg',
      'moment_likes': <Map<String, dynamic>>[],
      'expires_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: MomentCard(
              moment: moment,
              galleryMoments: [
                moment,
                {...moment, 'id': 'two'},
              ],
              onLike: (_) async {},
              onSave: (_) async {},
              onDelete: (_) async {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('1/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
