import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/seed_data.dart';
import '../models/organization.dart';
import 'api_service.dart';
import 'firestore_sync_service.dart';
import 'storage_service.dart';

/// Mirrors `OrganizationsService` from the Ionic web app.
class OrganizationsService {
  OrganizationsService(this._storage, this._api);

  final StorageService _storage;
  final ApiService _api;

  List<Organization> _organizations = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  void Function()? _onChanged;

  List<Organization> get organizations => List.unmodifiable(_organizations);

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> initialize() async {
    final rows = _storage.readJsonList(StorageKeys.organizations);
    if (rows.isEmpty) {
      _organizations = List.from(defaultOrganizations);
      await _save();
    } else {
      _organizations = rows.map(Organization.fromJson).toList();
    }
    await _startFirestoreListener();
  }

  Future<void> dispose() async {
    await _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  Future<void> _save() async {
    await _api.saveCollection(
      StorageKeys.organizations,
      _organizations.map((o) => o.toJson()).toList(),
    );
    _onChanged?.call();
  }

  Organization? getById(int id) {
    try {
      return _organizations.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _startFirestoreListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    await _firestoreSub?.cancel();
    _firestoreSub = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.organizations)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      _organizations = snap.docs.map((doc) {
        final data = doc.data();
        return Organization.fromJson({
          ...data,
          'id': data['id'] ?? int.tryParse(doc.id) ?? 0,
        });
      }).toList();
      await _save();
    });
  }
}
