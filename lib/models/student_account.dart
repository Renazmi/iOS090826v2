class StudentAccount {
  const StudentAccount({
    required this.studentId,
    required this.fullName,
    required this.phone,
    required this.gmail,
    required this.password,
    this.verified = true,
    this.status = 'active',
    this.passwordSetByAdmin = false,
    this.firebaseAuthLinked = false,
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

  /// 'active' or 'inactive' — admins deactivate accounts to block sign-in.
  final String status;

  /// True while the current password came from an admin reset, which makes the
  /// Firebase Auth password stale and unusable for sign-in.
  final bool passwordSetByAdmin;
  final bool firebaseAuthLinked;
  final bool profileCompleted;
  final String? createdAt;
  final String? profilePictureUrl;

  bool get isActive => status != 'inactive';

  factory StudentAccount.fromJson(Map<String, dynamic> json) {
    return StudentAccount(
      studentId: '${json['studentId'] ?? ''}'.trim(),
      fullName: '${json['fullName'] ?? ''}'.trim(),
      phone: '${json['phone'] ?? ''}'.trim(),
      gmail: '${json['gmail'] ?? ''}'.trim().toLowerCase(),
      password: '${json['password'] ?? ''}',
      verified: json['verified'] as bool? ?? true,
      status: '${json['status'] ?? 'active'}'.trim().toLowerCase() == 'inactive'
          ? 'inactive'
          : 'active',
      passwordSetByAdmin: json['passwordSetByAdmin'] as bool? ?? false,
      firebaseAuthLinked: json['firebaseAuthLinked'] as bool? ?? false,
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
        'status': status,
        'passwordSetByAdmin': passwordSetByAdmin,
        'firebaseAuthLinked': firebaseAuthLinked,
        'profileCompleted': profileCompleted,
        if (createdAt != null) 'createdAt': createdAt,
        if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
      };

  StudentAccount copyWith({
    String? fullName,
    String? phone,
    String? gmail,
    String? password,
    String? status,
    bool? passwordSetByAdmin,
    bool? firebaseAuthLinked,
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
      status: status ?? this.status,
      passwordSetByAdmin: passwordSetByAdmin ?? this.passwordSetByAdmin,
      firebaseAuthLinked: firebaseAuthLinked ?? this.firebaseAuthLinked,
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
