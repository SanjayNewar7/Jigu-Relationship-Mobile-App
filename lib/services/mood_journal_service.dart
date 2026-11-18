import '../core/config.dart';
import '../features/home/models/couple_quote_bank.dart';

class MoodJournalEntry {
  const MoodJournalEntry({required this.date, this.mood, this.journal});
  final DateTime date;
  final JiguMood? mood;
  final String? journal;

  factory MoodJournalEntry.fromMap(Map<String, dynamic> row) =>
      MoodJournalEntry(
        date: DateTime.parse(row['entry_date'] as String),
        mood: JiguMood.values
            .where((value) => value.name == row['mood'])
            .firstOrNull,
        journal: row['journal'] as String?,
      );
}

String moodDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class MoodJournalService {
  String get userId => db.auth.currentUser!.id;

  Future<List<MoodJournalEntry>> range(DateTime first, DateTime next) async {
    final rows = await db
        .from('mood_journal_entries')
        .select()
        .eq('user_id', userId)
        .gte('entry_date', moodDate(first))
        .lt('entry_date', moodDate(next))
        .order('entry_date', ascending: false);
    return rows.map(MoodJournalEntry.fromMap).toList();
  }

  Future<List<MoodJournalEntry>> partnerRange(
    String partnerId,
    DateTime first,
    DateTime next,
  ) async {
    final rows = await db
        .from('mood_journal_entries')
        .select()
        .eq('user_id', partnerId)
        .gte('entry_date', moodDate(first))
        .lt('entry_date', moodDate(next))
        .order('entry_date', ascending: false);
    return rows.map(MoodJournalEntry.fromMap).toList();
  }

  Future<Map<String, dynamic>> sharingContext() async {
    final own = await db
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .single();
    final space = own['couple_id'];
    if (space == null) return {};
    final partner = await db
        .from('profiles')
        .select('id,display_name')
        .eq('couple_id', space)
        .neq('id', userId)
        .maybeSingle();
    final sharing = await db
        .from('reflection_sharing')
        .select()
        .eq('couple_id', space);
    return {
      'space': space,
      'partner': partner,
      'mine': sharing.any(
        (r) => r['user_id'] == userId && r['enabled'] == true,
      ),
      'theirs': sharing.any(
        (r) => r['user_id'] == partner?['id'] && r['enabled'] == true,
      ),
    };
  }

  Future<void> share(String space, bool enabled) async {
    await db.from('reflection_sharing').upsert({
      'user_id': userId,
      'couple_id': space,
      'enabled': enabled,
    });
  }

  Future<void> save(DateTime date, {JiguMood? mood, String? journal}) async {
    final current = await db
        .from('mood_journal_entries')
        .select('mood,journal')
        .eq('user_id', userId)
        .eq('entry_date', moodDate(date))
        .maybeSingle();
    await db.from('mood_journal_entries').upsert({
      'user_id': userId,
      'entry_date': moodDate(date),
      'mood': mood?.name ?? current?['mood'],
      'journal': journal ?? current?['journal'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Removes only the note. A mood logged on the same date remains in history.
  Future<void> removeJournal(DateTime date) async {
    final current = await db
        .from('mood_journal_entries')
        .select('mood')
        .eq('user_id', userId)
        .eq('entry_date', moodDate(date))
        .maybeSingle();
    if (current == null) return;
    if (current['mood'] != null) {
      await db
          .from('mood_journal_entries')
          .update({
            'journal': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('entry_date', moodDate(date));
    } else {
      await db
          .from('mood_journal_entries')
          .delete()
          .eq('user_id', userId)
          .eq('entry_date', moodDate(date));
    }
  }
}
