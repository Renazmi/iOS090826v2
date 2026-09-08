enum ReportType { minutes, accomplishment, other }

class Report {
  const Report({
    required this.id,
    required this.officerId,
    required this.officerName,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    this.officerPosition,
    this.eventId,
    this.eventTitle,
  });

  final int id;
  final int officerId;
  final String officerName;
  final String? officerPosition;
  final ReportType type;
  final String title;
  final String content;
  final int createdAt;
  final int? eventId;
  final String? eventTitle;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as int,
      officerId: json['officerId'] as int,
      officerName: '${json['officerName'] ?? ''}',
      officerPosition: json['officerPosition'] as String?,
      type: _parseType('${json['type'] ?? 'other'}'),
      title: '${json['title'] ?? ''}',
      content: '${json['content'] ?? ''}',
      createdAt: json['createdAt'] as int? ?? 0,
      eventId: json['eventId'] as int?,
      eventTitle: json['eventTitle'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'officerId': officerId,
        'officerName': officerName,
        if (officerPosition != null) 'officerPosition': officerPosition,
        'type': type.name,
        'title': title,
        'content': content,
        'createdAt': createdAt,
        if (eventId != null) 'eventId': eventId,
        if (eventTitle != null) 'eventTitle': eventTitle,
      };

  static ReportType _parseType(String raw) {
    switch (raw) {
      case 'minutes':
        return ReportType.minutes;
      case 'accomplishment':
        return ReportType.accomplishment;
      default:
        return ReportType.other;
    }
  }
}
