import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 사용자 Get
  User? get currentUser => _auth.currentUser;

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

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(newUser.toMap());
    }

    return credential;
  }

  // 카카오 로그인 메서드 (웹 / 모바일 분기 처리)
  Future<User?> signInWithKakao() async {
    try {
      kakao.OAuthToken token;

      if (kIsWeb) {
        try {
          await kakao.AuthCodeClient.instance.authorize(
            redirectUri: 'http://localhost:3000',
          );
          return null;
        } catch (e) {
          debugPrint('웹 인가 코드 요청 중 예외: $e');
        }
      }

      if (!kIsWeb) {
        bool isInstalled = await kakao.isKakaoTalkInstalled();
        if (isInstalled) {
          try {
            token = await kakao.UserApi.instance.loginWithKakaoTalk();
          } catch (error) {
            debugPrint('카카오톡으로 로그인 실패: $error');

            if (error.toString().contains('CANCELED')) {
              return null;
            }

            try {
              token = await kakao.UserApi.instance.loginWithKakaoAccount();
            } catch (accountError) {
              debugPrint('카카오계정으로 로그인 실패: $accountError');
              return null;
            }
          }
        } else {
          try {
            token = await kakao.UserApi.instance.loginWithKakaoAccount();
          } catch (accountError) {
            debugPrint('카카오계정으로 로그인 실패: $accountError');
            return null;
          }
        }

        debugPrint('카카오 토큰 발급 성공: ${token.accessToken}');
      }

      kakao.User kakaoUser = await kakao.UserApi.instance.me();
      String kakaoEmail = kakaoUser.kakaoAccount?.email ?? '${kakaoUser.id}@kakao.com';
      String kakaoNickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오회원';

      String dummyUid = 'kakao_${kakaoUser.id}';

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

      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        UserCredential userCredential = await _auth.signInAnonymously();
        firebaseUser = userCredential.user;
      }

      return firebaseUser;
    } catch (e) {
      if (e.toString().contains("authentication token doesn't exist") ||
          e.toString().contains('CANCELED')) {
        debugPrint('사용자가 카카오 로그인을 취소했거나 인증 토큰이 존재하지 않습니다.');
      } else {
        debugPrint('카카오 로그인 중 오류 발생: $e');
      }
      return null;
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

  // 네이버 로그인 메서드
  Future<User?> signInWithNaver() async {
    if (kIsWeb) {
      debugPrint('네이버 로그인은 현재 모바일 전용 기능입니다.');
      return null;
    }
    try {
      final NaverLoginResult res = await FlutterNaverLogin.logIn();

      if (res.status == NaverLoginStatus.loggedIn) {
        final account = res.account;
        String naverId = account?.id ?? '';
        String naverEmail = account?.email ?? '$naverId@naver.com';
        String naverName = account?.name ?? account?.nickname ?? '네이버회원';
        String naverGender = account?.gender ?? '선택안함';

        String dummyUid = 'naver_$naverId';

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

        User? firebaseUser = _auth.currentUser;
        if (firebaseUser == null) {
          UserCredential userCredential = await _auth.signInAnonymously();
          firebaseUser = userCredential.user;
        }

        return firebaseUser;
      } else {
        debugPrint('네이버 로그인 실패 상태: ${res.status}, 에러: ${res.errorMessage}');
        return null;
      }
    } catch (e) {
      debugPrint('네이버 로그인 중 오류 발생: $e');
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
