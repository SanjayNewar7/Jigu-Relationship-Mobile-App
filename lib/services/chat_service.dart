import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../models/chat_message.dart';
import '../models/chat_reaction.dart';
import 'giphy_service.dart';
import 'chat_notifications.dart';

class ChatService {
  static const defaultReactions = ['❤️', '😂', '😮', '😢', '😡', '👍'];
  Future<List<String>> quickReactions() async {
    final row = await db
        .from('chat_user_preferences')
        .select('quick_reactions')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? defaultReactions
        : List<String>.from(row['quick_reactions']);
  }

  Future<void> saveQuickReactions(List<String> emojis) => db
      .from('chat_user_preferences')
      .upsert({'user_id': userId, 'quick_reactions': emojis});
  Future<void> unsend(String messageId) => db
      .from('chat_messages')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', messageId)
      .eq('sender_id', userId);
  static const maxBytes = 25 * 1024 * 1024;
  String get userId => db.auth.currentUser!.id;
  String newId() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<List<ChatMessage>> history(String space, {ChatMessage? before}) async {
    var query = db.from('chat_messages').select().eq('couple_id', space);
    if (before != null) {
      final date = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$date,and(created_at.eq.$date,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(40);
    return rows.map(ChatMessage.fromJson).toList();
  }

  Future<void> sendText(
    String space,
    String text,
    String id, {
    String? replyToId,
    bool checkExisting = false,
  }) async {
    // A retry checks whether a previous request committed before resending.
    if (checkExisting) {
      final existing = await db
          .from('chat_messages')
          .select('id')
          .eq('id', id)
          .maybeSingle();
      if (existing != null) return;
    }
    await db.from('chat_messages').insert({
      'id': id,
      'couple_id': space,
      'sender_id': userId,
      'kind': 'text',
      'body': text.trim(),
      'reply_to_id': replyToId,
    });
  }

  Future<void> sendFile(
    String space,
    File file,
    String kind,
    String mime,
    String id, {
    String? replyToId,
  }) async {
    if (await file.length() > maxBytes) {
      throw StateError('Choose a file smaller than 25 MB.');
    }
    final path = '$space/$userId/$id';
    await db.storage
        .from('chat-media')
        .upload(path, file, fileOptions: FileOptions(contentType: mime));
    try {
      await db.from('chat_messages').insert({
        'id': id,
        'couple_id': space,
        'sender_id': userId,
        'kind': kind,
        'storage_path': path,
        'reply_to_id': replyToId,
      });
    } catch (_) {
      // Do not delete an upload if the database committed but its response was lost.
      final existing = await db
          .from('chat_messages')
          .select('id')
          .eq('id', id)
          .maybeSingle();
      if (existing != null) return;
      await db.storage.from('chat-media').remove([path]);
      rethrow;
    }
  }

  Future<String> mediaUrl(ChatMessage message) async {
    if (message.expired) throw StateError('This attachment has expired.');
    if (message.giphyId != null) {
      return GiphyService().resolve(message.giphyId!);
    }
    return db.storage
        .from('chat-media')
        .createSignedUrl(
          message.storagePath!,
          min(
            300,
            message.expiresAt?.difference(DateTime.now()).inSeconds ?? 300,
          ).clamp(1, 300),
        );
  }

  Future<void> sendGif(
    String space,
    String gifId,
    String id, {
    String? replyToId,
  }) async {
    await db.from('chat_messages').insert({
      'id': id,
      'couple_id': space,
      'sender_id': userId,
      'kind': 'gif',
      'giphy_id': gifId,
      'reply_to_id': replyToId,
    });
  }

  Future<List<ChatReaction>> reactions(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];
    final rows = await db
        .from('chat_reactions')
        .select('message_id,user_id,emoji')
        .inFilter('message_id', messageIds);
    return rows.map(ChatReaction.fromJson).toList();
  }

  Future<void> react(String messageId, String emoji) async {
    await db.from('chat_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction(String messageId) async {
    await db
        .from('chat_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }

  Future<void> touch(String space, {bool typing = false}) async {
    await db.rpc('touch_chat', params: {'space': space, 'typing': typing});
    final state = await db
        .from('chat_state')
        .select('read_at')
        .eq('couple_id', space)
        .eq('user_id', userId)
        .single();
    await ChatNotifications.clearThrough(
      space,
      DateTime.parse(state['read_at']),
    );
  }

  Future<void> theme(String space, String theme) =>
      db.from('chat_preferences').upsert({'couple_id': space, 'theme': theme});
}
