import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../utils/philippines_time.dart';
import 'firestore_sync_service.dart';
import 'storage_service.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.senderOfficerId,
    this.senderRole = 'officer',
    this.mentionedIds = const [],
    this.imageUrl,
    this.videoUrl,
    this.fileUrl,
    this.fileName,
    this.sharedEvent,
    this.qrCodeDataUrl,
    this.qrEventId,
    this.qrEventTitle,
  });

  final int id;
  final String senderName;
  final String text;
  final int timestamp;
  final int? senderOfficerId;
  final String senderRole;
  final List<int> mentionedIds;
  final String? imageUrl;
  final String? videoUrl;
  final String? fileUrl;
  final String? fileName;
  final Map<String, dynamic>? sharedEvent;
  final String? qrCodeDataUrl;
  final int? qrEventId;
  final String? qrEventTitle;

  bool get isAnnouncement => senderRole == 'admin';

  bool get hasAttachment =>
      (imageUrl?.isNotEmpty ?? false) ||
      (videoUrl?.isNotEmpty ?? false) ||
      (fileUrl?.isNotEmpty ?? false) ||
      sharedEvent != null ||
      (qrCodeDataUrl?.isNotEmpty ?? false);

  bool isOwnedByOfficer(int officerId) =>
      senderOfficerId != null && senderOfficerId == officerId;

  bool isMentionedForOfficer(int officerId, {String? officerName}) {
    if (mentionedIds.contains(officerId)) return true;
    if (officerName == null || officerName.trim().isEmpty) return false;
    return text.contains('@${officerName.trim()}');
  }

  bool isDashboardItemForOfficer(int officerId, {String? officerName}) {
    return isAnnouncement || isMentionedForOfficer(officerId, officerName: officerName);
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final senderRoleRaw = '${json['senderRole'] ?? ''}';
    final senderId = _readInt(json['senderId']);
    final senderOfficerId = _readInt(json['senderOfficerId']) ??
        (senderRoleRaw == 'officer' ? senderId : null);
    final resolvedRole = senderRoleRaw.isNotEmpty
        ? senderRoleRaw
        : (senderOfficerId == null && (senderId == null || senderId == 0) ? 'admin' : 'officer');

    return ChatMessage(
      id: _readInt(json['id']) ?? 0,
      senderName: '${json['senderName'] ?? 'Admin'}',
      text: '${json['text'] ?? ''}',
      timestamp: PhilippinesTime.parseMillis(json['timestamp']) ?? 0,
      senderOfficerId: senderOfficerId,
      senderRole: resolvedRole,
      mentionedIds: (json['mentionedIds'] as List?)
              ?.map((value) => _readInt(value))
              .whereType<int>()
              .toList() ??
          const [],
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
      sharedEvent: json['sharedEvent'] is Map
          ? Map<String, dynamic>.from(json['sharedEvent'] as Map)
          : null,
      qrCodeDataUrl: json['qrCodeDataUrl'] as String?,
      qrEventId: _readInt(json['qrEventId']),
      qrEventTitle: json['qrEventTitle'] as String?,
    );
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderOfficerId ?? (senderRole == 'admin' ? 0 : null),
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp,
        if (senderOfficerId != null) 'senderOfficerId': senderOfficerId,
        'senderRole': senderRole,
        'mentionedIds': mentionedIds,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        if (sharedEvent != null) 'sharedEvent': sharedEvent,
        if (qrCodeDataUrl != null) 'qrCodeDataUrl': qrCodeDataUrl,
        if (qrEventId != null) 'qrEventId': qrEventId,
        if (qrEventTitle != null) 'qrEventTitle': qrEventTitle,
      };

  /// Oldest first — strict send-time order; never grouped by sender.
  static int compare(ChatMessage a, ChatMessage b) {
    if (a.timestamp != b.timestamp) return a.timestamp.compareTo(b.timestamp);
    return a.id.compareTo(b.id);
  }

  static List<ChatMessage> sorted(List<ChatMessage> messages) {
    return List<ChatMessage>.from(messages)..sort(compare);
  }
}

/// Mirrors officer channel message count from the Ionic web app.
class ChatService {
  ChatService(this._storage);

  final StorageService _storage;
  List<ChatMessage> _messages = [];
  int _nextId = 1;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _seededFirestore = false;
  void Function()? _onChanged;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void _setMessages(List<ChatMessage> messages) {
    _messages = ChatMessage.sorted(messages);
  }

  int _allocateMessageId(int timestamp) {
    var candidate = timestamp;
    final used = _messages.map((m) => m.id).toSet();
    while (used.contains(candidate)) {
      candidate += 1;
    }
    _nextId = [_nextId, candidate + 1, PhilippinesTime.nowMs() + 1]
        .reduce((a, b) => a > b ? a : b);
    return candidate;
  }

  void _syncNextIdFromMessages() {
    if (_messages.isEmpty) {
      _nextId = PhilippinesTime.nowMs() + 1;
      return;
    }
    final maxExisting = _messages.map((m) => m.id).reduce((a, b) => a > b ? a : b);
    _nextId = [maxExisting, _nextId, PhilippinesTime.nowMs()]
        .reduce((a, b) => a > b ? a : b) + 1;
  }

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> initialize() async {
    final raw = _storage.readJsonObject(StorageKeys.chatMessages);
    if (raw != null) {
      final rows = raw['messages'];
      if (rows is List && rows.isNotEmpty) {
        _setMessages(rows.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList());
        final storedNextId = raw['nextId'];
        if (storedNextId is int && storedNextId > 0) {
          _nextId = storedNextId;
        } else {
          _nextId = _messages.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1;
        }
      }
    }

    if (_messages.isEmpty) {
      _setMessages([
        ChatMessage(
          id: 0,
          senderName: 'Admin',
          text:
              'Welcome to the officer channel. Mention officers with @, and share events or QR codes from the attach menu.',
          timestamp: PhilippinesTime.nowMs() - 60000,
          senderRole: 'admin',
        ),
      ]);
      _nextId = 1;
      await _persist();
    }

    await PhilippinesTime.sync();
    await _startListener();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _persist() async {
    await _storage.writeJsonObject(StorageKeys.chatMessages, {
      'messages': _messages.map((m) => m.toJson()).toList(),
      'nextId': _nextId,
    });
    _onChanged?.call();
  }

  Future<void> _startListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    final query = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.messages)
        .orderBy('timestamp', descending: true)
        .limit(200);

    await _sub?.cancel();
    _sub = query.snapshots().listen((snap) async {
      if (snap.docs.isEmpty) {
        _seededFirestore = true;
        return;
      }

      _seededFirestore = true;
      _setMessages(
        snap.docs
            .map((doc) => ChatMessage.fromJson({...doc.data(), 'id': _parseMessageId(doc)}))
            .toList(),
      );
      _syncNextIdFromMessages();
      await _storage.writeJsonObject(StorageKeys.chatMessages, {
        'messages': _messages.map((m) => m.toJson()).toList(),
        'nextId': _nextId,
      });
      _onChanged?.call();
    });
  }

  int _parseMessageId(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return ChatMessage._readInt(doc.data()['id']) ??
        int.tryParse(doc.id) ??
        0;
  }

  Future<void> _seedFirestore() async {
    final db = FirestoreSyncService.instance.db;
    for (final message in _messages) {
      await db.collection(FirestoreCollections.messages).doc('${message.id}').set(message.toJson());
    }
  }

  Future<void> _writeMessageToFirestore(ChatMessage message) async {
    if (!FirestoreSyncService.instance.isReady) return;
    await FirestoreSyncService.instance.db
        .collection(FirestoreCollections.messages)
        .doc('${message.id}')
        .set(message.toJson());
  }

  Future<void> _deleteMessageFromFirestore(int messageId) async {
    if (!FirestoreSyncService.instance.isReady) return;
    await FirestoreSyncService.instance.db
        .collection(FirestoreCollections.messages)
        .doc('$messageId')
        .delete();
  }

  Future<void> sendMessage({
    required String senderName,
    required String text,
    int? senderOfficerId,
    String? imageUrl,
    String? videoUrl,
    String? fileUrl,
    String? fileName,
  }) async {
    final trimmed = text.trim();
    final hasImage = imageUrl?.isNotEmpty ?? false;
    final hasVideo = videoUrl?.isNotEmpty ?? false;
    final hasFile = fileUrl?.isNotEmpty ?? false;
    if (trimmed.isEmpty && !hasImage && !hasVideo && !hasFile) return;

    var messageText = trimmed;
    if (messageText.isEmpty) {
      if (hasImage) {
        messageText = '(image)';
      } else if (hasVideo) {
        messageText = '(video)';
      } else if (hasFile) {
        messageText = fileName?.trim().isNotEmpty == true ? fileName!.trim() : '(file)';
      }
    }

    await PhilippinesTime.sync();
    final timestamp = PhilippinesTime.nowMs();
    final message = ChatMessage(
      id: _allocateMessageId(timestamp),
      senderName: senderName,
      text: messageText,
      timestamp: timestamp,
      senderOfficerId: senderOfficerId,
      senderRole: senderOfficerId == null ? 'admin' : 'officer',
      imageUrl: hasImage ? imageUrl : null,
      videoUrl: hasVideo ? videoUrl : null,
      fileUrl: hasFile ? fileUrl : null,
      fileName: hasFile ? fileName : null,
    );

    _setMessages([..._messages, message]);
    await _persist();
    await _writeMessageToFirestore(message);
  }

  /// Deletes a message only when it belongs to the requesting officer.
  Future<bool> deleteOwnMessage({
    required int messageId,
    required int officerId,
  }) async {
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) return false;

    final message = _messages[index];
    if (!message.isOwnedByOfficer(officerId)) return false;

    _setMessages(_messages.where((message) => message.id != messageId).toList());
    await _persist();
    await _deleteMessageFromFirestore(messageId);
    return true;
  }

  /// Dashboard feed: admin announcements and messages that mention this officer.
  List<ChatMessage> dashboardMessagesForOfficer(
    int officerId, {
    String? officerName,
    int limit = 4,
  }) {
    final items = _messages
        .where((message) => message.isDashboardItemForOfficer(
              officerId,
              officerName: officerName,
            ))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (items.length <= limit) return List.unmodifiable(items);
    return List.unmodifiable(items.take(limit).toList());
  }
}
