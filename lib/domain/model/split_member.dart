class SplitMember {
  final String id;
  final String name;
  final String? userId;

  SplitMember({
    required this.id,
    required this.name,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
    };
  }

  factory SplitMember.fromMap(Map<String, dynamic> map) {
    return SplitMember(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      userId: map['userId']?.toString(),
    );
  }
}
