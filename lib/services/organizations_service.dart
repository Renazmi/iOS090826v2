import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/org_bylaws_defaults.dart';
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
    await OrgBylawsDefaults.ensureLoaded();
    final rows = _storage.readJsonList(StorageKeys.organizations);
    if (rows.isEmpty) {
      _organizations = List.from(defaultOrganizations);
    } else {
      _organizations = rows.map(Organization.fromJson).where((org) => org.id != 0).toList();
    }
    _organizations = _withDefaultBylaws(_organizations);
    await _save(notify: false);
    await _startFirestoreListener();
    _onChanged?.call();
  }

  Future<void> dispose() async {
    await _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  Future<void> _save({bool notify = true}) async {
    await _api.saveCollection(
      StorageKeys.organizations,
      _organizations.map((o) => o.toJson()).toList(),
    );
    if (notify) _onChanged?.call();
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
      final remote = <Organization>[];
      for (final doc in snap.docs) {
        try {
          final org = Organization.fromJson(
            Map<String, dynamic>.from(doc.data()),
            docId: doc.id,
          );
          if (org.id != 0 && org.name.trim().isNotEmpty) remote.add(org);
        } catch (_) {}
      }
      if (remote.isEmpty) return;
      _organizations = _withDefaultBylaws(_mergeIncoming(remote));
      await _save();
    });
  }

  List<Organization> _mergeIncoming(List<Organization> remote) {
    final previous = {for (final org in _organizations) org.id: org};
    return remote.map((incoming) {
      final local = previous[incoming.id];
      if (local == null) return incoming;
      if (incoming.hasBylaws) return incoming;
      if (local.hasBylaws) {
        return incoming.copyWith(
          bylawsTitle: local.bylawsTitle,
          bylawsBody: local.bylawsBody,
          bylawsUpdatedAt: local.bylawsUpdatedAt,
        );
      }
      return incoming;
    }).toList();
  }

  List<Organization> _withDefaultBylaws(List<Organization> orgs) {
    return orgs.map((org) {
      if (org.hasBylaws) return org;
      final body = OrgBylawsDefaults.bodyFor(org.name);
      if (body == null || body.isEmpty) return org;
      return org.copyWith(
        bylawsTitle: org.bylawsTitle ?? OrgBylawsDefaults.titleFor(org.name),
        bylawsBody: body,
      );
    }).toList();
  }
}
