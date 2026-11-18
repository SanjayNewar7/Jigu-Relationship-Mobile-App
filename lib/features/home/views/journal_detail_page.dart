import '../../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../widgets/mood_visuals.dart';
import '../../../services/mood_journal_service.dart';
import '../models/couple_quote_bank.dart';
import '../widgets/journal_editor_dialog.dart';

class JournalDetailPage extends StatefulWidget {
  const JournalDetailPage({
    super.key,
    required this.entry,
    this.readOnly = false,
    this.onSave,
    this.onDelete,
  });
  final MoodJournalEntry entry;
  final bool readOnly;
  final Future<void> Function(DateTime, String)? onSave;
  final Future<void> Function(DateTime)? onDelete;

  @override
  State<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends State<JournalDetailPage> {
  final service = MoodJournalService();
  late String note = widget.entry.journal ?? '';
  bool busy = false;

  Future<void> edit() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          JournalEditorDialog(day: widget.entry.date, initialText: note),
    );
    if (value == null || !mounted) return;
    setState(() => busy = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(widget.entry.date, value);
      } else {
        await service.save(widget.entry.date, journal: value);
      }
      if (mounted) setState(() => note = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Could not update your journal. Please retry.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this journal?'),
        content: const Text(
          'This note will be removed. Your mood for this day will stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep note'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete note'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      if (widget.onDelete != null) {
        await widget.onDelete!(widget.entry.date);
      } else {
        await service.removeJournal(widget.entry.date);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Could not delete your journal. Please retry.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.readOnly ? 'Your person’s journal' : 'Your journal'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '${widget.entry.date.day} ${_month(widget.entry.date.month)} ${widget.entry.date.year}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: plum),
          ),
          if (widget.entry.mood != null) ...[
            const SizedBox(height: 6),
            Text(
              'Feeling ${widget.entry.mood!.title.toLowerCase()}',
              style: const TextStyle(color: inkSoft),
            ),
          ],
          const SizedBox(height: 20),
          ReflectionSurface(
            child: SelectableText(
              note,
              style: const TextStyle(fontSize: 17, height: 1.55, color: plum),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: widget.readOnly
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : edit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit journal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    tooltip: 'Delete journal',
                    onPressed: busy ? null : remove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
  );
}

String _month(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];
