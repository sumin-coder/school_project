import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/background_removal_service.dart';

class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ApiKeyDialog(),
    );
  }

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: BackgroundRemovalService.apiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('배경 제거 (remove.bg) API 키'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'remove.bg API 키를 등록하면 옷 추가 시 배경을 자동으로 제거(누끼 따기)해 드립니다.\n(remove.bg에서 무료 발급 가능)',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'remove.bg API 키 입력',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            BackgroundRemovalService.apiKey = _controller.text.trim();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('배경 제거 API 키가 저장되었습니다.'),
                backgroundColor: AppColors.primary,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
