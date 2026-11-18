import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/controllers/call_controller.dart';
import 'package:jigulove/features/calls/call_page.dart';
import 'package:jigulove/models/partner_call.dart';

class TestCallController extends CallController {
  TestCallController(String kind)
    : super(
        PartnerCall(
          id: 'test',
          callerId: 'me',
          kind: kind,
          status: 'ringing',
          createdAt: DateTime.now(),
        ),
      );
  final acknowledgement = Completer<void>();
  bool hangupRequested = false;
  @override
  bool get incoming => false;
  @override
  Future<void> start() async {}
  @override
  Future<void> finish({bool decline = false}) {
    hangupRequested = true;
    return acknowledgement.future;
  }

  @override
  Future<void> disconnect() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'Sniglet',
    )..addFont(rootBundle.load('assets/fonts/Sniglet-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final kind in ['audio', 'video']) {
    testWidgets(
      '$kind controls remain visible while ringing; hang-up does not wait for server',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TestCallController(kind);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Sniglet'),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CallPage(
                        call: controller.call,
                        controller: controller,
                        partnerName: 'Jigu',
                      ),
                    ),
                  ),
                  child: const Text('Open call'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open call'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Mute'), findsOneWidget);
        expect(find.text('Speaker'), findsOneWidget);
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/jigu_lily_foreground.png'),
            tester.element(find.byType(CallPage)),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(CallPage),
          matchesGoldenFile('goldens/${kind}_call.png'),
        );
        if (kind == 'video') {
          expect(find.text('Camera'), findsOneWidget);
          expect(find.text('Flip'), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Mute'));
        await tester.pump();
        expect(controller.mic, false);
        expect(find.text('Unmute'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('End call'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.hangupRequested, true);
        expect(controller.acknowledgement.isCompleted, false);
        expect(find.text('Open call'), findsOneWidget);
        controller.acknowledgement.complete();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await controller.room.dispose();
          // The native audio session is absent in widget tests. Dispose the
          // engine explicitly so its SDK maintenance timer is also released.
          // ignore: invalid_use_of_internal_member
          await controller.room.engine.dispose();
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
