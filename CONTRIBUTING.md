# 같이 작업하는 법

## 담당 나누기

파일을 사람별로 갈라 뒀다. **자기 파일만 고치면 충돌이 안 난다.**

| 담당 | 화면 (Figma) | 파일 |
|---|---|---|
| **이 저장소 (완료)** | 00 첫 화면, 01 여행 리스트, 02 여행 추가, 04 국가 더보기, 05 기간 선택, 06 여행 편집(이름·기간·예산), 07 환율 툴팁, **여행 홈** (예산·사용 금액 요약, 오늘 예산, 빠른 환산) | `empty_home`, `trip_list`, `add_trip`, `trip_home` + `widgets/sheets.dart`, `quick_converter.dart`, `today_budget_sheet.dart`, `rate_info_tooltip.dart` |
| 장부 | 지출 목록, 지출 기록 입력 | 새로 `lib/screens/ledger_screen.dart` → 연결은 `ledger_entry.dart` |
| 로그인 | 로그인 / 회원가입 | 새로 `lib/screens/login_screen.dart` → 연결은 `main.dart` 의 `HomeRouter` |
| 더보기 | 더보기 메뉴 | `lib/screens/more_screen.dart` |

### 여행 홈

01 에서 여행을 누르면 들어온다.

```
← 🇯🇵 일본 여행  ¥100 = ₩950 ⓘ               ≡      ⓘ -> 07 환율 갱신 툴팁, ≡ -> 더보기
┌ D-11 · 10.04 – 10.08 · 4박 5일     📅 ✎ ┐      📅 -> 오늘 예산 시트, ✎ -> 06 여행 편집
│ 사용한 금액  456,950원          ¥48,100 │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░░░             38% │      예산 넘으면 "초과" 로 바뀜
│ 예산 1,200,000원          남은 743,050원 │
└─────────────────────────────────────────┘
┌ 빠른 환산  JPY → KRW                  ⇅ ┐      기록 안 남는 계산기
│ [¥ 1,500      ]  =          14,250원    │
└─────────────────────────────────────────┘
(여기 아래로 기능 카드를 더 붙일 자리)
[ + 지출 기록 ]  [ 장부 보기 ]                       -> 장부 (입력부터 / 목록)
```

- **오늘 예산**: 남은 예산 ÷ 오늘 포함 남은 날. 여행 중이면 "오늘 아침 기준" 으로 나누고
  오늘 쓴 만큼 뺀 "오늘 남은 금액" 도 보여준다 (지금 남은 돈으로 나누면 쓸수록 오늘 몫이 줄어든다).
  출발 전이면 전체 일수로 나눈 하루 예산. 계산은 `todayBudget()` 에 있고 테스트가 있다
- **07 툴팁**: 매일 06:00 갱신 기준으로 최근 갱신 시각을 보여준다 (`lastRateUpdate()`).
  환율 API 를 붙이면 실제 마지막 호출 시각으로 바꾸면 된다
- 사용한 금액 요약은 `trip.expenses` 를 **읽기만** 한다. 지출 목록·기록 입력은 장부 몫

### 장부 담당

여행 홈의 두 버튼("여행 장부", "지출 기록")이 이미 있고, 지금은 누르면 "준비 중" 안내만 뜬다.
**`lib/screens/ledger_entry.dart` 한 파일만** 고치면 연결된다 — 여행 홈은 건드릴 필요 없다.

- `openLedger(context, trip, start: LedgerStart.overview | addExpense)` 로 불린다.
  `addExpense` 면 입력 폼부터 열어 주면 된다
- 사용한 금액·남은 금액·오늘 예산·07 환율 툴팁은 여행 홈에 이미 있으니 **장부는 목록과 입력에 집중**하면 된다.
  장부 화면에도 환율 표시가 필요하면 `RateInfoButton` 을 그대로 쓴다
- 지출 목록 한 줄 위젯은 예전 구현을 참고해도 된다:
  ```bash
  git show 6fe2ac6:lib/widgets/budget_card.dart        # ExpenseTile
  ```
- 저장은 `tripStore.addExpense(trip.id, Expense(...))` — Firebase 모드면 Firestore 까지 간다

### 로그인 담당

로그인 **기능**은 이미 있다 (`lib/services/auth_service.dart`). 화면만 만들면 된다.

```dart
await authService.signIn(email, password);   // 실패 시 AuthException(message) — 한국어 문구
await authService.signUp(email, password);
await authService.signOut();
authService.isSignedIn / authService.currentUser
```

- 로그인 화면을 앱 앞에 세우려면 `main.dart` 의 `HomeRouter` 를
  "`authService.isSignedIn` 이면 여행 화면, 아니면 로그인 화면" 으로 감싼다.
  `authService` 는 ChangeNotifier 라 `AnimatedBuilder` 로 감싸면 로그인 즉시 넘어간다
- Firebase 모드에서는 로그인하는 순간 그 사람의 Firestore(`users/{uid}/...`)에
  자동으로 붙는다 (`services/session.dart`). 로그인 전 데이터는 메모리에만 있다
- 로컬 모드의 가짜 로그인도 Firebase 와 같은 규칙·문구라 로컬에서 되면 Firebase 에서도 된다

### Firebase 없이 작업하기 (로컬 모드)

`lib/firebase_options.dart` 가 비어 있으면 앱이 **로컬 임시 모드**로 뜬다
(참고한 naite-reservation 의 임시 저장 모드와 같다). 데이터는 메모리에만 있고
새로고침하면 목업 3건으로 돌아간다. **조원은 Firebase 키 없이 이 모드로 작업하면 된다.**

키를 채운 뒤에도 강제로 로컬 모드로 띄울 수 있다:

```bash
flutter run -d chrome --dart-define=LOCAL_MODE=true
```

### 공용 파일

여러 명이 같이 쓰는 파일이라 **말없이 고치면 충돌 난다.** 바꿔야 하면 먼저 얘기할 것:

```
lib/main.dart               HomeRouter (로그인 담당이 여기에 로그인 화면을 끼운다)
lib/firebase_options.dart   Firebase 키           ← flutterfire configure 가 덮어씀
lib/services/               authService, Backend  ← 로그인 기능 추가 시 여기 인터페이스부터 합의
lib/models/                 Trip, Expense, Country ← 필드 추가는 Firestore 저장 구조도 같이 바뀜
lib/data/                   tripStore, Firestore 저장
lib/theme/                  색·폰트·숫자 포맷
lib/widgets/                ScreenTopBar, AppSheet, CountryChip ...
lib/screens/trip_home_screen.dart   여행 홈 (장부·더보기로 가는 버튼)
firestore.rules
```

새 위젯이 필요하면 `lib/widgets/` 에 **새 파일**로 만든다. 기존 파일에 끼워
넣지 않는다. 그래야 서로 안 부딪힌다.

## 브랜치 / PR

`main` 에 직접 push 하지 않는다. 항상 브랜치를 따서 PR 로 합친다.

```bash
git switch main
git pull                       # 남이 합친 걸 먼저 받는다
git switch -c feat/ledger      # feat/login, feat/more, fix/xxx ...

# ... 작업 ...

flutter analyze                # 0건이어야 한다
flutter test                   # 전부 통과해야 한다

git add .
git commit -m "장부: 지출 기록 입력 폼"
git push -u origin feat/ledger
```

GitHub 에서 PR 을 열면 CI 가 자동으로 `analyze` + `test` + `웹 빌드` 를 돌린다.
**초록불일 때만 merge 한다.** merge 되면 1~2분 뒤 GitHub Pages 에 자동 배포된다.

### 충돌이 났을 때

```bash
git switch main
git pull
git switch feat/ledger
git merge main                 # 여기서 충돌 표시가 뜬다
# 파일 열어서 <<<<<<< ======= >>>>>>> 구간 정리
git add .
git commit
git push
```

당황해서 `--force` 를 쓰지 말 것. 남의 작업이 날아간다.

## 작업 전 확인

```bash
flutter pub get
flutter run -d chrome
```

Flutter 버전은 CI 와 같은 **3.47.5** 를 권장한다 (`flutter --version`).

지원 플랫폼은 **Android · iOS · 웹**이다. Windows 데스크톱은 뺐다 — 켜 두면 Windows 에서
"개발자 모드"를 켜지 않은 사람은 `flutter pub get` 이 플러그인 symlink 단계에서 실패한다.
필요해지면 `flutter create --platforms=windows .` 로 다시 만든다.

## 테스트

| 파일 | 보는 것 |
|---|---|
| `test/smoke_test.dart` | 화면들을 실제 사용 경로로 한 번씩. 폰 사이즈라 레이아웃이 넘치면 깨진다 |
| `test/firebase_test.dart` | Firestore 저장 구조, 로그인 기능·에러 문구. 가짜 Firebase 로 돌아서 키 필요 없음 |

지켜야 할 연결:

- **장부 담당**: 연결하면 `smoke_test.dart` 의 "하단에 장부로 가는 버튼들" 테스트를
  "장부로 들어가고 나온다" 로 바꿀 것 (지금은 "준비 중" 안내를 기대한다)
- **로그인 담당**: 로그인 화면을 앞에 세우면 기존 화면 테스트들이 로그인 뒤에서 시작하도록
  `setUp` 에서 `authService.signIn(...)` 을 불러 줄 것. 로그인 흐름 테스트도 새로 추가
- **더보기 담당**: 여행 홈에서 들어가고 뒤로 나오기

페이지 내용은 마음대로 바꿔도 된다. 기능을 추가하면 테스트도 같이 늘린다.

## 커밋 메시지

한 줄 요약 + (필요하면) 왜 그렇게 했는지. 한국어로 써도 된다.

```
장부: 지출을 날짜별로 묶어서 표시

같은 날 여러 건을 기록하면 순서가 섞여서 date 를 타임스탬프로 비교하도록 했다.
```
