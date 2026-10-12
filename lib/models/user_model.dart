class UserModel {
  final String uid;
  final String email;
  final String name;
  final String gender; // 성별 필드 추가
  final String preferredStyle;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.gender = '여성', // 기본값 설정
    this.preferredStyle = '미니멀 / 스마트 캐주얼',
    this.createdAt,
  });

  // Firestore 문서 데이터를 Dart 객체로 변환
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      gender: map['gender'] ?? '여성', // Firestore에 값이 없으면 기본값 적용
      preferredStyle: map['preferredStyle'] ?? '미니멀 / 스마트 캐주얼',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : null,
    );
  }

  // Dart 객체를 Firestore에 저장할 Map 형태로 변환
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'gender': gender, // Firestore에 성별 저장
      'preferredStyle': preferredStyle,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }
}