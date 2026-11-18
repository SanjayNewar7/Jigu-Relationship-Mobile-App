import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../services/mood_journal_service.dart';
import '../models/couple_quote_bank.dart';
import 'mood_visuals.dart';

class MoodBalanceCard extends StatefulWidget {
  const MoodBalanceCard({super.key, required this.entries, required this.name});
  final List<MoodJournalEntry> entries;
  final String name;
  @override
  State<MoodBalanceCard> createState() => _MoodBalanceCardState();
}

class _MoodBalanceCardState extends State<MoodBalanceCard> {
  JiguMood? selected;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final mood in JiguMood.values)
        mood: widget.entries.where((e) => e.mood == mood).length,
    };
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final active = selected != null && counts[selected]! > 0
        ? selected
        : counts.entries
              .where((e) => e.value > 0)
              .fold<JiguMood?>(
                null,
                (best, item) => best == null || item.value > counts[best]!
                    ? item.key
                    : best,
              );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAD9E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFD85283),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.name} mood balance',
                  style: const TextStyle(fontSize: 22, color: plum),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'A little portrait of your check-ins',
            style: TextStyle(color: inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Your feelings will bloom here after a check-in.'),
              ),
            )
          else ...[
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 54,
                      sectionsSpace: 3,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          final moods = counts.entries
                              .where((e) => e.value > 0)
                              .toList();
                          if (index != null &&
                              index >= 0 &&
                              index < moods.length) {
                            setState(() => selected = moods[index].key);
                          }
                        },
                      ),
                      sections: [
                        for (final item in counts.entries)
                          if (item.value > 0)
                            PieChartSectionData(
                              value: item.value.toDouble(),
                              color: item.key.tint,
                              radius: item.key == active ? 35 : 29,
                              showTitle: false,
                            ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: const TextStyle(
                          fontSize: 33,
                          color: plum,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'check-ins',
                        style: TextStyle(color: inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (active != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active.tint.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: active.tint.withValues(alpha: .45)),
                ),
                child: Row(
                  children: [
                    Image.asset(active.asset, width: 42, height: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active.title,
                            style: const TextStyle(
                              color: plum,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${counts[active]} of $total check-ins',
                            style: const TextStyle(
                              color: inkSoft,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 7,
              runSpacing: 8,
              children: [
                for (final item in counts.entries)
                  if (item.value > 0)
                    Semantics(
                      button: true,
                      label: '${item.key.title}: ${item.value} check-ins',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => selected = item.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: item.key.tint.withValues(alpha: .17),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: item.key == active
                                  ? item.key.tint
                                  : item.key.tint.withValues(alpha: .35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: item.key.tint,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.key.title} ${item.value}',
                                style: const TextStyle(
                                  color: plum,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
