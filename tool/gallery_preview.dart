import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:jigulove/features/home/views/moment_photo_view.dart';

Future<File> sample(String name, int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  canvas.drawCircle(
    Offset(width / 2, height / 2),
    width * .22,
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final file = File('${Directory.systemTemp.path}/$name.png');
  return file.writeAsBytes(data!.buffer.asUint8List());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final portrait = await sample('jigu-portrait-preview', 300, 800, Colors.pink);
  final landscape = await sample(
    'jigu-landscape-preview',
    800,
    300,
    Colors.teal,
  );
  runApp(
    MaterialApp(
      home: MomentPhotoView(
        moments: [
          {'id': 'portrait', 'path': portrait.path},
          {'id': 'landscape', 'path': landscape.path},
        ],
        imageLoader: (moment) async => File(moment['path']),
      ),
    ),
  );
}
