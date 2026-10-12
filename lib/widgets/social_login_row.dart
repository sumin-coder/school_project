import 'package:flutter/material.dart';

class SocialLoginRow extends StatelessWidget {
  final VoidCallback onNaverPressed;
  final VoidCallback onKakaoPressed;
  final VoidCallback onGooglePressed;

  const SocialLoginRow({
    super.key,
    required this.onNaverPressed,
    required this.onKakaoPressed,
    required this.onGooglePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. 네이버 로그인 버튼
        _buildSocialButton(
          backgroundColor: const Color(0xFF03C75A), // 네이버 녹색
          icon: Image.asset(
            'assets/logo/naver_logo.png',
            fit: BoxFit.contain,
          ),
          onPressed: onNaverPressed,
        ),
        // const SizedBox(width: 16),

        // 2. 카카오 로그인 버튼
        _buildSocialButton(
          backgroundColor: const Color(0xFFFEE500), // 카카오 노란색
          icon: Image.asset(
            'assets/logo/kakao_logo.png',
            fit: BoxFit.contain,
          ),
          onPressed: onKakaoPressed,
        ),
        // const SizedBox(width: 16),

        // 3. 구글 로그인 버튼 (흰색 배경에 테두리)
        _buildSocialButton(
          backgroundColor: Colors.white,
          borderColor: Colors.grey.shade300,
          icon: Image.asset(
            'assets/logo/google_logo.png',
            fit: BoxFit.contain,
          ),
          onPressed: onGooglePressed,
        ),
      ],
    );
  }

  // 동그란 버튼 공통 헬퍼 위젯
  Widget _buildSocialButton({
    required Color backgroundColor,
    required Widget icon,
    required VoidCallback onPressed,
    Color? borderColor,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 34, // 💡 아이콘 크기를 24에서 34로 키워주었습니다.
            height: 34,
            child: icon,
          ),
        ),
      ),
    );
  }
}