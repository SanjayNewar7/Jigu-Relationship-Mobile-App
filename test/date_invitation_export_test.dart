import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jigulove/services/date_invitation_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('completed invitation is exported as a readable JPEG', (tester) async {
    final key = GlobalKey();
    Uint8List? saved;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('gal'), (call) async {
      if (call.method == 'hasAccess') return true;
      if (call.method == 'putImageBytes') {
        saved = (call.arguments as Map)['bytes'] as Uint8List;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(const MethodChannel('gal'), null));
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 240,
              height: 300,
              child: ColoredBox(
                color: Color(0xFFFFEAF1),
                child: Center(child: Text('Our lovely date')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await DateInvitationExportService().save(
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary,
        'date-123',
      );
    });
    expect(saved, isNotNull);
    expect(saved![0], 0xff);
    expect(saved![1], 0xd8);
    expect(img.decodeJpg(saved!)?.width, greaterThan(240));
  });
}
