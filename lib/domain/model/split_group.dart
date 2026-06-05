import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitGroupStatus { active, settled }

class SplitGroup {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final String createdByUid;
  final SplitGroupStatus status;
  final List<String> memberUids;

  SplitGroup({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.createdByUid,
    required this.status,
    required this.memberUids,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUid': createdByUid,
      'status': status.name,
      'memberUids': memberUids,
    };
  }

  factory SplitGroup.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawMemberUids = map['memberUids'] as List? ?? [];
    
    DateTime parseTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return SplitGroup(
      id: docId ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      createdAt: parseTime(map['createdAt']),
      createdByUid: map['createdByUid']?.toString() ?? map['ownerId']?.toString() ?? '',
      status: map['status']?.toString() == 'settled'
          ? SplitGroupStatus.settled
          : SplitGroupStatus.active,
      memberUids: rawMemberUids.map((u) => u.toString()).toList(),
    );
  }

  SplitGroup copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    String? createdByUid,
    SplitGroupStatus? status,
    List<String>? memberUids,
  }) {
    return SplitGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      createdByUid: createdByUid ?? this.createdByUid,
      status: status ?? this.status,
      memberUids: memberUids ?? this.memberUids,
    );
  }
}
