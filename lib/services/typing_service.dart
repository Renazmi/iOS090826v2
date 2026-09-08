import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import 'firestore_sync_service.dart';

class TypingParticipant {
  const TypingParticipant({
    required this.key,
    required this.displayName,
    required this.role,
    required this.updatedAt,
  });

  final String key;
  final String displayName;
  final String role;
  final int updatedAt;

  bool get isAdmin => role == 'admin';

  String get initial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}

/// Real-time typing indicators for the ELITE officer channel.
class TypingService {
  static const staleMs = 5000;
  static const debounceMs = 250;
  static const heartbeatMs = 2000;

  final Map<String, TypingParticipant> _typers = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _debounce;
  Timer? _heartbeat;
  Timer? _staleTimer;
  String? _myKey;
  String _activeDisplayName = '';
  String _activeRole = 'officer';
  void Function()? _onChanged;

  List<TypingParticipant> get activeTypers {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _typers.values
        .where((t) => now - t.updatedAt < staleMs)
        .where((t) => t.key != _myKey)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> initialize() async {
    await _startListener();
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onChanged?.call());
  }

  /// Re-attach the Firestore listener when opening Messages (e.g. after login).
  Future<void> ensureListening() async {
    if (_sub != null) return;
    await _startListener();
  }

  Future<void> dispose() async {
    await clearMyTyping();
    await _sub?.cancel();
    _sub = null;
    _staleTimer?.cancel();
    _staleTimer = null;
  }

  void notifyOfficerTyping({required int officerId, required String displayName}) {
    _scheduleTyping('officer:$officerId', displayName, 'officer');
  }

  Future<void> clearMyTyping() async {
    _stopHeartbeat();
    _debounce?.cancel();
    _debounce = null;
    final key = _myKey;
    _myKey = null;
    _activeDisplayName = '';
    if (key == null) return;
    if (!FirestoreSyncService.instance.isReady) return;

    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.chatTyping)
        .doc(eliteChatMembersDocId);

    try {
      await ref.update({'typers.$key': FieldValue.delete()});
    } catch (_) {
      // Document may not exist yet.
    }
  }

  void _scheduleTyping(String key, String displayName, String role) {
    _myKey = key;
    _activeDisplayName = displayName;
    _activeRole = role;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: debounceMs), () {
      unawaited(_writeTyping(key, displayName, role));
      _startHeartbeat();
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(const Duration(milliseconds: heartbeatMs), (_) {
      final key = _myKey;
      if (key == null) return;
      unawaited(_writeTyping(key, _activeDisplayName, _activeRole));
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _writeTyping(String key, String displayName, String role) async {
    if (!FirestoreSyncService.instance.isReady) return;

    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.chatTyping)
        .doc(eliteChatMembersDocId);

    await ref.set({
      'typers': {
        key: {
          'displayName': displayName,
          'role': role,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      },
    }, SetOptions(merge: true));
  }

  static int? _readTimestampMs(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  Future<void> _startListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.chatTyping)
        .doc(eliteChatMembersDocId);

    await _sub?.cancel();
    _sub = ref.snapshots().listen((snap) {
      _typers.clear();
      final data = snap.data();
      final raw = data?['typers'];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is! Map) return;
          _typers['$key'] = TypingParticipant(
            key: '$key',
            displayName: '${value['displayName'] ?? 'Someone'}',
            role: '${value['role'] ?? 'officer'}',
            updatedAt: _readTimestampMs(value['updatedAt']) ?? 0,
          );
        });
      }
      _onChanged?.call();
    });
  }

  static String formatTypingLabel(List<TypingParticipant> typers) {
    if (typers.isEmpty) return '';
    if (typers.length == 1) return '${typers.first.displayName} is typing';
    if (typers.length == 2) {
      return '${typers[0].displayName} and ${typers[1].displayName} are typing';
    }
    final names = typers.map((t) => t.displayName).toList();
    return '${names.sublist(0, names.length - 1).join(', ')}, and ${names.last} are typing';
  }
}
