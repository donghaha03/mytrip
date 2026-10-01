# mytrip

해외여행 예산과 지출을 한눈에 확인하는 Flutter UI 프로토타입입니다.
여행 목록·추가·편집과 여행 홈 화면을 개발한 개인 저장소이며,
이후 [팀 저장소 `wannabb/tripledger`](https://github.com/wannabb/tripledger)의 공용 API와 연결할 예정입니다.

[웹 미리보기](https://donghaha03.github.io/mytrip/) · [개발 및 통합 안내](CONTRIBUTING.md)

## 구현 상태

| 기능 | 현재 상태 |
|---|---|
| 여행 목록·추가·수정·삭제 | 구현됨 |
| 여행 홈 | 사용액·남은 예산·진행률·D-day 표시 |
| 오늘 예산 | 여행 기간과 지출을 기준으로 계산 |
| 최근 지출 | 최근 7일 요약과 최신 3건 표시 |
| 빠른 환산·환율 안내 | 매일 06:00 KST 서버 갱신, 기준일·갱신 시각·기기 캐시 |
| 로그인·회원가입 | 인증 서비스만 있음, 화면 미구현 |
| 장부·지출 입력 | 버튼과 연결 지점만 있음, 화면 미구현 |
| 내 계정·설정 | 준비 중 안내만 표시 |

빠른 환산과 현재 예산의 현지 통화 표시는 API 환율을 사용합니다.
기존 샘플 지출의 원화 금액은 고정 예시 환율을 유지하며, 실제 지출 저장은 아직 팀 API에 연결되지 않았습니다.

## 환율

공개 환율 파일을 제공할 수 있는 [Currency API](https://github.com/fawazahmed0/exchange-api)의
KRW 기준 일별 참고 환율을 사용합니다([CC0](https://github.com/fawazahmed0/exchange-api/blob/main/LICENSE)).
API 키·새 패키지·DB 권한 없이 기존 GitHub Pages 배포를 재사용합니다.
팀 API 사용 가이드와 같은 `lib/api/api.dart` 진입점과 정적 `RateApi` 호출 형식을 사용합니다.

- **앱을 닫아도 매일 오전 6시(한국 시간)** mytrip의 GitHub Actions가 환율을 받아 `rates.json`을 배포합니다.
- 코드 변경·수동 배포 때는 기존 공개 환율 파일과 수집 시각을 그대로 유지합니다. 공개 파일이 없는 최초 배포만 즉시 수집합니다.
- 앱 시작·다시 활성화할 때 읽고, 열려 있는 앱은 5분마다 확인합니다. 서버 갱신 시각이 최근 06시 이후면 기기 캐시를 재사용합니다.
- 자정이 아니라 **06시 경계**를 넘으면 다시 조회합니다. 배포가 늦으면 이전 환율을 표시하며 재시도합니다.
- 여행 홈의 `ⓘ`에서 **매일 오전 6시 자동 갱신 일정**, API **환율 기준일**, **실제 마지막 수집 시각(KST)**을 구분해 확인합니다. 수동 재조회 버튼은 없습니다.
- 조회 실패 시 이전 캐시를 유지하고 연결 실패를 안내합니다. 환율이 전혀 없으면 환산을 비활성화합니다.
- 서버는 jsDelivr 조회 실패 시 제공자의 Cloudflare 주소를 시도합니다. 둘 다 실패하면 배포를 중단해 마지막 정상 파일을 보존합니다.
- 제공자가 새 데이터를 아직 내지 않았으면 같은 기준일의 값일 수 있습니다. 카드사 수수료·초 단위 시세·실제 결제 환율은 반영하지 않습니다.

GitHub 예약 실행과 빌드·배포는 지연될 수 있어 **06:00 정각 완료를 보장하지 않습니다**.
공개 저장소에서 활동이 60일 없으면 예약 실행이 중지될 수 있습니다
([GitHub 안내](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)).
정각 보장이나 장기 무관리 운영이 필요해지면 전용 서버 스케줄러로 바꿉니다.

```dart
import 'package:tripapp/api/api.dart';

await RateApi.load();
final rate = RateApi.krwPer('JPY'); // 1 JPY당 원화, 없으면 0
final won = RateApi.toKrw(1000, 'JPY');
final yen = RateApi.fromKrw(9000, 'JPY');
// rate <= 0일 때 계산/입력을 막는다. UI는 RateApi.changes를 구독한다.
```

환율 조회와 기기 캐시에 `http`, `shared_preferences`를 사용합니다.
CC0 제공자 출처는 이 문서에 남기고 화면 하단에서는 제거했습니다. 사용하지 않는 `url_launcher`도 `pubspec.yaml`과 잠금 파일에서 제거했습니다.
DB 구조·Firebase 설정·wannabb/tripledger는 변경하지 않았습니다.

## 실행

Flutter **3.47.5** 기준이며 Android·iOS·웹을 대상으로 합니다.
기본 실행은 Firebase 없이 샘플 여행 3건을 보여주는 화면 미리보기입니다.
팀 요구사항에 따라 이전 데이터가 있다고 가정하고 UI를 확인할 수 있습니다.

```sh
flutter pub get
flutter run -d chrome
```

로컬 모드의 데이터는 메모리에만 남고, 앱을 다시 실행하면 초기화됩니다.

Firebase 설정을 사용하려면 다음과 같이 실행합니다.

```sh
flutter run -d chrome --dart-define=LOCAL_MODE=false
```

현재 웹 설정은 개인 Firebase 프로젝트 `mytrip-fddfb`를 가리킵니다.
Android·iOS 설정은 비어 있어 로컬 모드로 실행됩니다.
Firebase 모드의 영구 저장은 인증 서비스에 로그인한 사용자에게만 연결되며,
현재는 로그인 화면이 없어 최초 실행 상태에서 원격 저장을 사용할 수 없습니다.
콘솔의 인증 제공자·보안 규칙·도메인 설정은 실행 전에 별도로 확인해야 합니다.

## 코드 구성

```text
lib/
├── main.dart                 앱 진입점
├── firebase_options.dart     개인 Firebase 설정
├── api/                      팀 형식의 환율 API 진입점·06시 캐시
└── trip_home/                이 저장소의 화면과 지원 코드
    ├── app.dart              테마·홈 화면 분기
    ├── screens/              여행 목록·추가·홈·연결 화면
    ├── widgets/              달력·편집 시트·계산기·요약 카드
    ├── models/               현재 프로토타입의 여행·지출 모델
    ├── data/                 메모리 상태·Firestore 저장
    ├── services/             인증·실행 모드·사용자 연결
    └── theme/                색상·글꼴·표시 형식
test/                         화면·계산·Firebase 모의 테스트
assets/fonts/                 Pretendard와 글꼴 라이선스
tool/update_rates.mjs         서버 환율 수집·검증(추가 패키지 없음)
```

## 팀 저장소로 옮길 때

팀 요구사항에 맞춰 개인 작업을 `lib/trip_home/` 폴더에 모았습니다.
이후 팀 저장소에서 별도 브랜치를 만들고 이 폴더의 필요한 화면과 위젯을 가져올 계획입니다.
YAML 변경이 필요하면 먼저 팀에 알리고, DB 권한은 연결 작업이 필요한 시점에 요청합니다.
현재 두 저장소의 모델과 저장 방식이 다르므로 **폴더를 복사하는 것만으로 통합되지는 않습니다.**

| 항목 | 현재 mytrip | 팀 tripledger |
|---|---|---|
| 예산 | `Trip.budgetKrw` | `Trip.budget` — 원화 정수 |
| 통화 | `Trip.country.currency` | `Trip.currency` |
| 지출 컬렉션 | `trips/{tripId}/records` | `trips/{tripId}/expenses` |
| 지출 원화 환산 | 샘플은 고정 환율, 현재 환산은 API | 지출에 저장된 `currency`·`rate`, `amountKrw` |
| 데이터 호출 | 환율은 `lib/api/api.dart`, 여행은 `tripStore` | `lib/api/api.dart`의 공용 API |
| Firebase 프로젝트 | `mytrip-fddfb` | `tripledger-ebc18` |

통합 시 화면의 데이터 연결을 팀 API로 맞추고, 팀의 `main.dart`·Firebase 설정·기존 모델을 유지합니다.
상세 절차는 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

## 검증과 웹 미리보기

```sh
flutter analyze --fatal-infos --fatal-warnings
flutter test
node tool/update_rates.mjs --check
flutter build web --release --no-wasm-dry-run --base-href /mytrip/
```

GitHub Actions가 브랜치와 PR을 검사합니다.
`main` 변경 시 빌드·검사를 통과하면 GitHub Pages에 웹 미리보기가 배포됩니다.
기존 공개 환율 검증 또는 예약 환율 수집까지 성공해야 새 배포로 교체합니다. 예약 실행도 같은 검사를 거칩니다.

글꼴은 [Pretendard, SIL Open Font License 1.1](assets/fonts/OFL.txt)을 사용합니다.
