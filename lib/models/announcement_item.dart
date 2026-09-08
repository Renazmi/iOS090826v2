class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.createdBy,
    required this.senderName,
    this.imageUrl,
  });

  final int id;
  final String title;
  final String message;
  final int createdAt;
  final String createdBy;
  final String senderName;
  final String? imageUrl;

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: json['id'] as int? ?? 0,
      title: '${json['title'] ?? 'Announcement'}',
      message: '${json['message'] ?? ''}',
      createdAt: json['createdAt'] as int? ?? 0,
      createdBy: '${json['createdBy'] ?? 'admin'}',
      senderName: '${json['senderName'] ?? 'Admin'}',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'createdAt': createdAt,
        'createdBy': createdBy,
        'senderName': senderName,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}
