enum TrackitRole { student, officer, admin }

extension TrackitRoleLabel on TrackitRole {
  String get label {
    switch (this) {
      case TrackitRole.student:
        return 'Student';
      case TrackitRole.officer:
        return 'Officer';
      case TrackitRole.admin:
        return 'Admin';
    }
  }
}
