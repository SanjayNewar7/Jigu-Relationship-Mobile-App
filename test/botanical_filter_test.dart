import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/moment_editor/services/botanical_renderer.dart';
import 'package:jigulove/features/moment_editor/widgets/discard_moment_dialog.dart';

Future<Uint8List> pixels(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  try {
    return (await frame.image.toByteData())!.buffer.asUint8List();
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}

void main() {
  testWidgets(
    'All botanical grades export distinctly; zero strength preserves pixels',
    (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('jigu_filter_test');
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 32, 24),
          Paint()..color = const Color(0xFFA87A59),
        );
        canvas.drawRect(
          const Rect.fromLTWH(16, 0, 16, 24),
          Paint()..color = const Color(0xFF437C9B),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(32, 24);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final path = '${dir.path}/sample.png';
        await File(path).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        final renderer = await BotanicalRenderer.load(path);
        try {
          final original = await renderer.export(0, .85);
          final results = <String>{};
          for (var i = 1; i <= 12; i++) {
            final result = await renderer.export(i, .85);
            expect(result, isNot(orderedEquals(original)));
            results.add(result.join(','));
            expect(await renderer.export(i, 0), orderedEquals(original));
          }
          expect(results.length, 12);
          expect(renderer.image.width, 32);
          expect(renderer.image.height, 24);
          final basePixels = await pixels(original);
          final midnightPixels = await pixels(await renderer.export(12, .85));
          for (final direction in [-1.0, 1.0]) {
            final wipeRecorder = ui.PictureRecorder();
            renderer.paint(
              Canvas(wipeRecorder),
              const Size(32, 24),
              0,
              12,
              .5,
              direction,
              .85,
            );
            final wipePicture = wipeRecorder.endRecording();
            final wipeImage = await wipePicture.toImage(32, 24);
            final wipe = (await wipeImage.toByteData())!.buffer.asUint8List();
            for (final x in [4, 28]) {
              final expected = (direction < 0 ? x > 16 : x < 16)
                  ? midnightPixels
                  : basePixels;
              final offset = (12 * 32 + x) * 4;
              expect(
                wipe.sublist(offset, offset + 4),
                expected.sublist(offset, offset + 4),
              );
            }
            wipeImage.dispose();
            wipePicture.dispose();
          }
        } finally {
          renderer.dispose();
          await dir.delete(recursive: true);
        }
      });
    },
  );

  testWidgets('Discard dialog retains or discards only on explicit choice', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await confirmDiscardMoment(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard edits'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}
