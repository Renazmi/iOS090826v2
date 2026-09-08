class Officer {
  const Officer({
    required this.id,
    required this.name,
    required this.position,
    required this.email,
    required this.yearLevel,
    required this.section,
    required this.attendanceCount,
    required this.dailyAttendanceCount,
    required this.organizationId,
    this.studentId,
    this.phone,
    this.profilePictureUrl,
    this.bio,
    this.achievements,
    this.hobby,
  });

  final int id;
  final String name;
  final String position;
  final String email;
  final String yearLevel;
  final String section;
  final int attendanceCount;
  final int dailyAttendanceCount;
  final int organizationId;
  final String? studentId;
  final String? phone;
  final String? profilePictureUrl;
  final String? bio;
  final List<String>? achievements;
  final String? hobby;

  factory Officer.fromJson(Map<String, dynamic> json) {
    return Officer(
      id: (json['id'] as num).toInt(),
      name: '${json['name'] ?? ''}',
      position: '${json['position'] ?? ''}',
      email: '${json['email'] ?? ''}',
      yearLevel: '${json['yearLevel'] ?? ''}',
      section: '${json['section'] ?? ''}',
      attendanceCount: (json['attendanceCount'] as num?)?.toInt() ?? 0,
      dailyAttendanceCount: (json['dailyAttendanceCount'] as num?)?.toInt() ?? 0,
      organizationId: (json['organizationId'] as num?)?.toInt() ?? 0,
      studentId: json['studentId'] as String?,
      phone: json['phone'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      bio: json['bio'] as String?,
      achievements: (json['achievements'] as List<dynamic>?)
          ?.map((e) => '$e')
          .toList(),
      hobby: json['hobby'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position,
        'email': email,
        'yearLevel': yearLevel,
        'section': section,
        'attendanceCount': attendanceCount,
        'dailyAttendanceCount': dailyAttendanceCount,
        'organizationId': organizationId,
        if (studentId != null) 'studentId': studentId,
        if (phone != null) 'phone': phone,
        if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
        if (bio != null) 'bio': bio,
        if (achievements != null) 'achievements': achievements,
        if (hobby != null) 'hobby': hobby,
      };

  Officer copyWith({
    String? name,
    String? email,
    String? phone,
    int? organizationId,
    String? profilePictureUrl,
    bool clearProfilePicture = false,
  }) {
    return Officer(
      id: id,
      name: name ?? this.name,
      position: position,
      email: email ?? this.email,
      yearLevel: yearLevel,
      section: section,
      attendanceCount: attendanceCount,
      dailyAttendanceCount: dailyAttendanceCount,
      organizationId: organizationId ?? this.organizationId,
      studentId: studentId,
      phone: phone ?? this.phone,
      profilePictureUrl:
          clearProfilePicture ? null : (profilePictureUrl ?? this.profilePictureUrl),
      bio: bio,
      achievements: achievements,
      hobby: hobby,
    );
  }
}
