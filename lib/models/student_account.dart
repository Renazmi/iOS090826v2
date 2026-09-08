class StudentAccount {
  const StudentAccount({
    required this.studentId,
    required this.fullName,
    required this.phone,
    required this.gmail,
    required this.password,
    this.verified = true,
    this.profileCompleted = true,
    this.createdAt,
    this.profilePictureUrl,
  });

  final String studentId;
  final String fullName;
  final String phone;
  final String gmail;
  final String password;
  final bool verified;
  final bool profileCompleted;
  final String? createdAt;
  final String? profilePictureUrl;

  factory StudentAccount.fromJson(Map<String, dynamic> json) {
    return StudentAccount(
      studentId: '${json['studentId'] ?? ''}'.trim(),
      fullName: '${json['fullName'] ?? ''}'.trim(),
      phone: '${json['phone'] ?? ''}'.trim(),
      gmail: '${json['gmail'] ?? ''}'.trim().toLowerCase(),
      password: '${json['password'] ?? ''}',
      verified: json['verified'] as bool? ?? true,
      profileCompleted: json['profileCompleted'] as bool? ?? true,
      createdAt: json['createdAt'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'fullName': fullName,
        'phone': phone,
        'gmail': gmail,
        'password': password,
        'verified': verified,
        'profileCompleted': profileCompleted,
        if (createdAt != null) 'createdAt': createdAt,
        if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
      };

  StudentAccount copyWith({
    String? fullName,
    String? phone,
    String? gmail,
    String? password,
    bool? profileCompleted,
    String? profilePictureUrl,
    bool clearProfilePicture = false,
  }) {
    return StudentAccount(
      studentId: studentId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      gmail: gmail ?? this.gmail,
      password: password ?? this.password,
      verified: verified,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt,
      profilePictureUrl:
          clearProfilePicture ? null : (profilePictureUrl ?? this.profilePictureUrl),
    );
  }

  bool get needsProfileCompletion {
    final hasPhone = phone.trim().isNotEmpty;
    final hasGmail =
        gmail.trim().isNotEmpty && gmail.trim().toLowerCase().endsWith('@gmail.com');
    return !hasPhone || !hasGmail;
  }
}
