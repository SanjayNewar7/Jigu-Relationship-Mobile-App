import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/core/theme/lily_theme.dart';
import 'package:jigulove/features/home/models/couple_quote_bank.dart';
import 'package:jigulove/features/home/widgets/mood_quote_card.dart';
import 'package:jigulove/services/mood_journal_service.dart';

class MemoryJournal extends MoodJournalService {
  JiguMood? saved;
  @override
  Future<List<MoodJournalEntry>> range(DateTime first, DateTime next) async => [
    for (var i = 0; i < 5; i++)
      MoodJournalEntry(
        date: first.add(Duration(days: i)),
        mood: JiguMood.values[i],
        journal: i == 1
            ? 'We made time for a quiet walk today. A small thing I want to remember.'
            : null,
      ),
  ];
  @override
  Future<void> save(DateTime date, {JiguMood? mood, String? journal}) async {
    saved = mood;
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Sniglet',
    )..addFont(rootBundle.load('assets/fonts/Sniglet-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'mood controls and calendar fit narrow screens with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MemoryJournal();
      await tester.pumpWidget(
        MaterialApp(
          theme: LilyTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MoodQuoteCard(service: service),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Angry'));
      await tester.tap(find.text('Angry'));
      await tester.pumpAndSettle();
      expect(service.saved, JiguMood.angry);
      await tester.ensureVisible(find.text('This month'));
      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Write journal'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('render reflection cards', (tester) async {
    await (FontLoader(
      'Sniglet',
    )..addFont(rootBundle.load('assets/fonts/Sniglet-Regular.ttf'))).load();
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: const ValueKey('reflection'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: MoodQuoteCard(service: MemoryJournal()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
