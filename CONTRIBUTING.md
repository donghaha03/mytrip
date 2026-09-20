# 같이 작업하는 법

## 담당 나누기

파일을 사람별로 갈라 뒀다. **자기 파일만 고치면 충돌이 안 난다.**

| 담당 | 건드리는 파일 | 하는 일 |
|---|---|---|
| 장부 페이지 | `lib/screens/ledger_screen.dart` | 전체 지출 내역, 지출 추가·수정·삭제 |
| 더보기 페이지 | `lib/screens/more_screen.dart` | 여행 정보 수정, 통화 설정, 여행 삭제 |
| 공통 | 아래 "공용 파일" 참고 | 합의 후 수정 |

두 페이지는 이미 03 메인에서 연결해 놨다. 각자 파일을 열면 맨 위 주석에
쓸 수 있는 데이터와 기존에 만들어진 것들이 정리돼 있다.

### 공용 파일

여러 명이 같이 쓰는 파일이라 **말없이 고치면 충돌 난다.** 바꿔야 하면 먼저 얘기할 것:

```
lib/models/         Trip, Expense, Country       ← 필드 추가는 특히 미리 공유
lib/data/           tripStore
lib/theme/          색·폰트·숫자 포맷
lib/widgets/        ScreenTopBar, AppSheet, CountryChip ...
lib/screens/trip_main_screen.dart                ← 두 페이지의 진입점
```

새 위젯이 필요하면 `lib/widgets/` 에 **새 파일**로 만든다. 기존 파일에 끼워
넣지 않는다. 그래야 서로 안 부딪힌다.

## 브랜치 / PR

`main` 에 직접 push 하지 않는다. 항상 브랜치를 따서 PR 로 합친다.

```bash
git switch main
git pull                       # 남이 합친 걸 먼저 받는다
git switch -c feat/ledger      # feat/more, fix/xxx ...

# ... 작업 ...

flutter analyze                # 0건이어야 한다
flutter test                   # 전부 통과해야 한다

git add .
git commit -m "장부 페이지: 날짜별 그룹 목록"
git push -u origin feat/ledger
```

GitHub 에서 PR 을 열면 CI 가 자동으로 `analyze` + `test` + `웹 빌드` 를 돌린다.
**초록불일 때만 merge 한다.**

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
. C:\Users\dongb\dev\flutter-env.ps1   # 이 PC 기준. 각자 환경에 맞게
flutter pub get
flutter run
```

## 테스트

`test/smoke_test.dart` 가 화면 8개를 실제 사용 경로로 한 번씩 돌려본다.
폰 사이즈(375×812)로 렌더링해서 레이아웃이 넘치면 바로 깨진다.

08/09 테스트는 **"03 에서 들어가고 뒤로 나온다"** 만 확인한다.
페이지 내용은 마음대로 바꿔도 되지만, 이 연결은 깨지 말 것.
기능을 추가하면 테스트도 같이 늘린다.

## 커밋 메시지

한 줄 요약 + (필요하면) 왜 그렇게 했는지. 한국어로 써도 된다.

```
장부 페이지: 지출을 날짜별로 묶어서 표시

같은 날 여러 건을 기록하면 순서가 섞여서 date 를 타임스탬프로 비교하도록 했다.
```
