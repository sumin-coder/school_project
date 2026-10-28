import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_login_row.dart';
import '../main.dart';
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

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

      // 로그인된 사용자의 이메일 가져오기 (없으면 입력값 사용)
      final userEmail = userCredential?.user?.email ?? _emailController.text.trim();

      if (mounted) {
        // 💡 수정됨: MainNavigationScreen에 userEmail 전달
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
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithNaver();

      if (user != null && mounted) {
        final userEmail = user.email ?? 'naver_user';
        Navigator.pushReplacement(
          context,
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
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithKakao();

      if (user != null && mounted) {
        final userEmail = user.email ?? 'kakao_user';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(userEmail: userEmail),
          ),
        );
      } else {
        if (mounted && !kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카카오 로그인 결과가 없습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/logo/app_logo.png', width: 65, height: 65,),
                  const SizedBox(height: 12),
                  const Text(
                    'Style Pulse',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '나만의 스마트한 모바일 옷장',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 36),

                  // 이메일 또는 아이디 입력 필드
                  CustomTextField(
                    controller: _emailController,
                    labelText: '이메일 또는 아이디',
                    hintText: '아이디 또는 이메일을 입력해 주세요',
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '아이디 또는 이메일을 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력 필드
                  CustomTextField(
                    controller: _passwordController,
                    labelText: '비밀번호',
                    hintText: '비밀번호를 입력해 주세요',
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
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해 주세요.';
                      }
                      if (value.length < 6) {
                        return '비밀번호는 6자리 이상이어야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // 로그인 버튼
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      '로그인',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 회원가입 페이지 이동 영역
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '계정이 없으신가요?',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 간편로그인 구분선
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '간편로그인',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 원형 간편 소셜 로그인 행 위젯 배치
                  SocialLoginRow(
                    onNaverPressed: _handleNaverLogin,
                    onKakaoPressed: _handleKakaoLogin,
                    onGooglePressed: _handleGoogleLogin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}