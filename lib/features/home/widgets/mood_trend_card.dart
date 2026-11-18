import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../services/mood_journal_service.dart';
import '../models/couple_quote_bank.dart';
import 'mood_visuals.dart';

/// Display groups of feelings, not a clinical or numerical wellbeing score.
double moodTone(JiguMood mood) => switch (mood) {
  JiguMood.sad || JiguMood.angry || JiguMood.misunderstood => 1,
  JiguMood.missing || JiguMood.needingHug => 2,
  JiguMood.peaceful => 3,
  JiguMood.loved || JiguMood.joyful => 4,
};

class MoodTrendCard extends StatefulWidget {
  const MoodTrendCard({
    super.key,
    required this.start,
    required this.end,
    required this.mine,
    required this.theirs,
    required this.partnerName,
  });
  final DateTime start, end;
  final List<MoodJournalEntry> mine, theirs;
  final String partnerName;
  @override
  State<MoodTrendCard> createState() => _MoodTrendCardState();
}

class _MoodTrendCardState extends State<MoodTrendCard> {
  int? selectedDay;
  @override
  void didUpdateWidget(covariant MoodTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      selectedDay = null;
    }
  }

  int dayOf(DateTime date) => DateTime.utc(date.year, date.month, date.day)
      .difference(
        DateTime.utc(widget.start.year, widget.start.month, widget.start.day),
      )
      .inDays;
  MoodJournalEntry? onDay(List<MoodJournalEntry> entries, int day) {
    for (final entry in entries) {
      if (entry.mood != null && dayOf(entry.date) == day) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final days = DateTime.utc(widget.end.year, widget.end.month, widget.end.day)
        .difference(
          DateTime.utc(widget.start.year, widget.start.month, widget.start.day),
        )
        .inDays;
    final mine = widget.mine.where((e) => e.mood != null).toList();
    final theirs = widget.theirs.where((e) => e.mood != null).toList();
    final hasData = mine.isNotEmpty || theirs.isNotEmpty;
    final picked =
        selectedDay ??
        (hasData
            ? [
                ...mine,
                ...theirs,
              ].map((e) => dayOf(e.date)).reduce((a, b) => a > b ? a : b)
            : null);
    final ownEntry = picked == null ? null : onDay(mine, picked);
    final partnerEntry = picked == null ? null : onDay(theirs, picked);
    const ownColor = Color(0xFFD85283);
    const partnerColor = Color(0xFF408D69);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD5E5D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Our mood journey',
            style: TextStyle(fontSize: 22, color: plum),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a dot to revisit a day',
            style: TextStyle(color: inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Legend(name: 'You', color: ownColor),
              if (theirs.isNotEmpty)
                _Legend(name: widget.partnerName, color: partnerColor),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            const SizedBox(
              height: 170,
              child: Center(
                child: Text('Your daily check-ins will draw this journey.'),
              ),
            )
          else ...[
            SizedBox(
              height: 225,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (days - 1).toDouble(),
                  minY: .7,
                  maxY: 4.3,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFFDCE9DD), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if ((value - value.round()).abs() > .01) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            switch (value.round()) {
                              1 => 'Heavy',
                              2 => 'Tender',
                              3 => 'Calm',
                              4 => 'Bright',
                              _ => '',
                            },
                            style: const TextStyle(
                              color: inkSoft,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 25,
                        interval: days > 10 ? 7 : 1,
                        getTitlesWidget: (value, meta) {
                          final day = value.round();
                          if (day < 0 || day >= days) {
                            return const SizedBox.shrink();
                          }
                          final date = widget.start.add(Duration(days: day));
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '${date.day}',
                              style: const TextStyle(
                                color: inkSoft,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      final spot = response?.lineBarSpots?.firstOrNull;
                      if (spot != null) {
                        setState(() => selectedDay = spot.x.round());
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => plum,
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                            spot.barIndex == 0 ? 'You' : widget.partnerName,
                            const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    _line(mine, ownColor),
                    if (theirs.isNotEmpty) _line(theirs, partnerColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (picked != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD5E5D6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moodDate(widget.start.add(Duration(days: picked))),
                      style: const TextStyle(
                        color: plum,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DayMood(name: 'You', entry: ownEntry, color: ownColor),
                    if (theirs.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _DayMood(
                        name: widget.partnerName,
                        entry: partnerEntry,
                        color: partnerColor,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Text(
              'The height groups feelings by tone. Every mood is valid.',
              style: TextStyle(color: inkSoft, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  LineChartBarData _line(List<MoodJournalEntry> entries, Color color) =>
      LineChartBarData(
        spots: [
          for (final entry
              in (entries.toList()..sort((a, b) => a.date.compareTo(b.date))))
            FlSpot(dayOf(entry.date).toDouble(), moodTone(entry.mood!)),
        ],
        isCurved: false,
        color: color,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: selectedDay == spot.x.round() ? 6 : 4,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 15,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(name, style: const TextStyle(color: plum, fontSize: 12)),
    ],
  );
}

class _DayMood extends StatelessWidget {
  const _DayMood({
    required this.name,
    required this.entry,
    required this.color,
  });
  final String name;
  final MoodJournalEntry? entry;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text('$name: ', style: const TextStyle(color: inkSoft, fontSize: 12)),
      Flexible(
        child: Text(
          entry?.mood?.title ?? 'No check-in',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: plum, fontSize: 12),
        ),
      ),
      if (entry?.mood != null) ...[
        const Spacer(),
        Image.asset(entry!.mood!.asset, width: 25, height: 25),
      ],
    ],
  );
}
