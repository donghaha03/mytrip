# TRIPER API 사용 설명서

## 0. API 폴더 구조

TRIPER은 화면(UI)과 데이터 처리 로직을 분리하기 위해 `lib/api/` 폴더에서 API 기능을 모듈별로 관리합니다.

디렉터리 구조는 다음과 같습니다. 참고로 모델 파일은 lib/models에 expense.dart와 trip.dart로 존재합니다.

```text
lib/
└── api/
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

### 0.1 파일별 역할

| 파일 | 역할 |
|---|---|
| `account_api.dart` | 계정 관련 기능 및 회원 탈퇴 |
| `api.dart` | API 및 모델의 공용 진입점 |
| `api_exception.dart` | API에서 사용하는 사용자 정의 예외 |
| `auth_api.dart` | 이메일 및 소셜 인증, 계정 관리 |
| `expense_api.dart` | 지출 데이터 관리 |
| `ledger_calc.dart` | 여행 장부 금액 및 통계 계산 |
| `paths.dart` | Firestore 데이터 경로 관리 |
| `rate_api.dart` | 환율 데이터 조회 및 환산 |
| `social_config.dart` | 소셜 로그인 설정값 관리 |
| `trip_api.dart` | 여행 데이터 관리 |

---

# 1. AuthApi

`AuthApi`는 TRIPER의 사용자 인증과 계정 관리를 담당하는 모듈입니다.

이메일 및 비밀번호 로그인, 회원가입, Google 로그인, Kakao 로그인, 이메일 인증, 비밀번호 변경 등의 기능을 제공합니다.

화면에서는 Firebase Authentication SDK를 직접 호출하지 않고 `AuthApi`에서 제공하는 메서드를 사용해야 합니다.

## 1.1 소셜 로그인 초기화

소셜 로그인 기능을 사용하기 전에 앱 시작 시 초기화해야 합니다.

Firebase 초기화가 완료된 이후 `AuthApi.initSocial()`을 한 번 호출합니다.

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

await AuthApi.initSocial();
```

초기화 함수는 중복 호출을 방지하도록 구현되어 있습니다.

현재 구현에서는 웹 환경일 경우 네이티브 Kakao 및 Google SDK 초기화 과정을 건너뜁니다.

## 1.2 사용자 상태 조회

`AuthApi`는 현재 로그인한 사용자의 정보와 인증 상태를 조회할 수 있는 정적 getter를 제공합니다.

| 속성 | 반환 타입 | 설명 |
|---|---|---|
| `user` | `User?` | 현재 Firebase 로그인 사용자 |
| `uid` | `String` | 현재 사용자의 UID |
| `isLoggedIn` | `bool` | 로그인 여부 |
| `email` | `String?` | 사용자 이메일 |
| `displayName` | `String` | 사용자 표시 이름 |
| `isEmailVerified` | `bool` | 이메일 인증 완료 여부 |
| `isPasswordUser` | `bool` | 이메일 및 비밀번호 로그인 사용자 여부 |
| `isGoogleUser` | `bool` | Google 로그인 사용자 여부 |
| `isKakaoUser` | `bool` | Kakao 로그인 사용자 여부 |
| `needsEmailVerification` | `bool` | 이메일 인증이 필요한 상태인지 여부 |
| `loginMethodLabel` | `String` | 로그인 방식 표시 문자열 |

`displayName`은 다음 우선순위로 반환됩니다.

1. Firebase에 저장된 표시 이름
2. 이메일 주소의 `@` 앞부분
3. 위 정보가 모두 없으면 `'사용자'`

`uid`는 로그인된 상태에서만 사용할 수 있습니다. 로그아웃 상태에서 접근하면 null이 아닌 사용자 객체를 전제로 하므로 오류가 발생할 수 있습니다.

### 로그인 방식 확인 예시

```dart
if (AuthApi.isPasswordUser) {
  // 이메일 로그인 사용자
} else if (AuthApi.isGoogleUser) {
  // Google 로그인 사용자
} else if (AuthApi.isKakaoUser) {
  // Kakao 로그인 사용자
}
```

## 1.3 사용자 상태 스트림

로그인 상태와 사용자 정보의 변화를 감지하기 위해 두 가지 스트림을 제공합니다.

| 스트림 | 설명 |
|---|---|
| `AuthApi.changes` | 로그인 및 로그아웃 상태 변화 감지 |
| `AuthApi.userChanges` | 로그인 상태와 사용자 프로필 변경 감지 |

사용 예시는 다음과 같습니다.

```dart
Stream<User?> authStream = AuthApi.userChanges;
```

`userChanges`는 표시 이름이나 이메일 인증 상태 등 사용자 정보의 변경도 감지할 수 있습니다.

로그인 상태에 따라 화면을 분기하는 최상위 위젯에서 활용할 수 있습니다.

## 1.4 입력값 검증

`AuthApi`는 회원가입 및 로그인 화면에서 사용할 수 있는 입력값 검증 함수를 제공합니다.

| 함수 | 검증 기준 |
|---|---|
| `validateEmail` | 이메일 필수 입력 및 형식 검사 |
| `validatePassword` | 로그인 비밀번호 필수 입력 |
| `validateNewPassword` | 8자 이상, 영문 및 숫자 포함 |
| `validatePasswordMatch` | 비밀번호와 비밀번호 확인 일치 여부 |
| `validateName` | 이름 필수 입력 및 최대 20자 제한 |

모든 검증 함수는 Flutter `TextFormField`의 `validator`에 사용할 수 있도록 `String?`을 반환합니다.

### 이메일 검증

```dart
TextFormField(
  validator: AuthApi.validateEmail,
)
```

### 비밀번호 검증

```dart
TextFormField(
  validator: AuthApi.validateNewPassword,
)
```

### 비밀번호 확인 검증

```dart
TextFormField(
  validator: AuthApi.validatePasswordMatch(
    () => passwordController.text,
  ),
)
```

### 이름 검증

```dart
TextFormField(
  validator: AuthApi.validateName,
)
```

**주의사항**

`validatePassword()`와 `validateNewPassword()`는 용도가 다릅니다.

- `validatePassword()`는 로그인 시 비밀번호가 입력되었는지만 검사합니다.
- `validateNewPassword()`는 신규 가입 및 비밀번호 변경 시 8자 이상, 영문과 숫자 포함 여부를 검사합니다.

기존에 짧은 비밀번호를 사용하던 계정도 로그인할 수 있도록 로그인 검증에는 신규 비밀번호 정책을 적용하지 않습니다.

## 1.5 이메일 회원가입

`AuthApi.signUp()`을 사용하여 이메일 기반 회원가입을 수행합니다.

```dart
await AuthApi.signUp(
  email,
  password,
  name: '홍길동',
  sendVerification: true,
);
```

### 매개변수

| 매개변수 | 타입 | 필수 여부 | 설명 |
|---|---|---|---|
| `email` | `String` | 필수 | 가입할 이메일 |
| `password` | `String` | 필수 | 가입 비밀번호 |
| `name` | `String?` | 선택 | 사용자 표시 이름 |
| `sendVerification` | `bool` | 선택 | 가입 후 인증 메일 발송 여부 |

`sendVerification`의 기본값은 `true`입니다.

### 처리 과정

1. 이메일 앞뒤 공백을 제거하고 소문자로 변환합니다.
2. Firebase Authentication을 통해 계정을 생성합니다.
3. 회원가입이 완료되면 자동 로그인됩니다.
4. 이름이 전달되었다면 Firebase 사용자 표시 이름을 설정합니다.
5. `sendVerification`이 `true`라면 이메일 인증 메일을 발송합니다.

이름 변경이나 인증 메일 발송 과정에서 오류가 발생하더라도 회원가입 자체를 실패 처리하지 않습니다. 해당 작업은 추후 다시 수행할 수 있습니다.

## 1.6 이메일 로그인

`AuthApi.signIn()`을 사용합니다.

```dart
await AuthApi.signIn(
  email,
  password,
);
```

이메일은 앞뒤 공백 제거 및 소문자 변환 후 Firebase Authentication에 전달됩니다.

로그인 성공 시 Firebase Authentication에 사용자 인증 상태가 반영됩니다.

## 1.7 로그아웃

```dart
await AuthApi.signOut();
```

소셜 SDK가 초기화된 네이티브 환경에서는 Google 및 Kakao SDK 로그아웃을 시도한 다음 Firebase Authentication 로그아웃을 수행합니다.

소셜 SDK 로그아웃 과정에서 발생한 오류는 무시하고 Firebase 로그아웃을 진행합니다.

## 1.8 Google 로그인

Google 로그인을 위해 `AuthApi.signInWithGoogle()`을 사용합니다.

```dart
final success = await AuthApi.signInWithGoogle();

if (success) {
  // 로그인 성공
} else {
  // 사용자가 로그인 취소
}
```

### 반환값

| 반환값 | 의미 |
|---|---|
| `true` | 로그인 성공 |
| `false` | 사용자가 로그인 취소 |
| 예외 발생 | 로그인 처리 중 오류 |

웹 환경에서는 Google 로그인 팝업을 사용하며, Android 및 iOS에서는 Google Sign-In SDK를 통해 인증 정보를 가져옵니다.

Google 로그인은 Firebase Authentication의 Google 인증 방식으로 최종 로그인합니다.

## 1.9 Kakao 로그인

Kakao 로그인을 위해 `AuthApi.signInWithKakao()`를 사용합니다.

```dart
final success = await AuthApi.signInWithKakao();
```

### 처리 과정

1. Kakao SDK를 통해 Access Token을 획득합니다.
2. Kakao Access Token을 Firebase Cloud Function에 전달합니다.
3. Cloud Function에서 Kakao 사용자 인증을 수행합니다.
4. 서버로부터 Firebase Custom Token을 전달받습니다.
5. Firebase Authentication의 Custom Token 로그인 기능으로 최종 로그인합니다.

Kakao 로그인 성공 시 `true`를 반환합니다.

현재 구현은 로그인 과정에서 발생한 오류를 `ApiException` 등으로 전달합니다. Google 로그인과 달리 사용자 취소를 별도의 `false` 반환값으로 처리하지는 않습니다.

## 1.10 비밀번호 재설정

로그인하지 않은 사용자도 이메일을 통해 비밀번호 재설정 메일을 요청할 수 있습니다.

```dart
await AuthApi.sendPasswordReset(email);
```

전달된 이메일은 앞뒤 공백 제거 및 소문자 변환 후 Firebase Authentication에 전달됩니다.

## 1.11 이메일 인증

### 인증 메일 발송

```dart
await AuthApi.sendEmailVerification();
```

현재 로그인한 사용자의 이메일 주소로 인증 메일을 발송합니다.

로그인하지 않은 상태라면 `ApiException`이 발생합니다.

### 인증 완료 여부 확인

```dart
final verified = await AuthApi.checkEmailVerified();

if (verified) {
  // 이메일 인증 완료
} else {
  // 이메일 인증 미완료
}
```

서버에서 최신 사용자 정보를 다시 불러온 후 이메일 인증 여부를 반환합니다.

인증 안내 화면의 '인증했어요' 버튼 등에 사용할 수 있습니다.

## 1.12 계정 정보 관리

### 사용자 정보 새로고침

```dart
await AuthApi.reload();
```

Firebase 서버에서 최신 사용자 정보를 다시 가져옵니다.

### 표시 이름 변경

```dart
await AuthApi.updateDisplayName('새 이름');
```

이름 앞뒤 공백을 제거한 뒤 Firebase 사용자 프로필을 변경하고 최신 정보를 다시 불러옵니다.

### 본인 재인증

민감한 계정 작업을 수행하기 전에 본인 확인이 필요한 경우 사용합니다.

```dart
await AuthApi.reauthenticate(
  password: currentPassword,
);
```

현재 구현 기준으로 다음과 같이 처리됩니다.

- 이메일 로그인: 현재 비밀번호를 이용한 재인증
- Google 로그인: Google 인증을 다시 수행
- Kakao 로그인: 지원하지 않음

Google 웹 환경에서는 인증 팝업을 사용하고, 네이티브 환경에서는 Google Sign-In SDK를 통해 인증 정보를 다시 가져옵니다.

### 비밀번호 변경

```dart
await AuthApi.changePassword(
  currentPassword,
  newPassword,
);
```

이메일 로그인 사용자만 사용할 수 있습니다.

처리 과정은 다음과 같습니다.

1. 이메일 로그인 사용자인지 확인합니다.
2. 현재 비밀번호를 이용하여 본인 재인증을 수행합니다.
3. Firebase Authentication에 신규 비밀번호를 반영합니다.

Google 및 Kakao 로그인 사용자는 이 기능을 사용할 수 없습니다.

## 1.13 오류 처리

`AuthApi.errorMessage()`는 인증 및 데이터 처리 과정에서 발생한 예외를 사용자에게 표시할 수 있는 한국어 메시지로 변환합니다.

```dart
try {
  await AuthApi.signIn(email, password);
} catch (e) {
  final message = AuthApi.errorMessage(e);

  // message를 SnackBar 또는 Dialog에 표시
}
```

주요 오류 처리 항목은 다음과 같습니다.

| 오류 상황 | 사용자 메시지 |
|---|---|
| 잘못된 이메일 형식 | 이메일 형식이 올바르지 않아요 |
| 계정이 존재하지 않거나 비밀번호 오류 | 이메일 또는 비밀번호가 맞지 않아요 |
| 이미 가입된 이메일 | 이미 가입된 이메일이에요 |
| 비밀번호가 너무 약함 | 비밀번호가 너무 약해요 |
| 사용 중지된 계정 | 사용이 중지된 계정이에요 |
| 재로그인 필요 | 보안을 위해 다시 로그인한 뒤 시도해주세요 |
| 네트워크 오류 | 네트워크 연결을 확인해주세요 |
| 요청 횟수 초과 | 시도가 너무 많아요. 잠시 후 다시 해주세요 |

`ApiException`, `GoogleSignInException`, `FirebaseAuthException`, `FirebaseException` 등을 구분하여 처리합니다.

위 표에 없는 오류는 예외에 포함된 메시지를 반환하거나 기본 오류 메시지를 반환합니다.

# 2. AccountApi

`AccountApi`는 사용자 계정과 관련된 복합 작업을 처리하는 모듈입니다.

현재 구현에서는 회원 탈퇴 기능을 제공합니다. 회원 탈퇴 시 인증 확인, 여행 및 지출 데이터 삭제, Firebase Authentication 계정 삭제를 순차적으로 수행합니다.

## 2.1 회원 탈퇴

`AccountApi.deleteAccount()`를 사용하여 회원 탈퇴를 수행합니다.

```dart
// 이메일 로그인 사용자
await AccountApi.deleteAccount(
  password: currentPassword,
);

// Google 로그인 사용자
await AccountApi.deleteAccount();
```

### 매개변수

| 매개변수 | 타입 | 필수 여부 | 설명 |
|---|---|---|---|
| `password` | `String?` | 선택 | 이메일 로그인 사용자의 현재 비밀번호 |

### 처리 과정

회원 탈퇴는 다음 순서로 진행됩니다.

1. `AuthApi.reauthenticate()`를 호출하여 본인 인증을 수행합니다.
2. `TripApi.deleteAll()`을 호출하여 해당 사용자의 모든 여행 및 지출 데이터를 삭제합니다.
3. `AuthApi.user!.delete()`를 호출하여 Firebase Authentication 계정을 삭제합니다.

### 로그인 방식별 처리

| 로그인 방식 | 처리 방법 |
|---|---|
| 이메일 로그인 | 현재 비밀번호를 전달하여 본인 인증 |
| Google 로그인 | 비밀번호 없이 호출하며 Google 재인증 수행 |
| Kakao 로그인 | 현재 재인증 미지원 |

### 주의사항

- 반드시 본인 인증을 먼저 수행합니다.
- 본인 인증에 실패하면 여행 및 지출 데이터 삭제는 진행되지 않습니다.
- 데이터 삭제가 완료된 이후 Firebase Authentication 계정을 삭제합니다.
- 현재 구현은 세 단계를 하나의 트랜잭션으로 처리하지 않습니다. 따라서 데이터 삭제 도중 오류가 발생하면 일부 데이터가 삭제된 상태로 남을 가능성이 있습니다.
- Kakao 계정은 현재 `AuthApi.reauthenticate()`에서 지원하지 않으므로 회원 탈퇴도 정상적으로 진행할 수 없습니다.


### 3. TripApi

`TripApi`는 로그인한 사용자의 여행 데이터를 관리하는 API입니다. 여행 목록 및 개별 여행 조회, 여행 생성·수정·삭제 기능을 제공합니다.

여행 데이터는 `Trip` 모델을 사용하며, Firestore 컬렉션 경로는 `Paths.trips`를 통해 가져옵니다.

#### 3.1. 여행 목록 실시간 조회

```dart
static Stream<List<Trip>> watchAll()
```

- 현재 사용자의 모든 여행 목록을 실시간으로 조회합니다.
- 여행 시작일(`start`)을 기준으로 내림차순 정렬합니다. 즉, 시작일이 최근인 여행이 먼저 표시됩니다.
- 데이터가 변경되면 새로운 `List<Trip>`을 전달합니다.
- 각 Firestore 문서는 `Trip.fromDoc`을 통해 `Trip` 객체로 변환됩니다.

사용 예시:

```dart
TripApi.watchAll().listen((trips) {
  // 여행 목록 처리
});
```

#### 3.2. 개별 여행 실시간 조회

```dart
static Stream<Trip?> watch(String tripId)
```

**매개변수**
- `tripId`: 조회할 여행의 문서 ID

**반환값**
- `Stream<Trip?>`: 여행 데이터가 변경될 때마다 `Trip` 객체를 전달합니다.
- 해당 여행 문서가 존재하지 않으면 `null`을 전달합니다.

여행이 수정되거나 삭제되는 상황을 실시간으로 반영해야 할 때 사용합니다.

#### 3.3. 개별 여행 한 번만 조회

```dart
static Future<Trip?> get(String tripId)
```

**매개변수**
- `tripId`: 조회할 여행의 문서 ID

**반환값**
- `Future<Trip?>`: 조회한 여행의 `Trip` 객체
- 해당 문서가 존재하지 않으면 `null`

`watch()`와 달리 실시간으로 변경 사항을 구독하지 않고, 호출 시점의 데이터만 한 번 가져옵니다.

#### 3.4. 여행 추가

```dart
static Future<String> add({
  required String name,
  required int budget,
  required String currency,
  required DateTime start,
  required DateTime end,
})
```

**매개변수**
- `name`: 여행 이름
- `budget`: 여행 예산
- `currency`: 예산 통화 코드
- `start`: 여행 시작일
- `end`: 여행 종료일

**반환값**
- `Future<String>`: Firestore에서 생성된 여행 문서 ID(`tripId`)

내부적으로 전달받은 값으로 `Trip` 객체를 생성한 다음, `toMap()`을 호출하여 Firestore에 저장합니다.

- 여행 이름은 저장 전에 `trim()`을 적용하여 앞뒤 공백을 제거합니다.
- 새 `Trip` 객체의 `id`는 빈 문자열로 설정하며, 실제 문서 ID는 Firestore가 생성합니다.
- 예산이나 여행 기간 등에 대한 별도 유효성 검사는 이 메서드에서 수행하지 않습니다.

#### 3.5. 여행 정보 수정

```dart
static Future<void> update(Trip trip)
```

**매개변수**
- `trip`: 수정할 여행 정보를 담은 `Trip` 객체

전달받은 `Trip` 객체의 `id`를 문서 ID로 사용하여 해당 여행 문서를 수정합니다.

`trip.toMap()`으로 변환한 데이터를 Firestore의 `update()`에 전달합니다.

여행 이름, 예산, 통화, 여행 기간 등 `Trip` 모델에 포함된 정보를 수정할 때 사용합니다.

#### 3.6. 여행 예산만 수정

```dart
static Future<void> updateBudget(String tripId, int budget)
```

**매개변수**
- `tripId`: 예산을 변경할 여행의 문서 ID
- `budget`: 변경할 예산

해당 여행 문서의 `budget` 필드만 수정합니다.

다른 여행 정보는 변경하지 않으므로 예산만 수정할 때 사용합니다.

#### 3.7. 여행 삭제

```dart
static Future<void> delete(String tripId)
```

**매개변수**
- `tripId`: 삭제할 여행의 문서 ID

여행 문서만 삭제하는 것이 아니라, 해당 여행에 연결된 지출 내역도 먼저 삭제합니다.

**처리 순서**

1. 해당 여행의 `expenses` 하위 컬렉션에서 지출 문서를 조회합니다.
2. 지출 문서를 최대 400개씩 나누어 Firestore 배치 삭제를 수행합니다.
3. 모든 지출 문서 삭제가 완료되면 여행 문서를 삭제합니다.

Firestore의 배치 쓰기 제한을 고려하여 한 번에 최대 400개의 문서를 삭제하도록 구현되어 있습니다.

주의 사항:
- 지출 내역 삭제 중 오류가 발생하면 여행 문서 삭제까지 진행되지 않습니다.
- 이 메서드는 `expenses` 하위 컬렉션의 문서만 삭제합니다. 지출 문서 아래에 별도의 하위 컬렉션이 존재한다면 해당 데이터까지 재귀적으로 삭제하지는 않습니다.
- 삭제 작업 전체가 하나의 트랜잭션으로 처리되는 것은 아닙니다.

#### 3.8. 모든 여행 삭제

```dart
static Future<void> deleteAll()
```

**반환값**
- `Future<void>`

현재 사용자의 모든 여행을 삭제합니다.

내부적으로 다음 순서로 처리합니다.

1. 현재 사용자의 여행 문서를 모두 조회합니다.
2. 각 여행 문서에 대해 `delete(tripId)`를 순차적으로 호출합니다.
3. 각 여행의 지출 내역을 삭제한 다음 여행 문서를 삭제합니다.

회원 탈퇴 과정에서 `AccountApi.deleteAccount()`가 호출하는 메서드입니다.

주의 사항:
- 여러 여행을 순차적으로 삭제하므로 여행 수와 지출 문서 수에 따라 처리 시간이 달라질 수 있습니다.
- 중간에 삭제 오류가 발생하면 이후 여행의 삭제는 진행되지 않습니다.
- 전체 삭제 작업이 하나의 트랜잭션으로 묶여 있지는 않습니다.

#### 3.9. 사용 시 주의 사항

- `watchAll()`과 `watch()`는 실시간 구독이므로 화면에서 사용한 경우 화면이 종료될 때 Stream 구독이 적절히 해제되도록 관리해야 합니다.
- `get()`은 일회성 조회이므로 실시간 데이터 갱신이 필요하지 않은 경우 사용합니다.
- `add()`와 `update()`는 입력값에 대한 별도 유효성 검사를 수행하지 않으므로 필요한 검증은 호출하는 화면 또는 별도의 로직에서 처리해야 합니다.
- 여행 삭제 시 지출 내역도 함께 삭제되므로 삭제 전 사용자 확인 절차를 두는 것이 좋습니다.

### 4. ExpenseApi

`ExpenseApi`는 특정 여행에 연결된 지출 데이터를 관리하는 API입니다. 지출 목록 조회, 지출 추가·수정·삭제 및 삭제한 지출 복원 기능을 제공합니다.

지출 데이터는 `Expense` 모델을 사용하며, Firestore 컬렉션 경로는 `Paths.expenses(tripId)`를 통해 가져옵니다.

#### 4.1. 지출 목록 실시간 조회

```dart
static Stream<List<Expense>> watchAll(String tripId)
```

**매개변수**
- `tripId`: 지출 목록을 조회할 여행의 문서 ID

**반환값**
- `Stream<List<Expense>>`: 해당 여행의 지출 목록

지출 날짜(`date`)를 기준으로 내림차순 정렬하여 최근 결제 내역이 먼저 표시되도록 합니다.

Firestore 데이터가 변경되면 새로운 지출 목록을 전달하며, 각 문서는 `Expense.fromDoc`을 통해 `Expense` 객체로 변환됩니다.

#### 4.2. 지출 추가

```dart
static Future<void> add(
  String tripId, {
  required String category,
  required String place,
  required double amount,
  required String currency,
  String paymentMethod = 'cash',
  DateTime? date,
})
```

**매개변수**
- `tripId`: 지출을 추가할 여행의 문서 ID
- `category`: 지출 카테고리
- `place`: 지출 장소 또는 사용처
- `amount`: 지출 금액
- `currency`: 지출에 사용한 통화 코드
- `paymentMethod`: 결제 수단. 기본값은 `'cash'`이며 `'card'`도 사용할 수 있습니다.
- `date`: 지출 날짜 및 시간. 생략하면 현재 시각을 사용합니다.

**반환값**
- `Future<void>`

지출을 추가할 때 다음 과정을 수행합니다.

1. 결제 수단이 `'cash'` 또는 `'card'`인지 검사합니다.
2. `RateApi.krwPer(currency)`를 호출하여 해당 통화의 현재 원화 환산 환율을 가져옵니다.
3. 환율이 0 이하이면 `ApiException`을 발생시킵니다.
4. 입력받은 정보와 환율을 사용하여 `Expense` 객체를 생성합니다.
5. `toMap()`으로 변환한 데이터를 Firestore에 저장합니다.

**중요 사항**
- `place`는 저장 전에 `trim()`을 적용하여 앞뒤 공백을 제거합니다.
- `date`를 전달하지 않으면 `DateTime.now()`를 사용합니다.
- 환율은 지출을 추가하는 시점에 조회하여 해당 지출 데이터에 저장합니다.
- 결제 수단이 `'cash'`, `'card'` 이외의 값이면 다음 예외가 발생합니다.

```dart
throw const ApiException('올바르지 않은 결제수단입니다.');
```

- 환율 정보가 없거나 유효하지 않은 경우 다음 예외가 발생합니다.

```dart
throw const ApiException(
  '환율 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요',
);
```

#### 4.3. 지출 수정

```dart
static Future<void> update(String tripId, Expense expense)
```

**매개변수**
- `tripId`: 지출이 속한 여행의 문서 ID
- `expense`: 수정할 지출 정보를 담은 `Expense` 객체

전달받은 `expense.id`를 문서 ID로 사용하여 해당 지출 문서를 수정합니다.

`expense.toMap()`으로 변환한 데이터를 Firestore의 `update()`에 전달합니다.

**중요 사항**
- 기존 지출 객체에 저장된 환율(`rate`)과 날짜(`date`)를 그대로 유지합니다.
- 현재 환율을 다시 조회하지 않습니다.
- 새로운 환율을 적용하고 싶다면 별도의 환율 조회 및 데이터 변경 로직이 필요합니다.
- 이 메서드 자체에서는 지출 금액이나 카테고리 등의 유효성을 별도로 검사하지 않습니다.

#### 4.4. 지출 삭제

```dart
static Future<void> delete(String tripId, String expenseId)
```

**매개변수**
- `tripId`: 지출이 속한 여행의 문서 ID
- `expenseId`: 삭제할 지출의 문서 ID

해당 여행의 `expenses` 하위 컬렉션에서 지정한 지출 문서를 삭제합니다.

#### 4.5. 지출 복원

```dart
static Future<void> restore(String tripId, Expense expense)
```

**매개변수**
- `tripId`: 지출이 속한 여행의 문서 ID
- `expense`: 복원할 지출 정보를 담은 `Expense` 객체

삭제 취소 기능을 구현하기 위한 메서드입니다.

일반적인 `add()`와 달리 Firestore가 새로운 문서 ID를 생성하도록 하지 않고, 기존 `expense.id`를 문서 ID로 지정하여 데이터를 저장합니다.

내부적으로 `set()`을 사용하므로 다음과 같은 특징이 있습니다.

- 기존 지출과 동일한 ID로 복원합니다.
- 지출에 저장되어 있던 날짜와 환율 등의 정보도 함께 복원합니다.
- 해당 ID의 문서가 이미 존재한다면 기존 데이터를 덮어씁니다.

#### 4.6. 사용 시 주의 사항

- `watchAll()`은 실시간 Stream이므로 화면에서 구독할 경우 화면 종료 시 구독을 해제해야 합니다.
- 지출 추가 시 환율 조회에 실패하면 지출 데이터는 저장되지 않습니다.
- 지출 수정은 기존 환율과 날짜를 유지하므로 과거 지출의 원화 환산 기준이 임의로 바뀌지 않습니다.
- `restore()`는 기존 문서를 덮어쓸 수 있으므로 복원 대상 ID가 이미 사용 중인지 고려해야 합니다.
- `add()`와 `update()`는 금액, 카테고리 등 입력값의 전반적인 유효성을 검사하지 않습니다.

### 5. RateApi

`RateApi`는 여행 장부에서 사용하는 환율 데이터를 관리하는 API입니다.

Firestore의 `rates/current` 문서에서 최신 환율을 가져오며, 가져온 환율은 `SharedPreferences`에 저장하여 캐싱합니다.

Firestore 조회에 실패하면 기존 캐시를 유지하여 네트워크 연결이 불안정한 상황에서도 이전에 저장된 환율을 사용할 수 있도록 구현되어 있습니다.

#### 5.1. 초기화 및 환율 데이터 불러오기

```dart
static Future<void> load({bool force = false})
```

**매개변수**
- `force`: 환율을 강제로 새로 불러올지 여부. 기본값은 `false`입니다.

**반환값**
- `Future<void>`

앱 시작 시 `main()`에서 다음과 같이 호출하여 환율 데이터를 초기화하는 것을 권장합니다.

```dart
await RateApi.load();
```

내부 처리 순서는 다음과 같습니다.

1. `SharedPreferences` 인스턴스를 가져옵니다.
2. 저장된 `rates` 값을 읽어 기존 환율 캐시를 복원합니다.
3. `rates_time` 값을 읽어 마지막 환율 갱신 시각을 복원합니다.
4. Firestore의 `rates/current` 문서를 조회합니다.
5. 문서의 `rates` 필드에서 지원 통화 목록에 해당하는 환율을 추출합니다.
6. 유효한 환율을 `_perKrw`에 반영합니다.
7. `lastUpdated` 필드가 Firestore `Timestamp`이면 해당 시각을 사용하고, 그렇지 않으면 현재 시각을 사용합니다.
8. 새 환율과 갱신 시각을 `SharedPreferences`에 저장합니다.

Firestore 조회에는 최대 10초의 제한 시간이 적용됩니다.

**Firestore 조회 실패 시**
- 기존 캐시가 존재하면 해당 캐시를 그대로 유지합니다.
- 캐시가 없다면 환율 데이터가 없는 상태로 남습니다.
- 이 과정에서 발생한 오류는 외부로 다시 전달하지 않습니다.

**주의 사항**
- 현재 코드에서는 `force` 매개변수를 선언하고 있지만 실제 처리 로직에서 사용하지 않습니다. 따라서 `true`로 전달해도 기본 호출과 동작이 달라지지 않습니다.
- 캐시를 먼저 불러오고 Firestore 조회를 시도하므로, 최신 데이터 조회에 실패해도 기존 환율을 사용할 수 있습니다.
- 캐시 데이터가 손상되어 JSON 변환에 실패하면 해당 캐시를 복원하지 않고 Firestore 조회를 시도합니다.

#### 5.2. 환율 초기화 여부 확인

```dart
static bool get ready
```

**반환값**
- `true`: 사용 가능한 환율 데이터가 존재함
- `false`: 환율 데이터가 존재하지 않음

내부 환율 데이터인 `_perKrw`가 비어 있는지를 기준으로 판단합니다.

따라서 앱에서 환율을 사용하기 전에 초기화 여부를 확인할 수 있습니다.

```dart
if (RateApi.ready) {
  // 환율 계산 가능
}
```

단, `ready`가 `true`라고 해서 반드시 최신 환율이라는 의미는 아닙니다. Firestore 조회에 실패했더라도 기존 캐시가 존재하면 `true`가 될 수 있습니다.

#### 5.3. 환율 마지막 갱신 시각

```dart
static DateTime? lastFetched
```

마지막으로 사용한 환율 데이터의 갱신 시각을 나타냅니다.

- Firestore 문서의 `lastUpdated`가 `Timestamp`이면 해당 시간을 사용합니다.
- `lastUpdated`가 없거나 `Timestamp`가 아니면 현재 시각을 사용합니다.
- Firestore 조회에 실패하면 기존 캐시에서 읽은 `rates_time` 값이 유지됩니다.
- 캐시에도 저장된 시간이 없다면 `null`일 수 있습니다.

화면에서 마지막 환율 갱신 시각을 표시할 때 사용할 수 있습니다.

#### 5.4. 원화 기준 환율 조회

```dart
static double krwPer(String cur)
```

**매개변수**
- `cur`: 환율을 조회할 통화 코드

**반환값**
- `double`: 해당 통화 1단위를 원화로 환산하기 위한 계수
- 환율 데이터가 없거나 0이면 `0`
- 통화 코드가 `KRW`이면 `1`

내부 환율 데이터는 원화 1원당 외국 통화의 양을 기준으로 저장되어 있습니다. 따라서 외국 통화를 원화로 환산할 때는 역수를 계산합니다.

예를 들어 내부 환율 데이터에서 USD가 `0.0007`이라면 다음과 같이 계산됩니다.

```dart
1 / 0.0007
```

즉, `krwPer('USD')`는 USD 1달러를 원화로 환산하기 위한 계수를 반환합니다.

#### 5.5. 현지 통화에서 원화로 환산

```dart
static double toKrw(double amount, String cur)
```

**매개변수**
- `amount`: 현지 통화 금액
- `cur`: 현지 통화 코드

**반환값**
- `double`: 원화로 환산한 금액

현지 통화 금액에 `krwPer(cur)`를 곱하여 원화 금액을 계산합니다.

```dart
final krw = RateApi.toKrw(100, 'USD');
```

환율 데이터가 없는 통화라면 `krwPer()`가 `0`을 반환하므로 결과도 `0`이 됩니다.

#### 5.6. 원화에서 현지 통화로 환산

```dart
static double fromKrw(num krw, String cur)
```

**매개변수**
- `krw`: 원화 금액
- `cur`: 변환할 현지 통화 코드

**반환값**
- `double`: 현지 통화로 환산한 금액

원화 금액을 `krwPer(cur)`로 나누어 현지 통화 금액을 계산합니다.

```dart
final usd = RateApi.fromKrw(100000, 'USD');
```

환율 데이터가 없거나 환율 계수가 `0`이면 나눗셈을 수행하지 않고 `0`을 반환합니다.

#### 5.7. 환율 데이터 및 저장 구조

환율 데이터는 다음 위치에서 관리합니다.

**Firestore**
- 컬렉션: `rates`
- 문서: `current`
- `rates`: 통화별 환율 데이터
- `lastUpdated`: 마지막 환율 갱신 시각

**SharedPreferences**
- `rates`: 환율 데이터를 JSON 문자열로 저장
- `rates_time`: 마지막 환율 갱신 시각을 ISO 8601 문자열로 저장

Firestore에서 가져온 환율은 `currencies` 목록에 포함된 통화만 대상으로 처리합니다. 또한 숫자 형식이면서 0보다 큰 값만 유효한 환율로 반영합니다.

#### 5.8. 사용 시 주의 사항

- 앱 시작 시 `await RateApi.load()`를 호출하여 환율 데이터를 초기화하는 것이 좋습니다.
- `load()`는 Firestore 조회에 실패해도 예외를 외부로 전달하지 않으므로, 호출이 완료되었다고 해서 최신 환율을 가져왔다는 의미는 아닙니다.
- 환율을 사용하기 전에 `RateApi.ready`를 확인하는 것이 좋습니다.
- `krwPer()`는 외국 통화 1단위를 원화로 환산하기 위한 계수를 반환합니다.
- 환율 데이터가 없는 경우 환산 결과가 `0`이 될 수 있으므로, 실제 지출 저장 시에는 반드시 유효한 환율인지 확인해야 합니다.
- `force` 매개변수는 현재 구현에서 사용되지 않으므로 별도의 강제 갱신 기능으로 간주하면 안 됩니다.

### 6. LedgerCalc

`LedgerCalc`는 여행 장부의 금액과 통계를 계산하는 모듈입니다.

Firebase나 Firestore에 직접 접근하지 않는 순수 계산 로직으로 구성되어 있어, 별도의 Firebase 초기화 없이 테스트할 수 있습니다.

계산에는 `Trip`과 `Expense` 모델을 사용하며, 원화 환산이 필요한 경우 `RateApi`를 활용합니다.

#### 6.1. 총 사용액 계산

```dart
static double spentKrw(List<Expense> list)
```

**매개변수**
- `list`: 계산할 지출 목록

**반환값**
- `double`: 전체 지출의 원화 합계

각 지출의 `amountKrw`를 모두 더하여 총 사용액을 계산합니다.

```dart
final spent = LedgerCalc.spentKrw(expenses);
```

지출 금액은 각 지출 객체에 저장된 환율을 반영한 원화 금액을 기준으로 합산합니다.

#### 6.2. 남은 예산 계산

```dart
static double remainingKrw(Trip trip, List<Expense> list)
```

**매개변수**
- `trip`: 예산을 계산할 여행 객체
- `list`: 해당 여행의 지출 목록

**반환값**
- `double`: 남은 예산(원)

여행 예산에서 총 사용액을 차감하여 계산합니다.

- 양수: 예산이 남아 있음
- 0: 예산을 모두 사용함
- 음수: 예산을 초과함

```dart
final remaining = LedgerCalc.remainingKrw(trip, expenses);
```

#### 6.3. 현지 통화 기준 남은 예산 계산

```dart
static double remainingLocal(Trip trip, List<Expense> list)
```

**매개변수**
- `trip`: 여행 객체
- `list`: 해당 여행의 지출 목록

**반환값**
- `double`: 현재 환율 기준으로 환산한 현지 통화 잔여 예산

먼저 `remainingKrw()`로 원화 기준 잔여 예산을 계산한 다음, `RateApi.fromKrw()`를 사용하여 여행에 설정된 통화(`trip.currency`)로 변환합니다.

```dart
final remaining = LedgerCalc.remainingLocal(trip, expenses);
```

**주의 사항**
- 지출 합계는 각 지출에 저장된 환율을 기준으로 계산합니다.
- 남은 예산을 현지 통화로 변환할 때는 현재 `RateApi`에 로드된 환율을 사용합니다.
- 따라서 지출 기록 당시의 환율과 현재 환율이 다르면 현지 통화 기준 잔여 예산은 달라질 수 있습니다.

#### 6.4. 예산 사용 비율 계산

```dart
static double usedRatio(Trip trip, List<Expense> list)
```

**매개변수**
- `trip`: 여행 객체
- `list`: 해당 여행의 지출 목록

**반환값**
- `double`: 예산 사용 비율

총 사용액을 여행 예산으로 나누어 계산합니다.

반환값은 `0.0`부터 `1.0` 사이로 제한됩니다.

- `0.0`: 예산 사용 없음
- `0.5`: 예산의 50% 사용
- `1.0`: 예산의 100% 이상 사용

예산이 0 이하인 경우에는 0을 반환합니다.

진행 바 등 예산 사용 정도를 시각적으로 표시할 때 사용할 수 있습니다.

```dart
final ratio = LedgerCalc.usedRatio(trip, expenses);
```

#### 6.5. 예산 초과 여부 확인

```dart
static bool isOverBudget(Trip trip, List<Expense> list)
```

**매개변수**
- `trip`: 여행 객체
- `list`: 해당 여행의 지출 목록

**반환값**
- `true`: 남은 예산이 0보다 작음
- `false`: 예산을 초과하지 않음

`remainingKrw()`의 결과가 음수인지 확인합니다.

```dart
if (LedgerCalc.isOverBudget(trip, expenses)) {
  // 예산 초과 상태 처리
}
```

예산을 정확히 모두 사용한 경우에는 `false`를 반환합니다.

#### 6.6. 카테고리별 사용액 계산

```dart
static Map<String, double> byCategory(List<Expense> list)
```

**매개변수**
- `list`: 계산할 지출 목록

**반환값**
- `Map<String, double>`: 카테고리를 키로, 해당 카테고리의 원화 지출 합계를 값으로 가지는 Map

각 지출의 카테고리를 기준으로 `amountKrw`를 합산합니다.

```dart
final categoryTotals = LedgerCalc.byCategory(expenses);
```

반환되는 Map의 예시는 다음과 같습니다.

```dart
{
  'food': 150000,
  'transport': 50000,
  'shopping': 80000,
}
```

차트나 카테고리별 지출 통계를 표시할 때 활용할 수 있습니다.

#### 6.7. 최근 지출 순으로 정렬

```dart
static List<Expense> recentFirst(List<Expense> list)
```

**매개변수**
- `list`: 정렬할 지출 목록

**반환값**
- `List<Expense>`: 날짜 기준 내림차순으로 정렬된 새로운 지출 목록

지출 날짜(`date`)를 기준으로 최근 결제 내역이 먼저 오도록 정렬합니다.

```dart
final sortedExpenses = LedgerCalc.recentFirst(expenses);
```

**주의 사항**
- 원본 리스트를 직접 정렬하지 않고 복사본을 생성한 뒤 정렬합니다.
- 따라서 원본 리스트의 순서는 변경되지 않습니다.

#### 6.8. 사용 시 주의 사항

- `LedgerCalc`는 데이터를 저장하거나 조회하지 않고 전달받은 객체를 바탕으로 계산만 수행합니다.
- 총 사용액과 카테고리별 사용액은 `Expense.amountKrw`를 기준으로 계산합니다.
- `remainingLocal()`은 현재 환율을 사용하므로 환율 데이터가 초기화되지 않았거나 없는 경우 결과가 0이 될 수 있습니다.
- `usedRatio()`는 최대 1.0으로 제한되므로 예산 초과 정도를 별도로 표시하려면 `isOverBudget()` 또는 `remainingKrw()`를 함께 사용해야 합니다.

### 7. ApiException

`ApiException`은 API 처리 과정에서 발생한 오류 중 사용자에게 직접 보여줄 메시지를 전달하기 위한 사용자 정의 예외 클래스입니다.

#### 7.1. 클래스 구조

```dart
class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}
```

**필드**
- `message`: 사용자에게 전달할 오류 메시지입니다.
- `final`로 선언되어 생성 후 변경할 수 없습니다.

**생성자**
```dart
const ApiException(this.message);
```

오류 메시지를 전달하여 예외 객체를 생성합니다. `const` 생성자를 지원하므로 컴파일 타임 상수로도 생성할 수 있습니다.

#### 7.2. 사용 예시

API 내부에서 특정 상황에 대한 오류를 발생시킬 때 사용합니다.

```dart
throw const ApiException('올바르지 않은 결제수단입니다.');
```

예외를 처리할 때는 `message`를 통해 오류 메시지를 가져올 수 있습니다.

```dart
try {
  await ExpenseApi.add(
    tripId,
    category: 'food',
    place: 'Restaurant',
    amount: 100,
    currency: 'USD',
  );
} on ApiException catch (e) {
  print(e.message);
}
```

#### 7.3. toString()

```dart
@override
String toString() => message;
```

예외 객체를 문자열로 변환하면 별도의 예외 클래스명이나 부가 정보 없이 `message`에 저장된 내용만 반환합니다.

따라서 `print(e)`와 같이 예외 객체를 출력해도 사용자에게 전달할 오류 메시지를 확인할 수 있습니다.

#### 7.4. 사용 시 주의 사항

- `ApiException`은 오류 메시지를 보관하고 전달하는 역할만 수행합니다.
- Firebase 오류나 네트워크 오류 등을 자동으로 변환하지는 않습니다.
- 예외를 발생시키는 API에서 적절한 메시지를 전달해야 합니다.
- 화면에서는 `catch` 또는 `on ApiException catch`를 사용하여 예외를 처리할 수 있습니다.
- `AuthApi.errorMessage()`와 같이 다른 예외까지 사용자 메시지로 변환하는 별도 메서드가 존재할 수 있으므로 용도에 맞게 사용해야 합니다.

### 8. Paths

`Paths`는 Firestore 데이터베이스의 컬렉션 및 문서 경로를 관리하는 클래스입니다.

Firestore 경로를 한곳에서 관리하여 각 API가 동일한 데이터 구조를 사용하도록 합니다.

#### 8.1. Firestore 데이터 구조

현재 프로젝트에서는 사용자별로 여행 데이터를 분리하여 저장합니다.

```text
users/
 └── {uid}/
      └── trips/
           └── {tripId}/
                └── expenses/
                     └── {expenseId}/
```

- `users/{uid}`: 사용자 문서
- `trips/{tripId}`: 해당 사용자의 여행 문서
- `expenses/{expenseId}`: 특정 여행에 속한 지출 문서

#### 8.2. 클래스 구조

```dart
class Paths {
  Paths._();
}
```

생성자를 private으로 선언하여 외부에서 `Paths` 객체를 생성하지 못하도록 합니다.

모든 경로는 `static` 멤버로 제공하므로 객체 생성 없이 접근할 수 있습니다.

#### 8.3. 여행 컬렉션 경로

```dart
static CollectionReference<Map<String, dynamic>> get trips =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(AuthApi.uid)
        .collection('trips');
```

현재 로그인한 사용자의 여행 컬렉션을 반환합니다.

**반환값**
- `CollectionReference<Map<String, dynamic>>`: 사용자별 여행 컬렉션 참조

`AuthApi.uid`를 사용하여 현재 로그인한 사용자의 UID를 가져옵니다.

예를 들어 사용자 UID가 `user123`이라면 다음 경로를 참조합니다.

```text
users/user123/trips
```

사용 예시:

```dart
final trips = Paths.trips;
```

#### 8.4. 지출 컬렉션 경로

```dart
static CollectionReference<Map<String, dynamic>> expenses(String tripId) =>
    trips.doc(tripId).collection('expenses');
```

특정 여행에 속한 지출 컬렉션을 반환합니다.

**매개변수**
- `tripId`: 지출 컬렉션을 가져올 여행의 문서 ID

**반환값**
- `CollectionReference<Map<String, dynamic>>`: 해당 여행의 지출 컬렉션 참조

예를 들어 현재 로그인한 사용자의 UID가 `user123`이고 여행 ID가 `trip456`이라면 다음 경로를 참조합니다.

```text
users/user123/trips/trip456/expenses
```

사용 예시:

```dart
final expenses = Paths.expenses(tripId);
```

#### 8.5. 사용 시 주의 사항

- `Paths.trips`와 `Paths.expenses()`는 Firestore 데이터를 직접 조회하거나 수정하지 않고 경로 참조만 반환합니다.
- 사용자 UID는 `AuthApi.uid`에서 가져오므로 해당 경로를 사용하기 전에 로그인되어 있어야 합니다.
- 로그인하지 않은 상태에서 `AuthApi.uid`를 호출하면 오류가 발생할 수 있습니다.
- 다른 사용자의 데이터에 접근하려면 별도의 경로가 필요하지만, 현재 구현은 로그인한 사용자 본인의 데이터 경로만 제공합니다.
- 여행 및 지출 관련 API에서는 직접 Firestore 경로를 구성하지 않고 `Paths`를 사용하여 데이터 경로를 일관되게 관리합니다.

### 9. SocialConfig

`SocialConfig`는 소셜 로그인에 필요한 외부 서비스 설정값을 관리하는 클래스입니다.

현재 Kakao 네이티브 앱 키와 Google 웹 클라이언트 ID를 정적 상수로 보관합니다.

#### 9.1. 클래스 구조

```dart
class SocialConfig {
  SocialConfig._();
}
```

생성자를 private으로 선언하여 외부에서 객체를 생성하지 못하도록 합니다.

모든 설정값은 `static const`로 선언되어 객체 생성 없이 접근할 수 있습니다.

#### 9.2. Kakao 네이티브 앱 키

```dart
static const String kakaoNativeAppKey = '...';
```

Kakao SDK 초기화에 사용하는 네이티브 앱 키입니다.

`AuthApi.initSocial()`에서 다음과 같이 사용합니다.

```dart
KakaoSdk.init(
  nativeAppKey: SocialConfig.kakaoNativeAppKey,
);
```

Kakao 개발자 콘솔에서 발급받은 네이티브 앱 키를 사용합니다.

#### 9.3. Google 웹 클라이언트 ID

```dart
static const googleServerClientId = '';
```

Google 로그인에 사용하는 웹 클라이언트 ID입니다.

Firebase 콘솔의 다음 위치에서 확인할 수 있습니다.

`Authentication → Sign-in method → Google → 웹 SDK 구성`

- 웹 클라이언트 ID를 지정하면 해당 값을 Google SDK 초기화에 전달합니다.
- 빈 문자열이면 `AuthApi.initSocial()`에서 `null`로 처리하여 별도의 클라이언트 ID를 전달하지 않습니다.
- 현재 프로젝트에서는 빈 문자열로 설정되어 있습니다.

#### 9.4. 사용 시 주의 사항

- 소셜 로그인 설정값은 `AuthApi`에서 참조하므로 화면에서 직접 접근할 필요가 없습니다.
- `static const`로 선언되어 실행 중 값을 변경할 수 없습니다.
- 실제 서비스에 사용하는 앱 키와 클라이언트 ID는 각 플랫폼 및 Firebase 설정과 일치해야 합니다.
- 현재 코드 주석에는 Google만 사용한다고 되어 있지만, Kakao 설정값도 존재하며 `AuthApi`에는 Kakao 로그인 구현도 포함되어 있습니다.

### 10. Trip 모델

`Trip`은 하나의 여행 정보를 표현하는 데이터 모델입니다.

Firestore의 `users/{uid}/trips/{tripId}` 문서에 대응하며, 여행 이름, 예산, 현지 통화 및 여행 기간을 관리합니다.

#### 10.1. 필드 구성

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | `String` | 여행 문서 ID |
| `name` | `String` | 여행 이름 |
| `budget` | `int` | 여행 예산(원화, KRW) |
| `currency` | `String` | 여행에서 사용하는 현지 통화 코드 |
| `start` | `DateTime` | 여행 시작일 |
| `end` | `DateTime` | 여행 종료일 |

**중요 사항**
- `budget`은 원화 정수로 관리합니다.
- `currency`는 현지 통화 코드를 별도로 보관합니다.
- `id`는 Firestore 문서 ID에 대응하며, `toMap()`에는 포함되지 않습니다.

#### 10.2. 생성자

```dart
const Trip({
  required this.id,
  required this.name,
  required this.budget,
  required this.currency,
  required this.start,
  required this.end,
});
```

모든 필드를 필수 매개변수로 전달해야 합니다.

`const` 생성자를 지원하며, 모든 필드는 `final`로 선언되어 생성 이후 직접 변경할 수 없습니다.

#### 10.3. copyWith()

```dart
Trip copyWith({
  String? name,
  int? budget,
  String? currency,
  DateTime? start,
  DateTime? end,
})
```

기존 `Trip` 객체를 바탕으로 일부 필드만 변경한 새로운 객체를 생성합니다.

변경하지 않을 필드는 기존 값을 유지합니다.

```dart
final updatedTrip = trip.copyWith(
  name: '도쿄 여행',
  budget: 1000000,
);
```

**주의 사항**
- `id`는 기존 객체의 값을 그대로 유지합니다.
- 원본 객체는 변경되지 않습니다.
- 현재 구현에서는 `null`을 전달하여 기존 필드 값을 null로 변경할 수 없습니다.

#### 10.4. toMap()

```dart
Map<String, dynamic> toMap()
```

`Trip` 객체를 Firestore에 저장할 수 있는 Map 형태로 변환합니다.

저장되는 필드는 다음과 같습니다.

```dart
{
  'name': name,
  'budget': budget,
  'currency': currency,
  'start': Timestamp.fromDate(start),
  'end': Timestamp.fromDate(end),
}
```

`DateTime` 타입인 `start`, `end`는 Firestore에서 사용할 수 있도록 `Timestamp`로 변환합니다.

`id`는 Map에 포함하지 않습니다. 문서 ID는 Firestore 문서 경로에서 별도로 관리합니다.

#### 10.5. fromDoc()

```dart
factory Trip.fromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
)
```

Firestore 문서를 `Trip` 객체로 변환하는 팩토리 생성자입니다.

**변환 과정**
- `id`: `doc.id`에서 가져옵니다.
- `name`: 값이 없으면 빈 문자열(`''`)을 사용합니다.
- `budget`: 값이 없으면 `0`을 사용하고, `toInt()`로 정수 변환합니다.
- `currency`: 값이 없으면 `'USD'`를 기본값으로 사용합니다.
- `start`: Firestore `Timestamp`를 `DateTime`으로 변환합니다.
- `end`: Firestore `Timestamp`를 DateTime으로 변환합니다.

#### 10.6. 사용 시 주의 사항

Trip 객체는 불변 데이터 모델이므로 수정할 때는 copyWith()를 활용할 수 있습니다.

toMap()과 fromDoc()은 Firestore 저장 및 조회 과정에서 사용됩니다.

budget은 원화 기준이므로 현지 통화로 표시할 때는 별도의 환산 과정이 필요합니다.

start와 end는 Firestore에서 Timestamp 형식으로 저장되어야 합니다.

fromDoc()은 문서 데이터가 존재한다고 가정하고 doc.data()!를 사용합니다. 또한 start, end가 Timestamp 형식이라고 가정하므로 잘못된 데이터가 저장되어 있으면 변환 중 오류가 발생할 수 있습니다.



### 11. Expense 모델

`Expense`는 여행 중 발생한 개별 지출 정보를 표현하는 데이터 모델입니다.

Firestore의 `users/{uid}/trips/{tripId}/expenses/{expenseId}` 문서에 대응하며, 지출 항목과 금액, 통화, 기록 시점 환율, 결제 수단 등을 관리합니다.

#### 11.1. 필드 구성

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | `String` | 지출 문서 ID |
| `category` | `String` | 지출 카테고리 |
| `place` | `String` | 지출 사용처 |
| `amount` | `double` | 현지 통화 기준 지출 금액 |
| `currency` | `String` | 지출 통화 코드 |
| `rate` | `double` | 기록 시점 환율(현지 통화 1단위당 원화 금액) |
| `date` | `DateTime` | 지출 날짜 및 시간 |
| `paymentMethod` | `String` | 결제 수단(`cash` 또는 `card`) |

**중요 사항**
- `amount`는 현지 통화 기준 금액입니다.
- `rate`는 지출을 기록할 당시 적용된 환율입니다.
- `paymentMethod`는 별도로 지정하지 않으면 `'cash'`가 기본값입니다.
- `id`는 Firestore 문서 ID에 대응하며, `toMap()`에는 포함되지 않습니다.

#### 11.2. 생성자

```dart
const Expense({
  required this.id,
  required this.category,
  required this.place,
  required this.amount,
  required this.currency,
  required this.rate,
  required this.date,
  this.paymentMethod = 'cash',
});
```

`id`, `category`, `place`, `amount`, `currency`, `rate`, `date`는 필수 매개변수입니다.

`paymentMethod`는 선택 매개변수이며, 생략하면 `'cash'`로 설정됩니다.

#### 11.3. amountKrw getter

```dart
double get amountKrw => amount * rate;
```

현지 통화 기준 지출 금액을 원화로 환산하여 반환합니다.

계산식은 다음과 같습니다.

\[
\text{amountKrw} = \text{amount} \times \text{rate}
\]

예를 들어 다음과 같은 지출이 있다면,

```dart
amount: 100.0,
currency: 'USD',
rate: 1400.0,
```

원화 환산 금액은 다음과 같습니다.

```dart
amountKrw // 140000.0
```

별도로 원화 환산 금액을 저장하지 않고, `amount`와 `rate`를 이용해 계산합니다.

#### 11.4. copyWith()

```dart
Expense copyWith({
  String? category,
  String? place,
  double? amount,
  double? rate,
  DateTime? date,
  String? paymentMethod,
})
```

기존 `Expense` 객체를 기반으로 일부 필드만 변경한 새로운 객체를 생성합니다.

```dart
final updatedExpense = expense.copyWith(
  category: '식비',
  amount: 150.0,
);
```

**주의 사항**
- `id`는 기존 값을 유지합니다.
- `currency`는 변경할 수 없으며 기존 값을 유지합니다.
- 변경하지 않은 필드는 기존 값을 유지합니다.
- 원본 객체는 변경되지 않습니다.
- 현재 구현에서는 `null`을 전달하여 기존 값을 null로 변경할 수 없습니다.

#### 11.5. toMap()

```dart
Map<String, dynamic> toMap()
```

`Expense` 객체를 Firestore에 저장할 수 있는 Map 형태로 변환합니다.

저장되는 필드는 다음과 같습니다.

```dart
{
  'category': category,
  'place': place,
  'amount': amount,
  'currency': currency,
  'rate': rate,
  'date': Timestamp.fromDate(date),
  'paymentMethod': paymentMethod,
}
```

`DateTime` 타입인 `date`는 Firestore에서 사용할 수 있도록 `Timestamp`로 변환합니다.

`id`는 Map에 포함하지 않습니다. 문서 ID는 Firestore 문서 경로에서 별도로 관리합니다.

#### 11.6. fromDoc()

```dart
factory Expense.fromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
)
```

Firestore 문서를 `Expense` 객체로 변환하는 팩토리 생성자입니다.

**변환 과정**
- `id`: `doc.id`에서 가져옵니다.
- `category`: 값이 없으면 `'기타'`를 사용합니다.
- `place`: 값이 없으면 빈 문자열(`''`)을 사용합니다.
- `amount`: 값이 없으면 `0`을 사용하고, `toDouble()`로 실수 변환합니다.
- `currency`: 값이 없으면 `'USD'`를 사용합니다.
- `rate`: 값이 없으면 `0`을 사용하고, `toDouble()`로 실수 변환합니다.
- `date`: Firestore `Timestamp`를 `DateTime`으로 변환합니다.
- `paymentMethod`: 값이 없으면 `'cash'`를 사용합니다.

#### 11.7. 사용 시 주의 사항

- 과거 지출의 원화 환산 금액은 저장된 `rate`를 사용하므로 이후 환율 변경의 영향을 받지 않습니다.
- `copyWith()`에서는 통화 코드인 `currency`를 변경할 수 없습니다.
- `amountKrw`는 별도로 저장된 값이 아니라 getter를 통해 계산되는 값입니다.
- `fromDoc()`은 문서 데이터가 존재한다고 가정하고 `doc.data()!`를 사용합니다.
- `date`는 Firestore `Timestamp` 형식으로 저장되어야 합니다.
- `fromDoc()`의 기본값은 누락된 필드에 대한 처리이며, 잘못된 타입의 데이터까지 자동으로 보정하지는 않습니다.

### 12. 공통 상수 및 카테고리 아이콘

`constants.dart`는 앱에서 공통으로 사용하는 통화 목록과 지출 카테고리별 아이콘을 정의하는 파일입니다.

#### 12.1. 지원 통화 목록

```dart
const currencies = [
  'USD', 'JPY', 'EUR', 'CNY',
  'VND', 'THB', 'PHP', 'TWD'
];
```

앱에서 지원하는 주요 여행지 통화 코드입니다.

| 통화 코드 | 통화 |
|---|---|
| USD | 미국 달러 |
| JPY | 일본 엔 |
| EUR | 유로 |
| CNY | 중국 위안 |
| VND | 베트남 동 |
| THB | 태국 바트 |
| PHP | 필리핀 페소 |
| TWD | 대만 달러 |

`RateApi.load()`에서 이 목록을 기준으로 Firestore의 환율 데이터를 필터링합니다.

따라서 목록에 포함되지 않은 통화는 현재 환율 데이터 로딩 과정에서 제외됩니다.

#### 12.2. 카테고리별 대표 아이콘

```dart
const categoryIcons = <String, IconData>{
  '식비': Icons.restaurant,
  '교통': Icons.directions_transit,
  '숙박': Icons.hotel,
  '쇼핑': Icons.shopping_bag,
  '관광': Icons.photo_camera,
  '기타': Icons.more_horiz,
};
```

지출 카테고리 이름을 기준으로 대표 아이콘을 연결하는 Map입니다.

| 카테고리 | 아이콘 |
|---|---|
| 식비 | restaurant |
| 교통 | directions_transit |
| 숙박 | hotel |
| 쇼핑 | shopping_bag |
| 관광 | photo_camera |
| 기타 | more_horiz |

카테고리 이름을 Map의 키로 사용하므로, 지출 데이터의 카테고리 문자열과 일치해야 해당 아이콘을 가져올 수 있습니다.

#### 12.3. iconOfCategory()

```dart
IconData iconOfCategory(String category)
```

카테고리 이름에 해당하는 아이콘을 반환하는 함수입니다.

```dart
IconData iconOfCategory(String category) =>
    categoryIcons[category] ?? Icons.more_horiz;
```

- 등록된 카테고리라면 연결된 아이콘을 반환합니다.
- 등록되지 않은 카테고리라면 `Icons.more_horiz`를 반환합니다.

따라서 새로운 카테고리가 추가되더라도 별도의 예외 처리 없이 기본 아이콘을 표시할 수 있습니다.

#### 12.4. 사용 시 주의 사항

- 새로운 지원 통화를 추가하려면 `currencies` 목록과 Firestore 환율 데이터 구성을 함께 확인해야 합니다.
- 새로운 지출 카테고리를 추가하려면 `categoryIcons`에 카테고리 이름과 아이콘을 등록해야 합니다.
- 카테고리 이름은 문자열로 비교되므로 띄어쓰기나 철자가 다르면 기본 아이콘이 반환됩니다.
- 이 파일은 Flutter Material 라이브러리의 `IconData`와 `Icons`를 사용합니다.

### 13. api.dart – 공용 진입점

`api.dart`는 TRIPER 프로젝트의 팀 공용 진입점입니다.

화면(UI) 코드에서 여러 API 파일을 개별적으로 import하지 않고, `api.dart` 하나만 import하여 필요한 기능을 사용할 수 있도록 구성되어 있습니다.

#### 13.1. 기본 사용 방법

화면 파일에서는 다음과 같이 import합니다.

```dart
import '../api/api.dart';
```

이후 별도의 import 없이 API 클래스와 모델 등을 사용할 수 있습니다.

```dart
final trips = TripApi.watchAll();

final expenses = ExpenseApi.watchAll(tripId);

final user = AuthApi.user;
```

#### 13.2. Export 구성

`api.dart`는 다음 파일들을 외부로 export합니다.

| Export 파일 | 제공 기능 |
|---|---|
| `constants.dart` | 지원 통화 및 카테고리 아이콘 |
| `models/expense.dart` | `Expense` 모델 |
| `models/trip.dart` | `Trip` 모델 |
| `utils/format.dart` | 금액 및 날짜 표시용 포맷 함수 |
| `account_api.dart` | 계정 관련 작업 |
| `api_exception.dart` | API 사용자 정의 예외 |
| `auth_api.dart` | 인증 및 계정 관리 |
| `expense_api.dart` | 지출 데이터 관리 |
| `ledger_calc.dart` | 장부 계산 |
| `rate_api.dart` | 환율 조회 및 환산 |
| `trip_api.dart` | 여행 데이터 관리 |

#### 13.3. 기능별 API 구성

**로그인 및 인증 – AuthApi**
- 이메일 회원가입 및 로그인
- 로그아웃
- Google 및 Kakao 소셜 로그인
- 비밀번호 재설정
- 이메일 인증
- 로그인 상태 및 사용자 정보 조회
- 입력값 검증 및 오류 메시지 변환

**계정 관리 – AccountApi / AuthApi**
- 사용자 이름 변경
- 비밀번호 변경
- 이메일 인증 메일 발송
- 회원 탈퇴 및 사용자 데이터 삭제

**여행 관리 – TripApi**
- 여행 목록 및 개별 여행 조회
- 여행 정보 추가 및 수정
- 여행 예산 수정
- 여행 삭제

**지출 관리 – ExpenseApi**
- 여행별 지출 목록 조회
- 지출 추가 및 수정
- 지출 삭제 및 복원

**환율 관리 – RateApi**
- 환율 데이터 로딩 및 캐싱
- 통화별 원화 환산 환율 조회
- 원화와 현지 통화 간 금액 변환

**장부 계산 – LedgerCalc**
- 총 지출액 계산
- 잔여 예산 계산
- 예산 사용 비율 계산
- 카테고리별 지출 집계
- 날짜순 지출 정렬

**표시 및 포맷 – format.dart**
- 원화 금액 표시
- 현지 통화 금액 표시
- 날짜 표시

#### 13.4. 화면 코드 작성 규칙

화면(UI) 코드에서는 Firebase SDK를 직접 호출하지 않고 API 클래스의 기능을 사용합니다.

예를 들어 Firestore에서 여행 목록을 가져올 때는 다음과 같이 작성합니다.

```dart
StreamBuilder<List<Trip>>(
  stream: TripApi.watchAll(),
  builder: (context, snapshot) {
    // 화면 표시 처리
  },
)
```

지출을 추가할 때도 Firestore를 직접 조작하지 않고 다음과 같이 API를 호출합니다.

```dart
await ExpenseApi.add(
  tripId,
  category: '식비',
  place: '식당',
  amount: 25.0,
  currency: 'USD',
);
```

이러한 구조를 통해 화면 코드와 데이터 처리 로직을 분리하고, Firebase 관련 구현을 API 모듈 내부에서 관리합니다.

**주의 사항**
- 화면에서는 `api/api.dart`만 import하는 것을 기본 규칙으로 합니다.
- Firebase 인증 및 Firestore 작업은 각 API 클래스에 위임합니다.
- API에 정의되지 않은 기능을 화면에서 직접 Firebase SDK로 구현하지 않습니다.
- `api.dart`는 기능을 재수출하는 진입점이며, 자체적으로 데이터 처리 로직을 수행하지 않습니다.
