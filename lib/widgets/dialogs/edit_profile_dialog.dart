import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';

class EditProfileDialog extends StatefulWidget {
  final String userEmail;
  final String currentName;
  final ValueChanged<String> onNameUpdated;

  const EditProfileDialog({
    super.key,
    required this.userEmail,
    required this.currentName,
    required this.onNameUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    required String userEmail,
    required String currentName,
    required ValueChanged<String> onNameUpdated,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EditProfileDialog(
        userEmail: userEmail,
        currentName: currentName,
        onNameUpdated: onNameUpdated,
      ),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('프로필 수정'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이메일: ${widget.userEmail}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '이름(닉네임)',
              hintText: '이름을 입력해 주세요',
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
          onPressed: () async {
            final newName = _nameController.text.trim();
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);

            if (newName.isNotEmpty) {
              widget.onNameUpdated(newName);

              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                try {
                  await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
                    'name': newName,
                    'email': widget.userEmail,
                  }, SetOptions(merge: true));
                } catch (_) {}
              }
            }

            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('프로필 정보가 변경되었습니다.'),
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
