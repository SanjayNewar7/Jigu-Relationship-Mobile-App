import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/chat/widgets/theme_flower.dart';
import 'package:jigulove/features/chat/widgets/chat_palette.dart';
import 'package:jigulove/models/partner_call.dart';

void main() {
  test('call lifecycle distinguishes active and finished states', () {
    PartnerCall call(String status) => PartnerCall(
      id: 'qa',
      callerId: 'a',
      kind: 'audio',
      status: status,
      createdAt: DateTime(2026),
    );
    expect(call('ringing').terminal, false);
    expect(call('accepted').terminal, false);
    for (final status in ['missed', 'declined', 'ended']) {
      expect(call(status).terminal, true);
    }
  });
  testWidgets('each chat theme has a transparent vector flower', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final name in ChatPalette.names)
                ThemeFlower(name: name, color: ChatPalette.forName(name).sent),
            ],
          ),
        ),
      ),
    );
    for (final name in ChatPalette.names) {
      expect(find.bySemanticsLabel('$name flower'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
