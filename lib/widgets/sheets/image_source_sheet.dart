import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';

class ImageSourceSheet extends StatelessWidget {
  final Function(ImageSource source) onSourceSelected;

  const ImageSourceSheet({
    super.key,
    required this.onSourceSelected,
  });

  static void show({
    required BuildContext context,
    required Function(ImageSource source) onSourceSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ImageSourceSheet(
        onSourceSelected: onSourceSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppColors.primary),
            title: const Text('카메라로 촬영하기'),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.primary),
            title: const Text('갤러리에서 가져오기'),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }
}
