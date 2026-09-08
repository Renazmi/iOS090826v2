import '../config/storage_keys.dart';
import '../models/report.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Mirrors `ReportsService` sample data from the Ionic web app.
class ReportsService {
  ReportsService(this._storage, this._api);

  final StorageService _storage;
  final ApiService _api;

  List<Report> _reports = [];

  List<Report> get reports => List.unmodifiable(_reports);

  Future<void> initialize() async {
    final rows = _storage.readJsonList(StorageKeys.reports);
    if (rows.isNotEmpty) {
      _reports = rows.map(Report.fromJson).toList();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _reports = [
      Report(
        id: 1,
        officerId: 3,
        officerName: 'Santos Gicelle',
        officerPosition: 'Secretary',
        type: ReportType.minutes,
        title: 'General Assembly – February 2026',
        content: 'Minutes of the Meeting…',
        createdAt: now - 86400000 * 2,
      ),
      Report(
        id: 2,
        officerId: 1,
        officerName: 'Faith Turtogo',
        officerPosition: 'President',
        type: ReportType.accomplishment,
        title: 'Q1 2026 Accomplishment Report',
        content: 'Accomplishment Report – President…',
        createdAt: now - 86400000 * 5,
      ),
      Report(
        id: 3,
        officerId: 2,
        officerName: 'Lance Enri Diamzon',
        officerPosition: 'Vice President',
        type: ReportType.minutes,
        title: 'Leadership Workshop Planning Meeting',
        content: 'Minutes – Workshop Planning…',
        createdAt: now - 86400000 * 4,
      ),
      Report(
        id: 4,
        officerId: 6,
        officerName: 'Bangate Diamzon',
        officerPosition: 'P.R.O.',
        type: ReportType.accomplishment,
        title: 'P.R.O. Monthly Report – February',
        content: 'Accomplishment Report – P.R.O.…',
        createdAt: now - 86400000,
      ),
    ];
    await _save();
  }

  Future<void> _save() async {
    await _api.saveCollection(
      StorageKeys.reports,
      _reports.map((r) => r.toJson()).toList(),
    );
  }

  List<Report> recentReports({int limit = 4}) {
    final sorted = [..._reports]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }
}
