class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.storagePath,
    this.giphyId,
    this.expiresAt,
    this.mediaDeleted = false,
    this.replyToId,
    this.replyPreview,
    this.replySenderId,
    this.replyKind,
    this.deleted = false,
    this.replyParentDeleted = false,
  });
  final String id, senderId, kind, body;
  final DateTime createdAt;
  final String? storagePath, giphyId;
  final DateTime? expiresAt;
  final bool mediaDeleted;
  final bool deleted, replyParentDeleted;
  final String? replyToId, replyPreview, replySenderId, replyKind;
  bool get expired =>
      mediaDeleted || (expiresAt?.isBefore(DateTime.now()) ?? false);
  factory ChatMessage.fromJson(Map<String, dynamic> row) => ChatMessage(
    id: row['id'] as String,
    senderId: row['sender_id'] as String,
    kind: row['kind'] as String,
    body: row['body'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String),
    storagePath: row['storage_path'] as String?,
    giphyId: row['giphy_id'] as String?,
    expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
    mediaDeleted: row['media_deleted'] == true,
    replyToId: row['reply_to_id'] as String?,
    replyPreview: row['reply_preview'] as String?,
    replySenderId: row['reply_sender_id'] as String?,
    replyKind: row['reply_kind'] as String?,
    deleted: row['deleted_at'] != null,
    replyParentDeleted: row['reply_parent_deleted'] == true,
  );
}
