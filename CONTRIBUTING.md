# 같이 작업하는 법

## 담당 나누기

파일을 사람별로 갈라 뒀다. **자기 파일만 고치면 충돌이 안 난다.**

| 담당 | 건드리는 파일 | 하는 일 |
|---|---|---|
| 로그인 페이지 | `lib/screens/login_screen.dart` | 로그인·회원가입 화면 (비밀번호 찾기 등) |
| 더보기 페이지 | `lib/screens/more_screen.dart` | 여행 정보 수정, 통화 설정, 여행 삭제, 로그아웃 |
| 팀장 | 공용 파일 | Firebase 설정, 리뷰, 합치기 |

두 화면 모두 이미 연결돼 있다 (로그인은 앱 시작, 더보기는 03 메인 ≡ 버튼).
각자 파일을 열면 맨 위 주석에 쓸 수 있는 함수·데이터와 이미 만들어진 것들이
정리돼 있다.

### 장부 페이지 (이 팀 범위 밖)

03 메인에 **"여행 장부" 메뉴는 있고**, 지금은 누르면 "준비 중" 안내만 뜬다.
나중에 누가 만들든 `lib/screens/ledger_entry.dart` **한 파일만** 고치면 연결된다
(공용인 `trip_main_screen.dart` 는 건드릴 필요 없다). 방법은 그 파일 맨 위 주석에 있다.

### Firebase 없이 작업하기

`lib/firebase_options.dart` 가 비어 있으면 앱이 **로컬 임시 모드**로 뜬다
(참고한 naite-reservation 과 같은 방식). 로그인 화면에 파란 안내 박스가 보이면 그 상태다.

- 로그인: 아무 이메일 + 6자 이상 비밀번호면 통과
- 데이터: 메모리에만. 새로고침하면 목업 3건으로 돌아간다

**조원은 Firebase 키 없이 이 모드로 작업하면 된다.** 로그인 화면은 로컬과 Firebase 가
같은 함수(`authService.signIn/signUp`)와 같은 에러 문구를 쓰게 맞춰 놨으니, 로컬에서
되면 Firebase 에서도 된다.

### 공용 파일

여러 명이 같이 쓰는 파일이라 **말없이 고치면 충돌 난다.** 바꿔야 하면 먼저 얘기할 것:

```
lib/firebase_options.dart   Firebase 키           ← 팀장만. flutterfire configure 가 덮어씀
lib/services/               authService, Backend  ← 로그인 기능 추가 시 여기 인터페이스부터 합의
lib/models/                 Trip, Expense, Country ← 필드 추가는 Firestore 저장 구조도 같이 바뀜
lib/data/                   tripStore, Firestore 저장
lib/theme/                  색·폰트·숫자 포맷
lib/widgets/                ScreenTopBar, AppSheet, CountryChip ...
lib/main.dart               AuthGate (로그인 여부로 화면 전환)
lib/screens/trip_main_screen.dart                  ← 더보기·장부 메뉴가 있는 곳
firestore.rules
```

새 위젯이 필요하면 `lib/widgets/` 에 **새 파일**로 만든다. 기존 파일에 끼워
넣지 않는다. 그래야 서로 안 부딪힌다.

## 브랜치 / PR

`main` 에 직접 push 하지 않는다. 항상 브랜치를 따서 PR 로 합친다.

```bash
git switch main
git pull                       # 남이 합친 걸 먼저 받는다
git switch -c feat/login       # feat/more, fix/xxx ...

# ... 작업 ...

flutter analyze                # 0건이어야 한다
flutter test                   # 전부 통과해야 한다

git add .
git commit -m "로그인 페이지: 비밀번호 찾기 추가"
git push -u origin feat/login
```

GitHub 에서 PR 을 열면 CI 가 자동으로 `analyze` + `test` + `웹 빌드` 를 돌린다.
**초록불일 때만 merge 한다.** merge 되면 1~2분 뒤 GitHub Pages 에 자동 배포된다.

### 충돌이 났을 때

```bash
git switch main
git pull
git switch feat/login
git merge main                 # 여기서 충돌 표시가 뜬다
# 파일 열어서 <<<<<<< ======= >>>>>>> 구간 정리
git add .
git commit
git push
```

당황해서 `--force` 를 쓰지 말 것. 남의 작업이 날아간다.

## 작업 전 확인

```bash
. C:\Users\dongb\dev\flutter-env.ps1   # 이 PC 기준. 각자 환경에 맞게
flutter pub get
flutter run
```

## 테스트

| 파일 | 보는 것 |
|---|---|
| `test/smoke_test.dart` | 화면들을 실제 사용 경로로 한 번씩. 폰 사이즈라 레이아웃이 넘치면 깨진다 |
| `test/auth_test.dart` | 로그인 -> 여행 목록 -> 로그아웃 -> 로그인 흐름 |
| `test/firebase_test.dart` | Firestore 저장 구조, 로그인 에러 문구. 가짜 Firebase 로 돌아서 키 필요 없음 |

지켜야 할 연결:

- **로그인 담당**: `auth_test.dart` 가 계속 통과해야 한다. 화면을 갈아엎으면서 버튼 문구
  (`로그인`, `처음이에요 · 회원가입`)가 바뀌면 테스트의 문구도 같이 바꿀 것
- **더보기 담당**: 03 에서 들어가고 뒤로 나오기, `로그아웃` 버튼으로 로그인 화면 복귀

페이지 내용은 마음대로 바꿔도 된다. 기능을 추가하면 테스트도 같이 늘린다.

## 커밋 메시지

한 줄 요약 + (필요하면) 왜 그렇게 했는지. 한국어로 써도 된다.

```
장부 페이지: 지출을 날짜별로 묶어서 표시

같은 날 여러 건을 기록하면 순서가 섞여서 date 를 타임스탬프로 비교하도록 했다.
```
