import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../../models/chat_message.dart';
import '../../../services/chat_service.dart';

class ChatMedia extends StatefulWidget {
  const ChatMedia({super.key, required this.message});
  final ChatMessage message;
  @override
  State<ChatMedia> createState() => _ChatMediaState();
}

class _ChatMediaState extends State<ChatMedia> {
  late Future<String> url;
  @override
  void initState() {
    super.initState();
    url = widget.message.expired
        ? Future.value('')
        : ChatService().mediaUrl(widget.message);
  }

  @override
  void didUpdateWidget(ChatMedia old) {
    super.didUpdateWidget(old);
    if (old.message.storagePath != widget.message.storagePath) {
      url = ChatService().mediaUrl(widget.message);
    }
  }

  @override
  Widget build(BuildContext context) => widget.message.expired
      ? const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Attachment expired after 30 days'),
        )
      : FutureBuilder<String>(
          future: url,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton.icon(
                onPressed: () => setState(
                  () => url = ChatService().mediaUrl(widget.message),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry attachment'),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (widget.message.kind == 'voice') {
              return VoicePlayer(
                url: snapshot.data!,
                resolveUrl: () => ChatService().mediaUrl(widget.message),
              );
            }
            if (widget.message.kind == 'video') {
              return TextButton.icon(
                onPressed: () async {
                  try {
                    final freshUrl = await ChatService().mediaUrl(
                      widget.message,
                    );
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VideoMessagePage(url: freshUrl),
                      ),
                    );
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => url = ChatService().mediaUrl(widget.message),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.play_circle_fill, size: 38),
                label: const Text('Play video'),
              );
            }
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    body: Center(
                      child: InteractiveViewer(
                        child: Image.network(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, e, s) => const Text(
                            'Image could not load',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  snapshot.data!,
                  height: 200,
                  width: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => const SizedBox(
                    height: 100,
                    child: Center(child: Text('Image unavailable')),
                  ),
                ),
              ),
            );
          },
        );
}

class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.url, this.resolveUrl});
  final String url;
  final Future<String> Function()? resolveUrl;
  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> with WidgetsBindingObserver {
  final player = AudioPlayer();
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> toggle() async {
    if (busy) return;
    if (player.playing) {
      await player.pause();
      return;
    }
    setState(() => busy = true);
    try {
      if (player.audioSource == null || error != null) {
        final source = await widget.resolveUrl?.call() ?? widget.url;
        await player.setUrl(source);
      }
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      player.play();
      error = null;
    } catch (_) {
      error = 'Could not play. Tap to retry.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) player.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Row(
      children: [
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (_, s) => IconButton(
            onPressed: toggle,
            tooltip: 'Play or pause voice message',
            icon: Icon(
              busy
                  ? Icons.hourglass_empty
                  : (s.data?.playing == true &&
                            s.data?.processingState != ProcessingState.completed
                        ? Icons.pause_circle
                        : Icons.play_circle),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error ?? 'Voice message',
                style: const TextStyle(fontSize: 13),
              ),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (_, s) {
                  final seconds = (s.data ?? Duration.zero).inSeconds;
                  return Text(
                    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class VideoMessagePage extends StatefulWidget {
  const VideoMessagePage({super.key, required this.url});
  final String url;
  @override
  State<VideoMessagePage> createState() => _VideoMessagePageState();
}

class _VideoMessagePageState extends State<VideoMessagePage>
    with WidgetsBindingObserver {
  late final controller = widget.url.startsWith('file:')
      ? VideoPlayerController.file(File.fromUri(Uri.parse(widget.url)))
      : VideoPlayerController.networkUrl(Uri.parse(widget.url));
  late final Future<void> ready;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ready = controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Your video'),
    ),
    body: FutureBuilder<void>(
      future: ready,
      builder: (_, s) {
        if (s.hasError) {
          return const Center(
            child: Text(
              'Video could not load. Reopen it to retry.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            VideoProgressIndicator(controller, allowScrubbing: true),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (_, value, child) => IconButton(
                color: Colors.white,
                iconSize: 48,
                onPressed: () {
                  if (value.isPlaying) {
                    controller.pause();
                  } else {
                    if (value.position >= value.duration) {
                      controller.seekTo(Duration.zero);
                    }
                    controller.play();
                  }
                },
                icon: Icon(
                  value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
