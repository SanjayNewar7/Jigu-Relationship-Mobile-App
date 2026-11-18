import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import '../core/config.dart';
import '../core/errors/app_error.dart';
import '../models/partner_call.dart';
import '../services/call_service.dart';

class CallController extends ChangeNotifier {
  CallController(this.call) {
    camera = call.kind == 'video';
    speaker = camera;
  }
  PartnerCall call;
  final service = CallService();
  final room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  static const native = MethodChannel('jigu/calls');
  Timer? timer;
  Future<void> Function()? beforeConnect;
  Future<void>? disconnecting;
  bool busy = false,
      ending = false,
      connecting = false,
      connected = false,
      disposed = false,
      polling = false,
      mic = true,
      camera = false,
      speaker = false;
  String? error;
  bool micBusy = false,
      cameraBusy = false,
      speakerBusy = false,
      flipBusy = false;
  DateTime lastSuccess = DateTime.now();
  bool get incoming => call.callerId != db.auth.currentUser?.id;
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> start() async {
    room.addListener(changed);
    timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
    await poll();
  }

  Future<void> poll() async {
    if (polling || disposed || ending || call.terminal) return;
    polling = true;
    try {
      final latest = await service.action(
        call.status == 'accepted' ? 'heartbeat' : 'status',
        id: call.id,
      );
      if (disposed || ending) return;
      call = latest;
      lastSuccess = DateTime.now();
      if (call.terminal) {
        await disconnect();
      } else if (call.status == 'accepted' && !connected && !connecting) {
        await connect();
      }
    } catch (e) {
      error = AppError.message(e, fallback: 'Reconnecting to your call…');
      if (DateTime.now().difference(lastSuccess).inSeconds > 30) {
        await disconnect();
      }
    } finally {
      polling = false;
      changed();
    }
  }

  Future<void> accept() async {
    if (busy) return;
    busy = true;
    changed();
    try {
      call = await service.action('accept', id: call.id);
      if (disposed || ending) return;
      await connect();
    } catch (e) {
      setError(e);
    } finally {
      busy = false;
      changed();
    }
  }

  void setError(Object e) {
    error = AppError.message(
      e,
      fallback:
          'Could not connect. Check microphone and camera permissions, then retry.',
    );
    changed();
  }

  Future<void> connect() async {
    if (connecting || disposed || ending || call.terminal) return;
    connecting = true;
    disconnecting = null;
    error = null;
    changed();
    try {
      await beforeConnect?.call();
      if (disposed || ending) return;
      final result = await service.request('token', id: call.id);
      if (disposed || ending) return;
      await room.connect(result['url'] as String, result['token'] as String);
      if (disposed || ending) {
        await disconnect();
        return;
      }
      await room.localParticipant?.setMicrophoneEnabled(mic);
      if (disposed || ending) {
        await disconnect();
        return;
      }
      if (camera) await room.localParticipant?.setCameraEnabled(true);
      if (disposed || ending) {
        await disconnect();
        return;
      }
      await AudioManager.instance.setSpeakerOutputPreferred(speaker);
      if (Platform.isAndroid) await native.invokeMethod('start');
      if (disposed || ending) {
        await disconnect();
        return;
      }
      connected = true;
    } catch (e) {
      await disconnect();
      setError(e);
      try {
        call = await service.action('end', id: call.id);
      } catch (_) {}
    } finally {
      connecting = false;
      changed();
    }
  }

  Future<void> finish({bool decline = false}) async {
    if (ending) return;
    ending = true;
    busy = true;
    timer?.cancel();
    changed();
    // Stop local media independently of the network acknowledgement.
    final localCleanup = disconnect();
    try {
      call = await service.action(decline ? 'decline' : 'end', id: call.id);
    } catch (e) {
      setError(e);
    } finally {
      await localCleanup;
      busy = false;
      changed();
    }
  }

  Future<void> toggleMic() async {
    if (ending || disposed || micBusy) return;
    micBusy = true;
    try {
      if (connected) await room.localParticipant?.setMicrophoneEnabled(!mic);
      mic = !mic;
      error = null;
      changed();
    } catch (e) {
      setError(e);
    } finally {
      micBusy = false;
    }
  }

  Future<void> toggleCamera() async {
    if (ending || disposed || cameraBusy || call.kind != 'video') return;
    cameraBusy = true;
    try {
      if (connected) await room.localParticipant?.setCameraEnabled(!camera);
      camera = !camera;
      error = null;
      changed();
    } catch (e) {
      setError(e);
    } finally {
      cameraBusy = false;
    }
  }

  Future<void> toggleSpeaker() async {
    if (ending || disposed || speakerBusy) return;
    speakerBusy = true;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(
        !speaker,
        force: !speaker,
      );
      speaker = !speaker;
      error = null;
      changed();
    } catch (e) {
      setError(e);
    } finally {
      speakerBusy = false;
    }
  }

  Future<void> flipCamera() async {
    if (ending || disposed || flipBusy || !connected || !camera) return;
    flipBusy = true;
    try {
      final devices = await Hardware.instance.videoInputs();
      final current = Hardware.instance.selectedVideoInput;
      final next = devices
          .where((d) => d.deviceId != current?.deviceId)
          .firstOrNull;
      if (next != null) await room.setVideoInputDevice(next);
    } catch (e) {
      setError(e);
    } finally {
      flipBusy = false;
    }
  }

  Future<void> background() async {
    if (connected && camera) {
      try {
        await room.localParticipant?.setCameraEnabled(false);
        camera = false;
        changed();
      } catch (e) {
        setError(e);
      }
    }
  }

  Future<void> disconnect() => disconnecting ??= stopMedia();

  Future<void> stopMedia() async {
    connected = false;
    try {
      await room.disconnect().timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (Platform.isAndroid) {
      try {
        await native.invokeMethod('stop');
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    disposed = true;
    timer?.cancel();
    room.removeListener(changed);
    unawaited(disconnect().whenComplete(() => room.dispose()));
    super.dispose();
  }
}
