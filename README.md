# TRIPER 프로젝트 아키텍처 및 개발 구조 안내서

## 0. 개발 및 협업 규칙

### 0. 기본 규칙
- 파일 생성 및 변경 시 프로젝트 구조도와 관련 문서를 함께 수정합니다.
- 이미 존재하는 기능은 중복 구현하지 않습니다. 기존 코드와 API를 먼저 확인합니다.
- 디자인과 UI/UX는 기존 프로젝트의 디자인 시스템을 따릅니다.
- 커밋 메시지는 변경 목적과 주요 변경 사항을 구체적으로 작성합니다.
- 새로운 기능에 필요한 API가 없다면 먼저 기존 API를 확인하고, 필요시 `lib/api/` 내부에 구현합니다.

### 1. 아키텍처 규칙
- 화면(UI)에서는 Firebase SDK를 직접 호출하지 않습니다.
- 화면에서는 `lib/api/api.dart`만 import하여 API에 접근합니다.
- Firebase Auth, Firestore 등 외부 서비스 의존성은 API 계층에서 처리합니다.
- 데이터 모델은 `lib/models/`에서 관리합니다.
- 여러 화면에서 재사용되는 계산 및 변환 로직은 적절한 공통 모듈에 구현합니다.
- 기존 디렉터리 구조와 계층 분리를 임의로 변경하지 않습니다.

### 2. 코드 수정 규칙
- 기존 코드의 동작을 충분히 파악한 후 수정합니다.
- 요청받은 기능과 직접 관련 없는 코드는 임의로 수정하지 않습니다.
- 기존 API의 함수명, 매개변수, 반환 타입을 변경할 때는 다른 코드에 미치는 영향을 확인합니다.
- 불필요한 중복 코드와 사용하지 않는 코드는 정리합니다.
- 예외 상황과 비동기 처리에 대한 안정성을 고려합니다.

### 3. UI/UX 규칙
- 기존 색상, 폰트, 여백, 버튼, 입력창 등의 디자인 기준을 유지합니다.
- 동일한 목적의 UI 컴포넌트는 가능한 한 공통 스타일을 사용합니다.
- 로딩, 오류, 빈 데이터, 성공 상태를 적절하게 처리합니다.
- 화면 크기와 기기 환경에 따른 레이아웃 깨짐을 방지합니다.
- 사용자에게 불필요한 확인창이나 알림을 반복적으로 표시하지 않습니다.

### 4. API 및 데이터 규칙
- Firestore 데이터 경로와 필드 구조를 임의로 변경하지 않습니다.
- 데이터 구조 변경 시 기존 데이터와의 호환성을 검토합니다.
- 지출 금액 및 환율 계산은 기존 계산 로직을 우선 활용합니다.
- 사용자 인증 및 권한 검증을 생략하지 않습니다.
- API에서 발생하는 오류는 사용자에게 적절한 메시지로 전달합니다.
- 민감한 키, 비밀번호, 인증 토큰 등은 GitHub에 업로드하지 않습니다.

### 5. 테스트 및 검증 규칙
- 기능 구현 후 관련 기능이 정상적으로 동작하는지 확인합니다.
- 코드 변경 후 최소한 `flutter analyze`를 실행합니다.
- 주요 기능 변경 시 직접 실행하여 UI와 실제 동작을 확인합니다.
- API 및 데이터 처리 로직 변경 시 가능한 범위에서 테스트합니다.
- 기존 기능이 정상적으로 동작하는지 회귀 테스트를 수행합니다.

### 6. Git 협업 규칙
- 작업 전 최신 코드를 Pull합니다.
- 기능 단위로 작업하고, 작업 내용을 구분하여 커밋합니다.
- 다른 팀원의 코드를 임의로 덮어쓰거나 삭제하지 않습니다.
- 충돌 발생 시 임의로 해결하지 않고 변경 의도를 확인합니다.
- `.env`, 서비스 계정 키, 비밀 인증 정보는 커밋하지 않습니다.
- `build/`, `.dart_tool/` 등 생성 파일은 Git에 업로드하지 않습니다.
## 1. 프로젝트 개요

TRIPER는 여행별 예산과 지출을 관리하는 Flutter 기반 크로스플랫폼 애플리케이션입니다.

사용자는 여행을 생성하고 여행별 예산을 설정할 수 있으며, 여행 중 발생한 지출을 기록하고 환율을 반영한 원화 기준 지출 내역을 확인할 수 있습니다.

### 기술 스택

| 구분 | 기술 |
|---|---|
| Frontend | Flutter |
| Programming Language | Dart |
| Backend | Firebase Cloud Functions |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Local Storage | SharedPreferences |
| HTTP Client | http |
| Exchange Rate API | open.er-api.com |
| UI Framework | Material Design |
| Font | Pretendard |

### 주요 기능

- 이메일 회원가입 및 로그인
- Google 로그인
- Kakao 로그인
- 이메일 인증
- 여행 생성, 조회, 수정, 삭제
- 여행별 예산 관리
- 지출 생성, 조회, 수정, 삭제
- 지출 카테고리 관리
- 현지 통화 및 원화 기준 지출 계산
- 환율 정보 조회 및 캐싱
- 회원 탈퇴

---

## 2. 전체 프로젝트 디렉터리 구조

프로젝트는 저장소 루트에 Flutter 애플리케이션과 Firebase 백엔드를 함께 관리하는 구조입니다.

```text
pbl/
│
├── .agents/
│
├── .git/
│
├── functions/
│   ├── node_modules/
│   ├── .eslintrc.js
│   ├── .gitignore
│   ├── index.js
│   ├── package.json
│   └── package-lock.json
│
├── tripledger/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── windows/
│   ├── macos/
│   ├── linux/
│   │
│   ├── assets/
│   ├── build/
│   ├── exam_img/
│   ├── test/
│   │
│   ├── lib/
│   │   ├── api/
│   │   ├── models/
│   │   ├── utils/
│   │   │
│   │   ├── AppColors.dart
│   │   ├── auth_gate.dart
│   │   ├── constants.dart
│   │   ├── expense_detail_page.dart
│   │   ├── firebase_options.dart
│   │   ├── homeshell.dart
│   │   ├── ledger_page.dart
│   │   ├── login_screen.dart
│   │   ├── main.dart
│   │   ├── my_info_page.dart
│   │   ├── sign_up_screen.dart
│   │   ├── trips_page.dart
│   │   └── verify_email_page.dart
│   │
│   └── pubspec.yaml
│
├── .firebaserc
├── .gitignore
├── firebase.json
├── firestore.rules
└── skills-lock.json
```

### 최상위 디렉터리

| 경로 | 역할 |
|---|---|
| `functions/` | Firebase Cloud Functions 백엔드 |
| `tripledger/` | Flutter 애플리케이션 |
| `.git/` | Git 버전 관리 데이터 |
| `.agents/` | 에이전트 관련 설정 및 자료 |
| `.firebaserc` | Firebase 프로젝트 연결 설정 |
| `firebase.json` | Firebase 배포 및 서비스 설정 |
| `firestore.rules` | Firestore 보안 규칙 |
| `.gitignore` | Git 추적 제외 설정 |
| `skills-lock.json` | 프로젝트 도구 관련 잠금 파일 |

Flutter 앱의 플랫폼별 폴더는 각각 Android, iOS, Web, Windows, macOS, Linux 실행 환경 및 네이티브 설정을 담당합니다.

`build/`, `.dart_tool/`, `node_modules/` 등은 도구가 생성하거나 관리하는 영역이므로 특별한 이유 없이 직접 수정하지 않습니다.

---

## 3. Flutter 애플리케이션 구조

Flutter 소스 코드는 `tripledger/lib/`에 위치합니다.

애플리케이션은 화면, API, 모델, 유틸리티를 구분하는 구조입니다.

### 3.1 API 계층

경로: `tripledger/lib/api/`

```text
api/
├── account_api.dart
├── api.dart
├── api_exception.dart
├── auth_api.dart
├── expense_api.dart
├── how to use.md
├── ledger_calc.dart
├── paths.dart
├── rate_api.dart
├── social_config.dart
└── trip_api.dart
```

API 계층은 화면과 Firebase 및 외부 서비스 사이에서 데이터 처리와 비즈니스 로직을 담당합니다.

| 파일 | 책임 |
|---|---|
| `api.dart` | API, 모델, 상수, 유틸리티를 모아 제공하는 공용 진입점 |
| `auth_api.dart` | 이메일 및 소셜 인증, 사용자 상태, 이메일 인증, 비밀번호 관리 |
| `account_api.dart` | 회원 탈퇴 및 계정 삭제 처리 |
| `trip_api.dart` | 여행 데이터 CRUD |
| `expense_api.dart` | 지출 데이터 CRUD 및 환율 스냅샷 저장 |
| `rate_api.dart` | 환율 조회, 캐싱, 통화 환산 |
| `ledger_calc.dart` | 장부 합계, 잔여 예산, 사용률, 카테고리별 집계 |
| `paths.dart` | Firestore 데이터 경로 구성 |
| `api_exception.dart` | 사용자에게 전달할 메시지를 포함하는 예외 |
| `social_config.dart` | 소셜 로그인 SDK 설정 |

#### api.dart의 역할

화면에서는 다음과 같이 공용 진입점을 사용합니다.

```dart
import 'api/api.dart';
```

`api.dart`는 다른 API와 모델, 상수, 포맷 함수를 export합니다.

따라서 화면에서 개별 API 구현 파일을 여러 개 직접 import할 필요가 없습니다.

또한 화면에서 Firebase SDK를 직접 호출하지 않고 API 계층을 통해 접근하도록 설계되어 있습니다.

### 3.2 Models

경로: `tripledger/lib/models/`

현재 확인된 주요 모델은 다음과 같습니다.

#### Trip

여행 정보를 표현합니다.

주요 필드:

- `id`: 여행 식별자
- `name`: 여행 이름
- `budget`: 여행 예산(KRW 정수)
- `currency`: 여행 기준 통화
- `startDate`: 시작 날짜
- `endDate`: 종료 날짜

Firestore Timestamp와 Dart DateTime 사이의 변환을 담당합니다.

#### Expense

지출 정보를 표현합니다.

주요 필드:

- `id`: 지출 식별자
- `category`: 지출 카테고리
- `place`: 지출 장소
- `amount`: 현지 통화 기준 지출 금액
- `currency`: 지출 통화
- `rate`: 기록 당시 환율
- `date`: 지출 날짜
- `paymentMethod`: 결제 수단(cash/card)

원화 환산 금액은 다음과 같이 계산합니다.

```dart
double get amountKrw => amount * rate;
```

지출 기록 당시의 환율을 보존하기 때문에 이후 환율이 변경되어도 과거 지출의 원화 환산 금액은 유지됩니다.

### 3.3 Utils

경로: `tripledger/lib/utils/`

공통 표시 형식 및 포맷 기능을 담당합니다.

API 공용 진입점에서 `format.dart`를 export하는 구조입니다.

### 3.4 주요 화면 파일

화면은 별도의 `screens/` 디렉터리 없이 `lib/` 바로 아래에 배치되어 있습니다.

| 파일 | 역할 |
|---|---|
| `main.dart` | 앱 진입점 및 초기화 |
| `auth_gate.dart` | 인증 상태에 따른 화면 분기 |
| `login_screen.dart` | 로그인 화면 |
| `sign_up_screen.dart` | 회원가입 화면 |
| `verify_email_page.dart` | 이메일 인증 화면 |
| `homeshell.dart` | 로그인 후 진입 화면 래퍼 |
| `trips_page.dart` | 여행 목록 및 관리 |
| `ledger_page.dart` | 여행별 지출 장부 |
| `expense_detail_page.dart` | 지출 상세 및 관리 |
| `my_info_page.dart` | 사용자 정보 및 계정 관리 |
| `AppColors.dart` | 공통 색상 |
| `constants.dart` | 통화 및 카테고리 상수 |
| `firebase_options.dart` | Firebase 플랫폼별 초기화 설정 |

---

## 4. 애플리케이션 실행 및 인증 흐름

### 4.1 앱 초기화

앱의 진입점은 `main.dart`입니다.

현재 구현된 초기화 순서는 다음과 같습니다.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AuthApi.initSocial();
  await RateApi.load();

  runApp(const MyApp());
}
```

초기화 과정:

1. Flutter 바인딩 초기화
2. Firebase 초기화
3. 소셜 로그인 SDK 초기화
4. 환율 데이터 로드
5. Flutter 앱 실행

Firebase 및 소셜 로그인과 환율 초기화가 완료된 이후 첫 화면이 실행됩니다.

### 4.2 인증 상태 관리

`AuthGate`는 `AuthApi.userChanges` 스트림을 구독합니다.

인증 상태에 따라 다음과 같이 화면을 분기합니다.

```text
AuthGate
│
├── 인증 상태 확인 중
│   └── Loading Indicator
│
├── 로그인하지 않은 상태
│   └── LoginScreen
│       └── SignUpScreen
│
├── 로그인했지만 이메일 미인증
│   └── VerifyEmailPage
│
└── 로그인 및 이메일 인증 완료
    └── HomeShell
        └── TripsPage
```

로그인 화면에서 직접 메인 화면으로 이동시키는 방식이 아니라, 인증 상태 변화를 기준으로 `AuthGate`가 화면을 결정합니다.

현재 `HomeShell`은 `TripsPage`를 반환하는 단순한 래퍼이며, 별도의 탭 내비게이션은 확인되지 않았습니다.

### 4.3 인증 방식

현재 확인된 인증 방식은 다음과 같습니다.

- 이메일 및 비밀번호 인증
- Google 로그인
- Kakao 로그인

Kakao 로그인은 Flutter 클라이언트와 Firebase Cloud Functions를 연동하는 방식입니다.

Naver 로그인 SDK도 패키지에 등록되어 있으나, 실제 로그인 구현 여부는 아직 확인되지 않았습니다.

---

## 5. Firebase 백엔드 구조

Firebase 백엔드 코드는 저장소 루트의 `functions/`에서 관리합니다.

### 5.1 Cloud Functions 구성

주요 구현 파일은 `functions/index.js`입니다.

현재 확인된 Cloud Functions는 두 가지입니다.

| 함수 | 유형 | 역할 |
|---|---|---|
| `kakaoLogin` | HTTPS Callable이 아닌 HTTP Request 함수 | Kakao 인증 검증 및 Firebase Custom Token 발급 |
| `updateExchangeRates` | Scheduled Function | 정기적인 환율 갱신 |

Functions 기본 리전은 `asia-northeast3`이며, 전역 최대 인스턴스 설정은 10입니다.

### 5.2 Kakao 로그인 처리

Kakao 로그인은 다음과 같은 구조로 동작합니다.

```text
Flutter Application
       │
       ▼
Kakao Flutter SDK
       │
       ▼
Kakao Access Token
       │
       ▼
Firebase Cloud Function
kakaoLogin
       │
       ▼
Kakao API
토큰 및 사용자 정보 검증
       │
       ▼
Firebase Admin SDK
사용자 조회 또는 생성
       │
       ▼
Firebase Custom Token 발급
       │
       ▼
Flutter Firebase Authentication
```

처리 과정:

1. Flutter에서 Kakao SDK를 통해 인증합니다.
2. 발급받은 Access Token을 Cloud Function으로 전달합니다.
3. Cloud Function이 Kakao API에 토큰 유효성을 확인합니다.
4. Kakao 사용자 정보를 조회합니다.
5. Firebase UID를 구성하고 사용자를 조회하거나 생성합니다.
6. Firebase Custom Token을 발급합니다.
7. Flutter가 Custom Token으로 Firebase에 로그인합니다.

즉, Kakao 인증과 Firebase 인증을 연결하는 중간 서버 역할을 Cloud Functions가 수행합니다.

### 5.3 환율 갱신

환율 갱신은 Firebase Scheduled Function으로 처리합니다.

외부 환율 API:

`https://open.er-api.com/v6/latest/KRW`

갱신 흐름:

```text
Cloud Scheduler
      │
      ▼
updateExchangeRates
      │
      ▼
Exchange Rate API
      │
      ▼
환율 데이터 검증
      │
      ▼
Firestore
rates/current
```

갱신 주기:

```text
0 */3 * * *
```

한국 시간 기준 3시간 간격으로 실행됩니다.

예를 들어 00시, 03시, 06시, 09시 등에 실행됩니다.

환율 데이터를 검증한 뒤 Firestore에 저장하며, 외부 API 호출에 실패하면 기존 Firestore 데이터를 유지하도록 구현되어 있습니다.

---

## 6. Firestore 데이터 구조

현재 확인된 Firestore 데이터 경로는 다음과 같습니다.

```text
Firestore
│
├── users/
│   └── {uid}/
│       └── trips/
│           └── {tripId}/
│               │
│               └── expenses/
│                   └── {expenseId}
│
└── rates/
    └── current
```

### 6.1 사용자 여행 데이터

사용자별로 여행 데이터를 분리합니다.

```text
users/{uid}/trips/{tripId}
```

각 여행 문서 아래에는 지출 데이터가 존재합니다.

```text
users/{uid}/trips/{tripId}/expenses/{expenseId}
```

이 구조를 통해 사용자 → 여행 → 지출의 계층 구조를 구성합니다.

### 6.2 환율 데이터

환율은 사용자 데이터와 별도로 관리합니다.

```text
rates/current
```

Cloud Functions가 주기적으로 데이터를 갱신하고, Flutter 앱은 해당 문서를 조회합니다.

---

## 7. 환율 및 장부 계산 구조

TRIPER에서 중요한 설계 요소 중 하나는 지출 기록 당시의 환율을 보존하는 것입니다.

### 7.1 환율 데이터 흐름

```text
Cloud Functions
      │
      ▼
External Exchange Rate API
      │
      ▼
Firestore rates/current
      │
      ▼
RateApi.load()
      │
      ├── SharedPreferences 캐시
      │
      ▼
ExpenseApi / LedgerCalc
```

`RateApi`의 주요 책임:

- Firestore에서 환율 조회
- SharedPreferences에 환율 캐싱
- Firestore 조회 실패 시 기존 캐시 사용
- 통화별 원화 환산 환율 제공

### 7.2 환율 계산 방식

환율 API 데이터는 KRW 기준으로 외화 환율을 제공합니다.

따라서 외화 1단위당 원화 금액을 얻기 위해 역수를 계산합니다.

예를 들어 다음과 같습니다.

```text
USD 환율 API 값 = 0.0007

1 USD당 KRW = 1 / 0.0007
```

실제 환율 값은 조회 시점에 따라 달라집니다.

### 7.3 지출 기록 시 환율 스냅샷

지출 저장 시점의 환율을 Expense 문서에 함께 저장합니다.

```text
지출 금액 × 기록 당시 환율 = 원화 환산 금액
```

예시:

```text
지출 금액: 100 USD
기록 당시 환율: 1,400 KRW

원화 환산 금액: 140,000 KRW
```

이후 환율이 1,450 KRW로 변경되더라도 해당 지출의 원화 환산 금액은 140,000 KRW로 유지됩니다.

반면 잔여 예산을 현지 통화로 환산할 때는 현재 환율을 사용할 수 있습니다.

따라서 과거 지출 기록과 현재 예산 환산은 서로 다른 환율 기준을 사용합니다.

---

## 8. Firestore 보안 규칙

보안 규칙은 저장소 루트의 `firestore.rules`에서 관리합니다.

### 사용자 데이터

```javascript
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null
                     && request.auth.uid == uid;
}
```

로그인한 사용자만 자신의 UID에 해당하는 데이터에 접근할 수 있습니다.

다른 사용자의 여행 및 지출 데이터는 접근할 수 없습니다.

### 환율 데이터

```javascript
match /rates/{document=**} {
  allow read: if true;
  allow write: if false;
}
```

- 모든 사용자가 환율 데이터를 읽을 수 있습니다.
- 클라이언트에서는 환율 데이터를 수정할 수 없습니다.
- Cloud Functions의 Firebase Admin SDK는 서버 권한으로 접근합니다.

**주의:** Admin SDK는 일반적인 Firestore 클라이언트 보안 규칙에 의해 제한되지 않으므로 서버 코드 자체에서 입력값과 권한을 검증해야 합니다.

---

## 9. API별 주요 동작 및 주의사항

### AuthApi

- 사용자 로그인 및 로그아웃
- 이메일 인증
- Google 및 Kakao 인증
- 비밀번호 관련 기능
- 현재 사용자 및 인증 상태 제공

### TripApi

- 여행 CRUD
- 여행 삭제 시 하위 지출 문서 삭제
- 사용자 전체 여행 삭제 기능

여행 삭제는 지출 문서를 최대 400개 단위 Batch로 삭제한 뒤 여행 문서를 삭제하는 구조입니다.

현재 구현은 더 깊은 중첩 하위 컬렉션까지 재귀적으로 삭제하는 구조는 아닙니다.

### ExpenseApi

- 지출 CRUD
- 지출 복원 관련 기능
- 지출 저장 시 환율 스냅샷 기록
- 결제 수단 및 지출 장소 관리

### AccountApi

회원 탈퇴 절차를 담당합니다.

```text
재인증
  │
  ▼
사용자 여행 및 지출 삭제
  │
  ▼
Firebase Authentication 계정 삭제
```

회원 탈퇴는 데이터 삭제와 인증 계정 삭제가 연속적으로 수행되므로 중간 실패 시 일부 데이터만 삭제될 가능성을 고려해야 합니다.

### LedgerCalc

Firebase에 직접 접근하지 않는 장부 계산 모듈입니다.

주요 기능:

- 총 지출 계산
- 잔여 예산 계산
- 사용률 계산
- 카테고리별 지출 집계
- 날짜 정렬

계산 로직과 Firebase 접근 로직을 분리하여 테스트와 유지보수를 쉽게 하는 역할을 합니다.

---

## 10. 패키지 및 개발 환경

Flutter 앱의 패키지 설정은 `tripledger/pubspec.yaml`에서 관리합니다.

### 주요 의존성

| 패키지 | 용도 |
|---|---|
| `firebase_core` | Firebase 초기화 |
| `firebase_auth` | Firebase 인증 |
| `cloud_firestore` | Firestore 데이터 처리 |
| `google_sign_in` | Google 로그인 |
| `kakao_flutter_sdk_user` | Kakao 로그인 |
| `naver_login_flutter` | Naver 로그인 SDK |
| `shared_preferences` | 로컬 캐싱 |
| `http` | HTTP 통신 |
| `intl` | 날짜 및 숫자 포맷 |
| `flutter_launcher_icons` | 앱 아이콘 생성 |
| `flutter_lints` | Dart 코드 분석 |

Dart SDK 요구 버전은 `^3.13.2`입니다.

### 디자인 리소스

- Pretendard Regular
- Pretendard Medium
- Pretendard SemiBold
- Pretendard Bold
- 앱 아이콘: `assets/tripericon.png`
- 이미지 리소스: `assets/images/`

---

## 11. 개발 및 배포 명령어

### Flutter 프로젝트

Flutter 앱 디렉터리에서 실행합니다.

```powershell
cd tripledger

# 패키지 설치
flutter pub get

# 앱 실행
flutter run

# 정적 분석
flutter analyze

# 테스트 실행
flutter test

# Android 빌드
flutter build apk
```

### Firebase Functions

저장소 루트에서 Functions 디렉터리로 이동합니다.

```powershell
cd functions

# 패키지 설치
npm install

# Firebase Functions Emulator
npm run serve

# Functions Shell
npm run shell

# Functions 배포
npm run deploy

# Functions 로그 조회
npm run logs
```

### Firebase 설정

저장소 루트의 `firebase.json`에서 다음 항목을 관리합니다.

- Cloud Functions 소스 경로: `functions/`
- Functions Codebase: `default`
- Firestore 보안 규칙 경로: `firestore.rules`

배포 명령:

```powershell
# Cloud Functions 배포
firebase deploy --only functions

# Firestore 보안 규칙 배포
firebase deploy --only firestore:rules

# 두 항목 동시 배포
firebase deploy --only functions,firestore:rules
```

---

## 12. 테스트 현황

현재 확인된 테스트 파일은 다음과 같습니다.

```text
tripledger/
└── test/
    └── widget_test.dart
```

현재 파일은 Flutter 기본 Counter 예제 테스트입니다.

TRIPER의 실제 기능을 검증하는 테스트는 확인되지 않았습니다.

### 향후 추가 권장 테스트

| 대상 | 테스트 내용 |
|---|---|
| LedgerCalc | 총 지출, 잔여 예산, 사용률 계산 |
| Trip 모델 | Firestore 데이터 변환 |
| Expense 모델 | 환율 및 원화 환산 |
| RateApi | 환율 캐시 및 오류 처리 |
| AuthApi | 인증 상태 및 입력값 검증 |
| TripApi | 여행 CRUD |
| ExpenseApi | 지출 CRUD 및 환율 스냅샷 |

특히 Firebase와 독립적으로 동작하는 `LedgerCalc`부터 단위 테스트를 작성하는 것을 권장합니다.

---

## 13. Git 및 협업 현황

현재 확인된 브랜치:

```text
master
remotes/master/master
```

별도의 기능별 브랜치 운영 정책은 아직 확인되지 않았습니다.

### 권장 협업 규칙

1. 화면 코드는 Firebase SDK를 직접 호출하지 않습니다.
2. 화면에서 API를 사용할 때는 `api/api.dart`를 공용 진입점으로 사용합니다.
3. Firebase 데이터 경로는 `paths.dart`의 기존 구조를 따릅니다.
4. 모델의 데이터 구조를 변경하면 Firestore 저장 및 조회 로직도 함께 확인합니다.
5. 환율 관련 로직을 수정할 때는 기록 당시 환율과 현재 환율의 사용 목적을 구분합니다.
6. 공용 API를 수정할 때는 기존 화면에서 사용하는 함수와 반환값에 영향을 주는지 확인합니다.
7. Firebase 보안 규칙을 변경할 때는 사용자별 데이터 접근 제한을 유지합니다.
8. 새 기능을 추가할 때는 가능하면 해당 기능의 테스트도 함께 작성합니다.

---

## 14. 핵심 아키텍처 요약

TRIPER는 다음과 같은 계층으로 구성됩니다.

```text
┌──────────────────────────────────────┐
│           Flutter Application        │
│                                      │
│  Screens                             │
│  - LoginScreen                       │
│  - TripsPage                         │
│  - LedgerPage                        │
│  - ExpenseDetailPage                 │
│  - MyInfoPage                        │
│                                      │
│              │                       │
│              ▼                       │
│  API Layer                           │
│  - AuthApi                           │
│  - TripApi                           │
│  - ExpenseApi                        │
│  - RateApi                           │
│  - AccountApi                        │
│  - LedgerCalc                        │
│                                      │
│              │                       │
│              ▼                       │
│  Models / Utils                      │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│             Firebase                 │
│                                      │
│  Firebase Authentication             │
│  Cloud Firestore                     │
│                                      │
└──────────────┬───────────────────────┘
               │
               │
       ┌───────┴────────┐
       ▼                ▼
┌──────────────┐  ┌────────────────────┐
│ Cloud        │  │ External Exchange  │
│ Functions    │◄─┤ Rate API            │
│              │  └────────────────────┘
│ kakaoLogin   │
│ updateRates  │
└──────────────┘
```

### 핵심 설계 원칙

- 화면과 데이터 처리 로직을 분리합니다.
- Firebase 접근은 API 계층을 통해 수행합니다.
- 사용자 데이터는 UID 기준으로 분리합니다.
- 환율은 서버에서 갱신하고 클라이언트에서는 읽기만 수행합니다.
- 지출 기록에는 당시 환율을 저장합니다.
- 인증 상태는 AuthGate가 중앙에서 관리합니다.

---

## 15. 추가 확인이 필요한 사항

다음 항목은 현재 제공된 파일만으로 확정할 수 없습니다.

- 각 화면의 상세한 페이지 이동 및 데이터 흐름
- 네이버 로그인 실제 구현 여부
- Git 원격 저장소 주소 및 팀원별 브랜치 운영 정책
- 각 API의 자동화된 테스트 범위
- `.agents/` 내부 설정의 구체적인 역할
- Functions의 실제 배포 상태 및 운영 환경

이 문서는 확인된 코드와 설정을 기준으로 작성한 아키텍처 안내서입니다. 위 항목은 확인되지 않은 상태로 구분하며, 실제 구현과 다른 내용을 임의로 가정하지 않습니다.

**문서의 목적은 새로운 협업자가 프로젝트의 전체 구조와 데이터 흐름을 이해하고, 기능을 수정하거나 추가할 때 올바른 계층에서 작업할 수 있도록 돕는 것입니다.**
