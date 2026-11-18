import '../core/config.dart';

class RelationshipService {
  Future<void> setStartedOn(String coupleId, DateTime date) async {
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await db
        .from('couples')
        .update({'started_on': day})
        .eq('id', coupleId)
        .select('started_on')
        .single();
  }
}
