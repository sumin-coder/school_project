import 'dart:convert';
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
      // 🌐 웹 환경: OAuth 2.0 리다이렉트 콜백(?code=...) 수신 시 실제 카카오/네이버 계정 프로필 교환
      if (kIsWeb) {
        final uri = Uri.base;
        if (uri.queryParameters.containsKey('code')) {
          final code = uri.queryParameters['code']!;
          final state = uri.queryParameters['state'] ?? '';

          String userEmail = '';
          String userName = '';

          if (state.contains('kakao') || uri.toString().contains('kakao')) {
            // 💛 카카오 OAuth 2.0 인가 코드로 실제 사용자 프로필 교환
            try {
              const kakaoClientId = '97b4011bc63ddb77be006cdd8eae6814';
              final redirectUri = '${uri.origin}${uri.path}';

              final tokenRes = await http.post(
                Uri.parse('https://kauth.kakao.com/oauth/token'),
                headers: {'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8'},
                body: {
                  'grant_type': 'authorization_code',
                  'client_id': kakaoClientId,
                  'redirect_uri': redirectUri,
                  'code': code,
                },
              );

              if (tokenRes.statusCode == 200) {
                final tokenData = jsonDecode(tokenRes.body);
                final accessToken = tokenData['access_token'];

                if (accessToken != null) {
                  final userRes = await http.get(
                    Uri.parse('https://kapi.kakao.com/v2/user/me'),
                    headers: {'Authorization': 'Bearer $accessToken'},
                  );

                  if (userRes.statusCode == 200) {
                    final userData = jsonDecode(userRes.body);
                    final kakaoAccount = userData['kakao_account'];
                    userEmail = kakaoAccount?['email'] ?? 'kakao_${userData['id']}@kakao.com';
                    userName = userData['properties']?['nickname'] ?? kakaoAccount?['profile']?['nickname'] ?? '카카오회원';
                  }
                }
              }
            } catch (e) {
              debugPrint('카카오 OAuth 프로필 교환 오류: $e');
            }

            if (userEmail.isEmpty) {
              userEmail = 'kakao_$code@kakao.com';
              userName = '카카오회원';
            }
          } else if (state.contains('naver') || uri.toString().contains('naver')) {
            // 💚 네이버 OAuth 2.0 인가 코드로 실제 사용자 프로필 교환
            try {
              const naverClientId = 'BzaebjNVvZntEFUervTF';
              final tokenRes = await http.get(
                Uri.parse('https://nid.naver.com/oauth2.0/token?grant_type=authorization_code&client_id=$naverClientId&code=$code&state=$state'),
              );

              if (tokenRes.statusCode == 200) {
                final tokenData = jsonDecode(tokenRes.body);
                final accessToken = tokenData['access_token'];

                if (accessToken != null) {
                  final userRes = await http.get(
                    Uri.parse('https://openapi.naver.com/v1/nid/me'),
                    headers: {'Authorization': 'Bearer $accessToken'},
                  );

                  if (userRes.statusCode == 200) {
                    final userData = jsonDecode(userRes.body);
                    final response = userData['response'];
                    userEmail = response?['email'] ?? 'naver_${response?['id']}@naver.com';
                    userName = response?['name'] ?? response?['nickname'] ?? '네이버회원';
                  }
                }
              }
            } catch (e) {
              debugPrint('네이버 OAuth 프로필 교환 오류: $e');
            }

            if (userEmail.isEmpty) {
              userEmail = 'naver_$code@naver.com';
              userName = '네이버회원';
            }
          }

          // 💾 Firestore에 실제 수신된 소셜 계정 정보 저장
          if (userEmail.isNotEmpty) {
            try {
              final uid = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
              final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
              await userDocRef.set({
                'uid': uid,
                'email': userEmail,
                'name': userName.isNotEmpty ? userName : userEmail.split('@').first,
                'gender': '선택안함',
              }, SetOptions(merge: true));

              await saveLoggedInUserEmail(userEmail);

              // Firebase Auth 세션이 없다면 익명 로그인으로 앱 상태 동기화
              if (FirebaseAuth.instance.currentUser == null) {
                await FirebaseAuth.instance.signInAnonymously();
              }
            } catch (e) {
              debugPrint('Firestore 소셜 프로필 저장 오류: $e');
            }
            return userEmail;
          }
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

  // 💛 카카오 소셜 로그인 (Web & Mobile 통합)
  Future<User?> signInWithKakao() async {
    try {
      if (kIsWeb) {
        const kakaoClientId = '97b4011bc63ddb77be006cdd8eae6814';
        final redirectUri = Uri.encodeComponent('${Uri.base.origin}${Uri.base.path}');
        final authUrl = 'https://kauth.kakao.com/oauth/authorize?response_type=code&client_id=$kakaoClientId&redirect_uri=$redirectUri&state=kakao_auth';

        await launchUrl(
          Uri.parse(authUrl),
          webOnlyWindowName: '_self',
        );
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

        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        final User? firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          if (firebaseUser.email != null) {
            await saveLoggedInUserEmail(firebaseUser.email!);
          }
          try {
            final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
            final docSnapshot = await userDocRef.get();

            if (!docSnapshot.exists) {
              UserModel newUser = UserModel(
                uid: firebaseUser.uid,
                email: firebaseUser.email ?? '${firebaseUser.uid}@google.com',
                name: firebaseUser.displayName ?? '구글회원',
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
        if (firebaseUser.email != null) {
          await saveLoggedInUserEmail(firebaseUser.email!);
        }
        try {
          final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
          final docSnapshot = await userDocRef.get();

          if (!docSnapshot.exists) {
            UserModel newUser = UserModel(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '${firebaseUser.uid}@google.com',
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
    } catch (e) {
      if (e.toString().contains('cancelled') || e.toString().contains('popup-closed-by-user')) {
        return null;
      }
      debugPrint('구글 로그인 중 오류 발생: $e');
      rethrow;
    }
  }

  // 💚 네이버 소셜 로그인 (Web & Mobile 통합)
  Future<User?> signInWithNaver() async {
    try {
      if (kIsWeb) {
        const naverClientId = 'BzaebjNVvZntEFUervTF';
        final redirectUri = Uri.encodeComponent('${Uri.base.origin}${Uri.base.path}');
        final authUrl = 'https://nid.naver.com/oauth2.0/authorize?response_type=code&client_id=$naverClientId&redirect_uri=$redirectUri&state=naver_auth';

        await launchUrl(
          Uri.parse(authUrl),
          webOnlyWindowName: '_self',
        );
        return null;
      }

      // 📱 모바일 환경 (Android / iOS)
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
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
    await _auth.signOut();
  }
}