import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  String _selectedGender = '여성';
  bool _isLoading = false;

  // 🔍 아이디 중복확인 상태 관련 변수
  bool _isIdChecked = false;
  bool _isCheckingId = false;
  bool _isIdAvailable = false;
  String _checkedId = '';
  String? _idCheckMessage;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_onIdChanged);
  }

  void _onIdChanged() {
    if (_idController.text.trim() != _checkedId && _isIdChecked) {
      setState(() {
        _isIdChecked = false;
        _isIdAvailable = false;
        _idCheckMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _idController.removeListener(_onIdChanged);
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🔍 아이디 중복확인 처리 함수
  Future<void> _checkDuplicateId() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('중복확인할 아이디를 입력해 주세요.')),
      );
      return;
    }

    if (id.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디에 @ 문자는 포함할 수 없습니다.')),
      );
      return;
    }

    if (id.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디는 4자리 이상이어야 합니다.')),
      );
      return;
    }

    setState(() => _isCheckingId = true);

    try {
      final isAvailable = await _authService.checkIdAvailability(id);
      if (!mounted) return;

      setState(() {
        _isCheckingId = false;
        _isIdChecked = true;
        _checkedId = id;
        _isIdAvailable = isAvailable;
        _idCheckMessage = isAvailable ? '✅ 사용 가능한 아이디입니다.' : '❌ 이미 사용 중인 아이디입니다.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_idCheckMessage!),
          backgroundColor: isAvailable ? AppColors.primary : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingId = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('중복확인 중 오류 발생: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isIdChecked || _idController.text.trim() != _checkedId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디 중복확인을 먼저 진행해 주세요!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (!_isIdAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 사용 중인 아이디입니다. 다른 아이디를 입력해 주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUpWithEmail(
        email: _idController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        gender: _selectedGender,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다! 로그인해 주세요.'),
            backgroundColor: AppColors.primary,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '회원가입에 실패했습니다.';
      if (e.code == 'email-already-in-use' || e.code == 'invalid-email') {
        message = '이미 사용 중인 아이디이거나 잘못된 형식입니다.';
      } else if (e.code == 'weak-password') {
        message = '비밀번호가 너무 취약합니다.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Style Pulse 계정 만들기',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '옷장 데이터와 AI 추천 기능을 위한 정보를 입력해주세요.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 28),

                // 🔍 아이디 입력 필드 + 중복확인 버튼
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _idController,
                        labelText: '아이디',
                        hintText: '영문, 숫자 조합 4자리 이상',
                        prefixIcon: Icons.account_circle_outlined,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return '아이디를 입력해 주세요.';
                          }
                          if (val.contains('@')) {
                            return '아이디에 @ 문자는 포함할 수 없습니다.';
                          }
                          if (val.length < 4) {
                            return '아이디는 4자리 이상이어야 합니다.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isCheckingId ? null : _checkDuplicateId,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isCheckingId
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('중복확인', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                if (_idCheckMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _idCheckMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isIdAvailable ? Colors.green : Colors.red,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _nameController,
                  labelText: '이름',
                  hintText: '홍길동',
                  prefixIcon: Icons.person_outline,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? '이름을 입력해 주세요.' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  labelText: '이메일 (선택 또는 알림용)',
                  hintText: 'example@email.com',
                  prefixIcon: Icons.email_outlined,
                  validator: (val) {
                    if (val != null && val.isNotEmpty && !val.contains('@')) {
                      return '올바른 이메일 형식이 아닙니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  labelText: '비밀번호',
                  hintText: '6자리 이상 입력',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return '비밀번호를 입력해 주세요.';
                    if (val.length < 6) return '비밀번호는 6자리 이상이어야 합니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _confirmPasswordController,
                  labelText: '비밀번호 확인',
                  hintText: '비밀번호를 다시 입력해 주세요',
                  prefixIcon: Icons.lock_reset,
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return '비밀번호 확인을 입력해 주세요.';
                    if (val != _passwordController.text) {
                      return '비밀번호가 일치하지 않습니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  '성별',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(value: '여성', label: Text('여성')),
                      ButtonSegment<String>(value: '남성', label: Text('남성')),
                    ],
                    selected: {_selectedGender},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedGender = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary;
                        }
                        return Colors.grey.shade100;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.black87;
                      }),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
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
                          '가입하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
