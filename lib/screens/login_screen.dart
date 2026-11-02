import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_colors.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_login_row.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🌐 웹 소셜 로그인 계정 입력 다이얼로그 (실제 유저 계정명 지정)
  Future<String?> _showSocialWebLoginDialog({
    required String providerName,
    required Color color,
    required String defaultSuffix,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: color == const Color(0xFFFEE500) ? Colors.black87 : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text('$providerName 계정 로그인'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '웹 환경에서 사용할 $providerName 아이디 또는 이메일을 입력해 주세요.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '$providerName 아이디/이메일',
                hintText: '예: sumin$defaultSuffix',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                Navigator.pop(context, input);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: color == const Color(0xFFFEE500) ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('로그인', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 이메일/아이디 로그인 처리
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userEmail = userCredential?.user?.email ?? _emailController.text.trim();
      await AuthService.saveLoggedInUserEmail(userEmail);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(userEmail: userEmail),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '로그인에 실패했습니다.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = '아이디(이메일) 또는 비밀번호가 올바르지 않습니다.';
      } else if (e.code == 'invalid-email') {
        message = '올바른 형식의 아이디나 이메일이 아닙니다.';
      } else if (e.code == 'user-disabled') {
        message = '비활성화된 계정입니다.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 네이버 로그인 핸들러 메서드
  Future<void> _handleNaverLogin() async {
    String? inputEmail;
    if (kIsWeb) {
      inputEmail = await _showSocialWebLoginDialog(
        providerName: '네이버',
        color: const Color(0xFF03C75A),
        defaultSuffix: '@naver.com',
      );
      if (inputEmail == null || inputEmail.isEmpty) return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithNaver(customEmail: inputEmail);

      if (user != null) {
        final userEmail = (inputEmail != null && inputEmail.isNotEmpty)
            ? (inputEmail.contains('@') ? inputEmail : '$inputEmail@naver.com')
            : (user.email ?? 'naver_user@naver.com');

        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);

        await AuthService.saveLoggedInUserEmail(userEmail);

        if (!mounted) return;

        messenger.showSnackBar(
          SnackBar(
            content: Text('✨ 네이버 계정($userEmail)으로 로그인되었습니다!'),
            backgroundColor: const Color(0xFF03C75A),
            duration: const Duration(seconds: 2),
          ),
        );

        nav.pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(userEmail: userEmail),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('네이버 로그인 오류: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 구글 로그인 핸들러 메서드
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();

      if (user != null && mounted) {
        final userEmail = (user.email != null && user.email!.isNotEmpty)
            ? user.email!
            : '${user.uid}@google.com';

        await AuthService.saveLoggedInUserEmail(userEmail);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ 구글 계정으로 로그인되었습니다!'),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigationScreen(userEmail: userEmail),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = '구글 로그인 오류: $e';
        final errStr = e.toString();

        if (errStr.contains('unauthorized-domain')) {
          msg = 'Firebase 도메인 설정 필요: Firebase 콘솔 > Authentication > Settings > 승인된 도메인에 sumin-coder.github.io 를 등록해 주세요.';
        } else if (errStr.contains('permission-denied')) {
          msg = 'Firebase DB 보안 규칙 설정 필요: Firestore Database > Rules 탭에서 allow read, write: if true; 를 설정해 주세요.';
        } else if (errStr.contains('popup-blocked') || errStr.contains('popup_blocked')) {
          msg = '브라우저 팝업이 차단되었습니다. 주소창 우측에서 팝업 허용을 설정하고 다시 시도해 주세요.';
        } else if (errStr.contains('operation-not-allowed')) {
          msg = 'Firebase 콘솔 > Authentication > Sign-in method 에서 구글(Google) 제공업체를 활성화해 주세요.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 카카오 로그인 핸들러 메서드
  Future<void> _handleKakaoLogin() async {
    String? inputEmail;
    if (kIsWeb) {
      inputEmail = await _showSocialWebLoginDialog(
        providerName: '카카오',
        color: const Color(0xFFFEE500),
        defaultSuffix: '@kakao.com',
      );
      if (inputEmail == null || inputEmail.isEmpty) return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithKakao(customEmail: inputEmail);

      if (user != null) {
        final userEmail = (inputEmail != null && inputEmail.isNotEmpty)
            ? (inputEmail.contains('@') ? inputEmail : '$inputEmail@kakao.com')
            : (user.email ?? 'kakao_user@kakao.com');

        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);

        await AuthService.saveLoggedInUserEmail(userEmail);

        if (!mounted) return;

        messenger.showSnackBar(
          SnackBar(
            content: Text('✨ 카카오 계정($userEmail)으로 로그인되었습니다!'),
            backgroundColor: const Color(0xFFFFE800),
            duration: const Duration(seconds: 2),
          ),
        );

        nav.pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(userEmail: userEmail),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오 로그인 오류: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/logo/app_logo.png',
                    height: 100,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.checkroom,
                      size: 80,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Style Pulse',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '나만의 스마트한 모바일 옷장',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),
                  CustomTextField(
                    controller: _emailController,
                    labelText: '이메일 또는 아이디',
                    hintText: '이메일 또는 아이디를 입력해 주세요.',
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이메일 또는 아이디를 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _passwordController,
                    labelText: '비밀번호',
                    hintText: '비밀번호를 입력해 주세요.',
                    prefixIcon: Icons.lock_outline,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '비밀번호를 입력해 주세요.';
                      }
                      if (value.length < 6) {
                        return '비밀번호는 6자리 이상이어야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              '로그인',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '계정이 없으신가요?',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          '간편로그인',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SocialLoginRow(
                    onNaverPressed: _handleNaverLogin,
                    onKakaoPressed: _handleKakaoLogin,
                    onGooglePressed: _handleGoogleLogin,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
