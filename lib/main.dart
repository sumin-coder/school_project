import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

import 'constants/app_colors.dart';
import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'models/cloth_item.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/closet_screen.dart';
import 'screens/recommend_screen.dart';
import 'screens/profile_screen.dart';
import 'services/closet_service.dart';
import 'services/auth_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  KakaoSdk.init(
    nativeAppKey: 'b881d4cf44b318b10abb56ab639f234c',
    javaScriptAppKey: 'b27cbbdaa02e789fe460b63bfd7796ec',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Style Pulse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          // 🔒 웹 새로고침 시에도 로그인 세션 100% 영구 보존
          home: FutureBuilder<String?>(
            future: AuthService.getSavedLoggedInUserEmail(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final savedEmail = snapshot.data;
              if (savedEmail != null && savedEmail.isNotEmpty) {
                return MainNavigationScreen(userEmail: savedEmail);
              }

              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final String userEmail;

  const MainNavigationScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final ClosetService _closetService = ClosetService();

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClothItem>>(
      stream: _closetService.getClothesStream(widget.userEmail),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final List<ClothItem> currentClothes = snapshot.data ?? [];

        final List<Widget> screens = [
          HomeScreen(onTabChange: _onTabChange, recentItems: currentClothes),
          ClosetScreen(userEmail: widget.userEmail),
          RecommendScreen(clothes: currentClothes),
          ProfileScreen(userEmail: widget.userEmail, clothes: currentClothes),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabChange,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppColors.primary),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.checkroom_outlined),
                selectedIcon: Icon(Icons.checkroom, color: AppColors.primary),
                label: '옷장',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome, color: AppColors.primary),
                label: '추천',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: AppColors.primary),
                label: '프로필',
              ),
            ],
          ),
        );
      },
    );
  }
}
