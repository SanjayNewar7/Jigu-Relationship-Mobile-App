import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceMessageService {
  final _recorder = AudioRecorder();
  String? _path;
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Allow microphone access to record a voice message.');
    }
    _path =
        '${(await getTemporaryDirectory()).path}/jigu-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _path!,
    );
  }

  Future<File?> stop() async {
    final path = await _recorder.stop();
    return path == null ? null : File(path);
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    await clear();
  }

  Future<void> clear() async {
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await clear();
  }
}
