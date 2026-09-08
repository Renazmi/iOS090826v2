import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../config/firestore_collections.dart';
import '../services/firestore_sync_service.dart';

/// Global clock for chat: Firestore server time, displayed in Asia/Manila.
class PhilippinesTime {
  PhilippinesTime._();

  static const Duration utcOffset = Duration(hours: 8);

  static int _offsetMs = 0;
  static Future<void>? _syncing;

  static int nowMs() => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  static Future<void> sync() {
    return _syncing ??= _syncOnce().whenComplete(() {
      _syncing = null;
    });
  }

  static Future<void> _syncOnce() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.chatTyping)
        .doc('__philippinesClock');
    await ref.set({'t': FieldValue.serverTimestamp()});
    final snap = await ref.get(const GetOptions(source: Source.server));
    final value = snap.data()?['t'];
    final serverMs = parseMillis(value);
    if (serverMs != null) {
      _offsetMs = serverMs - DateTime.now().millisecondsSinceEpoch;
    }
  }

  static int? parseMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is int) {
      return value > 0 && value < 1000000000000 ? value * 1000 : value;
    }
    if (value is num) {
      final n = value.toInt();
      return n > 0 && n < 1000000000000 ? n * 1000 : n;
    }
    if (value is String) {
      final n = int.tryParse(value);
      if (n == null) return null;
      return n > 0 && n < 1000000000000 ? n * 1000 : n;
    }
    if (value is Map) {
      final seconds = value['seconds'] ?? value['_seconds'];
      if (seconds is num) return (seconds * 1000).round();
    }
    return null;
  }

  /// Wall-clock DateTime in the Philippines (UTC+8, no DST).
  static DateTime dateTime(int timestampMs) {
    final utc = DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
    final ph = utc.add(utcOffset);
    return DateTime(
      ph.year,
      ph.month,
      ph.day,
      ph.hour,
      ph.minute,
      ph.second,
      ph.millisecond,
    );
  }

  static String formatChatTime(int timestampMs) {
    final when = dateTime(timestampMs);
    final now = dateTime(nowMs());
    final time = DateFormat.jm().format(when);
    final sameDay =
        when.year == now.year && when.month == now.month && when.day == now.day;
    if (sameDay) return time;
    return '${DateFormat.MMMd().format(when)} $time';
  }
}
