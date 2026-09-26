 # PBL1 - 실시간 환율 기반 해외 여행 장부앱

## 1. 프로젝트 개요
 - 주제: 실시간 환율 기반 해외 여행 장부앱 - 앱 이름 미정.
 - 기획 의도 및 해결하려는 문제: 해외 여행시 스마트한 예산 관리 가능
 - 타겟 사용자: 해외 여행을 가는 모든 사람들이 잠재적 유저층

## 2. 기술 스택 (Tech Stack)
 - `Flutter + FireBase`로 진행할 예정. 
 - 각자 Flutter와 FireBase 활용한 실습을 통한 개인 공부 필요.

## 2. 역할 분담 (Role Assignment)
 - 로그인: 로그인·회원가입 화면
 - 장부: 지출 목록·지출 기록 입력
 - 더보기: 더보기 메뉴
 - 나머지 화면: 여행 목록·추가·편집, 여행 홈, 환율 표시

## 4. 협업 방식 및 일정 관리
 - 코드 협업: `GitHub`
 - 소통 채널: `KakaoTalk / Discord` (정기 미팅: 주 1회 정도 빈도로 디스코드로 진행할 예정)

## 5. 개발 요구사항 (Core Features)
 - [필수] MVP (최소 기능 제품) 요구사항:
   1) **로그인 기능이 필요할지 결정해야함.** 확실한건 신용카드 결제 기록 API 연동할려면 로그인 기능 반드시 필요함. 
   2) 메인 페이지에서 새로운 여행 계획을 추가하고 삭제하고 수정하고 관리 가능. 리스트를 클릭하여 여행 장부 페이지로 이동 가능(입력값: 예산-원화로 입력, 기간, 여행 이름)
   3) 환율 API와 연동하여 (USD, JPY, EUR, CNY, VND, THB, PHP, TWD등 주로 가는 여행지의 화폐 단위 기준) 원화로 환산하여 남은 예산 표기. - 환율 API 트래픽량의 절감을 위해 환율 API 최근 호출 시간을 기록해두어 앱을 실행한 날짜와 다르다면 환율 API를 호출하는 방식으로 하면 비용 절감이 가능함
   4) 여행 장부 페이지로 이동하면 새로운 소비기록을 추가할 수 있음. 기록을 할 때 유저로부터 입력 받을 값은 (카테고리, 사용처, 사용금액)이고 날짜는 시스템의 날짜를 그대로 가져         와서 기록할 것. 
   5) 여행 장부 페이지에 기록되는 항목은 소비한 기록이며, 한 위젯 내에서 왼쪽 편에는 (카테고리별 대표 아이콘 이미지, 사용처, 현지 화폐기준 사용금액, 날짜)가 오른쪽 편에는           (원화로 환산한 금액)이 표시됨.
   6) 장부 기록들은 기본적으로 최근 결제한 것이 위로 가도록 정렬함.
  
  
 - [선택] 추가 구현 요구사항 (시간 남을 시):
   1) 현재 계획에서는 장부내 기록은 모두 수동임. 그러나 교수님이 조언하신대로 카드 결제 기록 API를 활용하여, 카드 결제건에 대한 것은 자동으로 기록되도록 하는 것도 괜찮을 거 같    음.
   2) ...

## 개발 가이드: 여행 장부앱 (Flutter + Firebase)

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
| 언제 | `--dart-define=LOCAL_MODE=true`, 또는 그 플랫폼 키가 비어 있을 때 | 키가 채워져 있을 때 (**웹은 지금 이 상태**) |
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

## Firebase 연결 상태

프로젝트 **`mytrip-fddfb`** (Firebase 콘솔). 아래는 **이미 끝난 설정**이다.

| 항목 | 상태 |
|---|---|
| Authentication 이메일/비밀번호 | 사용 설정됨 |
| Firestore Database | 생성됨 (`asia-northeast3` 서울, 프로덕션 모드) |
| 보안 규칙 | [`firestore.rules`](firestore.rules) 내용으로 게시됨 — 로그인한 사용자가 자기 `users/{uid}` 아래만 읽고 씀 |
| 승인된 도메인 | `donghaha03.github.io` 추가됨 (배포 사이트에서 로그인하려면 필요) |
| 웹 앱 키 | `lib/firebase_options.dart` 의 `web:` 에 들어 있음 |

남은 것:

- **Android / iOS 앱은 아직 콘솔에 등록하지 않았다.** 그 플랫폼에서는 키가 비어 있어서
  자동으로 로컬 모드로 뜬다 (앱은 정상 동작, 데이터만 메모리에 남음). 모바일에서도
  Firestore 를 쓰려면 콘솔 **프로젝트 설정 → 내 앱 → 앱 추가 → Android**
  (패키지 이름 `com.example.tripapp`) 로 등록하고 `firebase_options.dart` 의
  `android:` 칸을 채우면 된다.
- **로그인 화면이 붙기 전까지는 Firestore 에 아무것도 저장되지 않는다.** 이 앱은
  로그인한 사용자 기준으로(`users/{uid}/trips`) 연결하기 때문이다. 로그인 담당이
  화면을 붙이는 순간 배선이 살아난다 ([CONTRIBUTING.md](CONTRIBUTING.md) 참고).

웹 API 키는 비밀번호가 아니라서 공개 repo 에 있어도 된다 (Firebase 공식 입장).
보안은 위의 **보안 규칙**과 **승인된 도메인**이 담당한다.

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
4. **웹 첫 로딩** — Pretendard 4개 굵기(6MB)를 통째로 넣어서 웹 빌드가 46MB 다.
   느리면 쓰는 글자만 남기는 서브셋으로 줄이거나 굵기를 400/700 둘로 줄이면 된다.

## 글꼴

**Pretendard** (`assets/fonts/`, 400/500/600/700). `theme/app_theme.dart` 의
`ThemeData.fontFamily` 로 앱 전체에 적용된다. 국기 같은 이모지는 Pretendard 에
없어서 시스템 글꼴로 대체된다.

[SIL Open Font License 1.1](assets/fonts/OFL.txt) — 재배포·상업적 사용 모두 가능하고,
라이선스 파일을 같이 두는 것이 조건이라 `assets/fonts/OFL.txt` 로 포함했다.
