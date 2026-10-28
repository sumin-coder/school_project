import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_colors.dart';
import '../main.dart';
import '../models/cloth_item.dart';
import '../widgets/dialogs/edit_profile_dialog.dart';
import '../widgets/profile/profile_user_card.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userEmail;
  final List<ClothItem> clothes;

  const ProfileScreen({
    super.key,
    required this.userEmail,
    this.clothes = const [],
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _userName;
  late String _userEmail;
  final String _preferredStyle = '미니멀 / 스마트 캐주얼';

  bool _dailyRecommendNotification = true;
  bool _weatherLocationSync = true;

  final List<String> _styleTags = ['#미니멀', '#깔끔함', '#톤온톤', '#스마트캐주얼'];

  @override
  void initState() {
    super.initState();
    _userEmail = widget.userEmail;

    if (_userEmail.contains('@')) {
      _userName = _userEmail.split('@').first;
    } else {
      _userName = '회원';
    }

    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userName = currentUser.displayName!;
        });
      }
    }

    try {
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (doc.exists && doc.data()?['name'] != null && doc.data()!['name'].toString().isNotEmpty) {
          if (mounted) {
            setState(() {
              _userName = doc.data()!['name'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('프로필 정보 불러오기 에러: $e');
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 💡 실시간 등록된 옷 카테고리별 정밀 통계 계산
    final totalCount = widget.clothes.length;
    final topsCount = widget.clothes.where((c) => c.category == '상의').length;
    final bottomsCount = widget.clothes.where((c) => c.category == '하의').length;
    final outersCount = widget.clothes.where((c) => c.category == '아우터').length;
    final shoesCount = widget.clothes.where((c) => c.category == '신발/잡화').length;
    final favoriteCount = widget.clothes.where((c) => c.isFavorite).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필 & 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '프로필 수정',
            onPressed: () => EditProfileDialog.show(
              context: context,
              userEmail: _userEmail,
              currentName: _userName,
              onNameUpdated: (newName) {
                setState(() {
                  _userName = newName;
                });
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileUserCard(
              userName: _userName,
              userEmail: _userEmail,
              preferredStyle: _preferredStyle,
            ),
            const SizedBox(height: 20),
            const Text(
              '내 옷장 통계',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // 📊 1행 통계: 전체 옷, 상의, 하의
            Row(
              children: [
                StatCard(
                  title: '전체 옷',
                  count: '$totalCount개',
                  icon: Icons.checkroom,
                ),
                const SizedBox(width: 10),
                StatCard(
                  title: '상의',
                  count: '$topsCount개',
                  icon: Icons.dry_cleaning,
                ),
                const SizedBox(width: 10),
                StatCard(
                  title: '하의',
                  count: '$bottomsCount개',
                  icon: Icons.straighten,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 📊 2행 통계: 아우터, 신발/잡화, 찜한 옷
            Row(
              children: [
                StatCard(
                  title: '아우터',
                  count: '$outersCount개',
                  icon: Icons.layers,
                ),
                const SizedBox(width: 10),
                StatCard(
                  title: '신발/잡화',
                  count: '$shoesCount개',
                  icon: Icons.downhill_skiing,
                ),
                const SizedBox(width: 10),
                StatCard(
                  title: '찜한 옷',
                  count: '$favoriteCount개',
                  icon: Icons.favorite,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '선호하는 스타일 태그',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styleTags.map((tag) {
                return Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              '서비스 설정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    secondary: const Icon(Icons.notifications_active, color: AppColors.primary),
                    title: const Text('매일 아침 AI 코디 알림'),
                    subtitle: const Text('오전 8시 오늘의 날씨 맞춤 코디를 알려드립니다.'),
                    value: _dailyRecommendNotification,
                    onChanged: (val) {
                      setState(() {
                        _dailyRecommendNotification = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    secondary: const Icon(Icons.location_on, color: AppColors.primary),
                    title: const Text('위치 기반 날씨 자동 연동'),
                    subtitle: const Text('현재 위치의 일교차와 날씨 정보를 반영합니다.'),
                    value: _weatherLocationSync,
                    onChanged: (val) {
                      setState(() {
                        _weatherLocationSync = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    secondary: const Icon(Icons.dark_mode, color: AppColors.primary),
                    title: const Text('다크 모드'),
                    subtitle: const Text('어두운 테마로 화면을 전환합니다.'),
                    value: isDarkMode,
                    onChanged: (val) {
                      setState(() {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '앱 정보 및 계정 관리',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.grey),
                    title: Text('버전 정보'),
                    trailing: Text('v1.0.0', style: TextStyle(color: Colors.grey)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Colors.grey),
                    title: const Text('도움말 및 문의하기'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.primary),
                    title: const Text(
                      '로그아웃',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
