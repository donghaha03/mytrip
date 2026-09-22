# 여행 장부앱 (Flutter + Firebase)

Figma `환율 여행 장부앱 - PBL1` 을 옮긴 Flutter 앱.
로그인은 Firebase Auth, 데이터는 Firestore, 배포는 GitHub Pages.

- **배포 주소**: `https://<계정>.github.io/<repo>/` — `main` 에 합쳐지면 1~2분 뒤 자동 반영
- **팀 작업 규칙**: [CONTRIBUTING.md](CONTRIBUTING.md) — 누가 어떤 파일을 맡는지

## 두 가지 모드

`lib/firebase_options.dart` 가 채워져 있는지에 따라 알아서 바뀐다.
(참고한 [naite-reservation](https://github.com/gnu-naite/naite-reservation) 의
`store.js` 가 Firestore ↔ 임시 저장을 자동 전환하는 것과 같은 방식)

| | 로컬 임시 모드 | Firebase 모드 |
|---|---|---|
| 언제 | `firebase_options.dart` 가 비어 있을 때 (**지금 상태**) | 키가 채워져 있을 때 |
| 로그인 | 아무 이메일 + 6자 이상 비밀번호 | Firebase Auth 이메일/비밀번호 |
| 데이터 | 메모리. 새로고침하면 목업 3건으로 초기화 | Firestore. 기기 간 실시간 동기화 |
| 표시 | 로그인 화면에 파란 "로컬 임시 모드" 안내 | 안내 없음 |

조원은 Firebase 키 없이 로컬 모드로 바로 작업하면 된다.

## 실행

```powershell
. C:\Users\dongb\dev\flutter-env.ps1   # 이 PC 기준. flutter 가 PATH 에 있으면 생략
flutter pub get
flutter run -d chrome
```

## 처음 한 번: Firebase 연결 (팀장)

### 1. Firebase 프로젝트

1. [Firebase 콘솔](https://console.firebase.google.com) → **프로젝트 추가** (이름 예: `tripapp`)
2. 왼쪽 **빌드 → Authentication → 시작하기 → 로그인 방법 → 이메일/비밀번호 → 사용 설정**
3. **빌드 → Firestore Database → 데이터베이스 만들기**
   - 위치: `asia-northeast3 (서울)`
   - **프로덕션 모드**로 시작
4. Firestore **규칙** 탭에 repo 의 [`firestore.rules`](firestore.rules) 내용을 붙여 넣고 **게시**

### 2. 앱에 키 넣기

```powershell
npm install -g firebase-tools        # 없으면
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=<firebase 프로젝트 id> --platforms=web,android,ios
```

`lib/firebase_options.dart` 가 덮어써진다. 다시 `flutter run` 하면 로그인 화면의
파란 안내가 사라지고 Firebase 모드로 뜬다.

> CLI 가 번거로우면: 콘솔 **프로젝트 설정 → 내 앱 → 웹 앱 추가** 에서 나오는
> `firebaseConfig` 값을 `firebase_options.dart` 의 `web:` 칸에 직접 옮겨 적어도 된다.

웹 API 키는 비밀번호가 아니라서 공개 repo 에 커밋해도 된다 (Firebase 공식 입장).
**대신 1-4 의 보안 규칙은 반드시** — 테스트 모드로 두면 누구나 전체 DB 를 읽고 쓴다.

### 3. GitHub Pages 도메인 허용 (안 하면 배포 사이트에서 로그인이 막힌다)

**Authentication → 설정 → 승인된 도메인 → 도메인 추가** → `<계정>.github.io`

## 처음 한 번: GitHub 에 올리기 (팀장)

1. github.com 에서 새 repo — **README·.gitignore·license 모두 체크 해제**
2. 올리기:

   ```powershell
   git remote add origin https://github.com/<계정>/<repo>.git
   git push -u origin main feat/login feat/more
   ```

   `feat/login`, `feat/more` 는 조원 작업용으로 미리 만들어 둔 브랜치다.
3. repo **Settings → Pages → Source: GitHub Actions**
4. repo **Settings → Collaborators** 에서 조원 초대
5. (권장) **Settings → Branches → main 보호 규칙**: PR 필수 + `CI` 통과 필수

Actions 탭에서 "Deploy to GitHub Pages" 가 초록불이 되면
`https://<계정>.github.io/<repo>/` 에서 열린다.

## 화면 구성

| 파일 | 번호 | 설명 | 담당 |
|---|---|---|---|
| `screens/login_screen.dart` | 10 | 로그인 / 회원가입 | **로그인 담당** |
| `screens/empty_home_screen.dart` | 00 | 여행이 없을 때의 첫 화면 | |
| `screens/trip_list_screen.dart` | 01 | 내 여행 목록 (길게 눌러 편집) | |
| `screens/add_trip_screen.dart` | 02 | 새 여행 추가 | |
| `screens/trip_main_screen.dart` | 03 | 여행 메인 (예산 요약) | |
| `widgets/sheets.dart` | 04~06 | 국가 더보기 / 기간 선택 / 이름 편집 시트 | |
| `widgets/rate_info_tooltip.dart` | 07 | 환율 갱신 안내 툴팁 | |
| `screens/more_screen.dart` | 09 | 더보기 — **구현 전** | **더보기 담당** |
| `screens/ledger_entry.dart` | 08 | 장부 연결 지점 (메뉴만, 페이지는 범위 밖) | — |

## 구조

```
lib/
  main.dart                  AuthGate: 로그인 여부로 화면 전환
  firebase_options.dart      Firebase 키 (비어 있으면 로컬 모드)
  services/
    backend.dart             로컬 / Firebase 모드 판정
    auth_service.dart        로그인 (로컬·Firebase 구현이 같은 인터페이스)
    session.dart             로그인 사용자 -> 그 사람의 Firestore 경로 연결
  data/
    trip_store.dart          화면이 보는 여행 목록 (ChangeNotifier)
    trip_repository.dart     Firestore 읽기/쓰기
  models/ screens/ widgets/ theme/
firestore.rules              Firestore 보안 규칙
.github/workflows/
  ci.yml                     PR 마다 analyze + test + 웹 빌드
  pages.yml                  main 에 합쳐지면 GitHub Pages 배포
```

Firestore 저장 구조:

```
users/{uid}/trips/{tripId}                  이름, 통화코드, 기간, 예산
users/{uid}/trips/{tripId}/records/{id}     지출 한 건 (date 는 시분초 포함 Timestamp)
```

## 테스트

```powershell
flutter analyze
flutter test
```

Firebase 경로 테스트(`test/firebase_test.dart`)는 가짜 Firestore/Auth 로 돌아서
키도 네트워크도 필요 없다.

## 다음 단계

1. **환율** — `models/country.dart` 의 `krwPerUnit` 이 하드코딩. 환율 API 를 붙이고
   마지막 호출 날짜를 저장해 두었다가 날짜가 바뀐 경우에만 다시 호출한다
   (트래픽 절감). `rate_info_tooltip.dart` 의 `lastUpdated` 에 그 시각을 넘기면 된다.
2. **장부 페이지** — 03 의 "여행 장부" 메뉴는 있고 지금은 "준비 중". 저장 쪽
   (`tripStore.addExpense`)은 Firestore 까지 연결돼 있어서 화면만 만들면 된다.
   `screens/ledger_entry.dart` 한 파일에서 연결.
3. **폰트** — Figma 는 Inter. `google_fonts` 추가 후 `theme/app_theme.dart` 에서
   `GoogleFonts.interTextTheme()`.
