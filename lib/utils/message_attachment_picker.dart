import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'trackit_responsive.dart';

/// Maximum attachment size for officer channel messages (25 MB).
const maxMessageAttachmentBytes = 25 * 1024 * 1024;

enum MessageAttachmentKind { image, video, file }

class MessageAttachmentDraft {
  const MessageAttachmentDraft({
    required this.kind,
    required this.dataUrl,
    this.fileName,
  });

  final MessageAttachmentKind kind;
  final String dataUrl;
  final String? fileName;
}

class MessageAttachmentException implements Exception {
  MessageAttachmentException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<MessageAttachmentDraft?> pickMessageImage(ImageSource source) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    imageQuality: 90,
  );
  if (file == null) return null;
  return _draftFromXFile(file, MessageAttachmentKind.image);
}

Future<MessageAttachmentDraft?> pickMessageVideo(ImageSource source) async {
  final picker = ImagePicker();
  final file = await picker.pickVideo(source: source);
  if (file == null) return null;
  return _draftFromXFile(file, MessageAttachmentKind.video);
}

Future<MessageAttachmentDraft?> pickMessageFile() async {
  final result = await FilePicker.pickFiles(withData: true);
  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.single;
  final bytes = picked.bytes;
  if (bytes == null) {
    throw MessageAttachmentException('Could not read the selected file.');
  }
  _ensureWithinSize(bytes.length);

  final name = picked.name.trim().isNotEmpty ? picked.name.trim() : 'attachment';
  final mime = _mimeFromName(name, picked.extension);
  return MessageAttachmentDraft(
    kind: MessageAttachmentKind.file,
    dataUrl: _toDataUrl(bytes, mime),
    fileName: name,
  );
}

Future<MessageAttachmentDraft> _draftFromXFile(
  XFile file,
  MessageAttachmentKind kind,
) async {
  final bytes = await file.readAsBytes();
  _ensureWithinSize(bytes.length);

  final name = file.name.trim().isNotEmpty ? file.name.trim() : file.path;
  final mime = kind == MessageAttachmentKind.video
      ? _mimeFromName(name, null, fallback: 'video/mp4')
      : _mimeFromName(name, null, fallback: 'image/jpeg');

  return MessageAttachmentDraft(
    kind: kind,
    dataUrl: _toDataUrl(bytes, mime),
    fileName: name.split(Platform.pathSeparator).last,
  );
}

void _ensureWithinSize(int bytes) {
  if (bytes > maxMessageAttachmentBytes) {
    throw MessageAttachmentException('File must be 25 MB or smaller.');
  }
}

String _toDataUrl(List<int> bytes, String mime) {
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

String _mimeFromName(String name, String? extension, {String fallback = 'application/octet-stream'}) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
  if (lower.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (lower.endsWith('.txt')) return 'text/plain';
  if (lower.endsWith('.zip')) return 'application/zip';

  final ext = (extension ?? '').toLowerCase();
  if (ext == 'png') return 'image/png';
  if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
  if (ext == 'mp4') return 'video/mp4';
  if (ext == 'pdf') return 'application/pdf';

  return fallback;
}

Future<void> showMessageAttachmentSheet(
  BuildContext context, {
  required Future<void> Function(MessageAttachmentDraft draft) onPicked,
  required void Function(String message) onError,
}) async {
  // Shell bottom nav is drawn above route overlays — lift sheet content clear of it.
  final navClearance = context.layout.bottomNavHeight;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: navClearance),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () => _pickAndClose(
                    sheetContext,
                    () => pickMessageImage(ImageSource.camera),
                    onPicked,
                    onError,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose photo'),
                  onTap: () => _pickAndClose(
                    sheetContext,
                    () => pickMessageImage(ImageSource.gallery),
                    onPicked,
                    onError,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Choose video'),
                  onTap: () => _pickAndClose(
                    sheetContext,
                    () => pickMessageVideo(ImageSource.gallery),
                    onPicked,
                    onError,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Choose file'),
                  subtitle: const Text('Images, videos, PDFs, documents — max 25 MB'),
                  onTap: () => _pickAndClose(
                    sheetContext,
                    pickMessageFile,
                    onPicked,
                    onError,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _pickAndClose(
  BuildContext sheetContext,
  Future<MessageAttachmentDraft?> Function() pick,
  Future<void> Function(MessageAttachmentDraft draft) onPicked,
  void Function(String message) onError,
) async {
  Navigator.of(sheetContext).pop();
  try {
    final draft = await pick();
    if (draft != null) await onPicked(draft);
  } on MessageAttachmentException catch (error) {
    onError(error.message);
  } catch (_) {
    onError('Could not attach that file. Try again.');
  }
}

/// Decode a `data:` URL into raw bytes.
Uint8List? decodeDataUrlBytes(String? dataUrl) {
  if (dataUrl == null || !dataUrl.startsWith('data:')) return null;
  final comma = dataUrl.indexOf(',');
  if (comma == -1) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

bool isImageDataUrl(String? url) => url?.startsWith('data:image/') ?? false;

bool isVideoDataUrl(String? url) => url?.startsWith('data:video/') ?? false;
