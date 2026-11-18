import '../core/errors/app_error.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../models/chat_message.dart';
import '../models/chat_reaction.dart';
import '../services/chat_service.dart';

class ChatController extends ChangeNotifier {
  ChatController(this.space, {ChatService? service})
    : service = service ?? ChatService();
  final String space;
  final ChatService service;
  bool accessLost = false;
  final List<ChatMessage> messages = [];
  final Map<String, List<ChatReaction>> reactions = {};
  RealtimeChannel? _channel;
  Timer? _heartbeat;
  Timer? _reconcile;
  bool disposed = false,
      loading = true,
      loadingMore = false,
      hasMore = true,
      active = true;
  String theme = 'lily';
  List<String> quickReactions = List.of(ChatService.defaultReactions);
  String? error;
  Map<String, dynamic>? partnerState;
  DateTime? partnerLastActive;
  DateTime? _lastTyping;
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> start() async {
    _channel = db
        .channel('chat:$space:${service.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_user_preferences',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: service.userId,
          ),
          callback: (event) {
            final values = event.newRecord['quick_reactions'];
            if (values is List && values.length == 6) {
              quickReactions = List<String>.from(values);
              changed();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_reactions',
          callback: (event) {
            final id =
                (event.newRecord['message_id'] ?? event.oldRecord['message_id'])
                    ?.toString();
            if (id != null && messages.any((m) => m.id == id)) {
              final row = event.newRecord;
              final user = (row['user_id'] ?? event.oldRecord['user_id'])
                  ?.toString();
              if (user == null) return;
              reactions[id]?.removeWhere((r) => r.userId == user);
              if (row['emoji'] is String) {
                reactions
                    .putIfAbsent(id, () => [])
                    .add(ChatReaction.fromJson(row));
              }
              changed();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: space,
          ),
          callback: (event) {
            if (event.newRecord.isNotEmpty) {
              final message = ChatMessage.fromJson(event.newRecord);
              acceptSent(message);
              if (active && message.senderId != service.userId) {
                unawaited(beat());
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_state',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: space,
          ),
          callback: (event) {
            if (event.newRecord['user_id'] != service.userId) {
              partnerState = event.newRecord;
              changed();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_preferences',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: space,
          ),
          callback: (event) {
            theme = event.newRecord['theme'] as String? ?? 'lily';
            changed();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(refresh());
          }
        });
    await refresh();
    if (disposed) return;
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      if (active) unawaited(beat());
    });
    _reconcile = Timer.periodic(const Duration(minutes: 2), (_) {
      if (active) unawaited(refresh());
    });
  }

  void acceptSent(ChatMessage message) {
    if (disposed) return;
    messages.removeWhere((m) => m.id == message.id);
    messages.add(message);
    _sort();
    changed();
  }

  void _sort() => messages.sort((a, b) {
    final c = b.createdAt.compareTo(a.createdAt);
    return c != 0 ? c : b.id.compareTo(a.id);
  });
  bool _refreshing = false;
  Future<void> refresh() async {
    if (_refreshing || disposed) return;
    _refreshing = true;
    try {
      final me = await db
          .from('profiles')
          .select('couple_id')
          .eq('id', service.userId)
          .maybeSingle();
      if (me?['couple_id'] != space) {
        accessLost = true;
        messages.clear();
        _heartbeat?.cancel();
        error = 'You are no longer in this shared space.';
        return;
      }
      final rows = await service.history(space);
      if (disposed) return;
      for (final m in rows) {
        messages.removeWhere((old) => old.id == m.id);
        messages.add(m);
      }
      _sort();
      await refreshReactions();
      final states = await db
          .from('chat_state')
          .select()
          .eq('couple_id', space)
          .neq('user_id', service.userId);
      partnerState = states.isEmpty ? null : states.first;
      final prefs = await db
          .from('chat_preferences')
          .select()
          .eq('couple_id', space)
          .maybeSingle();
      theme = prefs?['theme'] as String? ?? 'lily';
      quickReactions = await service.quickReactions();
      final profiles = await db
          .from('profiles')
          .select('last_active_at')
          .eq('couple_id', space)
          .neq('id', service.userId);
      partnerLastActive = profiles.isEmpty
          ? null
          : DateTime.tryParse(
              profiles.first['last_active_at']?.toString() ?? '',
            );
      error = null;
      if (active) await beat();
    } catch (e) {
      error = AppError.message(
        e,
        fallback: 'Could not refresh chat. Please retry.',
      );
    } finally {
      loading = false;
      _refreshing = false;
      changed();
    }
  }

  Future<void> more() async {
    if (loadingMore || !hasMore || messages.isEmpty) return;
    loadingMore = true;
    changed();
    try {
      final rows = await service.history(space, before: messages.last);
      hasMore = rows.length == 40;
      for (final m in rows) {
        if (!messages.any((x) => x.id == m.id)) messages.add(m);
      }
      _sort();
      await refreshReactions();
    } catch (e) {
      error = AppError.message(
        e,
        fallback: 'Could not load older messages. Try again.',
      );
    } finally {
      loadingMore = false;
      changed();
    }
  }

  Future<void> beat({bool typing = false}) async {
    try {
      await service.touch(space, typing: typing);
    } catch (_) {}
  }

  Future<void> refreshReactions() async {
    try {
      final rows = await service.reactions(messages.map((m) => m.id).toList());
      if (disposed) return;
      reactions.clear();
      for (final row in rows) {
        reactions.putIfAbsent(row.messageId, () => []).add(row);
      }
      changed();
    } catch (_) {
      // Keep messages visible when reactions cannot be refreshed.
    }
  }

  void typing() {
    final now = DateTime.now();
    if (_lastTyping == null || now.difference(_lastTyping!).inSeconds >= 3) {
      _lastTyping = now;
      unawaited(beat(typing: true));
    }
  }

  @override
  void dispose() {
    disposed = true;
    _heartbeat?.cancel();
    _reconcile?.cancel();
    if (_channel != null) unawaited(db.removeChannel(_channel!));
    super.dispose();
  }
}
