class RosterStudent {
  const RosterStudent({
    required this.name,
    required this.studentId,
    required this.section,
    this.status = 'active',
  });

  final String name;
  final String studentId;
  final String section;
  final String status;

  bool get isActive => status != 'inactive';

  factory RosterStudent.fromJson(Map<String, dynamic> json) {
    final rawStatus = '${json['status'] ?? 'active'}'.trim().toLowerCase();
    return RosterStudent(
      name: '${json['name'] ?? ''}'.trim(),
      studentId: '${json['studentId'] ?? ''}'.trim(),
      section: '${json['section'] ?? ''}'.trim(),
      status: rawStatus == 'inactive' ? 'inactive' : 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'studentId': studentId,
        'section': section,
        'status': status,
      };

  RosterStudent copyWith({
    String? name,
    String? section,
    String? status,
  }) {
    return RosterStudent(
      name: name ?? this.name,
      studentId: studentId,
      section: section ?? this.section,
      status: status ?? this.status,
    );
  }
}
