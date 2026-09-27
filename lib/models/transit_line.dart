class TransitLine {
  final String id;
  final String name;
  final String city;
  final String colorHex;
  final String code;

  const TransitLine({
    required this.id,
    required this.name,
    required this.city,
    required this.colorHex,
    required this.code,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'color_hex': colorHex,
      'code': code,
    };
  }

  factory TransitLine.fromMap(Map<String, dynamic> map) {
    return TransitLine(
      id: map['id'] as String,
      name: map['name'] as String,
      city: map['city'] as String,
      colorHex: map['color_hex'] as String,
      code: map['code'] as String,
    );
  }

  @override
  String toString() => '$name ($code)';
}
