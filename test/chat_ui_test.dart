import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jigulove/controllers/chat_controller.dart';
import 'package:jigulove/features/chat/chat_page.dart';
import 'package:jigulove/models/chat_message.dart';
import 'package:jigulove/services/chat_service.dart';
import 'package:jigulove/features/chat/widgets/chat_media.dart';

class FakeService extends ChatService {
  @override
  String get userId => 'me';
  @override
  Future<void> react(String messageId, String emoji) async {}
  @override
  Future<void> removeReaction(String messageId) async {}
}

class FakeChat extends ChatController {
  FakeChat() : super('space', service: FakeService()) {
    loading = false;
    hasMore = false;
    messages.addAll([
      ChatMessage(
        id: '2',
        senderId: 'me',
        kind: 'text',
        body: 'My message',
        createdAt: DateTime.now(),
      ),
      ChatMessage(
        id: '1',
        senderId: 'partner',
        kind: 'text',
        body: 'Their message',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ]);
  }
  @override
  Future<void> start() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> refreshReactions() async {}
  @override
  void typing() {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'double tap toggles a reaction and directional swipes preserve drafts',
    (tester) async {
      final controller = FakeChat();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            space: 'space',
            partnerName: 'Partner',
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      final message = find.text('Their message');
      await tester.tap(message);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(message);
      await tester.pumpAndSettle();
      expect(
        controller.reactions['1']!.single.emoji,
        controller.quickReactions.first,
      );
      await tester.tap(message);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(message);
      await tester.pumpAndSettle();
      expect(controller.reactions['1'], isEmpty);
      await tester.enterText(find.byType(TextField), 'My draft');
      await tester.drag(message, const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(find.text('Replying to Partner'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel reply'));
      await tester.drag(find.text('My message'), const Offset(-90, 0));
      await tester.pumpAndSettle();
      expect(find.text('Replying to you'), findsOneWidget);
      expect(find.text('My draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('expired media renders without fetching a signed URL', (
    tester,
  ) async {
    final old = ChatMessage(
      id: 'old',
      senderId: 'me',
      kind: 'image',
      body: '',
      createdAt: DateTime(2020),
      expiresAt: DateTime(2020, 2),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatMedia(message: old)),
      ),
    );
    expect(find.text('Attachment expired after 30 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('chat fits a narrow phone and separates sender sides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          space: 'space',
          partnerName: 'Your person',
          controller: FakeChat(),
        ),
      ),
    );
    await tester.pump();
    final mine = find.text('My message'), theirs = find.text('Their message');
    expect(mine, findsOneWidget);
    expect(theirs, findsOneWidget);
    expect(
      tester.getTopLeft(mine).dx,
      greaterThan(tester.getTopLeft(theirs).dx),
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    expect(find.byTooltip('Send message'), findsOneWidget);
    await tester.tap(find.byTooltip('Open emoji picker'));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPicker), findsOneWidget);
    expect(find.byTooltip('Close emoji picker'), findsOneWidget);
    final draft = tester
        .widget<TextField>(find.byType(TextField).first)
        .controller!;
    final beforeEmoji = draft.text;
    await tester.tap(find.byType(EmojiCell).first);
    await tester.pump();
    expect(draft.text.length, greaterThan(beforeEmoji.length));
    expect(tester.takeException(), isNull);
    await tester.longPress(theirs);
    await tester.pumpAndSettle();
    expect(find.text('React or reply'), findsOneWidget);
    expect(find.byTooltip('Another reaction'), findsOneWidget);
    await tester.tap(find.byTooltip('Another reaction'));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiCell), findsWidgets);
    await tester.tap(find.byType(EmojiCell).first);
    await tester.pumpAndSettle();
    await tester.longPress(theirs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply to this message'));
    await tester.pumpAndSettle();
    expect(find.text('Replying to Your person'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel reply'));
    await tester.pumpAndSettle();
    expect(find.text('Replying to Your person'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  test('attachments expire while text remains available', () {
    final expired = ChatMessage(
      id: '1',
      senderId: 'me',
      kind: 'image',
      body: '',
      createdAt: DateTime.now().subtract(const Duration(days: 31)),
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    final text = ChatMessage(
      id: '2',
      senderId: 'me',
      kind: 'text',
      body: 'hello',
      createdAt: DateTime(2020),
    );
    expect(expired.expired, isTrue);
    expect(text.expired, isFalse);
  });
}
