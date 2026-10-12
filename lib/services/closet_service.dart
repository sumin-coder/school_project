import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cloth_item.dart';

class ClosetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. 특정 사용자의 이메일 문서 하위에서 옷 목록 조회
  Stream<List<ClothItem>> getClothesStream(String userEmail) {
    return _firestore
        .collection('clothes')
        .doc(userEmail)
        .collection('user_items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ClothItem.fromMap(doc.data())).toList();
    });
  }

  // 2. 옷 데이터 저장 (중간 테이블 느낌 없이 이메일 문서 바로 아래에 아이템 문서로 저장)
  Future<void> addClothItem({
    required String userEmail,
    required ClothItem item,
    required Uint8List imageBytes,
  }) async {
    String base64Image = base64Encode(imageBytes);

    ClothItem finalItem = ClothItem(
      id: item.id, // 고유 ID 유지
      title: item.title,
      category: item.category,
      color: item.color,
      imageUrl: base64Image,
      isFavorite: item.isFavorite,
    );

    Map<String, dynamic> itemData = finalItem.toMap();
    itemData['userEmail'] = userEmail;
    itemData['createdAt'] = FieldValue.serverTimestamp();

    // clothes -> 유저이메일 -> user_items -> 고유ID 문서 형식으로 저장
    await _firestore
        .collection('clothes')
        .doc(userEmail)
        .collection('user_items')
        .doc(item.id)
        .set(itemData);
  }

  // 3. 옷 즐겨찾기(찜) 상태 토글
  Future<void> toggleFavorite({
    required String userEmail,
    required String clothId,
    required bool isFavorite,
  }) async {
    await _firestore
        .collection('clothes')
        .doc(userEmail)
        .collection('user_items')
        .doc(clothId)
        .update({'isFavorite': isFavorite});
  }

  // 4. 옷 삭제
  Future<void> deleteClothItem({
    required String userEmail,
    required String clothId,
  }) async {
    await _firestore
        .collection('clothes')
        .doc(userEmail)
        .collection('user_items')
        .doc(clothId)
        .delete();
  }
}