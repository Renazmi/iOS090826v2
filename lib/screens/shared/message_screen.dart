import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../services/app_state.dart';
import '../../services/chat_service.dart';
import '../../services/typing_service.dart';
import '../../utils/message_attachment_picker.dart';
import '../../utils/philippines_time.dart';
import '../../utils/trackit_confirm_dialog.dart';
import '../../utils/trackit_responsive.dart';

/// Officer channel chat — bubble layout with composer pinned at the bottom.
class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  MessageAttachmentDraft? _pendingAttachment;
  TypingService? _typingService;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(jump: true);
      unawaited(context.read<AppState>().typing.ensureListening());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _typingService = context.read<AppState>().typing;
  }

  @override
  void dispose() {
    unawaited(_typingService?.clearMyTyping());
    _controller.removeListener(_onComposerChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    if (!mounted) return;
    setState(() {});

    final app = context.read<AppState>();
    if (_controller.text.trim().isEmpty) {
      unawaited(app.typing.clearMyTyping());
      return;
    }

    final officer = app.auth.currentOfficer;
    if (officer != null) {
      app.typing.notifyOfficerTyping(
        officerId: officer.id,
        displayName: app.roles.displayName,
      );
    }
  }

  bool get _canSend =>
      _controller.text.trim().isNotEmpty || _pendingAttachment != null;

  Future<void> _send(AppState app) async {
    if (!_canSend) return;
    if (!app.canAccessMessages()) {
      _showSnack('You must be added to the group chat before sending messages.');
      return;
    }

    final officer = app.auth.currentOfficer;
    final attachment = _pendingAttachment;

    await app.chat.sendMessage(
      senderName: app.roles.displayName,
      text: _controller.text,
      senderOfficerId: officer?.id,
      imageUrl: attachment?.kind == MessageAttachmentKind.image ? attachment!.dataUrl : null,
      videoUrl: attachment?.kind == MessageAttachmentKind.video ? attachment!.dataUrl : null,
      fileUrl: attachment?.kind == MessageAttachmentKind.file ? attachment!.dataUrl : null,
      fileName: attachment?.fileName,
    );

    await app.typing.clearMyTyping();

    _controller.clear();
    setState(() => _pendingAttachment = null);
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _deleteMessage(AppState app, ChatMessage message) async {
    final officerId = app.auth.currentOfficer?.id;
    if (officerId == null || !message.isOwnedByOfficer(officerId)) return;

    final confirmed = await confirmTrackitAction(
      context,
      title: 'Delete message?',
      message: 'This removes your message from the officer channel for everyone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final removed = await app.chat.deleteOwnMessage(
      messageId: message.id,
      officerId: officerId,
    );
    if (!mounted) return;
    if (!removed) {
      _showSnack('You can only delete messages you sent.');
      return;
    }
    setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickAttachment() async {
    await showMessageAttachmentSheet(
      context,
      onPicked: (draft) async {
        setState(() => _pendingAttachment = draft);
      },
      onError: _showSnack,
    );
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final layout = context.layout;
    final colors = context.trackit;

    if (!app.canAccessMessages()) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.pageHorizontalPadding),
        child: Center(
          child: Text(
            'You are not in the group chat yet. Ask an admin to add you from the Messages member list.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final messages = app.chat.messages;
    final currentOfficerId = app.auth.currentOfficer?.id;
    final activeTypers = app.typing.activeTypers;

    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom(jump: messages.length <= 1);
    } else if (activeTypers.isNotEmpty) {
      _scrollToBottom();
    }

    final showEmptyState = messages.isEmpty && activeTypers.isEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: layout.pageHorizontalPadding,
        right: layout.pageHorizontalPadding,
        bottom: layout.scrollBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChatHeader(colors: colors),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border.withValues(alpha: 0.45)),
              ),
              child: showEmptyState
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 40, color: colors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Say hello to the officer channel.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                      itemCount: messages.length + activeTypers.length,
                      itemBuilder: (context, index) {
                        if (index < messages.length) {
                          final message = messages[index];
                          final isMe = message.isOwnedByOfficer(currentOfficerId ?? -1);
                          return KeyedSubtree(
                            key: ValueKey('${message.timestamp}:${message.id}'),
                            child: _ChatBubble(
                              message: message,
                              isMe: isMe,
                              colors: colors,
                              onDelete: isMe ? () => _deleteMessage(app, message) : null,
                            ),
                          );
                        }

                        final typer = activeTypers[index - messages.length];
                        return KeyedSubtree(
                          key: ValueKey('typing:${typer.key}'),
                          child: _TypingBubbleRow(typer: typer, colors: colors),
                        );
                      },
                    ),
            ),
          ),
          if (_pendingAttachment != null) ...[
            const SizedBox(height: 8),
            _AttachmentPreview(
              attachment: _pendingAttachment!,
              colors: colors,
              onRemove: () => setState(() => _pendingAttachment = null),
            ),
          ],
          if (activeTypers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _TypingStatusBar(typers: activeTypers, colors: colors),
          ],
          const SizedBox(height: 10),
          _MessageComposer(
            controller: _controller,
            colors: colors,
            canSend: _canSend,
            onChanged: () => setState(() {}),
            onAttach: _pickAttachment,
            onSend: () => _send(app),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.colors});

  final TrackitColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: AppTheme.headerGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Officer channel',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Campus announcements & officer chat',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.colors,
    this.onDelete,
  });

  final ChatMessage message;
  final bool isMe;
  final TrackitColors colors;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final time = PhilippinesTime.formatChatTime(message.timestamp);

    final bubbleColor = isMe
        ? AppTheme.red
        : (colors.isDark ? const Color(0xFF2A2A2A) : Colors.white);
    final textColor = isMe ? Colors.white : colors.textPrimary;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    final isPlaceholderText = message.text == '(image)' ||
        message.text == '(video)' ||
        message.text.startsWith('Shared event:') ||
        message.text.startsWith('Shared QR:') ||
        (message.hasAttachment && message.text == message.fileName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.red.withValues(alpha: 0.12),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppTheme.red,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onDelete,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: isMe
                          ? [
                              BoxShadow(
                                color: AppTheme.red.withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.imageUrl != null)
                          _MessageImageAttachment(
                            dataUrl: message.imageUrl!,
                            isMe: isMe,
                          ),
                        if (message.videoUrl != null)
                          _MessageVideoAttachment(
                            dataUrl: message.videoUrl!,
                            isMe: isMe,
                          ),
                        if (message.fileUrl != null)
                          _MessageFileAttachment(
                            fileName: message.fileName ?? 'Attachment',
                            isMe: isMe,
                          ),
                        if (message.sharedEvent != null)
                          _MessageSharedEventAttachment(
                            event: message.sharedEvent!,
                            isMe: isMe,
                          ),
                        if (message.qrCodeDataUrl != null)
                          _MessageQrAttachment(
                            dataUrl: message.qrCodeDataUrl!,
                            title: message.qrEventTitle,
                            isMe: isMe,
                          ),
                        if (message.text.isNotEmpty && !isPlaceholderText)
                          Text(
                            message.text,
                            style: TextStyle(
                              color: textColor,
                              height: 1.35,
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isMe && onDelete != null) ...[
                              InkWell(
                                onTap: onDelete,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.78)
                                    : colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageImageAttachment extends StatelessWidget {
  const _MessageImageAttachment({required this.dataUrl, required this.isMe});

  final String dataUrl;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeDataUrlBytes(dataUrl);
    if (bytes == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () => _openImagePreview(context, bytes),
          child: Image.memory(
            bytes,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _attachmentFallback(isMe, Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }

  void _openImagePreview(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageVideoAttachment extends StatelessWidget {
  const _MessageVideoAttachment({required this.dataUrl, required this.isMe});

  final String dataUrl;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isMe ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openVideoPlayer(context, dataUrl),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 220,
            height: 124,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 48,
                  color: isMe ? Colors.white : AppTheme.red,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to play video',
                  style: TextStyle(
                    color: isMe ? Colors.white : AppTheme.redDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openVideoPlayer(BuildContext context, String dataUrl) async {
    final bytes = decodeDataUrlBytes(dataUrl);
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/trackit_msg_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    await file.writeAsBytes(bytes);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _VideoPlayerDialog(file: file),
    );
  }
}

class _MessageFileAttachment extends StatelessWidget {
  const _MessageFileAttachment({required this.fileName, required this.isMe});

  final String fileName;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: isMe ? Colors.white : AppTheme.red,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMe ? Colors.white : AppTheme.redDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageSharedEventAttachment extends StatelessWidget {
  const _MessageSharedEventAttachment({required this.event, required this.isMe});

  final Map<String, dynamic> event;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final title = '${event['title'] ?? 'Event'}';
    final when = '${event['whenDate'] ?? ''} ${event['whenTime'] ?? ''}'.trim();
    final where = '${event['where'] ?? ''}';
    final status = '${event['status'] ?? ''}';
    final labelColor = isMe ? Colors.white : AppTheme.redDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared event',
              style: TextStyle(
                color: labelColor.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: labelColor, fontWeight: FontWeight.w700, fontSize: 13)),
            if (when.isNotEmpty)
              Text(when, style: TextStyle(color: labelColor, fontSize: 12)),
            if (where.isNotEmpty)
              Text(where, style: TextStyle(color: labelColor, fontSize: 12)),
            if (status.isNotEmpty)
              Text(status, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MessageQrAttachment extends StatelessWidget {
  const _MessageQrAttachment({
    required this.dataUrl,
    required this.isMe,
    this.title,
  });

  final String dataUrl;
  final String? title;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title?.trim().isNotEmpty == true ? title! : 'Event QR code',
            style: TextStyle(
              color: isMe ? Colors.white : AppTheme.redDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: dataUrl.startsWith('data:')
                ? Image.memory(
                    Uri.parse(dataUrl).data?.contentAsBytes() ?? Uint8List(0),
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : Image.network(
                    dataUrl,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.file});

  final File file;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.black,
      child: AspectRatio(
        aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_ready)
              VideoPlayer(_controller)
            else
              const CircularProgressIndicator(color: Colors.white),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (_ready)
              Positioned(
                bottom: 8,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _attachmentFallback(bool isMe, IconData icon) {
  return Container(
    width: 220,
    height: 120,
    alignment: Alignment.center,
    color: isMe ? Colors.white24 : Colors.black12,
    child: Icon(icon, color: isMe ? Colors.white70 : AppTheme.red),
  );
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.colors,
    required this.onRemove,
  });

  final MessageAttachmentDraft attachment;
  final TrackitColors colors;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            _previewThumb(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _previewLabel(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Max 25 MB',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Remove attachment',
            ),
          ],
        ),
      ),
    );
  }

  String _previewLabel() {
    return switch (attachment.kind) {
      MessageAttachmentKind.image => 'Photo attached',
      MessageAttachmentKind.video => 'Video attached',
      MessageAttachmentKind.file => attachment.fileName ?? 'File attached',
    };
  }

  Widget _previewThumb() {
    if (attachment.kind == MessageAttachmentKind.image) {
      final bytes = decodeDataUrlBytes(attachment.dataUrl);
      if (bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 52, height: 52, fit: BoxFit.cover),
        );
      }
    }

    final icon = switch (attachment.kind) {
      MessageAttachmentKind.image => Icons.image_outlined,
      MessageAttachmentKind.video => Icons.videocam_outlined,
      MessageAttachmentKind.file => Icons.insert_drive_file_outlined,
    };

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppTheme.red),
    );
  }
}

class _TypingStatusBar extends StatelessWidget {
  const _TypingStatusBar({
    required this.typers,
    required this.colors,
  });

  final List<TypingParticipant> typers;
  final TrackitColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.red.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                TypingService.formatTypingLabel(typers),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubbleRow extends StatefulWidget {
  const _TypingBubbleRow({
    required this.typer,
    required this.colors,
  });

  final TypingParticipant typer;
  final TrackitColors colors;

  @override
  State<_TypingBubbleRow> createState() => _TypingBubbleRowState();
}

class _TypingBubbleRowState extends State<_TypingBubbleRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typer = widget.typer;
    final colors = widget.colors;
    final isAdmin = typer.isAdmin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isAdmin ? AppTheme.red : AppTheme.red.withValues(alpha: 0.12),
            child: Text(
              typer.initial,
              style: TextStyle(
                color: isAdmin ? Colors.white : AppTheme.red,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        typer.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.textMuted,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.red,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? AppTheme.red.withValues(alpha: 0.08)
                        : (colors.isDark ? const Color(0xFF2A2A2A) : Colors.white),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: isAdmin
                          ? AppTheme.red.withValues(alpha: 0.22)
                          : colors.border.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final phase = (_controller.value + index * 0.2) % 1.0;
                          final offset = phase < 0.5
                              ? -4 * (phase / 0.5)
                              : -4 * ((1 - phase) / 0.5);
                          return Transform.translate(
                            offset: Offset(0, offset),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 7,
                          height: 7,
                          margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
                          decoration: BoxDecoration(
                            color: isAdmin ? AppTheme.red : colors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.colors,
    required this.canSend,
    required this.onChanged,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final TrackitColors colors;
  final bool canSend;
  final VoidCallback onChanged;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onAttach,
              tooltip: 'Attach photo, video, or file',
              icon: Icon(Icons.attach_file_rounded, color: colors.textMuted),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onChanged: (_) => onChanged(),
                onSubmitted: canSend ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(color: colors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                ),
              ),
            ),
            Material(
              color: canSend ? AppTheme.red : AppTheme.red.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: canSend ? onSend : null,
                borderRadius: BorderRadius.circular(20),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
