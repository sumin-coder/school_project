import 'package:flutter/material.dart';
import '../../models/cloth_item.dart';
import '../../services/closet_service.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  final String userEmail;
  final ClothItem item;

  const ConfirmDeleteDialog({
    super.key,
    required this.userEmail,
    required this.item,
  });

  static Future<void> show({
    required BuildContext context,
    required String userEmail,
    required ClothItem item,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        userEmail: userEmail,
        item: item,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClosetService closetService = ClosetService();

    return AlertDialog(
      title: const Text('옷 삭제'),
      content: Text('\'${item.title}\' 항목을 옷장에서 삭제하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () async {
            await closetService.deleteClothItem(
              userEmail: userEmail,
              clothId: item.id,
            );
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('삭제'),
        ),
      ],
    );
  }
}
