import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../services/mood_journal_service.dart';
import '../models/couple_quote_bank.dart';
import 'mood_visuals.dart';

class MoodHistoryPanel extends StatelessWidget {
  const MoodHistoryPanel({
    super.key,
    required this.entries,
    required this.start,
    required this.month,
    required this.onDay,
  });
  final List<MoodJournalEntry> entries;
  final DateTime start;
  final bool month;
  final ValueChanged<DateTime> onDay;
  @override
  Widget build(BuildContext context) {
    final totals = <JiguMood, int>{};
    for (final entry in entries) {
      if (entry.mood != null) {
        totals.update(entry.mood!, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final count = totals.values.fold(0, (a, b) => a + b);
    final days = month ? DateTime(start.year, start.month + 1, 0).day : 7;
    final offset = month ? start.weekday - 1 : 0;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$count', style: const TextStyle(fontSize: 32, color: plum)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 1 ? 'day checked in' : 'days checked in',
                style: const TextStyle(color: inkSoft, fontSize: 13),
              ),
            ),
            const Icon(Icons.calendar_month_outlined, color: inkSoft, size: 22),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: inkSoft, fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 5,
            runSpacing: 6,
            children: [
              for (var i = 0; i < days + offset; i++)
                SizedBox(
                  width: (box.maxWidth - 30) / 7,
                  height: 48,
                  child: i < offset
                      ? null
                      : Builder(
                          builder: (context) {
                            final date = DateTime(
                              start.year,
                              start.month,
                              start.day + i - offset,
                            );
                            final entry = entries
                                .where(
                                  (e) => moodDate(e.date) == moodDate(date),
                                )
                                .firstOrNull;
                            final tint = entry?.mood?.tint;
                            final isToday = moodDate(date) == moodDate(now);
                            final enabled = !date.isAfter(now);
                            return Semantics(
                              label:
                                  '${moodDate(date)}, ${entry?.mood?.title ?? 'No mood recorded'}',
                              child: Material(
                                color:
                                    tint?.withValues(alpha: .17) ??
                                    const Color(0xFFF4F0EF),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: enabled ? () => onDay(date) : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isToday
                                            ? plum
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${date.day}',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: enabled
                                                ? plum
                                                : inkSoft.withValues(alpha: .4),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: tint ?? Colors.transparent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (count == 0)
          const Text(
            'Your check-ins will appear here, one day at a time.',
            style: TextStyle(color: inkSoft, fontSize: 13, height: 1.5),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                for (final mood in JiguMood.values)
                  if (totals.containsKey(mood))
                    Expanded(
                      flex: totals[mood]!,
                      child: Container(height: 7, color: mood.tint),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final mood in JiguMood.values)
                if (totals.containsKey(mood))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mood.tint,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${mood.title}  ${totals[mood]}',
                        style: const TextStyle(fontSize: 12, color: inkSoft),
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
