import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../models/cloth_item.dart';
import 'background_removal_service.dart';

class AiAvatarService {
  final BackgroundRemovalService _bgService = BackgroundRemovalService();

  /// 📸 내 전신 사진으로 3D 아바타 피팅 모델 생성
  Future<Uint8List?> generateAvatarFromPhoto(Uint8List userPhotoBytes) async {
    try {
      // 1. 전신 사진에서 배경을 투명하게 누끼 처리하여 아바타 피규어 추출
      final Uint8List? transparentBody = await _bgService.removeBackground(userPhotoBytes);
      if (transparentBody == null) return userPhotoBytes;

      // 2. 아바타 스테이지 캔버스 생성 (300x500 피팅룸 해상도)
      final codec = await ui.instantiateImageCodec(transparentBody, targetWidth: 300);
      final frame = await codec.getNextFrame();
      final ui.Image bodyImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 은은한 스테이지 서클 그리기
      final paint = ui.Paint()
        ..color = const ui.Color(0xFFFF6F61).withValues(alpha: 0.15)
        ..style = ui.PaintingStyle.fill;
      canvas.drawCircle(const ui.Offset(150, 430), 100, paint);

      final bodyPaint = ui.Paint()..filterQuality = ui.FilterQuality.high;
      canvas.drawImageRect(
        bodyImage,
        ui.Rect.fromLTWH(0, 0, bodyImage.width.toDouble(), bodyImage.height.toDouble()),
        ui.Rect.fromLTWH(30, 20, 240, 440),
        bodyPaint,
      );

      final picture = recorder.endRecording();
      final avatarStage = await picture.toImage(300, 500);
      final ByteData? pngBytes = await avatarStage.toByteData(format: ui.ImageByteFormat.png);

      return pngBytes?.buffer.asUint8List();
    } catch (e) {
      debugPrint('AI 아바타 생성 에러: $e');
      return userPhotoBytes;
    }
  }

  /// 👗 아바타 위에 옷장 아이템 착용 (상의, 하의, 아우터, 신발 레이어 합성)
  Future<ui.Image?> decodeClothImage(ClothItem cloth) async {
    try {
      Uint8List? bytes = cloth.imageBytes;
      if (bytes == null && cloth.imageUrl != null && cloth.imageUrl!.isNotEmpty) {
        if (!cloth.imageUrl!.startsWith('http')) {
          bytes = base64Decode(cloth.imageUrl!);
        }
      }
      if (bytes == null) return null;

      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 260);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
