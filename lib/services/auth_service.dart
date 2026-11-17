import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'oauth_navigation_stub.dart'
    if (dart.library.html) 'oauth_navigation_web.dart'
    as oauth_navigation;

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _sessionKey = 'style_pulse_logged_in_email';
  static const String _explicitLogoutKey = 'style_pulse_explicitly_logged_out';
  static const String _oauthErrorKey = 'style_pulse_oauth_error';
  static const String _kakaoOAuthStateKey = 'style_pulse_kakao_oauth_state';
  static const String _naverOAuthStateKey = 'style_pulse_naver_oauth_state';
  static const String _oauthBaseUrl = String.fromEnvironment(
    'STYLE_PULSE_OAUTH_URL',
  );

  // 현재 사용자 Get
  User? get currentUser => _auth.currentUser;

  // 🔒 로그인 세션 영구 보관 (SharedPreferences)
  static Future<void> saveLoggedInUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, email.trim());
      await prefs.remove(_explicitLogoutKey);
    } catch (e) {
      debugPrint('세션 저장 실패: $e');
    }
  }

  static Future<String?> consumeOAuthError() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final message = prefs.getString(_oauthErrorKey);
      await prefs.remove(_oauthErrorKey);
      return message;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveOAuthError(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_oauthErrorKey, message);
    } catch (e) {
      debugPrint('OAuth error could not be saved: $e');
    }
  }

  /// 🌐 [핵심] 웹 환경 리다이렉트 콜백 처리 및 세션 복원
  static Future<String?> getSavedLoggedInUserEmail() async {
    try {
      if (kIsWeb) {
        final uri = Uri.base;
        final state = uri.queryParameters['state'] ?? '';
        final isKakao = state.startsWith('kakao_');
        final isNaver = state.startsWith('naver_');
        final isOAuthCallback =
            uri.queryParameters.containsKey('code') ||
            uri.queryParameters.containsKey('error');

        if (uri.queryParameters.containsKey('error')) {
          final prefs = await SharedPreferences.getInstance();
          if (isKakao) await prefs.remove(_kakaoOAuthStateKey);
          if (isNaver) await prefs.remove(_naverOAuthStateKey);
          await _saveOAuthError('소셜 로그인이 취소되었거나 실패했습니다. 다시 시도해 주세요.');
          return null;
        }

        if (uri.queryParameters.containsKey('code')) {
          final prefs = await SharedPreferences.getInstance();
          final expectedState = isKakao
              ? prefs.getString(_kakaoOAuthStateKey)
              : isNaver
              ? prefs.getString(_naverOAuthStateKey)
              : null;
          if (expectedState == null || expectedState != state) {
            await _saveOAuthError('로그인 요청이 만료되었습니다. 다시 시도해 주세요.');
            return null;
          }

          if (!isKakao && !isNaver) {
            await _saveOAuthError('지원하지 않는 소셜 로그인 응답입니다.');
            return null;
          }
          await prefs.remove(isKakao ? _kakaoOAuthStateKey : _naverOAuthStateKey);

          final provider = isKakao ? 'kakao' : 'naver';
          Map<String, dynamic> profile = {};
          if (isKakao && _oauthBaseUrl.isEmpty) {
            await _saveOAuthError('카카오 프로필 서버가 설정되지 않았습니다.');
            return null;
          }
          if (isKakao) {
            late final http.Response response;
            try {
              response = await http.post(
                Uri.parse('$_oauthBaseUrl/kakaoOAuth'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'code': uri.queryParameters['code'],
                  'state': state,
                  'redirectUri': '${uri.origin}${uri.path}',
                }),
              );
            } catch (e) {
              debugPrint('Kakao profile request failed: $e');
              await _saveOAuthError('카카오 프로필 서버에 연결할 수 없습니다.');
              return null;
            }
            if (response.statusCode != 200) {
              debugPrint('Kakao profile request failed: ${response.statusCode}');
              await _saveOAuthError('카카오 계정 정보를 가져오지 못했습니다. 카카오 설정을 확인해 주세요.');
              return null;
            }
            profile = jsonDecode(response.body) as Map<String, dynamic>;
            if (profile['id'] == null) {
              await _saveOAuthError('카카오 계정 정보를 확인할 수 없습니다.');
              return null;
            }
          }
          final firebaseUser =
              FirebaseAuth.instance.currentUser ??
              (await FirebaseAuth.instance.signInAnonymously()).user;
          if (firebaseUser == null) {
            await _saveOAuthError('익명 로그인을 완료하지 못했습니다. 다시 시도해 주세요.');
            return null;
          }

          final providerId = profile['id']?.toString() ?? firebaseUser.uid;
          final userEmail = profile['email']?.toString().trim().isNotEmpty == true
              ? profile['email'].toString().trim()
              : '${provider}_$providerId@stylepulse.com';
          final userName = profile['name']?.toString().trim().isNotEmpty == true
              ? profile['name'].toString().trim()
              : (isKakao ? '카카오 사용자' : '네이버 사용자');
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'))
                .set({
                  'uid': firebaseUser.uid,
                  'email': userEmail,
                  'name': userName,
                  'gender': '선택안함',
                  'provider': provider,
                  'providerId': providerId,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Firestore anonymous profile save failed: $e');
          }

          await saveLoggedInUserEmail(userEmail);
          await launchUrl(
            Uri.parse('${uri.origin}${uri.path}'),
            webOnlyWindowName: '_self',
          );
          return userEmail;
        }

        if (isOAuthCallback) return null;
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_explicitLogoutKey) == true) return null;
      final savedEmail = prefs.getString(_sessionKey);
      if (savedEmail != null && savedEmail.isNotEmpty) return savedEmail;

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        return firebaseUser.email?.isNotEmpty == true
            ? firebaseUser.email!
            : '${firebaseUser.uid}@stylepulse.com';
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }
    return null;
  }

  static Future<void> clearSavedLoggedInUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_explicitLogoutKey, true);
      await prefs.remove(_sessionKey);
      await prefs.remove(_kakaoOAuthStateKey);
      await prefs.remove(_naverOAuthStateKey);
    } catch (e) {
      debugPrint('세션 삭제 실패: $e');
    }
  }

  /// 🔍 아이디 중복 확인
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

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('아이디 중복 확인 오류: $e');
      return true;
    }
  }

  // 이메일 로그인
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    String identifier = email.trim();
    if (!identifier.contains('@')) {
      identifier = '$identifier@stylepulse.com';
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: identifier,
      password: password,
    );
    await saveLoggedInUserEmail(identifier);
    return credential;
  }

  // 이메일 회원가입
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
      await saveLoggedInUserEmail(identifier);
    }

    return credential;
  }

  // 💛 카카오 소셜 로그인 (웹: 공식 인증 페이지 이동 / 모바일: SDK 연동)
  Future<User?> signInWithKakao() async {
    try {
      if (kIsWeb) {
        const kakaoClientId = 'b27cbbdaa02e789fe460b63bfd7796ec';
        final prefs = await SharedPreferences.getInstance();
        final randomBytes = List<int>.generate(
          32,
          (_) => Random.secure().nextInt(256),
        );
        final state =
            'kakao_${base64UrlEncode(randomBytes).replaceAll('=', '')}';
        await prefs.setString(_kakaoOAuthStateKey, state);
        final redirectUri = '${Uri.base.origin}${Uri.base.path}';
        final authUri = Uri.https('kauth.kakao.com', '/oauth/authorize', {
          'response_type': 'code',
          'client_id': kakaoClientId,
          'redirect_uri': redirectUri,
          'state': state,
          'scope': 'account_email,profile_nickname',
        });
        oauth_navigation.navigate(authUri.toString());
        return null;
      }

      // 📱 모바일 환경 (Android / iOS)
      bool isInstalled = await kakao.isKakaoTalkInstalled();
      if (isInstalled) {
        try {
          await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          debugPrint('카카오톡으로 로그인 실패: $error');
          if (error.toString().contains('CANCELED')) return null;
          await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      kakao.User kakaoUser = await kakao.UserApi.instance.me();
      String kakaoEmail =
          kakaoUser.kakaoAccount?.email ?? '${kakaoUser.id}@kakao.com';
      String kakaoNickname =
          kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오회원';
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

      await saveLoggedInUserEmail(kakaoEmail);

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

  // 🌐 구글 로그인 메서드
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final UserCredential userCredential = await _auth.signInWithPopup(
          googleProvider,
        );
        final User? firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          final userEmail =
              (firebaseUser.email != null && firebaseUser.email!.isNotEmpty)
              ? firebaseUser.email!
              : '${firebaseUser.uid}@google.com';

          await saveLoggedInUserEmail(userEmail);

          try {
            final userDocRef = _firestore
                .collection('users')
                .doc(firebaseUser.uid);
            final docSnapshot = await userDocRef.get();

            if (!docSnapshot.exists) {
              UserModel newUser = UserModel(
                uid: firebaseUser.uid,
                email: userEmail,
                name: firebaseUser.displayName ?? userEmail.split('@').first,
                gender: '선택안함',
              );
              await userDocRef.set(newUser.toMap());
            }
          } catch (e) {
            debugPrint('Firestore 구글 유저 정보 연동 예외: $e');
          }
        }
        return firebaseUser;
      }

      try {
        await GoogleSignIn.instance.initialize();
      } catch (e) {
        debugPrint('GoogleSignIn 이미 초기화됨: $e');
      }

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('구글 인증 토큰이 존재하지 않습니다.');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final userEmail =
            (firebaseUser.email != null && firebaseUser.email!.isNotEmpty)
            ? firebaseUser.email!
            : '${firebaseUser.uid}@google.com';

        await saveLoggedInUserEmail(userEmail);

        try {
          final userDocRef = _firestore
              .collection('users')
              .doc(firebaseUser.uid);
          final docSnapshot = await userDocRef.get();

          if (!docSnapshot.exists) {
            UserModel newUser = UserModel(
              uid: firebaseUser.uid,
              email: userEmail,
              name: firebaseUser.displayName ?? userEmail.split('@').first,
              gender: '선택안함',
            );
            await userDocRef.set(newUser.toMap());
          }
        } catch (e) {
          debugPrint('Firestore 모바일 구글 유저 연동 예외: $e');
        }
      }

      return firebaseUser;
    } catch (e) {
      if (e.toString().contains('cancelled') ||
          e.toString().contains('popup-closed-by-user')) {
        return null;
      }
      debugPrint('구글 로그인 중 오류 발생: $e');
      rethrow;
    }
  }

  // 💚 네이버 소셜 로그인 (웹: 공식 인증 페이지 이동 / 모바일: SDK 연동)
  Future<User?> signInWithNaver() async {
    try {
      if (kIsWeb) {
        const naverClientId = 'BzaebjNVvZntEFUervTF';
        final prefs = await SharedPreferences.getInstance();
        final random = Random.secure();
        final randomBytes = List<int>.generate(32, (_) => random.nextInt(256));
        final state =
            'naver_${base64UrlEncode(randomBytes).replaceAll('=', '')}';
        await prefs.setString(_naverOAuthStateKey, state);

        final redirectUri = '${Uri.base.origin}${Uri.base.path}';
        final authUri = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
          'response_type': 'code',
          'client_id': naverClientId,
          'redirect_uri': redirectUri,
          'state': state,
        });

        oauth_navigation.navigate(authUri.toString());
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

        await saveLoggedInUserEmail(naverEmail);

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
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      try {
        await FlutterNaverLogin.logOut();
      } catch (_) {}
    }
    try {
      await _auth.signOut().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Firebase sign-out failed: $e');
    }
  }
}
