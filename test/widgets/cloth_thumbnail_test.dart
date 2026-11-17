import 'package:flutter_test/flutter_test.dart';
import 'package:style_pulse/widgets/cloth_thumbnail.dart';

void main() {
  group('ClothThumbnail.decodeBase64', () {
    test('reuses decoded image bytes from the shared cache', () {
      const encoded =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/G6kAAAAASUVORK5CYII=';

      final first = ClothThumbnail.decodeBase64(encoded);
      final second = ClothThumbnail.decodeBase64(encoded);

      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
    });

    test('returns null for invalid base64 data', () {
      expect(ClothThumbnail.decodeBase64('not base64!'), isNull);
    });
  });

}
