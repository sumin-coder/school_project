import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';

class ImageSourceSheet extends StatelessWidget {
  final Function(ImageSource source) onSourceSelected;
  final VoidCallback onApiKeySelected;

  const ImageSourceSheet({
    super.key,
    required this.onSourceSelected,
    required this.onApiKeySelected,
  });

  static void show({
    required BuildContext context,
    required Function(ImageSource source) onSourceSelected,
    required VoidCallback onApiKeySelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ImageSourceSheet(
        onSourceSelected: onSourceSelected,
        onApiKeySelected: onApiKeySelected,
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.auto_fix_high, color: AppColors.primary),
            title: const Text('배경 제거 (remove.bg) API 키 설정'),
            onTap: () {
              Navigator.pop(context);
              onApiKeySelected();
            },
          ),
        ],
      ),
    );
  }
}
