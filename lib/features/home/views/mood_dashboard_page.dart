import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../core/errors/app_error.dart';
import '../../../services/mood_journal_service.dart';
import '../models/couple_quote_bank.dart';
import '../widgets/mood_visuals.dart';
import '../widgets/mood_history_panel.dart';
import '../widgets/mood_balance_card.dart';
import '../widgets/mood_trend_card.dart';
import 'journal_detail_page.dart';

class MoodDashboardPage extends StatefulWidget {
  const MoodDashboardPage({super.key, this.service});
  final MoodJournalService? service;
  @override
  State<MoodDashboardPage> createState() => _MoodDashboardPageState();
}

class _MoodDashboardPageState extends State<MoodDashboardPage> {
  late final service = widget.service ?? MoodJournalService();
  bool partner = false, month = false, loading = true, saving = false;
  DateTime anchor = DateTime.now();
  Map<String, dynamic> sharing = {};
  List<MoodJournalEntry> entries = [];
  List<MoodJournalEntry> myEntries = [], partnerEntries = [];
  String? error;
  int revision = 0;
  DateTime get start => month
      ? DateTime(anchor.year, anchor.month)
      : DateTime(anchor.year, anchor.month, anchor.day - anchor.weekday + 1);
  DateTime get end => month
      ? DateTime(anchor.year, anchor.month + 1)
      : DateTime(start.year, start.month, start.day + 7);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ticket = ++revision;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final info = await service.sharingContext();
      final id = info['partner']?['id'] as String?;
      final mineFuture = service.range(start, end);
      final theirsFuture = id != null && info['theirs'] == true
          ? service.partnerRange(id, start, end)
          : Future.value(<MoodJournalEntry>[]);
      final mine = await mineFuture;
      final theirs = await theirsFuture;
      if (!mounted || ticket != revision) return;
      setState(() {
        sharing = info;
        myEntries = mine;
        partnerEntries = theirs;
        entries = partner ? theirs : mine;
      });
    } catch (e) {
      if (mounted && ticket == revision) {
        setState(
          () => error = AppError.message(
            e,
            fallback: 'Could not load reflections. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted && ticket == revision) setState(() => loading = false);
    }
  }

  Future<void> toggleShare(bool value) async {
    setState(() => saving = true);
    try {
      await service.share(sharing['space'] as String, value);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> open(MoodJournalEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalDetailPage(entry: entry, readOnly: partner),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final mood in JiguMood.values)
        mood: entries.where((e) => e.mood == mood).length,
    };
    final total = counts.values.fold(0, (a, b) => a + b);
    final leadingMood = counts.entries
        .where((e) => e.value > 0)
        .fold<MapEntry<JiguMood, int>?>(
          null,
          (best, item) => best == null || item.value > best.value ? item : best,
        );
    final notes = entries.where((e) => e.journal?.isNotEmpty == true).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Our reflections'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            tooltip: 'Refresh reflections',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDFEA),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFF0B9CE)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FEELINGS IN BLOOM',
                          style: TextStyle(
                            letterSpacing: 1.7,
                            color: plum,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          total == 0
                              ? 'Every feeling belongs here'
                              : '${leadingMood?.key.title ?? 'Your'} days, in color',
                          style: const TextStyle(
                            color: plum,
                            fontSize: 23,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          total == 0
                              ? 'Your little check-ins will make this space yours.'
                              : '$total check-ins in this ${month ? 'month' : 'week'}',
                          style: const TextStyle(color: inkSoft),
                        ),
                      ],
                    ),
                  ),
                  if (leadingMood != null)
                    Image.asset(
                      leadingMood.key.asset,
                      width: 82,
                      height: 82,
                      fit: BoxFit.contain,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('You')),
                ButtonSegment(value: true, label: Text('Your person')),
              ],
              selected: {partner},
              onSelectionChanged: (v) {
                setState(() => partner = v.first);
                load();
              },
            ),
            const SizedBox(height: 12),
            if (!partner && sharing['space'] != null)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share my moods & journal'),
                subtitle: const Text(
                  'Your current partner can read all your entries. Only you can edit them. Turn off to stop access.',
                ),
                value: sharing['mine'] == true,
                onChanged: saving || loading ? null : toggleShare,
              ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Week')),
                ButtonSegment(value: true, label: Text('Month')),
              ],
              selected: {month},
              onSelectionChanged: (v) {
                setState(() {
                  month = v.first;
                  anchor = DateTime.now();
                });
                load();
              },
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous period',
                  onPressed: () {
                    setState(
                      () => anchor = month
                          ? DateTime(anchor.year, anchor.month - 1)
                          : anchor.subtract(const Duration(days: 7)),
                    );
                    load();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${moodDate(start)} — ${moodDate(end.subtract(const Duration(days: 1)))}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Next period',
                  onPressed: end.isAfter(DateTime.now())
                      ? null
                      : () {
                          setState(
                            () => anchor = month
                                ? DateTime(anchor.year, anchor.month + 1)
                                : anchor.add(const Duration(days: 7)),
                          );
                          load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!),
              TextButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ] else if (!loading && partner && sharing['theirs'] != true)
              const ReflectionSurface(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your person has not shared their reflections in this space yet.',
                  ),
                ),
              )
            else if (!loading) ...[
              MoodBalanceCard(
                entries: entries,
                name: partner
                    ? '${sharing['partner']?['display_name'] as String? ?? 'Your person'}’s'
                    : 'Your',
              ),
              const SizedBox(height: 16),
              MoodTrendCard(
                start: start,
                end: end,
                mine: myEntries,
                theirs: partnerEntries,
                partnerName:
                    sharing['partner']?['display_name'] as String? ??
                    'Your person',
              ),
              const SizedBox(height: 16),
              ReflectionSurface(
                child: MoodHistoryPanel(
                  entries: entries,
                  start: start,
                  month: month,
                  onDay: (date) {
                    final entry = entries
                        .where(
                          (e) =>
                              moodDate(e.date) == moodDate(date) &&
                              e.journal?.isNotEmpty == true,
                        )
                        .firstOrNull;
                    if (entry != null) open(entry);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                partner ? 'Their journal' : 'Your journal',
                style: const TextStyle(fontSize: 23, color: plum),
              ),
              const SizedBox(height: 10),
              if (notes.isEmpty)
                const Text(
                  'No journal entries in this period.',
                  style: TextStyle(color: inkSoft),
                ),
              for (final entry in notes)
                Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  decoration: BoxDecoration(
                    color: (entry.mood?.tint ?? coral).withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (entry.mood?.tint ?? coral).withValues(alpha: .32),
                    ),
                  ),
                  child: ListTile(
                    leading: entry.mood == null
                        ? const Icon(Icons.menu_book_outlined)
                        : Image.asset(entry.mood!.asset, width: 38, height: 38),
                    title: Text(moodDate(entry.date)),
                    subtitle: Text(
                      entry.journal!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(entry),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
