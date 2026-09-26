# 여행 장부앱 (Flutter + Firebase)

Figma `환율 여행 장부앱 - PBL1` 을 옮긴 Flutter 앱. 데이터는 Firestore, 배포는 GitHub Pages.
장부(03·07)와 로그인 화면은 다른 담당이 만든다 — 연결 지점만 준비돼 있다.

- **배포 주소**: https://donghaha03.github.io/mytrip/ — `main` 에 합쳐지면 1~2분 뒤 자동 반영
- **저장소**: https://github.com/donghaha03/mytrip
- **팀 작업 규칙**: [CONTRIBUTING.md](CONTRIBUTING.md) — 누가 어떤 파일을 맡는지

## 두 가지 모드

`lib/firebase_options.dart` 가 채워져 있는지에 따라 알아서 바뀐다.
(참고한 [naite-reservation](https://github.com/gnu-naite/naite-reservation) 의
`store.js` 가 Firestore ↔ 임시 저장을 자동 전환하는 것과 같은 방식)

| | 로컬 임시 모드 | Firebase 모드 |
|---|---|---|
| 언제 | `firebase_options.dart` 가 비어 있을 때 (**지금 상태**) | 키가 채워져 있을 때 |
| 데이터 | 메모리. 새로고침하면 목업 3건으로 초기화 | 로그인한 사용자의 Firestore. 기기 간 실시간 동기화 |
| 로그인 기능 | 아무 이메일 + 6자 이상 비밀번호 (가짜) | Firebase Auth 이메일/비밀번호 |

조원은 Firebase 키 없이 로컬 모드로 바로 작업하면 된다.
키를 채운 뒤에도 `--dart-define=LOCAL_MODE=true` 를 주면 강제로 로컬 모드로 뜬다.

## 실행

```powershell
flutter pub get
flutter run -d chrome
flutter run -d chrome --dart-define=LOCAL_MODE=true   # 키가 있어도 로컬로
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

`lib/firebase_options.dart` 가 덮어써진다. 다시 `flutter run` 하면 Firebase 모드로 뜬다
(목업 3건 대신 빈 화면에서 시작). 로그인 화면이 붙기 전까지는 데이터가 메모리에만 있다.

> CLI 가 번거로우면: 콘솔 **프로젝트 설정 → 내 앱 → 웹 앱 추가** 에서 나오는
> `firebaseConfig` 값을 `firebase_options.dart` 의 `web:` 칸에 직접 옮겨 적어도 된다.

웹 API 키는 비밀번호가 아니라서 공개 repo 에 커밋해도 된다 (Firebase 공식 입장).
**대신 1-4 의 보안 규칙은 반드시** — 테스트 모드로 두면 누구나 전체 DB 를 읽고 쓴다.

### 3. GitHub Pages 도메인 허용 (안 하면 배포 사이트에서 로그인이 막힌다)

**Authentication → 설정 → 승인된 도메인 → 도메인 추가** → `<계정>.github.io`

## 처음 한 번: GitHub 에 올리기

1. github.com 에서 새 repo — **README·.gitignore·license 모두 체크 해제**
2. 올리기:

   ```powershell
   git remote add origin https://github.com/<계정>/<repo>.git
   git push -u origin main
   ```

3. repo **Settings → Pages → Source: GitHub Actions**

Actions 탭에서 "Deploy to GitHub Pages" 가 초록불이 되면
`https://<계정>.github.io/<repo>/` 에서 열린다.

## 나중에 조원과 공유할 때

1. repo **Settings → Collaborators** 에서 조원 초대
2. (권장) **Settings → Branches → main 보호 규칙**: PR 필수 + `CI` 통과 필수
3. 조원은 clone 후 각자 브랜치에서 작업 (`feat/login`, `feat/more` — [CONTRIBUTING.md](CONTRIBUTING.md))
4. Firebase 를 붙였다면 조원도 콘솔에서 보게 하려면: Firebase **프로젝트 설정 → 사용자 및 권한** 에서 추가

## 화면 구성

| 파일 | Figma | 설명 | 담당 |
|---|---|---|---|
| `screens/empty_home_screen.dart` | 00 | 여행이 없을 때의 첫 화면 | ✅ |
| `screens/trip_list_screen.dart` | 01 | 내 여행 목록: 요약 줄, D-day 배지, 예산·사용률 (길게 눌러 편집) | ✅ |
| `screens/add_trip_screen.dart` | 02 | 새 여행 추가 | ✅ |
| `widgets/sheets.dart` | 04~06 | 국가 더보기 / 기간 선택 / 여행 편집(이름·기간·예산) 시트 | ✅ |
| `screens/trip_home_screen.dart` | — | **여행 홈**: 사용한 금액·예산·남은 금액 + 하단 장부 버튼 | ✅ |
| `widgets/quick_converter.dart` | — | 빠른 환산 계산기 (현지 ↔ 원화, 기록 안 남김) | ✅ |
| `widgets/today_budget_sheet.dart` | — | 오늘 예산: 남은 예산 ÷ 남은 날 | ✅ |
| `widgets/recent_expenses_card.dart` | — | 최근 지출 요약: 7일 막대 + 마지막 3건 | ✅ |
| `widgets/rate_info_tooltip.dart` | 07 | 여행 이름 옆 환율 + 갱신 시각 툴팁 (매일 06:00) | ✅ |
| `screens/ledger_entry.dart` | 03 | 장부 연결 지점 (버튼만, 지출 목록·입력은 장부 담당) | 장부 담당 |
| `screens/more_screen.dart` | — | 더보기 — **구현 전** | 더보기 담당 |
| (없음) | — | 로그인 화면 — `services/auth_service.dart` 에 기능은 있음 | 로그인 담당 |

흐름: 00/01 → 여행 누르면 **여행 홈** → 하단 "여행 장부" / "지출 기록" → 장부 (준비 중), "더보기" → 더보기

## 구조

```
lib/
  main.dart                  HomeRouter: 00 빈 화면 / 01 리스트 (로그인 화면은 여기에 끼운다)
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

1. **장부 (장부 담당)** — 여행 홈의 "여행 장부"/"지출 기록" 버튼은 있고 지금은 "준비 중".
   `screens/ledger_entry.dart` 한 파일에서 연결. 예전 03/07 구현은
   `git show 6fe2ac6:lib/screens/trip_main_screen.dart` 로 꺼내 쓸 수 있다.
2. **로그인 (로그인 담당)** — `authService` 로 화면만 만들어 `main.dart` 의 `HomeRouter` 앞에 세운다.
3. **환율 API** — `models/country.dart` 의 `krwPerUnit` 이 하드코딩. 마지막 호출 날짜를
   저장해 두었다가 날짜가 바뀐 경우에만 다시 호출한다 (트래픽 절감).
4. **폰트** — Figma 는 Inter. `google_fonts` 추가 후 `theme/app_theme.dart` 에서
   `GoogleFonts.interTextTheme()`.
