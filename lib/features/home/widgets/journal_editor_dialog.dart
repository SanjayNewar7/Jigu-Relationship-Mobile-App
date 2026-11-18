import 'package:flutter/material.dart';
import '../../../core/config.dart';

class JournalEditorDialog extends StatefulWidget {
  const JournalEditorDialog({
    super.key,
    required this.day,
    required this.initialText,
  });
  final DateTime day;
  final String initialText;

  @override
  State<JournalEditorDialog> createState() => _JournalEditorDialogState();
}

class _JournalEditorDialogState extends State<JournalEditorDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFFFFFCFA),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    icon: const Icon(Icons.menu_book_outlined, color: sage, size: 32),
    title: Text(
      'Your journal · ${widget.day.day}/${widget.day.month}/${widget.day.year}',
    ),
    content: TextField(
      controller: controller,
      autofocus: true,
      minLines: 4,
      maxLines: 9,
      maxLength: 4000,
      style: const TextStyle(fontSize: 16, height: 1.6, color: plum),
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        hintText: 'What would you like to remember about this day?',
        filled: true,
        fillColor: Color(0xFFF7F3F2),
        contentPadding: EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFFDAB6C4)),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Save note'),
      ),
    ],
  );
}
