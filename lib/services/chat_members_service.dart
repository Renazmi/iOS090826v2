import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/class_roster_officers.dart';
import 'firestore_sync_service.dart';
import 'storage_service.dart';

/// ELITE group chat membership — synced with Angular `ChatService`.
class ChatMembersService {
  ChatMembersService(this._storage);

  final StorageService _storage;
  List<int> _memberIds = [];
  List<int> _defaultEliteMemberIds = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  void Function()? _onChanged;

  List<int> get memberIds => List.unmodifiable(_memberIds);

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> initialize({List<int>? defaultEliteMemberIds}) async {
    _defaultEliteMemberIds = List<int>.from(defaultEliteMemberIds ?? const []);
    _loadLocal();
    if (_memberIds.isEmpty && _defaultEliteMemberIds.isNotEmpty) {
      _memberIds = List<int>.from(_defaultEliteMemberIds);
      await _persistLocal();
    }
    await _startListener();
  }

  /// Remember roster IDs for first-time seed only — never overwrite a live member list.
  Future<void> syncEliteMembersFromRoster(List<int> eliteOfficerIds) async {
    _defaultEliteMemberIds = List<int>.from(eliteOfficerIds);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  bool isMember(int officerId) => _memberIds.contains(officerId);

  /// Ensures president, VP, ELITE officers, and class roster messaging accounts.
  void ensureRequiredMembers() {
    const required = [1, 2];
    final merged = {
      ..._memberIds,
      ...required,
      ..._defaultEliteMemberIds,
      ...classRosterOfficerIds,
    }.toList()
      ..sort();
    if (merged.length == _memberIds.length && _listsEqual(merged, _memberIds)) return;
    _memberIds = merged;
    unawaited(_persistLocal());
    unawaited(_writeToFirestoreIfReady());
  }

  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _writeToFirestoreIfReady() async {
    if (!FirestoreSyncService.instance.isReady || _memberIds.isEmpty) return;
    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.chatMembers)
        .doc(eliteChatMembersDocId);
    await ref.set({
      'organizationId': eliteOrganizationId,
      'organizationName': 'ELITE',
      'memberIds': _memberIds,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  void _loadLocal() {
    final raw = _storage.readJsonObject(StorageKeys.chatMembers);
    if (raw == null) return;
    final ids = raw['memberIds'];
    if (ids is List) {
      _memberIds = ids.map((v) => v is int ? v : int.tryParse('$v')).whereType<int>().toList();
    }
  }

  Future<void> _persistLocal() async {
    await _storage.writeJsonObject(StorageKeys.chatMembers, {
      'organizationId': eliteOrganizationId,
      'organizationName': 'ELITE',
      'memberIds': _memberIds,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _startListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.chatMembers)
        .doc(eliteChatMembersDocId);

    await _sub?.cancel();
    _sub = ref.snapshots().listen((snap) async {
      if (!snap.exists) {
        if (_memberIds.isNotEmpty) {
          await ref.set({
            'organizationId': eliteOrganizationId,
            'organizationName': 'ELITE',
            'memberIds': _memberIds,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
        return;
      }

      final data = snap.data();
      if (data == null) return;
      final ids = data['memberIds'];
      if (ids is! List) return;

      _memberIds = ids.map((v) => v is int ? v : int.tryParse('$v')).whereType<int>().toList();
      await _persistLocal();
      _onChanged?.call();
    });
  }
}
