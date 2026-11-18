import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/config.dart';

class DateSelfie extends StatefulWidget {
  const DateSelfie({super.key, required this.path});
  final String path;
  @override
  State<DateSelfie> createState() => _DateSelfieState();
}

class _DateSelfieState extends State<DateSelfie> {
  late Future<Uint8List> photo = db.storage
      .from('date-memories')
      .download(widget.path);
  @override
  void didUpdateWidget(DateSelfie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      photo = db.storage.from('date-memories').download(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: photo,
    builder: (context, snapshot) => ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: snapshot.hasData
          ? Image.memory(
              snapshot.data!,
              height: 230,
              fit: BoxFit.cover,
              cacheWidth: 900,
              semanticLabel: 'Our selfie together',
            )
          : SizedBox(
              height: 100,
              child: Center(
                child: snapshot.hasError
                    ? TextButton(
                        onPressed: () => setState(
                          () => photo = db.storage
                              .from('date-memories')
                              .download(widget.path),
                        ),
                        child: const Text('Tap to reload our photo'),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
    ),
  );
}
