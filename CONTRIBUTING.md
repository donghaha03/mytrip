# 개발 안내

## 실행과 검증

```sh
flutter pub get
flutter run -d chrome
flutter analyze --fatal-infos --fatal-warnings
flutter test
node tool/update_rates.mjs --check
flutter build web --release --no-wasm-dry-run --base-href /mytrip/
```

기능 브랜치에서 작업하고 검사를 통과한 PR을 `main`에 합칩니다.
`main`은 GitHub Pages에 자동 배포됩니다.

## 코드 위치

- `lib/trip_home/`: 화면·위젯·모델·여행 데이터
- `lib/api/`: 환율 조회와 정수 환산
- `tool/update_rates.mjs`: 서버 환율 수집과 검증
- `test/`: 화면·계산·환율·Firebase 모의 테스트
- `server/card/`: 인증된 사용자용 카드 승인내역 조회 서버와 테스트

기본 실행은 메모리 데이터로 동작합니다. Firebase 모드는
`--dart-define=LOCAL_MODE=false`로 실행하며 인증된 사용자에게만 원격 저장을 연결합니다.
웹 설정은 개인 프로젝트 `mytrip-fddfb`를 사용합니다. 로그인 화면과 Android·iOS 설정은 준비 중입니다.

## 팀 작업

기준 문서: [tripledger](https://github.com/wannabb/tripledger) · [API 사용 가이드](https://github.com/wannabb/tripledger/blob/main/lib/api/how%20to%20use.md)

- 개인 브랜치와 `lib/` 아래 담당 폴더에서 작업합니다. mytrip의 화면 폴더는 `lib/trip_home/`입니다.
- YAML이나 공용 파일을 수정하기 전에 팀과 조율합니다.
- DB 연결이 필요한 시점에 프로젝트 접근 권한을 요청합니다.
- 화면 개발에는 샘플 데이터를 사용합니다.

## tripledger 통합

1. 팀 저장소의 최신 `main`에서 개인 브랜치를 만듭니다.
2. `lib/trip_home/`의 필요한 화면과 위젯만 가져옵니다. 같은 경로에 기존 작업이 있으면 파일별로 비교합니다.
3. 모델과 데이터 호출을 팀의 `lib/api/api.dart`에 맞춥니다.
4. 로그인·장부·계정·설정 화면의 연결 지점을 조원들과 맞춥니다.
5. 검사 후 PR로 통합합니다.

| 항목 | mytrip | tripledger |
|---|---|---|
| 예산 | `Trip.budgetKrw` | `Trip.budget` |
| 통화 | `Trip.country.currency` | `Trip.currency` |
| 지출 경로 | `trips/{tripId}/records` | `trips/{tripId}/expenses` |
| 환산 기준 | 현재 상단 정수 환율 | 기록 당시 `Expense.rate`·`amountKrw` |

화면에서 팀의 `AuthApi`·`TripApi`·`ExpenseApi`·`RateApi`·`LedgerCalc`를 재사용합니다.
개인 저장 계층을 중복 연결하거나 팀의 `main.dart`·API·Firebase 설정·보안 규칙을 덮어쓰지 않습니다.
정수 환산과 과거 지출 처리 정책은 API 담당자와 먼저 맞춥니다.
`paymentMethod`(현금·카드)와 `isTaxFree`(면세 표시)는 개인 추가 필드이므로 팀 API에 합칠 때 함께 조율합니다. `amount`는 면세 처리 후 실제 결제액입니다.
통화·메모·기록 당시 환율·자동 기록 출처·취소 상태 필드도 팀 모델과 조율합니다. 기존 필드가 없는 문서는 여행 통화와 정상 지출로 읽습니다.

장부 연결은 `screens/ledger_entry.dart`, 계정·설정 연결은 `screens/more_screen.dart`에서 담당합니다.

## 카드 연동

공개 앱의 테스트 카드는 실제 API·실카드와 연결되지 않은 로컬 이벤트입니다.
실제 연결용 서버의 권한·제공자 설정·실행 안내는 [카드 서버](server/card/README.md)를 참고하세요.
서버는 여행의 기존 `records` 경로에 저장하며 앱은 Firestore 구독으로 갱신합니다.
카드 기록의 삭제는 숨김 처리이며 실제 결제를 취소하지 않습니다.

## 환율 운영

`pages.yml`의 예약 실행은 매일 06:00 KST에 새 환율을 수집합니다.
일반 배포는 기존 환율과 수집 시각을 유지하며, 공개 파일이 없는 최초 배포만 즉시 수집합니다.
조회 실패 시 마지막 정상 데이터를 보존합니다.

앱은 시작·다시 활성화할 때 서버를 확인하고, 실행 중에는 5분마다 확인합니다.
공개 저장소가 60일간 비활성 상태이면 예약 실행이 중지될 수 있습니다
([GitHub 예약 실행 안내](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)).
