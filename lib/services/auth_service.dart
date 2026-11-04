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

  /// 🌐 [핵심] 웹 환경 리다이렉트 콜백 처리 및 세션 복원
  static Future<String?> getSavedLoggedInUserEmail() async {
    try {
      if (kIsWeb) {
        final uri = Uri.base;
        final isOAuthCallback =
            uri.queryParameters.containsKey('code') ||
            uri.queryParameters.containsKey('error');
        if (uri.queryParameters.containsKey('code')) {
          final code = uri.queryParameters['code']!;
          final state = uri.queryParameters['state'] ?? '';

          String userEmail = '';
          String userName = '';

          // 1. 카카오 웹 로그인 콜백 처리
          if (state.contains('kakao') || uri.toString().contains('kakao')) {
            try {
              const kakaoClientId = '97b4011bc63ddb77be006cdd8eae6814';
              // 현재 웹 페이지 주소 (Redirect URI)
              final redirectUri = '${uri.origin}${uri.path}';

              // 인가 코드로 Access Token 요청
              final tokenRes = await http.post(
                Uri.parse('https://kauth.kakao.com/oauth/token'),
                headers: {
                  'Content-Type':
                      'application/x-www-form-urlencoded;charset=utf-8',
                },
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
                  // 토큰으로 실제 카카오 회원 프로필 조회
                  final userRes = await http.get(
                    Uri.parse('https://kapi.kakao.com/v2/user/me'),
                    headers: {'Authorization': 'Bearer $accessToken'},
                  );

                  if (userRes.statusCode == 200) {
                    final userData = jsonDecode(userRes.body);
                    final kakaoAccount = userData['kakao_account'];
                    userEmail =
                        kakaoAccount?['email'] ??
                        'kakao_${userData['id']}@kakao.com';
                    userName =
                        userData['properties']?['nickname'] ??
                        kakaoAccount?['profile']?['nickname'] ??
                        '카카오회원';
                  }
                }
              }
            } catch (e) {
              debugPrint('카카오 웹 토큰 교환 오류: $e');
            }
          }
          // 2. 네이버 웹 로그인 콜백 처리
          else if (state.contains('naver') ||
              uri.toString().contains('naver')) {
            try {
              const naverClientId = 'BzaebjNVvZntEFUervTF';
              // 주의: 네이버는 웹에서 클라이언트 시크릿(Client Secret)이 노출될 수 있으므로,
              // 정석은 백엔드 서버를 거쳐야 하지만, 프론트에서 단독 처리 시 클라이언트 시크릿이 필요할 수 있습니다.
              // 아래는 인가 코드를 받아 프로필을 조회하는 흐름입니다.
              final tokenRes = await http.get(
                Uri.parse(
                  'https://nid.naver.com/oauth2.0/token?grant_type=authorization_code&client_id=$naverClientId&code=$code&state=$state',
                ),
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
                    userEmail =
                        response?['email'] ??
                        'naver_${response?['id']}@naver.com';
                    userName =
                        response?['name'] ?? response?['nickname'] ?? '네이버회원';
                  }
                }
              }
            } catch (e) {
              debugPrint('네이버 웹 토큰 교환 오류: $e');
            }
          }

          // 💾 실제 사용자 정보가 확인되면 Firestore 및 세션 저장
          if (userEmail.isNotEmpty) {
            try {
              final uid = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
              final userDocRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid);
              await userDocRef.set({
                'uid': uid,
                'email': userEmail,
                'name': userName.isNotEmpty
                    ? userName
                    : userEmail.split('@').first,
                'gender': '선택안함',
              }, SetOptions(merge: true));

              await saveLoggedInUserEmail(userEmail);

              if (FirebaseAuth.instance.currentUser == null) {
                await FirebaseAuth.instance.signInAnonymously();
              }
            } catch (e) {
              debugPrint('웹 소셜 로그인 Firestore 저장 오류: $e');
            }
            return userEmail;
          }
        }

        // OAuth 콜백이 실패한 경우 이전 세션으로 로그인된 것처럼 처리하지 않습니다.
        if (isOAuthCallback) return null;
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

  // 💛 카카오 소셜 로그인 (웹: 공식 인증 페이지 이동 / 모바일: SDK 연동)
  Future<User?> signInWithKakao() async {
    try {
      if (kIsWeb) {
        const kakaoClientId = '97b4011bc63ddb77be006cdd8eae6814';
        final redirectUri = Uri.encodeComponent(
          '${Uri.base.origin}${Uri.base.path}',
        );
        // state에 kakao_auth 명시하여 리다이렉트 시 카카오 로그인임을 판별
        final authUrl =
            'https://kauth.kakao.com/oauth/authorize?response_type=code&client_id=$kakaoClientId&redirect_uri=$redirectUri&state=kakao_auth';

        await launchUrl(
          Uri.parse(authUrl),
          webOnlyWindowName: '_self', // 현재 창에서 카카오 로그인 페이지로 이동
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
        final redirectUri = Uri.encodeComponent(
          '${Uri.base.origin}${Uri.base.path}',
        );
        // state에 naver_auth 명시하여 리다이렉트 시 네이버 로그인임을 판별
        final authUrl =
            'https://nid.naver.com/oauth2.0/authorize?response_type=code&client_id=$naverClientId&redirect_uri=$redirectUri&state=naver_auth';

        await launchUrl(
          Uri.parse(authUrl),
          webOnlyWindowName: '_self', // 현재 창에서 네이버 로그인 페이지로 이동
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
