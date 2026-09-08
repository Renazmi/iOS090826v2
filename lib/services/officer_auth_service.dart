import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/class_roster_officers.dart';
import '../data/seed_data.dart';
import '../models/officer.dart';
import '../utils/firebase_password_sync.dart';
import '../utils/password_hash.dart';
import '../utils/settings_validation.dart';
import 'api_service.dart';
import 'firestore_sync_service.dart';
import 'storage_service.dart';

/// Mirrors `OfficersService` auth/password logic from the Ionic web app.
class OfficerAuthService {
  OfficerAuthService(this._storage, this._api);

  final StorageService _storage;
  final ApiService _api;

  List<Officer> _officers = [];
  Map<int, String> _passwords = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  bool _applyingFirestoreSnapshot = false;
  void Function()? _onChanged;

  List<Officer> get officers => List.unmodifiable(_officers);

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> initialize() async {
    await _loadOfficers();
    await _ensureSeededOfficers();
    await _loadPasswords();
    await _ensureSeededPasswords();
    await _ensurePrimaryLoginAccounts();
    await _ensureClassRosterOfficersUnassigned();
    await _startFirestoreListener();
  }

  Future<void> dispose() async {
    await _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  Future<void> _loadOfficers() async {
    final rows = _storage.readJsonList(StorageKeys.officers);
    if (rows.isEmpty) {
      _officers = buildDefaultOfficers();
      await _saveOfficers();
      return;
    }
    try {
      _officers = rows.map(Officer.fromJson).toList();
    } catch (_) {
      _officers = buildDefaultOfficers();
      await _saveOfficers();
    }
  }

  Future<void> _saveOfficers() async {
    await _api.saveCollection(
      StorageKeys.officers,
      _officers.map((o) => o.toJson()).toList(),
    );
    _onChanged?.call();
  }

  Future<void> _loadPasswords() async {
    final raw = _storage.readJsonObject(StorageKeys.officerPasswords);
    if (raw == null) {
      _passwords = {};
      return;
    }
    var changed = false;
    _passwords = raw.map((key, value) {
      final stored = '$value';
      if (isHashedPassword(stored) || stored.isEmpty) {
        return MapEntry(int.parse(key), stored);
      }
      changed = true;
      return MapEntry(int.parse(key), normalizeStoredPassword(stored));
    });
    if (changed) await _savePasswords();
  }

  Future<void> _savePasswords() async {
    await _storage.writeJsonObject(
      StorageKeys.officerPasswords,
      _passwords.map((key, value) => MapEntry('$key', value)),
    );
  }

  Future<void> _ensureSeededOfficers() async {
    var changed = false;
    final ids = _officers.map((o) => o.id).toSet();
    for (final seed in buildDefaultOfficers()) {
      if (!ids.contains(seed.id)) {
        _officers.add(seed);
        changed = true;
      }
    }
    if (changed) {
      await _saveOfficers();
    }
  }

  Future<void> _ensureSeededPasswords() async {
    var changed = false;
    for (final entry in defaultOfficerPasswords.entries) {
      if (!_hasStoredPassword(entry.key)) {
        _passwords[entry.key] = hashPassword(entry.value);
        changed = true;
      }
    }
    for (final entry in classRosterOfficerPasswords.entries) {
      if (!_hasStoredPassword(entry.key)) {
        _passwords[entry.key] = hashPassword(entry.value);
        changed = true;
      }
    }
    if (changed) {
      await _savePasswords();
    }
  }

  bool _hasStoredPassword(int officerId) {
    final stored = _passwords[officerId];
    return stored != null && stored.isNotEmpty;
  }

  /// Keeps known login emails/passwords working even after older app data was saved.
  Future<void> _ensurePrimaryLoginAccounts() async {
    var officersChanged = false;
    var passwordsChanged = false;
    final seedById = {for (final officer in buildDefaultOfficers()) officer.id: officer};

    for (final login in primaryOfficerLogins) {
      final seed = seedById[login.officerId];
      final index = _officers.indexWhere((o) => o.id == login.officerId);

      if (seed != null) {
        if (index < 0) {
          _officers.add(seed.copyWith(email: login.email));
          officersChanged = true;
        } else {
          final current = _officers[index];
          final legacyRenazPhoto = current.profilePictureUrl?.trim();
          final needsRenazPhotoUpdate = login.officerId == 1 &&
              (legacyRenazPhoto == 'assets/images/lance1.jpg' ||
                  legacyRenazPhoto == 'assets/images/muichiro.jpg');
          if (current.email.trim().toLowerCase() != login.email.trim().toLowerCase() ||
              current.position.trim().toLowerCase() != seed.position.trim().toLowerCase() ||
              current.organizationId != seed.organizationId ||
              current.name.trim().isEmpty ||
              needsRenazPhotoUpdate) {
            _officers[index] = seed.copyWith(
              email: login.email,
              phone: current.phone ?? seed.phone,
              profilePictureUrl: needsRenazPhotoUpdate
                  ? 'assets/images/bangate.jpg'
                  : current.profilePictureUrl ?? seed.profilePictureUrl,
            );
            officersChanged = true;
          }
        }
      } else if (index >= 0) {
        final officer = _officers[index];
        if (officer.email.trim().toLowerCase() != login.email.trim().toLowerCase()) {
          _officers[index] = officer.copyWith(email: login.email);
          officersChanged = true;
        }
      }

      if (!_hasStoredPassword(login.officerId)) {
        _passwords[login.officerId] = hashPassword(login.password);
        passwordsChanged = true;
      }
    }

    for (final login in mobileTestOfficerLogins) {
      final seed = seedById[login.officerId];
      final index = _officers.indexWhere((o) => o.id == login.officerId);

      if (seed != null && index < 0) {
        _officers.add(seed.copyWith(email: login.email));
        officersChanged = true;
      } else if (seed != null && index >= 0) {
        final current = _officers[index];
        if (current.email.trim().toLowerCase() != login.email.trim().toLowerCase() ||
            current.name.trim().isEmpty) {
          _officers[index] = seed.copyWith(email: login.email);
          officersChanged = true;
        }
      }

      if (!_hasStoredPassword(login.officerId)) {
        _passwords[login.officerId] = hashPassword(login.password);
        passwordsChanged = true;
      }
    }

    if (officersChanged) await _saveOfficers();
    if (passwordsChanged) await _savePasswords();
  }

  Future<void> _ensureClassRosterOfficersUnassigned() async {
    var changed = false;
    for (var i = 0; i < _officers.length; i++) {
      final officer = _officers[i];
      if (!classRosterOfficerIds.contains(officer.id)) continue;
      if (officer.organizationId == classRosterOrganizationId) continue;
      _officers[i] = officer.copyWith(organizationId: classRosterOrganizationId);
      changed = true;
    }
    if (changed) await _saveOfficers();
  }

  Officer? getOfficerById(int id) {
    try {
      return _officers.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Officer? verifyOfficerLogin(String email, String password) {
    final officer = findOfficerByEmail(email);
    if (officer == null) return null;
    final stored = _passwords[officer.id];
    if (!verifyPassword(password, stored)) return null;
    return officer;
  }

  Officer? findOfficerByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final item in _officers) {
      if (item.email.toLowerCase() == normalized) {
        return item;
      }
    }

    final aliasId = defaultOfficerEmailAliases[normalized];
    if (aliasId != null) {
      return getOfficerById(aliasId);
    }

    return null;
  }

  Future<void> resetOfficerPasswordFromRecovery(int officerId, String newPassword) async {
    _passwords[officerId] = hashPassword(newPassword);
    await _savePasswords();
    final officer = getOfficerById(officerId);
    if (officer != null) {
      await _writeOfficerToFirestore(officer);
    }
  }

  Future<Officer?> acceptRemotePasswordIfValid(String email, String password) async {
    final officer = findOfficerByEmail(email);
    if (officer == null) return null;
    final accepted = await tryFirebasePasswordSignIn(officer.email, password);
    if (!accepted) return null;
    await resetOfficerPasswordFromRecovery(officer.id, password);
    return getOfficerById(officer.id);
  }

  Officer? getCurrentOfficer() {
    final raw = _storage.readString(StorageKeys.currentOfficer);
    if (raw == null || raw.isEmpty) return null;
    final id = int.tryParse(raw);
    if (id == null) return null;
    return getOfficerById(id);
  }

  Future<void> setCurrentOfficer(int officerId) async {
    await _storage.writeString(StorageKeys.currentOfficer, '$officerId');
  }

  Future<void> clearCurrentOfficer() async {
    await _storage.remove(StorageKeys.currentOfficer);
  }

  Future<OfficerUpdateResult> updateOfficerAccount(
    int id, {
    String? name,
    String? email,
    String? phone,
  }) async {
    final index = _officers.indexWhere((o) => o.id == id);
    if (index < 0) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }

    final trimmedName = name?.trim();
    final trimmedEmail = email?.trim().toLowerCase();
    final trimmedPhone = phone?.trim();

    if (trimmedName != null ||
        trimmedEmail != null ||
        trimmedPhone != null) {
      final validationError = SettingsValidation.validateOfficerProfile(
        fullName: trimmedName ?? _officers[index].name,
        email: trimmedEmail ?? _officers[index].email,
        phone: trimmedPhone ?? _officers[index].phone ?? '',
      );
      if (validationError != null) {
        return OfficerUpdateResult.fail(validationError);
      }
    }

    if (trimmedEmail != null) {
      final duplicate = _officers.any(
        (o) => o.id != id && o.email.toLowerCase() == trimmedEmail,
      );
      if (duplicate) {
        return const OfficerUpdateResult.fail('That username is already in use.');
      }
    }

    var updated = _officers[index];
    if (trimmedName != null) updated = updated.copyWith(name: trimmedName);
    if (trimmedEmail != null) updated = updated.copyWith(email: trimmedEmail);
    if (trimmedPhone != null) {
      updated = updated.copyWith(phone: trimmedPhone.isEmpty ? '' : trimmedPhone);
    }

    _officers[index] = updated;
    await _saveOfficers();
    await _writeOfficerToFirestore(updated);
    return const OfficerUpdateResult.ok();
  }

  Future<OfficerUpdateResult> changeOfficerPassword(
    int id,
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    final officer = getOfficerById(id);
    if (officer == null) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }

    final validationError = SettingsValidation.validateOfficerPasswordChange(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (validationError != null) {
      return OfficerUpdateResult.fail(validationError);
    }

    if (!verifyPassword(currentPassword, _passwords[id])) {
      return const OfficerUpdateResult.fail('Current password is incorrect.');
    }

    _passwords[id] = hashPassword(newPassword);
    await _savePasswords();
    await _writeOfficerToFirestore(officer);
    await syncFirebaseAccountPassword(
      email: officer.email,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return const OfficerUpdateResult.ok();
  }

  Future<OfficerUpdateResult> setOfficerProfilePicture(int id, String dataUrl) async {
    final index = _officers.indexWhere((o) => o.id == id);
    if (index < 0) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }
    final url = dataUrl.trim();
    if (!url.startsWith('data:image/')) {
      return const OfficerUpdateResult.fail('Choose a valid image file.');
    }
    _officers[index] = _officers[index].copyWith(profilePictureUrl: url);
    await _saveOfficers();
    await _writeOfficerToFirestore(_officers[index]);
    return const OfficerUpdateResult.ok();
  }

  Future<OfficerUpdateResult> clearOfficerProfilePicture(int id) async {
    final index = _officers.indexWhere((o) => o.id == id);
    if (index < 0) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }
    _officers[index] = _officers[index].copyWith(clearProfilePicture: true);
    await _saveOfficers();
    await _writeOfficerToFirestore(_officers[index]);
    return const OfficerUpdateResult.ok();
  }

  Future<void> _startFirestoreListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    await _firestoreSub?.cancel();
    _firestoreSub = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.officers)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;

      _applyingFirestoreSnapshot = true;
      try {
        _officers = [];
        for (final doc in snap.docs) {
          final data = doc.data();
          final officer = Officer.fromJson({
            ...data,
            'id': data['id'] ?? int.tryParse(doc.id) ?? 0,
          });
          _officers.add(officer);
          final hash = '${data['passwordHash'] ?? ''}';
          if (hash.isNotEmpty) {
            _passwords[officer.id] = hash;
          }
        }
        await _saveOfficers();
        await _savePasswords();
      } finally {
        _applyingFirestoreSnapshot = false;
      }
    });
  }

  Future<void> _writeOfficerToFirestore(Officer officer) async {
    if (_applyingFirestoreSnapshot) return;
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;
    try {
      await FirestoreSyncService.instance.db
          .collection(FirestoreCollections.officers)
          .doc('${officer.id}')
          .set({
        ...officer.toJson(),
        if (_passwords[officer.id] != null) 'passwordHash': _passwords[officer.id],
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}

class OfficerUpdateResult {
  const OfficerUpdateResult._({required this.success, this.error});

  const OfficerUpdateResult.ok() : this._(success: true);
  const OfficerUpdateResult.fail(String message) : this._(success: false, error: message);

  final bool success;
  final String? error;
}
