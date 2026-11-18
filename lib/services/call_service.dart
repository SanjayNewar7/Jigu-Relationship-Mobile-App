import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../models/partner_call.dart';

class CallService {
  Future<Map<String, dynamic>> request(
    String action, {
    String? id,
    String? kind,
  }) async {
    try {
      final result = await db.functions
          .invoke(
            'partner-call',
            body: {
              'action': action,
              'call_id': ?id,
              'kind': ?kind,
            },
          )
          .timeout(const Duration(seconds: 25));
      return Map<String, dynamic>.from(result.data as Map);
    } on FunctionException catch (e) {
      final data = e.details;
      throw StateError(
        data is Map && data['message'] is String
            ? data['message'] as String
            : 'Call service is unavailable. Please try again.',
      );
    }
  }

  Future<PartnerCall> action(String action, {String? id, String? kind}) async =>
      PartnerCall.fromMap(
        Map<String, dynamic>.from(
          (await request(action, id: id, kind: kind))['call'] as Map,
        ),
      );
  Future<PartnerCall?> incoming() async {
    final me = db.auth.currentUser?.id;
    if (me == null) return null;
    final rows = await db
        .from('partner_calls')
        .select()
        .eq('callee_id', me)
        .eq('status', 'ringing')
        .gte(
          'created_at',
          DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 45))
              .toIso8601String(),
        )
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : PartnerCall.fromMap(rows.first);
  }
}
