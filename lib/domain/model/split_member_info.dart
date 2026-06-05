class SplitMemberInfo {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;

  SplitMemberInfo({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
    };
  }

  factory SplitMemberInfo.fromMap(Map<String, dynamic> map) {
    return SplitMemberInfo(
      uid: map['uid']?.toString() ?? map['userId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'Người dùng',
      email: map['email']?.toString() ?? '',
      photoUrl: map['photoURL']?.toString() ?? map['photoUrl']?.toString() ?? '',
    );
  }
}
