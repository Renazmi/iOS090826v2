import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../models/announcement_item.dart';
import 'firestore_sync_service.dart';
import 'storage_service.dart';

/// Real-time announcements from the Angular web app (`announcements` collection).
class AnnouncementsService {
  AnnouncementsService(this._storage);

  final StorageService _storage;
  List<AnnouncementItem> _announcements = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  void Function()? _onChanged;

  List<AnnouncementItem> get announcements => List.unmodifiable(_announcements);

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> initialize() async {
    _loadLocal();
    await _startListener();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  List<AnnouncementItem> recent({int limit = 8}) {
    final sorted = List<AnnouncementItem>.from(_announcements)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (sorted.length <= limit) return List.unmodifiable(sorted);
    return List.unmodifiable(sorted.take(limit).toList());
  }

  void _loadLocal() {
    final rows = _storage.readJsonList(StorageKeys.announcements);
    if (rows.isEmpty) return;
    _announcements = rows.map((e) => AnnouncementItem.fromJson(e)).toList();
  }

  Future<void> _persistLocal() async {
    await _storage.writeJsonList(
      StorageKeys.announcements,
      _announcements.map((a) => a.toJson()).toList(),
    );
  }

  Future<void> _startListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    final query = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.announcements)
        .orderBy('createdAt', descending: true)
        .limit(50);

    await _sub?.cancel();
    _sub = query.snapshots().listen((snap) {
      _announcements = snap.docs
          .map((doc) => AnnouncementItem.fromJson({...doc.data(), 'id': _parseId(doc)}))
          .toList();
      unawaited(_persistLocal());
      _onChanged?.call();
    });
  }

  int _parseId(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final dataId = doc.data()['id'];
    if (dataId is int) return dataId;
    return int.tryParse(doc.id) ?? 0;
  }
}
