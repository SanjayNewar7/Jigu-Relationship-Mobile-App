import '../core/config.dart';

class ChildSafetyService {
  Future<void> submit({
    required String category,
    required String details,
  }) async {
    final reporter = db.auth.currentUser?.id;
    if (reporter == null) throw StateError('Please sign in to send a report.');
    final message = details.trim();
    if (message.length < 20 || message.length > 4000) {
      throw const FormatException(
        'Describe the concern in 20 to 4000 characters.',
      );
    }
    await db.from('child_safety_reports').insert({
      'reporter_id': reporter,
      'category': category,
      'details': message,
    });
  }
}
