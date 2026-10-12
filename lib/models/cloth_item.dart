import 'dart:typed_data';

class ClothItem {
  final String id;
  final String title;
  final String category;
  final String color;
  final String? imageUrl;       // 이미지 주소 (Base64 또는 HTTP URL)
  final Uint8List? imageBytes;  // 로컬 임시 표시용
  bool isFavorite;              // 💡 즐겨찾기(찜) 상태 여부

  ClothItem({
    required this.id,
    required this.title,
    required this.category,
    required this.color,
    this.imageUrl,
    this.imageBytes,
    this.isFavorite = false,
  });

  // Firestore에 저장할 맵(Map) 데이터로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'color': color,
      'imageUrl': imageUrl ?? '',
      'isFavorite': isFavorite,
    };
  }

  // Firestore에서 가져온 데이터로 ClothItem 객체 생성
  factory ClothItem.fromMap(Map<String, dynamic> map) {
    return ClothItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? '상의',
      color: map['color'] ?? '기타',
      imageUrl: map['imageUrl'],
      isFavorite: map['isFavorite'] ?? false,
    );
  }
}