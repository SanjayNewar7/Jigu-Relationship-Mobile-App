import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/models/chat_message.dart';
import 'package:jigulove/models/chat_reaction.dart';
import 'package:jigulove/services/chat_visibility.dart';

void main() {
  test('reply and reaction data remain attached to the right message', () {
    final message = ChatMessage.fromJson({
      'id': 'new',
      'sender_id': 'me',
      'kind': 'text',
      'body': 'See you soon',
      'created_at': '2026-11-18T08:00:00Z',
      'reply_to_id': 'old',
      'reply_preview': 'At the cafe?',
      'reply_sender_id': 'partner',
    });
    final reaction = ChatReaction.fromJson({
      'message_id': 'new',
      'user_id': 'partner',
      'emoji': '\u2764\uFE0F',
    });
    expect(message.replyToId, 'old');
    expect(message.replyPreview, 'At the cafe?');
    expect(message.replySenderId, 'partner');
    expect(reaction.messageId, message.id);
    expect(reaction.emoji, '\u2764\uFE0F');
  });

  test('visible chat suppresses only its own foreground push', () {
    ChatVisibility.space = 'our-space';
    ChatVisibility.isCurrent = () => true;
    expect(ChatVisibility.viewing('our-space'), isTrue);
    expect(ChatVisibility.viewing('another-space'), isFalse);
    ChatVisibility.isCurrent = () => false;
    expect(ChatVisibility.viewing('our-space'), isFalse);
    ChatVisibility.clear('our-space');
    expect(ChatVisibility.viewing('our-space'), isFalse);
  });
}
