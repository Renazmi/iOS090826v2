import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/beta_tester_students.dart';
import '../data/class_roster_students.dart';
import '../models/roster_student.dart';
import '../utils/student_id.dart';
import 'firestore_sync_service.dart';
import 'storage_service.dart';

const _classRosterSection = 'CCS';

/// Default roster entries — used only when Firestore has no roster yet.
const defaultRosterSeed = [
  RosterStudent(studentId: '201172224', name: 'Renaz Mi', section: '3B'),
  RosterStudent(studentId: '2025999001', name: 'Mobile Test Student', section: '3A'),
  RosterStudent(studentId: '2025999002', name: 'Mobile Student Alpha', section: '1A'),
  RosterStudent(studentId: '2025999003', name: 'Mobile Student Beta', section: '2B'),
  RosterStudent(studentId: '2025999004', name: 'Mobile Student Gamma', section: '3C'),
  RosterStudent(studentId: '2025999005', name: 'Mobile Student Delta', section: '4A'),
  RosterStudent(studentId: '2025999006', name: 'Mobile Student Epsilon', section: '1B'),
  RosterStudent(studentId: '2025999007', name: 'Mobile Student Zeta', section: '2A'),
  RosterStudent(studentId: '2025999008', name: 'Mobile Student Eta', section: '2C'),
  RosterStudent(studentId: '2025999009', name: 'Mobile Student Theta', section: '3A'),
  RosterStudent(studentId: '2025999010', name: 'Mobile Student Iota', section: '3B'),
  RosterStudent(studentId: '2025999011', name: 'Mobile Student Kappa', section: '4B'),
  RosterStudent(studentId: '202501002', name: 'Carlo Mendoza', section: '1A'),
  RosterStudent(studentId: '202501003', name: 'Patricia Santos', section: '1B'),
  RosterStudent(studentId: '202502002', name: 'Gabriel Torres', section: '2B'),
  RosterStudent(studentId: '202503001', name: 'Hannah Villanueva', section: '3C'),
  RosterStudent(studentId: '202504001', name: 'Miguel Dela Cruz', section: '4A'),
];

/// Section roster lookup — mirrors `SectionsService` enrollment checks for signup.
class SectionsService {
  SectionsService(this._storage);

  final StorageService _storage;
  Map<String, List<RosterStudent>> _roster = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  bool _seededFirestore = false;
  bool _applyingFirestoreSnapshot = false;
  void Function()? _onChanged;

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> dispose() async {
    await _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  Future<void> initialize() async {
    _loadRoster();
    if (_roster.isEmpty) {
      _applySeed();
      _ensureClassRosterStudents();
      _ensureBetaTesterStudents();
      await _persistRoster();
    }
    await _startFirestoreListener();
  }

  void _loadRoster() {
    final raw = _storage.readJsonObject(StorageKeys.sectionRoster);
    if (raw == null || raw.isEmpty) {
      _roster = {};
      return;
    }
    _roster = raw.map(
      (key, value) {
        if (value is! List) return MapEntry(key, <RosterStudent>[]);
        final students = value
            .whereType<Map>()
            .map((row) => RosterStudent.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        return MapEntry(key, students);
      },
    );
  }

  Future<void> _persistRoster() async {
    final encoded = _roster.map(
      (key, value) => MapEntry(key, value.map((s) => s.toJson()).toList()),
    );
    await _storage.writeJsonObject(StorageKeys.sectionRoster, encoded);

    final totals = _roster.map(
      (key, value) => MapEntry(key, value.where((s) => s.isActive).length),
    );
    await _storage.writeJsonObject(StorageKeys.sectionTotals, totals);
    _onChanged?.call();
  }

  void _applySeed() {
    _roster = {};
    for (final seed in defaultRosterSeed) {
      final section = seed.section.trim().toUpperCase();
      _roster.putIfAbsent(section, () => []).add(
            RosterStudent(
              studentId: _normalizeId(seed.studentId),
              name: seed.name,
              section: section,
            ),
          );
    }
  }

  void _ensureClassRosterStudents() {
    for (final student in classRosterStudents) {
      final id = _normalizeId(student.studentId);
      if (id.isEmpty || findStudentByIdAny(id) != null) continue;
      _roster.putIfAbsent(_classRosterSection, () => []).add(
            RosterStudent(
              studentId: id,
              name: student.fullName.trim(),
              section: _classRosterSection,
            ),
          );
    }
  }

  void _ensureBetaTesterStudents() {
    for (final entry in betaTesterRosterEntries) {
      final id = _normalizeId(entry.studentId);
      if (id.isEmpty || findStudentByIdAny(id) != null) continue;
      final section = entry.section.trim().toUpperCase();
      _roster.putIfAbsent(section, () => []).add(
            RosterStudent(studentId: id, name: entry.fullName.trim(), section: section),
          );
    }
  }

  String _normalizeId(String studentId) => normalizeStudentId(studentId);

  RosterStudent? findStudentByIdAny(String studentId) {
    final id = _normalizeId(studentId);
    if (id.isEmpty) return null;
    for (final students in _roster.values) {
      for (final student in students) {
        if (_normalizeId(student.studentId) == id) return student;
      }
    }
    return null;
  }

  RosterStudent? findStudentById(String studentId) {
    final found = findStudentByIdAny(studentId);
    if (found == null || !found.isActive) return null;
    return found;
  }

  /// Live Firestore lookup so a newly uploaded Student ID can register at once.
  Future<RosterStudent?> fetchStudentByIdAny(String studentId) async {
    final local = findStudentByIdAny(studentId);
    if (local != null) return local;

    final id = _normalizeId(studentId);
    if (id.isEmpty) return null;
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return null;

    try {
      final snap = await FirestoreSyncService.instance.db
          .collection(FirestoreCollections.rosterStudents)
          .doc(id)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists) return null;
      final student = RosterStudent.fromJson({...snap.data() ?? {}, 'studentId': snap.id});
      final section = student.section.trim().isEmpty ? '1A' : student.section.trim().toUpperCase();
      final record = RosterStudent(
        studentId: _normalizeId(student.studentId),
        name: student.name,
        section: section,
        status: student.status,
      );
      _upsertLocal(record);
      await _persistRoster();
      _onChanged?.call();
      return record;
    } catch (_) {
      return findStudentByIdAny(id);
    }
  }

  Future<RosterStudent?> fetchStudentById(String studentId) async {
    final found = await fetchStudentByIdAny(studentId);
    if (found == null || !found.isActive) return null;
    return found;
  }

  void _upsertLocal(RosterStudent student) {
    final section = student.section.trim().toUpperCase();
    final id = _normalizeId(student.studentId);
    for (final entry in _roster.entries) {
      entry.value.removeWhere((row) => _normalizeId(row.studentId) == id);
    }
    _roster.putIfAbsent(section, () => []).add(student);
  }

  Future<void> _startFirestoreListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    await _firestoreSub?.cancel();
    _firestoreSub = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.rosterStudents)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) {
        _seededFirestore = true;
        return;
      }

      _seededFirestore = true;
      _applyingFirestoreSnapshot = true;
      try {
        _roster = {};
        for (final doc in snap.docs) {
          final student = RosterStudent.fromJson({...doc.data(), 'studentId': doc.id});
          final section = student.section.trim().isEmpty ? '1A' : student.section.trim().toUpperCase();
          _roster.putIfAbsent(section, () => []).add(
                RosterStudent(
                  studentId: _normalizeId(student.studentId),
                  name: student.name,
                  section: section,
                  status: student.status,
                ),
              );
        }
        await _persistRoster();
        _onChanged?.call();
      } finally {
        _applyingFirestoreSnapshot = false;
      }
    });
  }

  Future<void> _seedFirestoreFromLocal() async {
    if (_applyingFirestoreSnapshot) return;
    if (!FirestoreSyncService.instance.isReady) return;
    final db = FirestoreSyncService.instance.db;
    for (final students in _roster.values) {
      for (final student in students) {
        await db
            .collection(FirestoreCollections.rosterStudents)
            .doc(_normalizeId(student.studentId))
            .set({
          ...student.toJson(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    }
  }
}
