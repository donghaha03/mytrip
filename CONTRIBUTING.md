# 개발 및 팀 통합 안내

이 저장소는 개인 UI 개발용입니다. 팀의 역할 분담과 공용 API 규칙은
[`wannabb/tripledger` README](https://github.com/wannabb/tripledger#readme)와
[API 사용 가이드](https://github.com/wannabb/tripledger/blob/main/lib/api/how%20to%20use.md)를 기준으로 합니다.

## 팀 작업 규칙

- 각자 별도 Git 브랜치에서 작업하고, `lib/` 아래 담당 작업 폴더를 사용합니다. 이 저장소의 폴더는 `lib/trip_home/`입니다.
- `pubspec.yaml` 등 YAML을 수정해야 한다면 변경 목적과 내용을 미리 팀에 알립니다. 이번 환율 연결에는 `http`, `shared_preferences`, `url_launcher`를 추가했습니다.
- DB 작업이 필요해지면 팀 담당자에게 프로젝트 멤버 추가를 요청합니다. 지금은 DB 권한 없이 작업할 수 있습니다.
- 우선 이전 데이터가 있다고 가정해 화면을 완성합니다. 기본 실행의 샘플 여행·지출은 실제 사용자 데이터가 아닙니다.

## 현재 화면의 연결 지점

| 연결할 기능 | 파일 | 현재 동작 |
|---|---|---|
| 로그인 상태에 따른 화면 분기 | `lib/trip_home/app.dart` | 여행 홈·목록으로 바로 진입 |
| 장부·지출 입력 | `lib/trip_home/screens/ledger_entry.dart` | 준비 중 안내 |
| 내 계정·설정 | `lib/trip_home/screens/more_screen.dart` | 준비 중 화면 |
| API 환율 | `lib/trip_home/services/rate_api.dart`와 환율 관련 위젯 | 일 1회 갱신 데이터·24시간 기기 캐시 |

여행 홈의 지출 요약은 읽기용입니다. 장부의 전체 목록·입력 화면은 별도로 연결해야 합니다.
`openLedger(context, trip, start: ...)`의 `overview`와 `addExpense`는 각 버튼의 진입 목적을 나타냅니다.

## 이 저장소에서 작업하기

화면 확인은 로컬 모드로 실행합니다.

```sh
flutter pub get
flutter run -d chrome
```

변경은 기능 브랜치에서 작업한 뒤 PR로 `main`에 합칩니다.

```sh
git switch main
git pull --ff-only
git switch -c feature/my-change
```

PR 전에 다음 검사를 실행합니다.

```sh
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build web --release --no-wasm-dry-run
```

`test/smoke_test.dart`는 화면 이동·입력·예산 계산을,
`test/firebase_test.dart`는 모의 Firebase로 인증과 저장 구조를 확인합니다.
`test/rate_api_test.dart`는 실제 네트워크 호출 없이 환율 방향·캐시·오류 복구를 확인합니다.
화면 동작을 변경했다면 해당 테스트의 기대값도 함께 갱신합니다.

## 이후 tripledger로 옮기는 절차

아래는 **나중에 팀 저장소에서 실행할 절차**입니다.

1. 팀의 최신 `main`에서 본인 작업용 기능 브랜치를 만듭니다.
2. 이 저장소의 `lib/trip_home/`에서 필요한 화면과 위젯을 가져옵니다.
3. 화면의 모델·데이터 호출을 팀의 `lib/api/api.dart`에 맞춥니다.
4. 로그인·장부·계정·설정 화면으로 이동하는 연결 지점을 조원들과 맞춥니다.
5. 검사 후 팀 저장소에 PR을 열어 통합합니다.

```sh
# 팀 저장소의 로컬 체크아웃에서 실행
git switch main
git pull --ff-only
git switch -c feature/trip-home
git remote add mytrip https://github.com/donghaha03/mytrip.git
git fetch mytrip
git restore --source=mytrip/main -- lib/trip_home
```

`mytrip` 원격이 이미 등록되어 있으면 `git remote add`는 생략합니다.
이 명령은 폴더를 가져오는 단계이며, 앱 연결과 API 변환은 별도로 해야 합니다.
이미 `lib/trip_home/`에 조원의 작업이 있다면 파일별로 비교해 필요한 부분만 반영합니다.

## 통합할 때 맞춰야 할 기준

- **공용 API:** 화면에서 Firebase를 직접 호출하지 않고 팀의 `AuthApi`, `TripApi`, `ExpenseApi`, `RateApi`, `LedgerCalc`를 사용합니다. 현재 `services/`와 `data/`는 개인 프로토타입용이므로 팀 저장 계층과 함께 중복 실행하지 않습니다.
- **모델:** 예산은 `Trip.budget`에 원화 정수로, 지출은 현지 금액과 기록 당시 `currency`·`rate`로 처리합니다. `records` 경로와 `budgetKrw` 필드를 그대로 사용하지 않습니다. 현재 샘플 지출의 고정 환율은 팀의 `Expense.rate`로 대체하며, 과거 지출을 새 환율로 재계산하지 않습니다.
- **환율:** 팀의 기존 `RateApi`로 데이터 연결을 바꾸고 개인 환율 서비스를 중복 초기화하지 않습니다. `http`·`shared_preferences`는 팀에 이미 있으며 출처 링크용 `url_launcher`가 없다면 추가 전에 팀에 알립니다.
- **앱 진입점:** 팀의 `lib/main.dart`에 화면을 연결하고, 이 저장소의 앱 초기화 코드를 통째로 대체하지 않습니다. Firebase와 소셜 로그인·환율 초기화는 앱 시작 시 한 번만 수행합니다.
- **Firebase:** 팀의 `lib/firebase_options.dart`와 `tripledger-ebc18` 설정을 사용합니다. 개인 프로젝트 설정이나 `firestore.rules`를 팀 프로젝트에 덮어쓰지 않습니다.
- **글꼴·패키지:** 팀에 Pretendard와 Firebase 패키지가 이미 있으므로 먼저 기존 설정을 확인합니다. 테스트 의존성이나 추가 글꼴이 필요하면 실제 사용하는 항목만 반영합니다.
- **공용 파일:** `main.dart`, `pubspec.yaml`, 공용 API·모델·테마 변경은 조원들과 조율합니다. 폴더를 나눠도 데이터 계약과 공용 파일의 충돌은 별도로 해결해야 합니다.

이 저장소 전체나 관련 없는 Git 이력을 병합할 필요는 없습니다.
