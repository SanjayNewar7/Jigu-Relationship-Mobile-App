import '../core/config.dart';

class ChatUnreadService {
  Future<int> count(String space) async {
    final value = await db.rpc('chat_unread_count', params: {'space': space});
    return (value as num).toInt();
  }
}
