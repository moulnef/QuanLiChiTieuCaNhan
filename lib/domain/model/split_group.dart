import 'split_member.dart';
import 'split_expense.dart';

enum SplitGroupStatus { active, settled }

class SplitGroup {
  final String id;
  final String name;
  final DateTime createdAt;
  final SplitGroupStatus status;
  final String ownerId;
  final List<String> memberUids;
  final List<SplitMember> members;
  final List<SplitExpense> expenses;

  SplitGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.status,
    required this.ownerId,
    required this.memberUids,
    required this.members,
    required this.expenses,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.name,
      'ownerId': ownerId,
      'memberUids': memberUids,
      'members': members.map((m) => m.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };
  }

  factory SplitGroup.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'] as List? ?? [];
    final rawExpenses = map['expenses'] as List? ?? [];
    final rawMemberUids = map['memberUids'] as List? ?? [];

    return SplitGroup(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      status: map['status']?.toString() == 'settled'
          ? SplitGroupStatus.settled
          : SplitGroupStatus.active,
      ownerId: map['ownerId']?.toString() ?? '',
      memberUids: rawMemberUids.map((u) => u.toString()).toList(),
      members: rawMembers
          .map((m) => SplitMember.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      expenses: rawExpenses
          .map((e) => SplitExpense.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  SplitGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    SplitGroupStatus? status,
    String? ownerId,
    List<String>? memberUids,
    List<SplitMember>? members,
    List<SplitExpense>? expenses,
  }) {
    return SplitGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      memberUids: memberUids ?? this.memberUids,
      members: members ?? this.members,
      expenses: expenses ?? this.expenses,
    );
  }
}
