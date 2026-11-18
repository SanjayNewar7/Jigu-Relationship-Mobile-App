import '../calls/call_page.dart';
import '../../services/call_service.dart';
import 'widgets/theme_flower.dart';
import 'widgets/chat_wallpaper.dart';
import '../../core/errors/app_error.dart';
import 'widgets/typing_bubble.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/chat_reaction.dart';
import 'widgets/message_gestures.dart';
import 'widgets/reaction_picker.dart';
import 'widgets/reply_quote.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_message.dart';
import '../../services/voice_message_service.dart';
import '../../utils/location_label.dart';
import 'widgets/chat_media.dart';
import 'widgets/chat_palette.dart';
import 'widgets/giphy_picker.dart';
import '../../services/giphy_service.dart';
import '../../services/chat_visibility.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.space,
    required this.partnerName,
    this.controller,
  });
  final String space, partnerName;
  final ChatController? controller;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late final chat = widget.controller ?? ChatController(widget.space);
  final text = TextEditingController();
  final itemScroll = ItemScrollController();
  final messageFocus = FocusNode();
  ChatMessage? replyingTo;
  String? failedReplyId;
  final voice = VoiceMessageService();
  bool sending = false, recording = false, startingRecording = false;
  bool showEmojiPicker = false;
  DateTime? recordingStarted;
  Timer? clock;
  String? failedTextId, failedText;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatVisibility.space = widget.space;
    ChatVisibility.isCurrent = () =>
        mounted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false);
    chat.addListener(rebuild);
    chat.start();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (recording || DateTime.now().second == 0)) {
        setState(() {});
      }
      if (recording &&
          DateTime.now().difference(recordingStarted!).inMinutes >= 2) {
        finishVoice();
      }
    });
  }

  void rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    chat.active = state == AppLifecycleState.resumed;
    if (chat.active) {
      chat.refresh();
    } else if (recording) {
      voice.cancel();
      setState(() => recording = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatVisibility.clear(widget.space);
    clock?.cancel();
    chat.dispose();
    voice.dispose();
    text.dispose();
    messageFocus.dispose();
    super.dispose();
  }

  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppError.message(e, fallback: 'Could not send. Please try again.'),
          ),
        ),
      );
    }
  }

  void bottom() {
    if (itemScroll.isAttached) {
      itemScroll.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> sendText() async {
    final value = text.text.trim();
    if (sending || value.isEmpty) return;
    final reply = replyingTo;
    final replyId = reply?.id;
    final retrying = failedText == value && failedReplyId == replyId;
    final id = retrying ? failedTextId! : chat.service.newId();
    setState(() => sending = true);
    try {
      await chat.service.sendText(
        widget.space,
        value,
        id,
        replyToId: replyId,
        checkExisting: retrying,
      );
      if (text.text.trim() == value) text.clear();
      failedText = null;
      failedTextId = null;
      failedReplyId = null;
      if (mounted) setState(() => replyingTo = null);
      chat.acceptSent(
        ChatMessage(
          id: id,
          senderId: chat.service.userId,
          kind: 'text',
          body: value,
          createdAt: DateTime.now().toUtc(),
          replyToId: replyId,
          replyPreview: reply == null
              ? null
              : reply.kind == 'text'
              ? reply.body
              : reply.kind,
          replySenderId: reply?.senderId,
          replyKind: reply?.kind,
        ),
      );
      bottom();
    } catch (e) {
      failedText = value;
      failedTextId = id;
      failedReplyId = replyId;
      error(e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> attachment(String kind) async {
    if (sending || recording) return;
    try {
      final picker = ImagePicker();
      final XFile? picked = kind == 'video'
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      final lower = picked.path.toLowerCase();
      final actual = lower.endsWith('.gif') ? 'gif' : kind;
      if (kind == 'gif' && actual != 'gif') {
        throw StateError('Choose an animated .gif file from your gallery.');
      }
      final mime = actual == 'video'
          ? (lower.endsWith('.mov') ? 'video/quicktime' : 'video/mp4')
          : actual == 'gif'
          ? 'image/gif'
          : lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      await previewAndSend(file, actual, mime);
    } catch (e) {
      error(e);
    }
  }

  Future<void> previewAndSend(File file, String kind, String mime) async {
    if (await file.length() > 25 * 1024 * 1024) {
      throw StateError('Choose a file smaller than 25 MB.');
    }
    if (!mounted) return;
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kind == 'voice'
                    ? 'A little voice note'
                    : 'Send to ${widget.partnerName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (kind == 'image' || kind == 'gif')
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              if (kind == 'video')
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          VideoMessagePage(url: file.uri.toString()),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle, size: 48),
                  label: const Text('Preview video'),
                ),
              if (kind == 'voice') VoicePlayer(url: file.uri.toString()),
              const SizedBox(height: 12),
              const Text(
                'This attachment is available for 30 days.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => sending = true);
    try {
      final id = chat.service.newId();
      final reply = replyingTo;
      await chat.service.sendFile(
        widget.space,
        file,
        kind,
        mime,
        id,
        replyToId: reply?.id,
      );
      if (mounted) setState(() => replyingTo = null);
      chat.acceptSent(
        ChatMessage(
          id: id,
          senderId: chat.service.userId,
          kind: kind,
          body: '',
          storagePath: '${widget.space}/${chat.service.userId}/$id',
          createdAt: DateTime.now().toUtc(),
          replyToId: reply?.id,
          replyPreview: reply == null
              ? null
              : reply.kind == 'text'
              ? reply.body
              : reply.kind,
          replySenderId: reply?.senderId,
          replyKind: reply?.kind,
        ),
      );
      bottom();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> startVoice() async {
    if (sending || recording || startingRecording) return;
    setState(() => startingRecording = true);
    try {
      await voice.start();
      if (!mounted) {
        await voice.cancel();
        return;
      }
      setState(() {
        recording = true;
        recordingStarted = DateTime.now();
      });
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => startingRecording = false);
    }
  }

  Future<void> finishVoice() async {
    if (!recording) return;
    setState(() => recording = false);
    try {
      final file = await voice.stop();
      if (file != null) await previewAndSend(file, 'voice', 'audio/mp4');
    } catch (e) {
      error(e);
    } finally {
      await voice.clear();
    }
  }

  bool startingCall = false;
  Future<void> startCall(String kind) async {
    if (startingCall || CallPage.isOpen || recording) return;
    setState(() => startingCall = true);
    try {
      final call = await CallService().action('start', kind: kind);
      if (mounted) {
        await CallPage.open(context, call, partnerName: widget.partnerName);
      }
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => startingCall = false);
    }
  }

  Future<void> themes() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('A colour for us', style: TextStyle(fontSize: 24)),
              const Text('Changes for both of you.'),
              const SizedBox(height: 20),
              for (final name in ChatPalette.names)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ChatPalette.forName(name).background,
                    child: ThemeFlower(
                      name: name,
                      color: ChatPalette.forName(name).sent,
                    ),
                  ),
                  title: Text(name[0].toUpperCase() + name.substring(1)),
                  trailing: chat.theme == name ? const Icon(Icons.check) : null,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await chat.service.theme(widget.space, name);
                      await chat.refresh();
                    } catch (e) {
                      error(e);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void emojis() {
    if (!showEmojiPicker) messageFocus.unfocus();
    setState(() => showEmojiPicker = !showEmojiPicker);
  }

  Future<void> attachments() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label, icon) in [
              ('image', 'Photo', Icons.image_outlined),
              ('video', 'Video', Icons.videocam_outlined),
              ('giphy', 'Search GIPHY', Icons.gif_outlined),
              ('gif', 'GIF from your phone', Icons.gif_box_outlined),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(context, value),
              ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Up to 25 MB • Automatically removed after 30 days',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
    if (kind == 'giphy') {
      if (!mounted) return;
      final gif = await showModalBottomSheet<GiphyGif>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const GiphyPicker(),
      );
      if (gif == null || !mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send this GIF?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(gif.url, height: 180),
              const Text('Powered By GIPHY'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      setState(() => sending = true);
      try {
        final id = chat.service.newId();
        final reply = replyingTo;
        await chat.service.sendGif(
          widget.space,
          gif.id,
          id,
          replyToId: reply?.id,
        );
        if (mounted) setState(() => replyingTo = null);
        chat.acceptSent(
          ChatMessage(
            id: id,
            senderId: chat.service.userId,
            kind: 'gif',
            body: '',
            giphyId: gif.id,
            createdAt: DateTime.now().toUtc(),
            replyToId: reply?.id,
            replyPreview: reply == null
                ? null
                : reply.kind == 'text'
                ? reply.body
                : reply.kind,
            replySenderId: reply?.senderId,
            replyKind: reply?.kind,
          ),
        );
        bottom();
      } catch (e) {
        error(e);
      } finally {
        if (mounted) setState(() => sending = false);
      }
    } else if (kind != null) {
      await attachment(kind);
    }
  }

  String get status {
    final typing = DateTime.tryParse(
      chat.partnerState?['typing_until']?.toString() ?? '',
    );
    if (typing?.isAfter(DateTime.now()) ?? false) return 'Typing…';
    final seen = DateTime.tryParse(
      chat.partnerState?['last_seen_at']?.toString() ?? '',
    );
    final latest = seen == null
        ? chat.partnerLastActive
        : chat.partnerLastActive == null ||
              seen.isAfter(chat.partnerLastActive!)
        ? seen
        : chat.partnerLastActive;
    return latest == null
        ? 'Your little conversation'
        : activityLabel(latest.toIso8601String());
  }

  void reply(ChatMessage message) {
    if (message.deleted) return;
    setState(() {
      replyingTo = message;
      showEmojiPicker = false;
    });
    messageFocus.requestFocus();
  }

  final pendingReactions = <String>{};
  Future<void> react(ChatMessage message, String emoji) async {
    if (message.deleted || !pendingReactions.add(message.id)) return;
    final before = List<ChatReaction>.of(chat.reactions[message.id] ?? []);
    final mine = before
        .where((r) => r.userId == chat.service.userId)
        .firstOrNull;
    chat.reactions[message.id] = before
        .where((r) => r.userId != chat.service.userId)
        .toList();
    if (mine?.emoji != emoji) {
      chat.reactions[message.id]!.add(
        ChatReaction(
          messageId: message.id,
          userId: chat.service.userId,
          emoji: emoji,
        ),
      );
    }
    chat.changed();
    try {
      if (mine?.emoji == emoji) {
        await chat.service.removeReaction(message.id);
      } else {
        await chat.service.react(message.id, emoji);
      }
      await chat.refreshReactions();
    } catch (e) {
      final partner = (chat.reactions[message.id] ?? [])
          .where((r) => r.userId != chat.service.userId)
          .toList();
      if (mine != null) partner.add(mine);
      chat.reactions[message.id] = partner;
      chat.changed();
      error(e);
    } finally {
      pendingReactions.remove(message.id);
    }
  }

  Future<void> customReaction(ChatMessage message) async {
    final emoji = await pickReaction(context, ChatPalette.forName(chat.theme));
    if (emoji != null && mounted) await react(message, emoji);
  }

  Future<void> customizeReactions() async {
    final slot = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Make these reactions yours'),
              subtitle: Text(
                'Choose a slot to replace. Your first reaction is used for double-tap.',
              ),
            ),
            for (var i = 0; i < chat.quickReactions.length; i++)
              ListTile(
                leading: Text(
                  chat.quickReactions[i],
                  style: const TextStyle(fontSize: 26, fontFamily: ''),
                ),
                title: Text('Reaction ${i + 1}'),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (slot == null || !mounted) return;
    final emoji = await pickReaction(context, ChatPalette.forName(chat.theme));
    if (emoji == null || !mounted) return;
    final next = List<String>.of(chat.quickReactions)..[slot] = emoji;
    try {
      await chat.service.saveQuickReactions(next);
      chat.quickReactions = next;
      chat.changed();
    } catch (e) {
      error(e);
    }
  }

  Future<void> reactionDetails(ChatMessage message) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('A little reaction')),
            for (final reaction
                in chat.reactions[message.id] ?? <ChatReaction>[])
              ListTile(
                leading: Text(
                  reaction.emoji,
                  style: const TextStyle(fontFamily: '', fontSize: 28),
                ),
                title: Text(
                  reaction.userId == chat.service.userId
                      ? 'You'
                      : widget.partnerName,
                ),
                subtitle: reaction.userId == chat.service.userId
                    ? const Text('Tap to remove')
                    : null,
                onTap: reaction.userId == chat.service.userId
                    ? () => Navigator.pop(context, reaction.emoji)
                    : null,
              ),
          ],
        ),
      ),
    );
    if (choice != null) await react(message, choice);
  }

  Future<void> messageActions(ChatMessage message, Rect anchor) async {
    if (message.deleted) return;
    messageFocus.unfocus();
    if (showEmojiPicker) setState(() => showEmojiPicker = false);
    final selected = await reactionMenu(
      context,
      anchor,
      chat.quickReactions,
      chat.reactions[message.id]
          ?.where((r) => r.userId == chat.service.userId)
          .firstOrNull
          ?.emoji,
      ChatPalette.forName(chat.theme),
      mine: message.senderId == chat.service.userId,
      text: message.kind == 'text',
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'reply':
        reply(message);
      case 'custom':
        await customReaction(message);
      case 'customize':
        await customizeReactions();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
      case 'unsend':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsend this message?'),
            content: const Text(
              'It will be removed from your conversation for both of you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Unsend'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await chat.service.unsend(message.id);
            await chat.refresh();
          } catch (e) {
            error(e);
          }
        }
      default:
        await react(message, selected);
    }
  }

  bool locatingReply = false;
  String? highlightedMessage;
  Future<void> jumpToReply(ChatMessage message) async {
    if (locatingReply ||
        message.replyToId == null ||
        message.replyParentDeleted) {
      return;
    }
    setState(() => locatingReply = true);
    try {
      var index = chat.messages.indexWhere((m) => m.id == message.replyToId);
      while (index < 0 && chat.hasMore && mounted) {
        final length = chat.messages.length;
        await chat.more();
        if (chat.messages.length == length) break;
        index = chat.messages.indexWhere((m) => m.id == message.replyToId);
      }
      if (!mounted) return;
      if (index < 0) {
        error(StateError('Original message unavailable.'));
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !itemScroll.isAttached) return;
      await itemScroll.scrollTo(
        index: index,
        alignment: .4,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      setState(() => highlightedMessage = message.replyToId);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) setState(() => highlightedMessage = null);
    } finally {
      if (mounted) setState(() => locatingReply = false);
    }
  }

  Widget bubble(ChatMessage message, ChatPalette palette) {
    final mine = message.senderId == chat.service.userId;
    final seen = DateTime.tryParse(
      chat.partnerState?['read_at']?.toString() ?? '',
    );
    final local = message.createdAt.toLocal();
    final currentReactions = chat.reactions[message.id] ?? [];
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            MessageGestures(
              mine: mine,
              onMenu: (anchor) => messageActions(message, anchor),
              onReact: () => react(message, chat.quickReactions.first),
              onReply: () => reply(message),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .76,
                ),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  border: highlightedMessage == message.id
                      ? Border.all(color: palette.sent, width: 3)
                      : null,
                  color: message.kind == 'text' && mine
                      ? palette.sent
                      : palette.received,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(mine ? 22 : 6),
                    bottomRight: Radius.circular(mine ? 6 : 22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.replyToId != null && !message.deleted)
                      ReplyQuote(
                        message: message,
                        parent: chat.messages
                            .where((m) => m.id == message.replyToId)
                            .firstOrNull,
                        mine: mine,
                        palette: palette,
                        name: message.replySenderId == chat.service.userId
                            ? 'You'
                            : widget.partnerName,
                        onTap: () => jumpToReply(message),
                      ),
                    message.deleted
                        ? Text(
                            'Message unsent',
                            style: TextStyle(
                              color: mine ? Colors.white70 : palette.muted,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : message.kind == 'text'
                        ? Text(
                            message.body,
                            style: TextStyle(
                              color: mine ? Colors.white : palette.ink,
                              fontSize: 16,
                              height: 1.35,
                            ),
                          )
                        : Theme(
                            data: Theme.of(context).copyWith(
                              iconTheme: IconThemeData(color: palette.ink),
                              iconButtonTheme: IconButtonThemeData(
                                style: IconButton.styleFrom(
                                  foregroundColor: palette.ink,
                                ),
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.ink,
                                ),
                              ),
                            ),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(color: palette.ink),
                              child: ChatMedia(
                                key: ValueKey(message.id),
                                message: message,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            if (currentReactions.isNotEmpty && !message.deleted)
              Transform.translate(
                offset: const Offset(0, -5),
                child: InkWell(
                  onTap: () => reactionDetails(message),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.received,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: palette.sent.withValues(alpha: .2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentReactions
                              .map((r) => r.emoji)
                              .toSet()
                              .join(' '),
                          style: const TextStyle(fontFamily: '', fontSize: 16),
                        ),
                        if (currentReactions.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Text(
                              '${currentReactions.length}',
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}${mine ? (seen != null && !seen.isBefore(message.createdAt) ? ' · Seen' : ' · Sent') : ''}',
              style: TextStyle(color: palette.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.forName(chat.theme);
    if (chat.accessLost) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your chat')),
        body: const Center(
          child: Text('Reconnect with your person to open this conversation.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: const AssetImage(
                'assets/jigu_lily_foreground.png',
              ),
              backgroundColor: palette.received,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    status,
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: startingCall || recording
                ? null
                : () => startCall('audio'),
            tooltip: 'Audio call',
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            onPressed: startingCall || recording
                ? null
                : () => startCall('video'),
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(
            onPressed: themes,
            tooltip: 'Chat theme',
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: ChatWallpaper(
        name: chat.theme,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (chat.error != null)
                MaterialBanner(
                  content: Text(chat.error!),
                  actions: [
                    TextButton(
                      onPressed: chat.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Expanded(
                child: chat.loading
                    ? const Center(child: CircularProgressIndicator())
                    : chat.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/jigu_lily_foreground.png',
                              width: 64,
                              height: 64,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Just you, me & a little hello.',
                              style: TextStyle(
                                fontSize: 21,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your conversation starts here.',
                              style: TextStyle(color: palette.muted),
                            ),
                          ],
                        ),
                      )
                    : ScrollablePositionedList.builder(
                        itemScrollController: itemScroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                        itemCount: chat.messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == chat.messages.length) {
                            return chat.hasMore
                                ? TextButton(
                                    onPressed: chat.loadingMore
                                        ? null
                                        : chat.more,
                                    child: Text(
                                      chat.loadingMore
                                          ? 'Loading…'
                                          : 'Earlier messages',
                                    ),
                                  )
                                : const SizedBox(height: 12);
                          }
                          final m = chat.messages[index];
                          final day = m.createdAt.toLocal();
                          final older = index + 1 < chat.messages.length
                              ? chat.messages[index + 1].createdAt.toLocal()
                              : null;
                          final showDay =
                              older == null ||
                              older.year != day.year ||
                              older.month != day.month ||
                              older.day != day.day;
                          return Column(
                            children: [
                              if (showDay)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    '${day.day}/${day.month}/${day.year}',
                                    style: TextStyle(
                                      color: palette.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              bubble(m, palette),
                            ],
                          );
                        },
                      ),
              ),
              if (sending || locatingReply)
                const LinearProgressIndicator(minHeight: 2),
              if (replyingTo != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                  decoration: BoxDecoration(
                    color: palette.received,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: palette.sent.withValues(alpha: .35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply_rounded, color: palette.sent, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyingTo!.senderId == chat.service.userId
                                  ? 'Replying to you'
                                  : 'Replying to ${widget.partnerName}',
                              style: TextStyle(
                                color: palette.sent,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              replyingTo!.kind == 'text'
                                  ? replyingTo!.body
                                  : replyingTo!.kind,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => replyingTo = null),
                        tooltip: 'Cancel reply',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              if (status == 'Typing…')
                TypingBubble(palette: palette, name: widget.partnerName),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.received,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: palette.muted.withValues(alpha: .15),
                  ),
                ),
                child: recording
                    ? Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              setState(() => recording = false);
                              await voice.cancel();
                            },
                            tooltip: 'Cancel recording',
                            icon: const Icon(Icons.delete_outline),
                          ),
                          Expanded(
                            child: Text(
                              'Recording · ${DateTime.now().difference(recordingStarted!).inSeconds}s',
                              style: TextStyle(color: palette.ink),
                            ),
                          ),
                          IconButton(
                            onPressed: finishVoice,
                            tooltip: 'Review voice message',
                            icon: Icon(Icons.stop_circle, color: palette.sent),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: sending ? null : attachments,
                            tooltip: 'Attach photo, video or GIF',
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: palette.muted,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: text,
                              focusNode: messageFocus,
                              onTap: () {
                                if (showEmojiPicker) {
                                  setState(() => showEmojiPicker = false);
                                }
                              },
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 4000,
                              style: TextStyle(color: palette.ink),
                              decoration: InputDecoration(
                                filled: false,
                                hintText: 'A message for your person…',
                                hintStyle: TextStyle(
                                  color: palette.muted,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (_) => chat.typing(),
                            ),
                          ),
                          IconButton(
                            onPressed: emojis,
                            tooltip: showEmojiPicker
                                ? 'Close emoji picker'
                                : 'Open emoji picker',
                            icon: Icon(
                              Icons.sentiment_satisfied_alt,
                              color: palette.muted,
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: text,
                            builder: (context, value, _) {
                              final empty = value.text.trim().isEmpty;
                              return IconButton.filled(
                                onPressed: sending || startingRecording
                                    ? null
                                    : empty
                                    ? startVoice
                                    : sendText,
                                tooltip: empty
                                    ? 'Record a voice message'
                                    : 'Send message',
                                style: IconButton.styleFrom(
                                  backgroundColor: palette.sent,
                                ),
                                icon: Icon(
                                  empty
                                      ? Icons.mic_none
                                      : Icons.arrow_upward_rounded,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
              if (showEmojiPicker)
                SizedBox(
                  height: 290,
                  width: double.infinity,
                  child: EmojiPicker(
                    textEditingController: text,
                    onEmojiSelected: (_, _) => chat.typing(),
                    config: Config(
                      height: 290,
                      checkPlatformCompatibility: false,
                      emojiViewConfig: EmojiViewConfig(
                        backgroundColor: palette.received,
                        columns: 8,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        initCategory: Category.SMILEYS,
                        recentTabBehavior: RecentTabBehavior.NONE,
                        backgroundColor: palette.received,
                        indicatorColor: palette.sent,
                        iconColorSelected: palette.sent,
                      ),
                      bottomActionBarConfig: BottomActionBarConfig(
                        backgroundColor: palette.received,
                        buttonColor: palette.sent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
