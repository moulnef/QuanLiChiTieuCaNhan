import 'package:cloud_firestore/cloud_firestore.dart';

class AppFeedback {
  AppFeedback({
    this.id = '',
    required this.userId,
    required this.userDisplayName,
    required this.userEmail,
    required this.rating,
    required this.comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String userId;
  final String userDisplayName;
  final String userEmail;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userEmail': userEmail,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory AppFeedback.fromMap(Map<String, dynamic> map, [String? documentId]) {
    return AppFeedback(
      id: documentId ?? map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userDisplayName: map['userDisplayName']?.toString() ?? 'Người dùng',
      userEmail: map['userEmail']?.toString() ?? '',
      rating: _parseRating(map['rating']),
      comment: map['comment']?.toString() ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt'] ?? map['createdAt']),
    );
  }

  AppFeedback copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userEmail,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userEmail: userEmail ?? this.userEmail,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _parseRating(dynamic value) {
    if (value is int) return value.clamp(1, 5);
    if (value is num) return value.toInt().clamp(1, 5);
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) return 5;
    return parsed.clamp(1, 5);
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
