import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _sessionKey = 'style_pulse_logged_in_email';

  // 현재 사용자 Get
  User? get currentUser => _auth.currentUser;

  // 🔒 로그인 세션 영구 보관 (SharedPreferences)
  static Future<void> saveLoggedInUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, email.trim());
    } catch (e) {
      debugPrint('세션 저장 실패: $e');
    }
  }

  static Future<String?> getSavedLoggedInUserEmail() async {
    try {
      // 🌐 웹 환경: OAuth 2.0 리다이렉트 콜백(?code=...) 파라미터 체크
      if (kIsWeb) {
        final uri = Uri.base;
        if (uri.queryParameters.containsKey('code')) {
          final code = uri.queryParameters['code']!;
          final state = uri.queryParameters['state'] ?? '';

          String userEmail = 'social_user@stylepulse.com';
          if (state.contains('naver') || uri.toString().contains('naver')) {
            userEmail = 'naver_$code@naver.com';
          } else {
            userEmail = 'kakao_$code@kakao.com';
          }

          await saveLoggedInUserEmail(userEmail);
          return userEmail;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(_sessionKey);
      if (savedEmail != null && savedEmail.isNotEmpty) {
        return savedEmail;
      }

      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        return (fbUser.email != null && fbUser.email!.isNotEmpty)
            ? fbUser.email!
            : '${fbUser.uid}@stylepulse.com';
      }
    } catch (e) {
      debugPrint('세션 읽기 실패: $e');
    }
    return null;
  }

  static Future<void> clearSavedLoggedInUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('세션 삭제 실패: $e');
    }
  }

  /// 🔍 아이디 중복 확인 (Firestore users 컬렉션에서 해당 아이디 존재 여부 확인)
  Future<bool> checkIdAvailability(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return false;

    String formattedEmail = cleanId;
    if (!formattedEmail.contains('@')) {
      formattedEmail = '$formattedEmail@stylepulse.com';
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: formattedEmail)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty; // empty면 사용 가능 (true)
    } catch (e) {
      debugPrint('아이디 중복 확인 오류: $e');
      return true;
    }
  }

  // 이메일 또는 아이디로 로그인
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    String identifier = email.trim();

    if (!identifier.contains('@')) {
      identifier = '$identifier@stylepulse.com';
    }

    return await _auth.signInWithEmailAndPassword(
      email: identifier,
      password: password,
    );
  }

  // 이메일 또는 아이디로 회원가입 및 Firestore 사용자 생성
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String gender,
  }) async {
    String identifier = email.trim();

    if (!identifier.contains('@')) {
      identifier = '$identifier@stylepulse.com';
    }

    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: identifier,
      password: password,
    );

    if (credential.user != null) {
      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        email: identifier,
        name: name,
        gender: gender,
      );

      try {
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(newUser.toMap());
      } catch (e) {
        debugPrint('Firestore 유저 생성 예외: $e');
      }
    }

    return credential;
  }

  // 💛 카카오 실제 소셜 로그인 (구글처럼 독립 팝업창 _blank 실행)
  Future<User?> signInWithKakao() async {
    try {
      if (kIsWeb) {
        // 🌐 웹 환경: 구글처럼 카카오 공식 계정 선택/로그인 독립 크롬 팝업창 열기
        const kakaoClientId = 'b881d4cf44b318b10abb56ab639f234c';
        final redirectUri = Uri.encodeComponent('${Uri.base.origin}${Uri.base.path}');
        final authUrl = 'https://kauth.kakao.com/oauth/authorize?response_type=code&client_id=$kakaoClientId&redirect_uri=$redirectUri&state=kakao_auth';

        await launchUrl(
          Uri.parse(authUrl),
          webOnlyWindowName: '_blank', // 💡 구글처럼 독립 팝업창으로 실행
        );
        return null;
      }

      // 📱 모바일 환경 (Android / iOS)
      kakao.OAuthToken token;
      bool isInstalled = await kakao.isKakaoTalkInstalled();
      if (isInstalled) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          debugPrint('카카오톡으로 로그인 실패: $error');
          if (error.toString().contains('CANCELED')) return null;
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      debugPrint('카카오 토큰 발급 성공: ${token.accessToken}');

      kakao.User kakaoUser = await kakao.UserApi.instance.me();
      String kakaoEmail = kakaoUser.kakaoAccount?.email ?? '${kakaoUser.id}@kakao.com';
      String kakaoNickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오회원';

      String dummyUid = 'kakao_${kakaoUser.id}';

      try {
        final userDocRef = _firestore.collection('users').doc(dummyUid);
        final docSnapshot = await userDocRef.get();

        if (!docSnapshot.exists) {
          UserModel newUser = UserModel(
            uid: dummyUid,
            email: kakaoEmail,
            name: kakaoNickname,
            gender: '선택안함',
          );

          await userDocRef.set(newUser.toMap());
        }
      } catch (e) {
        debugPrint('Firestore 카카오 유저 연동 예외: $e');
      }

      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        UserCredential userCredential = await _auth.signInAnonymously();
        firebaseUser = userCredential.user;
      }

      return firebaseUser;
    } catch (e) {
      debugPrint('카카오 로그인 예외: $e');
      rethrow;
    }
  }

  // 🌐 구글 로그인 메서드 (Web: signInWithPopup, Mobile: GoogleSignIn)
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // 🌐 웹 환경: Firebase Auth 팝업 로그인
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        final User? firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          try {
            final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
            final docSnapshot = await userDocRef.get();

            if (!docSnapshot.exists) {
              UserModel newUser = UserModel(
                uid: firebaseUser.uid,
                email: (firebaseUser.email != null && firebaseUser.email!.isNotEmpty)
                    ? firebaseUser.email!
                    : '${firebaseUser.uid}@google.com',
                name: firebaseUser.displayName ?? '구글회원',
                gender: '선택안함',
              );

              await userDocRef.set(newUser.toMap());
            }
          } catch (e) {
            debugPrint('Firestore 구글 유저 정보 연동 예외 (보안규칙 등): $e');
          }
        }

        return firebaseUser;
      }

      // 📱 모바일 환경
      try {
        await GoogleSignIn.instance.initialize();
      } catch (e) {
        debugPrint('GoogleSignIn 이미 초기화됨: $e');
      }

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('구글 인증 토큰이 존재하지 않습니다.');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        try {
          final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
          final docSnapshot = await userDocRef.get();

          if (!docSnapshot.exists) {
            UserModel newUser = UserModel(
              uid: firebaseUser.uid,
              email: (firebaseUser.email != null && firebaseUser.email!.isNotEmpty)
                  ? firebaseUser.email!
                  : '${firebaseUser.uid}@google.com',
              name: firebaseUser.displayName ?? '구글회원',
              gender: '선택안함',
            );

            await userDocRef.set(newUser.toMap());
          }
        } catch (e) {
          debugPrint('Firestore 모바일 구글 유저 연동 예외: $e');
        }
      }

      return firebaseUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled' || e.code == 'user-cancelled') {
        debugPrint('사용자가 구글 로그인 팝업을 닫았습니다.');
        return null;
      }
      debugPrint('Firebase 구글 로그인 오류 (${e.code}): ${e.message}');
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('사용자가 구글 로그인을 취소했습니다.');
        return null;
      }
      debugPrint('구글 로그인 오류 (GoogleSignInException): $e');
      rethrow;
    } catch (e) {
      if (e.toString().contains('cancelled') || e.toString().contains('popup-closed-by-user')) {
        return null;
      }
      debugPrint('구글 로그인 중 오류 발생: $e');
      rethrow;
    }
  }

  // 💚 네이버 실제 소셜 로그인 (구글처럼 독립 팝업창 _blank 실행)
  Future<User?> signInWithNaver() async {
    try {
      if (kIsWeb) {
        // 🌐 웹 환경: 구글처럼 네이버 공식 계정 선택/로그인 독립 크롬 팝업창 열기
        const naverClientId = 'C2_yT0r_6G';
        final redirectUri = Uri.encodeComponent('${Uri.base.origin}${Uri.base.path}');
        final authUrl = 'https://nid.naver.com/oauth2.0/authorize?response_type=code&client_id=$naverClientId&redirect_uri=$redirectUri&state=naver_auth';

        await launchUrl(
          Uri.parse(authUrl),
          webOnlyWindowName: '_blank', // 💡 구글처럼 독립 팝업창으로 실행
        );
        return null;
      }

      // 📱 모바일 환경
      final NaverLoginResult res = await FlutterNaverLogin.logIn();

      if (res.status == NaverLoginStatus.loggedIn) {
        final account = res.account;
        String naverId = account?.id ?? '';
        String naverEmail = account?.email ?? '$naverId@naver.com';
        String naverName = account?.name ?? account?.nickname ?? '네이버회원';
        String naverGender = account?.gender ?? '선택안함';

        String dummyUid = 'naver_$naverId';

        try {
          final userDocRef = _firestore.collection('users').doc(dummyUid);
          final docSnapshot = await userDocRef.get();

          if (!docSnapshot.exists) {
            UserModel newUser = UserModel(
              uid: dummyUid,
              email: naverEmail,
              name: naverName,
              gender: naverGender,
            );

            await userDocRef.set(newUser.toMap());
          }
        } catch (e) {
          debugPrint('Firestore 네이버 유저 연동 예외: $e');
        }

        User? firebaseUser = _auth.currentUser;
        if (firebaseUser == null) {
          UserCredential userCredential = await _auth.signInAnonymously();
          firebaseUser = userCredential.user;
        }

        return firebaseUser;
      } else {
        debugPrint('네이버 로그인 실패 상태: ${res.status}');
        return null;
      }
    } catch (e) {
      debugPrint('네이버 로그인 예외: $e');
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await clearSavedLoggedInUserEmail();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
