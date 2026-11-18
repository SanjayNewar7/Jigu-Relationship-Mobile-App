import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/home/models/couple_quote_bank.dart';
import 'package:jigulove/features/home/views/journal_detail_page.dart';
import 'package:jigulove/services/mood_journal_service.dart';

void main() {
  testWidgets('saved journal opens fully and can be updated', (tester) async {
    final original = 'A long little memory. ' * 30;
    String? saved;
    await tester.pumpWidget(MaterialApp(home: JournalDetailPage(
      entry: MoodJournalEntry(
        date: DateTime(2026, 11, 7),
        mood: JiguMood.peaceful,
        journal: original,
      ),
      onSave: (_, note) async => saved = note,
    )));
    expect(find.text(original), findsOneWidget);
    expect(find.text('Feeling calm'), findsOneWidget);
    await tester.tap(find.text('Edit journal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated memory');
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(saved, 'Updated memory');
    expect(find.text('Updated memory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete asks first and only removes after confirmation', (tester) async {
    var deletes = 0;
    await tester.pumpWidget(MaterialApp(home: JournalDetailPage(
      entry: MoodJournalEntry(
        date: DateTime(2026, 11, 7), journal: 'Remember this day.',
      ),
      onDelete: (_) async => deletes++,
    )));
    await tester.tap(find.byTooltip('Delete journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep note'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.byTooltip('Delete journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(tester.takeException(), isNull);
  });
}
