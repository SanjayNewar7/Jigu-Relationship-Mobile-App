class ChatReaction {
  const ChatReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });
  final String messageId, userId, emoji;
  factory ChatReaction.fromJson(Map<String, dynamic> row) => ChatReaction(
    messageId: row['message_id'] as String,
    userId: row['user_id'] as String,
    emoji: row['emoji'] as String,
  );
}
