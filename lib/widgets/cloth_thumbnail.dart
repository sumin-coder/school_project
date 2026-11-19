import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/cloth_item.dart';

class ClothThumbnail extends StatelessWidget {
  final ClothItem item;
  final double size;

  // ⚡ 속도 최적화: Base64 이미지 디코딩 결과 메모리 캐싱 (매 프레임 재디코딩 방지)
  static final _base64Cache = <String, Uint8List>{};
  static const int _maxCacheBytes = 32 * 1024 * 1024;
  static int _cachedBytes = 0;

  const ClothThumbnail({
    super.key,
    required this.item,
    this.size = 40,
  });

  static Uint8List? _getDecodedBytes(String base64Str) {
    final cached = _base64Cache.remove(base64Str);
    if (cached != null) {
      _base64Cache[base64Str] = cached;
      return cached;
    }
    try {
      final decoded = base64Decode(base64Str);
      if (decoded.lengthInBytes > _maxCacheBytes) return decoded;
      while (_cachedBytes + decoded.lengthInBytes > _maxCacheBytes) {
        final oldestKey = _base64Cache.keys.first;
        _cachedBytes -= _base64Cache.remove(oldestKey)!.lengthInBytes;
      }
      _base64Cache[base64Str] = decoded;
      _cachedBytes += decoded.lengthInBytes;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? decodeBase64(String base64Str) => _getDecodedBytes(base64Str);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = item.imageUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.checkroom,
              size: size * 0.8,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        );
      } else {
        final bytes = _getDecodedBytes(imageUrl);
        if (bytes != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.checkroom,
                size: size * 0.8,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          );
        }
      }
    } else if (item.imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          item.imageBytes!,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }

    return Icon(
      Icons.checkroom,
      size: size * 0.8,
      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
    );
  }
}
