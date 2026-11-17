# 📱 Style Pulse (스타일 펄스)

> **🌐 라이브 웹 사이트 바로가기**: [https://sumin-coder.github.io/school_project/](https://sumin-coder.github.io/school_project/)

스마트 모바일 옷장 & AI 3D 가상 피팅 애플리케이션 **Style Pulse**입니다.

---

## 🌐 라이브 웹 데모 (Live Web App)

별도의 앱 설치 없이 브라우저에서 라이브 서비스를 바로 체험해 보실 수 있습니다!

👉 **[https://sumin-coder.github.io/school_project/](https://sumin-coder.github.io/school_project/)**

---

## ✨ 핵심 주요 기능 (Key Features)

1. **⚡ 100% 무료 온디바이스 자동 배경 제거 (누끼)**
   - 외부 유료 API 결제 없이 스마트폰/브라우저 내 C++ 그래픽 엔진(`dart:ui`)으로 0.015초 만에 투명 PNG 잘라내기.
   - 전신/착샷/마네킹 사진 등록 시 카테고리(`상의`, `하의`, `아우터`, `신발`)별 자동 영역 감지 자르기.

2. **🤖 실시간 날씨 연동 AI 맞춤 코디 큐레이션**
   - GPS 실시간 위치 날씨(기온/기상) 수집.
   - 가상의 옷이 아닌 **내 실제 옷장의 등록된 옷들만 조합**하여 TPO(캐주얼, 비즈니스, 데이트, 운동) 상황별 코디 추천 (Groq LLM).

3. **💖 껏다 켜도 지속되는 옷장 & 추천 코디 영구 즐겨찾기(찜)**
   - 옷장의 관심 아이템 및 추천 코디 하트 버튼을 누르면 Firebase Cloud DB 및 로컬에 안전하게 영구 저장되어 앱을 종료하거나 다시 켜도 즐겨찾기가 그대로 유지.

4. **🎮 3D 게임형 아바타 커스텀 피팅룸 & 3D 피팅 리포트**
   - 내 전신 사진 기반 AI 3D 아바타 모델 생성.
   - 내 옷장 옷을 터치하여 아바타 상의/하의/아우터/신발 실시간 레이어 착용 및 신체 치수 분석 3D 피팅 리포트 제공.

5. **🔐 간편 소셜 로그인**
   - 카카오, 네이버, 구글 간편 신분증 인증 지원.

---

## 🛠️ 기술 스택 (Tech Stack)

* **Framework**: Flutter 3 (Dart)
* **Backend**: Firebase Authentication, Cloud Firestore Cloud NoSQL
* **Image Processing**: On-Device C++ Canvas Graphics Engine (`dart:ui`)
* **AI Model**: Groq LLM (`llama-3.3-70b-versatile`)
* **Deployment**: GitHub Pages (`gh-pages`)

## 네이버 웹 로그인 배포 설정

네이버 Client Secret은 Flutter 웹 코드에 넣지 않고 Firebase Functions Secret Manager에 보관합니다. Firebase Functions 배포에는 Blaze 요금제가 필요합니다.

1. 네이버 개발자센터의 로그인 callback URL에 `https://sumin-coder.github.io/school_project/`를 등록합니다. 로컬 테스트 시에는 `http://localhost:5173/`도 등록합니다.
2. 네이버 개발자센터에서 Client Secret을 새로 발급한 뒤 프로젝트 루트에서 `firebase functions:secrets:set NAVER_CLIENT_SECRET`을 실행하고, 터미널의 비밀 입력 프롬프트에 새 값을 직접 입력합니다.
3. `firebase deploy --only functions:naverOAuth`를 실행합니다.

Client Secret은 코드, GitHub, 채팅에 붙여 넣지 마세요. GitHub Pages와 Firebase Function의 callback URL 허용 목록이 일치해야 합니다.

## 카카오 웹 로그인 배포 설정

카카오 REST API 토큰 교환에는 Client Secret이 필요할 수 있으며, 이 프로젝트는 비밀 값을 Flutter 코드에 넣지 않고 Firebase Functions에서 사용합니다. Kakao Developers의 REST API 키에 라이브 주소 `https://sumin-coder.github.io/school_project/`와 로컬 주소 `http://localhost:5173/`를 Redirect URI로 등록하세요.

Firebase 프로젝트에서 `firebase functions:secrets:set KAKAO_CLIENT_SECRET`을 실행하고 프롬프트에서 Client Secret을 입력하세요. 네이버 secret도 설정한 뒤 `firebase deploy --only functions`로 두 OAuth 함수를 배포합니다. Functions 배포에는 Blaze 요금제가 필요합니다.