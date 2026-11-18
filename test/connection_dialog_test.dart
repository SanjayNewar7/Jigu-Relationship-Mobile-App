import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/pairing/connection_dialog.dart';

void main() {
  testWidgets('paired names appear with the smiling lily', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionDialog(yourName: 'Sanjaya', partnerName: 'Jigu'),
        ),
      ),
    );

    expect(find.text('Sanjaya & Jigu'), findsOneWidget);
    expect(find.text('Together in Jigu'), findsOneWidget);
    expect(find.bySemanticsLabel('A smiling lily flower'), findsOneWidget);
    expect(find.text('Our little world'), findsOneWidget);
  });
}
