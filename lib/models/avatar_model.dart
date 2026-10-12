import 'dart:typed_data';

class AvatarModel {
  final String id;
  final String? userPhotoBase64;
  final Uint8List? avatarImageBytes;
  final double height;
  final double weight;
  final String bodyType; // 'Standard', 'Slim', 'Athletic', 'Curvy'

  AvatarModel({
    required this.id,
    this.userPhotoBase64,
    this.avatarImageBytes,
    this.height = 175.0,
    this.weight = 68.0,
    this.bodyType = 'Standard',
  });
}
