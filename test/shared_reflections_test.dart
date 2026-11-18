import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/core/errors/app_error.dart';
import 'package:jigulove/features/home/views/mood_dashboard_page.dart';
import 'package:jigulove/features/home/models/couple_quote_bank.dart';
import 'package:jigulove/features/chat/widgets/typing_bubble.dart';
import 'package:jigulove/features/chat/widgets/chat_palette.dart';
import 'package:jigulove/services/mood_journal_service.dart';

class ReflectionsFake extends MoodJournalService {
  @override
  Future<Map<String,dynamic>> sharingContext() async => {'space':'qa', 'mine':true, 'theirs':true, 'partner': {'id':'partner','display_name':'Lily'}};
  @override
  Future<List<MoodJournalEntry>> range(DateTime first, DateTime next) async => [MoodJournalEntry(date: DateTime.now(), mood: JiguMood.loved, journal: 'My note')];
  @override
  Future<List<MoodJournalEntry>> partnerRange(String id, DateTime first, DateTime next) async => [MoodJournalEntry(date: DateTime.now(), mood: JiguMood.sad, journal: 'Partner note')];
}
void main() {
  test('network errors are actionable without exposing internal details', () {
    expect(AppError.message(const SocketException('private-host')), contains('No internet connection'));
    expect(AppError.message(TimeoutException('private-host')), contains('taking too long'));
    expect(AppError.message(Exception('private token')), isNot(contains('private token')));
  });
  testWidgets('partner dashboard opens journals read-only on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360,800); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MoodDashboardPage(service: ReflectionsFake())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your person')); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Partner note'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Partner note')); await tester.pumpAndSettle();
    expect(find.text('Partner note'), findsOneWidget);
    expect(find.text('Edit'), findsNothing); expect(find.text('Delete note'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('typing bubble is accessible and disposes animation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TypingBubble(palette: ChatPalette.forName('lily'), name:'Lily'))));
    await tester.pump(const Duration(milliseconds:500));
    expect(find.bySemanticsLabel('Lily is typing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });
}
