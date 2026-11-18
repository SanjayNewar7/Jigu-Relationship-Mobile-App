import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/home/models/couple_quote_bank.dart';
import 'package:jigulove/core/theme/lily_theme.dart';
import 'package:jigulove/features/home/widgets/mood_balance_card.dart';
import 'package:jigulove/features/home/widgets/mood_trend_card.dart';
import 'package:jigulove/services/mood_journal_service.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Sniglet',
    )..addFont(rootBundle.load('assets/fonts/Sniglet-Regular.ttf'))).load();
  });
  final start = DateTime(2026, 11, 16);
  final mine = [
    MoodJournalEntry(date: start, mood: JiguMood.loved),
    MoodJournalEntry(
      date: start.add(const Duration(days: 1)),
      mood: JiguMood.peaceful,
    ),
  ];
  final theirs = [
    MoodJournalEntry(date: start, mood: JiguMood.joyful),
    MoodJournalEntry(
      date: start.add(const Duration(days: 1)),
      mood: JiguMood.missing,
    ),
  ];

  testWidgets('balance and shared trend fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  MoodBalanceCard(entries: mine, name: 'Your'),
                  const SizedBox(height: 12),
                  MoodTrendCard(
                    start: start,
                    end: start.add(const Duration(days: 7)),
                    mine: mine,
                    theirs: theirs,
                    partnerName: 'Jigu',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your mood balance'), findsOneWidget);
    expect(find.text('Our mood journey'), findsOneWidget);
    expect(find.text('Jigu'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/mood_charts.png'),
    );
  });

  test('mood tone groups are stable and not an ordinal mood index', () {
    expect(moodTone(JiguMood.sad), moodTone(JiguMood.angry));
    expect(moodTone(JiguMood.peaceful), lessThan(moodTone(JiguMood.joyful)));
  });
}
