import 'package:flutter/services.dart';

class OrgBylawsDefaults {
  OrgBylawsDefaults._();

  static const aspTitle = 'Constitution and By-Laws of CCS – ASP: Alliance of Student Programmers';
  static const obraTitle = 'Constitution and By-Laws of OBRA: CCS Creative Media Production Organization';

  static String? _aspBody;
  static String? _obraBody;
  static Future<void>? _loading;

  static Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      _aspBody = (await rootBundle.loadString('assets/bylaws/asp.txt')).trim();
      _obraBody = (await rootBundle.loadString('assets/bylaws/obra.txt')).trim();
    } catch (_) {
      _aspBody ??= '';
      _obraBody ??= '';
    }
  }

  static String orgKey(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.contains('elite')) return 'elite';
    if (normalized.contains('obra')) return 'obra';
    if (normalized == 'asp' || normalized.startsWith('asp ') || normalized.contains('alliance')) {
      return 'asp';
    }
    return normalized;
  }

  static String? titleFor(String name) {
    switch (orgKey(name)) {
      case 'asp':
        return aspTitle;
      case 'obra':
        return obraTitle;
      default:
        return null;
    }
  }

  static String? bodyFor(String name) {
    switch (orgKey(name)) {
      case 'asp':
        return _aspBody;
      case 'obra':
        return _obraBody;
      default:
        return null;
    }
  }
}
