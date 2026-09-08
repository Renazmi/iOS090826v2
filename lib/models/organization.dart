class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  final int id;
  final String name;
  final String? logoUrl;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: (json['id'] as num).toInt(),
      name: '${json['name'] ?? ''}',
      logoUrl: json['logoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
      };
}
