import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/config.dart';

Future<bool> confirmDiscardMoment(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cream.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/jigu_lily_foreground.png', height: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Leave this little moment?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Sniglet',
                      fontSize: 22,
                      color: plum,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your edits will be lost. You can stay and make it yours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: inkSoft),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: plum,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep editing'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Discard edits',
                      style: TextStyle(color: plum),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ??
    false;
