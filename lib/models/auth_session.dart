import 'trackit_role.dart';

class AuthSession {
  const AuthSession({
    required this.role,
    this.studentId,
    this.officerId,
    this.displayName,
  });

  final TrackitRole role;
  final String? studentId;
  final int? officerId;
  final String? displayName;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final roleName = '${json['role'] ?? ''}';
    return AuthSession(
      role: TrackitRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => TrackitRole.student,
      ),
      studentId: json['studentId'] as String?,
      officerId: (json['officerId'] as num?)?.toInt(),
      displayName: json['displayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        if (studentId != null) 'studentId': studentId,
        if (officerId != null) 'officerId': officerId,
        if (displayName != null) 'displayName': displayName,
      };

  bool get isAuthenticated =>
      role == TrackitRole.student
          ? studentId != null && studentId!.isNotEmpty
          : role == TrackitRole.officer
              ? officerId != null
              : false;
}
