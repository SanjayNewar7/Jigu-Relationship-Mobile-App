import '../views/mood_dashboard_page.dart';
import '../../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import 'mood_visuals.dart';
import 'mood_history_panel.dart';
import '../../../services/mood_journal_service.dart';
import '../models/couple_quote_bank.dart';
import '../views/journal_detail_page.dart';
import 'journal_editor_dialog.dart';

class MoodQuoteCard extends StatefulWidget {
  const MoodQuoteCard({super.key, this.service});
  final MoodJournalService? service;
  @override
  State<MoodQuoteCard> createState() => _MoodQuoteCardState();
}

class _MoodQuoteCardState extends State<MoodQuoteCard> {
  late final service = widget.service ?? MoodJournalService();
  JiguMood mood = JiguMood.loved;
  int variation = 0;
  int loadRevision = 0;
  bool monthMode = false, loading = false;
  DateTime anchor = DateTime.now();
  List<MoodJournalEntry> entries = [];

  DateTime get periodStart => monthMode
      ? DateTime(anchor.year, anchor.month)
      : DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(Duration(days: anchor.weekday - 1));
  DateTime get periodEnd => monthMode
      ? DateTime(anchor.year, anchor.month + 1)
      : periodStart.add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  Future<void> loadEntries() async {
    final revision = ++loadRevision;
    setState(() {
      loading = true;
      entries = [];
    });
    try {
      final values = await service.range(periodStart, periodEnd);
      if (!mounted || revision != loadRevision) return;
      setState(() {
        entries = values;
        final today = values
            .where((e) => moodDate(e.date) == moodDate(DateTime.now()))
            .firstOrNull;
        if (today?.mood != null) {
          mood = today!.mood!;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Mood history could not load. Check your connection.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && revision == loadRevision) setState(() => loading = false);
    }
  }

  Future<void> select(JiguMood value) async {
    final previous = mood;
    setState(() {
      mood = value;
      variation = 0;
    });
    try {
      await service.save(DateTime.now(), mood: value);
      await loadEntries();
    } catch (e) {
      if (!mounted) return;
      setState(() => mood = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppError.message(
              e,
              fallback: 'Could not save your mood. Please retry.',
            ),
          ),
        ),
      );
    }
  }

  void movePeriod(int direction) {
    setState(
      () => anchor = monthMode
          ? DateTime(anchor.year, anchor.month + direction)
          : anchor.add(Duration(days: 7 * direction)),
    );
    loadEntries();
  }

  Future<void> editJournal([DateTime? initial]) async {
    final day =
        initial ??
        await showDatePicker(
          context: context,
          initialDate: initial ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          helpText: 'Choose a day for your journal',
        );
    if (day == null || !mounted) return;
    MoodJournalEntry? existing = entries
        .where((e) => moodDate(e.date) == moodDate(day))
        .firstOrNull;
    if (existing == null) {
      try {
        existing = (await service.range(
          day,
          day.add(const Duration(days: 1)),
        )).firstOrNull;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppError.message(e))));
        }
        return;
      }
    }
    if (!mounted) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) =>
          JournalEditorDialog(day: day, initialText: existing?.journal ?? ''),
    );
    if (note != null) {
      try {
        await service.save(day, journal: note.trim());
        if (!mounted) return;
        setState(() => anchor = day);
        await loadEntries();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppError.message(
                  e,
                  fallback: 'Could not save your journal. Please retry.',
                ),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> openJournal(MoodJournalEntry entry) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => JournalDetailPage(entry: entry)),
    );
    if (mounted) await loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final notes = entries.where((e) => e.journal?.isNotEmpty == true).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoodDashboardPage()),
            ),
            icon: const Icon(Icons.donut_large_outlined),
            label: const Text('Our mood & journal dashboard'),
          ),
        ),
        ReflectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A MOMENT FOR YOU',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How are you feeling today?',
                style: TextStyle(fontSize: 22, height: 1.2, color: plum),
              ),
              const SizedBox(height: 6),
              const Text(
                'There is room for every feeling.',
                style: TextStyle(fontSize: 13, color: inkSoft),
              ),
              const SizedBox(height: 20),
              MoodPicker(selected: mood, onSelected: select),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.only(left: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFDAB6C4), width: 2),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    quoteForDay(mood, DateTime.now(), variation: variation),
                    key: ValueKey('${mood.index}_$variation'),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: plum,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => variation++),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'Another little thought',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ReflectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your moods',
                style: TextStyle(fontSize: 21, color: plum),
              ),
              const SizedBox(height: 4),
              const Text(
                'A little perspective on your days.',
                style: TextStyle(fontSize: 13, color: inkSoft),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.standard,
                    side: const WidgetStatePropertyAll(
                      BorderSide(color: Color(0xFFEADFE3)),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFFEEDDE4)
                          : const Color(0xFFF7F3F2),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('This week')),
                    ButtonSegment(value: true, label: Text('This month')),
                  ],
                  selected: {monthMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      monthMode = selection.first;
                      anchor = DateTime.now();
                    });
                    loadEntries();
                  },
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Earlier',
                    onPressed: () => movePeriod(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      monthMode
                          ? '${_monthName(anchor.month)} ${anchor.year}'
                          : '${periodStart.day} ${_monthName(periodStart.month)} \u2013 ${periodEnd.subtract(const Duration(days: 1)).day} ${_monthName(periodEnd.subtract(const Duration(days: 1)).month)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: inkSoft, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Later',
                    onPressed: periodEnd.isAfter(DateTime.now())
                        ? null
                        : () => movePeriod(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              MoodHistoryPanel(
                entries: entries,
                start: periodStart,
                month: monthMode,
                onDay: (day) {
                  final note = entries
                      .where(
                        (e) =>
                            moodDate(e.date) == moodDate(day) &&
                            e.journal?.isNotEmpty == true,
                      )
                      .firstOrNull;
                  if (note != null) {
                    openJournal(note);
                  } else {
                    editJournal(day);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ReflectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEDE5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      color: sage,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your journal',
                          style: TextStyle(fontSize: 21, color: plum),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'A space of your own',
                          style: TextStyle(fontSize: 12, color: inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => editJournal(),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Write journal'),
                ),
              ),
              if (notes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Keep a thought, a memory, or something you want to let go of.',
                    style: TextStyle(color: inkSoft, fontSize: 13, height: 1.5),
                  ),
                ),
              for (final entry in notes)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Material(
                    color: const Color(0xFFF7F3F2),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => openJournal(entry),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 36,
                              child: Column(
                                children: [
                                  Text(
                                    '${entry.date.day}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: plum,
                                    ),
                                  ),
                                  Text(
                                    _monthName(entry.date.month),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.mood?.title ?? 'A little reflection',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: plum,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    entry.journal!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: inkSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
