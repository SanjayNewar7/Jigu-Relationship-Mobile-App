import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/settings/child_safety_page.dart';

void main() {
  testWidgets('safety standards and in-app report form are reachable', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChildSafetyPage()));
    expect(find.text('Report a child safety concern'), findsOneWidget);
    expect(find.text('Send report'), findsOneWidget);
    await tester.tap(find.text('Read our safety standards'));
    await tester.pumpAndSettle();
    expect(find.text('Our standard'), findsOneWidget);
    expect(find.text('How we respond'), findsOneWidget);
  });
}
