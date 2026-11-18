import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// One image texture and one shader, shared by preview and export.
class BotanicalRenderer {
  BotanicalRenderer._(this.image, this.program)
    : shader = program.fragmentShader();
  final ui.Image image;
  final ui.FragmentProgram program;
  final ui.FragmentShader shader;

  static Future<BotanicalRenderer> load(String path) async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/botanical_filters.frag',
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await File(path).readAsBytes(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      // Match the existing moment editor's 2560px export limit. Never upscale.
      final scale = math.min(
        1.0,
        2560 / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
      try {
        final frame = await codec.getNextFrame();
        return BotanicalRenderer._(frame.image, program);
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  void paint(
    ui.Canvas canvas,
    ui.Size size,
    int current,
    int next,
    double progress,
    double direction,
    double intensity,
  ) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, current.toDouble())
      ..setFloat(3, next.toDouble())
      ..setFloat(4, progress)
      ..setFloat(5, direction)
      ..setFloat(6, intensity)
      ..setImageSampler(0, image);
    canvas.drawRect(ui.Offset.zero & size, ui.Paint()..shader = shader);
  }

  Future<Uint8List> export(int selected, double intensity) async {
    // Export has independent uniforms so a preview repaint cannot change it.
    final exporter = BotanicalRenderer._(image, program);
    final recorder = ui.PictureRecorder();
    exporter.paint(
      ui.Canvas(recorder),
      ui.Size(image.width.toDouble(), image.height.toDouble()),
      selected,
      selected,
      0,
      0,
      intensity,
    );
    final picture = recorder.endRecording();
    try {
      final rendered = await picture.toImage(image.width, image.height);
      try {
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Image export failed');
        return bytes.buffer.asUint8List();
      } finally {
        rendered.dispose();
      }
    } finally {
      picture.dispose();
      exporter.shader.dispose();
    }
  }

  void dispose() {
    shader.dispose();
    image.dispose();
  }
}
