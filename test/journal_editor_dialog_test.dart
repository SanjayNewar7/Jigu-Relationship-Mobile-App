import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/home/widgets/journal_editor_dialog.dart';

void main() {
  testWidgets('journal can save and close after route animation', (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await showDialog<String>(
          context: context,
          builder: (_) => JournalEditorDialog(
            day: DateTime(2026, 11, 7), initialText: 'first thought',
          ),
        ),
        child: const Text('Open journal'),
      ),
    ))));
    await tester.tap(find.text('Open journal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a private note');
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(result, 'a private note');
    expect(tester.takeException(), isNull);
    expect(find.byType(JournalEditorDialog), findsNothing);
  });

  testWidgets('journal cancel and system back close without a disposed controller', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<String>(
          context: context,
          builder: (_) => JournalEditorDialog(
            day: DateTime(2026, 11, 7), initialText: '',
          ),
        ),
        child: const Text('Open journal'),
      ),
    ))));
    await tester.tap(find.text('Open journal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'unsaved thought');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Open journal'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(JournalEditorDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
