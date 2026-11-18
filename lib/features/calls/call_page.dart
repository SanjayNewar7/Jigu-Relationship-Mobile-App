import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import '../../controllers/call_controller.dart';
import '../../models/partner_call.dart';

class CallPage extends StatefulWidget {
  const CallPage({
    super.key,
    required this.call,
    this.partnerName,
    this.controller,
  });
  final PartnerCall call;
  final String? partnerName;
  final CallController? controller;
  static bool isOpen = false;
  static Future<void> open(
    BuildContext context,
    PartnerCall call, {
    String? partnerName,
  }) async {
    if (isOpen) return;
    isOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallPage(call: call, partnerName: partnerName),
        ),
      );
    } finally {
      isOpen = false;
    }
  }

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final controller = widget.controller ?? CallController(widget.call);
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  Timer? clock;
  rtc.RTCVideoRenderer? ringingPreview;
  rtc.MediaStream? ringingStream;
  Future<void>? previewReady;
  bool previewLoading = false;

  Future<void> startPreview() async {
    if (widget.call.kind != 'video' ||
        widget.controller != null ||
        previewLoading ||
        ringingPreview != null ||
        controller.connected ||
        controller.connecting ||
        controller.call.terminal) {
      return;
    }
    previewLoading = true;
    final renderer = rtc.RTCVideoRenderer();
    try {
      await renderer.initialize();
      final stream = await rtc.navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {'facingMode': 'user'},
      });
      if (!mounted || controller.connecting || controller.ending) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        await stream.dispose();
        await renderer.dispose();
        return;
      }
      renderer.srcObject = stream;
      ringingStream = stream;
      ringingPreview = renderer;
      setState(() {});
    } catch (_) {
      await renderer.dispose();
      // A denied camera permission leaves the call available without preview.
    } finally {
      previewLoading = false;
    }
  }

  Future<void> releasePreview() async {
    await previewReady;
    final stream = ringingStream;
    ringingStream = null;
    final renderer = ringingPreview;
    ringingPreview = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      await stream.dispose();
    }
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(update);
    controller.beforeConnect = releasePreview;
    previewReady = startPreview();
    controller.start();
    clock = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  void update() {
    if (controller.connected || controller.call.terminal) {
      pulse.stop();
    } else if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (ringingPreview != null) unawaited(releasePreview());
      controller.background();
    } else if (state == AppLifecycleState.resumed &&
        !controller.connected &&
        !controller.connecting &&
        ringingPreview == null) {
      previewReady = startPreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock?.cancel();
    controller.removeListener(update);
    controller.beforeConnect = null;
    unawaited(releasePreview());
    controller.dispose();
    pulse.dispose();
    super.dispose();
  }

  bool leaving = false;
  Future<void> leave() async {
    if (leaving) return;
    setState(() => leaving = true);
    if (!controller.call.terminal) {
      unawaited(
        controller.finish(
          decline: controller.incoming && controller.call.status == 'ringing',
        ),
      );
    }
    // Allow PopScope to rebuild before leaving; never wait for the server.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final video = c.call.kind == 'video';
    final remote = c.room.remoteParticipants.values.firstOrNull;
    final remoteVideo = remote?.videoTrackPublications
        .where((p) => !p.muted && p.track != null)
        .firstOrNull
        ?.track;
    final localVideo = c.room.localParticipant?.videoTrackPublications
        .where((p) => !p.muted && p.track != null)
        .firstOrNull
        ?.track;
    final seconds = c.call.acceptedAt == null
        ? 0
        : DateTime.now()
              .difference(c.call.acceptedAt!)
              .inSeconds
              .clamp(0, 86400);
    final name = widget.partnerName?.trim().isNotEmpty == true
        ? widget.partnerName!.trim()
        : 'Your person';
    final incoming = c.incoming && c.call.status == 'ringing';
    final status = c.call.terminal
        ? (c.call.status == 'declined'
              ? 'Call declined'
              : c.call.status == 'missed'
              ? 'No answer'
              : 'Call ended')
        : c.room.connectionState == ConnectionState.reconnecting
        ? 'Reconnecting...'
        : c.connecting
        ? 'Connecting...'
        : c.connected
        ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
        : incoming
        ? 'Incoming ${video ? 'video' : 'audio'} call'
        : 'Ringing...';
    return PopScope(
      canPop: leaving || c.call.terminal,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF271C29),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: video
                        ? const [Color(0xFF322333), Color(0xFF17151D)]
                        : const [
                            Color(0xFF694259),
                            Color(0xFF342439),
                            Color(0xFF211C2A),
                          ],
                  ),
                ),
              ),
            ),
            if (remoteVideo != null)
              Positioned.fill(child: VideoTrackRenderer(remoteVideo)),
            if (remoteVideo == null &&
                ringingPreview != null &&
                !c.connected &&
                !c.connecting)
              Positioned.fill(
                child: rtc.RTCVideoView(
                  ringingPreview!,
                  mirror: true,
                  objectFit:
                      rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            if (remoteVideo != null || ringingPreview != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.black87,
                        ],
                        stops: const [0, .45, 1],
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.spa_outlined,
                          color: Color(0xFFF2B9CF),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'JIGU  /  ${video ? 'VIDEO CALL' : 'AUDIO CALL'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        if (c.connected)
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: Color(0xFFF2B9CF),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        children: [
                          Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (remoteVideo == null &&
                                      ringingPreview == null) ...[
                                    AnimatedBuilder(
                                      animation: pulse,
                                      builder: (_, child) => Transform.scale(
                                        scale: c.connected || c.call.terminal
                                            ? 1
                                            : .98 + pulse.value * .025,
                                        child: Container(
                                          width: 142,
                                          height: 142,
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(
                                              alpha: .08,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: .18,
                                              ),
                                            ),
                                          ),
                                          child: child,
                                        ),
                                      ),
                                      child: Image.asset(
                                        'assets/jigu_lily_foreground.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                  ],
                                  Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: .16,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      status,
                                      style: const TextStyle(
                                        color: Color(0xFFF5DCE7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (c.connected &&
                                      remoteVideo == null &&
                                      video)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 12),
                                      child: Text(
                                        'Their camera is off',
                                        style: TextStyle(color: Colors.white60),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (localVideo != null && c.camera)
                            Positioned(
                              right: 20,
                              top: 8,
                              width: 96,
                              height: 136,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    VideoTrackRenderer(localVideo),
                                    const Positioned(
                                      left: 10,
                                      bottom: 8,
                                      child: Text(
                                        'You',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Text(
                        c.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD5DD),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .12),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!c.call.terminal)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    CallControl(
                                      icon: c.mic
                                          ? Icons.mic_none_rounded
                                          : Icons.mic_off_rounded,
                                      label: c.mic ? 'Mute' : 'Unmute',
                                      selected: !c.mic,
                                      onPressed: c.connecting
                                          ? null
                                          : c.toggleMic,
                                    ),
                                    CallControl(
                                      icon: c.speaker
                                          ? Icons.volume_up_rounded
                                          : Icons.hearing_rounded,
                                      label: 'Speaker',
                                      selected: c.speaker,
                                      onPressed: c.toggleSpeaker,
                                    ),
                                    if (video)
                                      CallControl(
                                        icon: c.camera
                                            ? Icons.videocam_outlined
                                            : Icons.videocam_off_outlined,
                                        label: 'Camera',
                                        selected: c.camera,
                                        onPressed: c.connecting
                                            ? null
                                            : c.toggleCamera,
                                      ),
                                    if (video)
                                      CallControl(
                                        icon: Icons.cameraswitch_outlined,
                                        label: 'Flip',
                                        onPressed: c.connected && c.camera
                                            ? c.flipCamera
                                            : null,
                                      ),
                                  ],
                                ),
                              if (!c.call.terminal) const SizedBox(height: 24),
                              Row(
                                children: [
                                  if (incoming) ...[
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: c.busy ? null : c.accept,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF518870,
                                          ),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 56),
                                        ),
                                        icon: Icon(
                                          video
                                              ? Icons.videocam_rounded
                                              : Icons.call_rounded,
                                        ),
                                        label: const Text('Answer'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: leaving ? null : leave,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFD94D67,
                                        ),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 56),
                                      ),
                                      icon: Icon(
                                        c.call.terminal
                                            ? Icons.arrow_back_rounded
                                            : Icons.call_end_rounded,
                                      ),
                                      label: Text(
                                        c.call.terminal
                                            ? 'Back to chat'
                                            : incoming
                                            ? 'Decline'
                                            : 'End call',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CallControl extends StatelessWidget {
  const CallControl({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Flexible(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          toggled: selected,
          child: IconButton.filledTonal(
            onPressed: onPressed,
            tooltip: label,
            style: IconButton.styleFrom(
              minimumSize: const Size(54, 54),
              backgroundColor: selected
                  ? const Color(0xFFF5D5E3)
                  : Colors.white.withValues(alpha: .1),
              foregroundColor: selected
                  ? const Color(0xFF56324B)
                  : Colors.white,
              disabledForegroundColor: Colors.white30,
            ),
            icon: Icon(icon, size: 25),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: TextStyle(
            color: onPressed == null ? Colors.white38 : Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
