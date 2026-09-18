class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.logoUrl,
    this.bylawsTitle,
    this.bylawsBody,
    this.bylawsUpdatedAt,
  });

  final int id;
  final String name;
  final String? logoUrl;
  final String? bylawsTitle;
  final String? bylawsBody;
  final String? bylawsUpdatedAt;

  bool get hasBylaws => (bylawsBody ?? '').trim().isNotEmpty;

  factory Organization.fromJson(Map<String, dynamic> json, {String? docId}) {
    return Organization(
      id: _parseId(json['id']) ?? _parseId(docId) ?? 0,
      name: '${json['name'] ?? ''}',
      logoUrl: _optionalString(json['logoUrl']),
      bylawsTitle: _optionalString(json['bylawsTitle']),
      bylawsBody: _optionalString(json['bylawsBody']),
      bylawsUpdatedAt: _optionalString(json['bylawsUpdatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (bylawsTitle != null) 'bylawsTitle': bylawsTitle,
        if (bylawsBody != null) 'bylawsBody': bylawsBody,
        if (bylawsUpdatedAt != null) 'bylawsUpdatedAt': bylawsUpdatedAt,
      };

  Organization copyWith({
    String? name,
    String? logoUrl,
    String? bylawsTitle,
    String? bylawsBody,
    String? bylawsUpdatedAt,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      bylawsTitle: bylawsTitle ?? this.bylawsTitle,
      bylawsBody: bylawsBody ?? this.bylawsBody,
      bylawsUpdatedAt: bylawsUpdatedAt ?? this.bylawsUpdatedAt,
    );
  }

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
