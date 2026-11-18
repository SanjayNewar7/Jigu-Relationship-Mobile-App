import 'package:flutter/cupertino.dart';
import '../../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../models/relationship_days.dart';

class RelationshipCard extends StatelessWidget {
  const RelationshipCard({super.key, this.startedOn, this.onSetDate});
  final DateTime? startedOn;
  final Future<void> Function(DateTime date)? onSetDate;
  Future<void> chooseDate(BuildContext context) async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: startedOn ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'When did your story begin?',
    );
    if (chosen == null || onSetDate == null) return;
    try {
      await onSetDate!(chosen);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                error,
                fallback: 'Could not save your date. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = RelationshipDays.fromDate(startedOn, DateTime.now());
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.heart_fill, color: coral, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Our days together',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (onSetDate != null)
                IconButton(
                  tooltip: count == null ? 'Set our date' : 'Change our date',
                  onPressed: () => chooseDate(context),
                  icon: const Icon(CupertinoIcons.calendar, size: 21),
                ),
            ],
          ),
          const SizedBox(height: 2),
          if (count == null) ...[
            const Text('Choose the day your story began.'),
            TextButton(
              onPressed: onSetDate == null ? null : () => chooseDate(context),
              child: const Text('Set our date'),
            ),
          ] else ...[
            Text(
              '${count.days} ${count.days == 1 ? 'day' : 'days'} together',
              style: const TextStyle(fontSize: 29, color: plum),
            ),
            const SizedBox(height: 2),
            Text(count.message, style: const TextStyle(color: inkSoft)),
          ],
        ],
      ),
    );
  }
}
