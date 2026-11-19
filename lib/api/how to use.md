# 여행 장부 앱 – API 사용 가이드

화면(UI)을 만드는 팀원을 위한 문서입니다.
**화면 코드는 `lib/api/api.dart` 하나만 import 해서 쓰고, Firebase는 직접 만지지 않습니다.**

```dart
import '../api/api.dart';   // 로그인, 여행, 지출, 환율, 계산, 표시 도우미가 전부 들어 있음
```

---

## 목차

1. [빠른 시작](#1-빠른-시작)
2. [핵심 규칙](#2-핵심-규칙)
3. [데이터 구조](#3-데이터-구조)
4. [API 레퍼런스](#4-api-레퍼런스)
5. [화면별 사용 레시피](#5-화면별-사용-레시피)
6. [자주 하는 실수](#6-자주-하는-실수)
7. [Firebase 콘솔 체크리스트](#7-firebase-콘솔-체크리스트)
8. [API를 추가/수정할 때](#8-api를-추가수정할-때)

---

## 1. 빠른 시작

### 1-1. 패키지

```powershell
flutter pub add cloud_firestore firebase_auth intl http shared_preferences google_sign_in
```

Windows에서 빌드가 안 되면 **설정 → 개발자 모드**를 켜고 터미널을 다시 여세요.

### 1-2. 폴더 구조

```
lib/
├─ constants.dart          통화 목록, 카테고리 아이콘
├─ models/
│  ├─ trip.dart            Trip 모델
│  └─ expense.dart         Expense 모델
├─ utils/
│  └─ format.dart          won(), localAmt(), dateShort(), dayOnly()
└─ api/
   ├─ api.dart             ★ 화면에서 import 하는 유일한 파일
   ├─ auth_api.dart        로그인/가입/계정
   ├─ account_api.dart     회원 탈퇴
   ├─ trip_api.dart        여행
   ├─ expense_api.dart     지출
   ├─ rate_api.dart        환율
   ├─ ledger_calc.dart     계산
   ├─ api_exception.dart   사용자용 문구가 담긴 예외
   ├─ paths.dart           Firestore 경로 (API 내부용)
   └─ social_config.dart   구글 웹 클라이언트 ID
```

### 1-3. main() 초기화 (앱 시작 시 딱 한 번)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthApi.initSocial();   // 구글 로그인 준비
  await RateApi.load();         // 환율 (하루 1회만 실제 호출, 나머지는 캐시)
  runApp(const MyApp());
}
```

### 1-4. 화면 분기 (로그인 여부)

```dart
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthApi.userChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) return const LoginPage();
        // (선택) 이메일 인증을 강제하려면:
        // if (AuthApi.needsEmailVerification) return const VerifyEmailPage();
        return const HomeShell();
      },
    );
  }
}
```

로그인/로그아웃 후 화면 이동은 **AuthGate가 자동으로** 합니다. 화면에서 `Navigator`로 직접 이동시키지 마세요.

---

## 2. 핵심 규칙

1. **Firestore/FirebaseAuth를 화면에서 직접 호출하지 않는다.** 필요한 기능이 없으면 [8장](#8-api를-추가수정할-때)대로 API에 추가한다.
2. **API 함수는 실패하면 예외를 던진다.** 화면에서 `try/catch` 하고 문구는 `AuthApi.errorMessage(e)`로 만든다. (이름은 Auth지만 모든 API 예외를 처리한다)
3. **로그인된 화면에서만** 여행/지출 API를 호출한다. 로그아웃 상태에서 호출하면 앱이 크래시한다.
4. **`Stream`은 `initState`(또는 `late final` 필드)에서 한 번만 만든다.** `build()` 안에서 만들면 화면이 갱신될 때마다 다시 구독된다.
5. **`await` 뒤에 `context`를 쓰기 전에 `if (!mounted) return;`** 을 확인한다.
6. **금액 단위:** 예산(`Trip.budget`)은 **원화 정수**, 지출(`Expense.amount`)은 **현지 통화 double**, 원화 환산은 `expense.amountKrw`.
7. **날짜/환율은 직접 넣지 않는다.** 지출 추가 시 API가 지금 시각과 현재 환율을 자동으로 채운다.
8. **테스트는 안드로이드/iOS 에뮬레이터나 실기기에서.** Windows 데스크톱 실행에서는 구글 로그인이 동작하지 않는다.

---

## 3. 데이터 구조

### 3-1. Firestore 경로

```
users/{uid}/trips/{tripId}
users/{uid}/trips/{tripId}/expenses/{expenseId}
```

각 사용자는 **자기 `uid` 아래 데이터만** 읽고 쓴다. (경로는 API 내부에서 자동 처리되므로 화면에서 신경 쓸 필요 없음)

### 3-2. `Trip` (여행)

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | `String` | 문서 ID (`LedgerPage(tripId: trip.id)` 처럼 화면 이동에 사용) |
| `name` | `String` | 여행 이름 |
| `budget` | `int` | 예산, **원화(KRW)** |
| `currency` | `String` | 현지 통화 코드. `USD JPY EUR CNY VND THB PHP TWD` 중 하나 |
| `start` / `end` | `DateTime` | 여행 기간 |

`trip.copyWith(name:, budget:, currency:, start:, end:)` 로 일부 값만 바꾼 복사본을 만든다.

### 3-3. `Expense` (지출)

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | `String` | 문서 ID |
| `category` | `String` | `식비 교통 숙박 쇼핑 관광 기타` 중 하나 |
| `place` | `String` | 사용처 |
| `amount` | `double` | **현지 통화** 금액 |
| `currency` | `String` | 결제 통화 (여행의 통화와 같음) |
| `rate` | `double` | **기록 시점 환율** (1 현지통화 = `rate` 원) |
| `date` | `DateTime` | 결제 시각 (기본: 기록한 시각) |
| `amountKrw` | `double` (getter) | `amount × rate`, 원화 환산 금액 |

`expense.copyWith(category:, place:, amount:, rate:, date:)` – 통화(`currency`)는 바꿀 수 없다.

> **환율은 기록 시점 값이 저장됩니다.** 나중에 환율이 바뀌어도 이미 기록한 지출의 원화 금액은 변하지 않습니다.

---

## 4. API 레퍼런스

### 4-1. `AuthApi` – 로그인 / 가입 / 계정

#### 상태 조회

| 이름 | 반환 | 설명 |
|---|---|---|
| `AuthApi.isLoggedIn` | `bool` | 로그인 여부 |
| `AuthApi.uid` | `String` | 사용자 ID (로그인 상태에서만) |
| `AuthApi.email` | `String?` | 이메일 |
| `AuthApi.displayName` | `String` | 표시 이름. 없으면 이메일 앞부분, 그것도 없으면 `'사용자'` |
| `AuthApi.loginMethodLabel` | `String` | `'이메일'` / `'Google'` |
| `AuthApi.isPasswordUser` | `bool` | 이메일 가입자인가 (비밀번호 변경 메뉴 노출 판단) |
| `AuthApi.isGoogleUser` | `bool` | 구글 로그인 사용자인가 |
| `AuthApi.isEmailVerified` | `bool` | 이메일 인증 완료 여부 |
| `AuthApi.needsEmailVerification` | `bool` | 이메일 가입자인데 **아직 인증 안 함** |
| `AuthApi.changes` | `Stream` | 로그인/로그아웃 변화 |
| `AuthApi.userChanges` | `Stream` | 위 + **이름/인증 상태 변경**까지 (**AuthGate와 프로필 화면은 이걸 구독**) |

#### 입력 검증 – `TextFormField(validator: ...)` 에 바로 연결

통과하면 `null`, 실패하면 안내 문구를 반환한다.

| 함수 | 용도 | 규칙 |
|---|---|---|
| `AuthApi.validateEmail` | 이메일 칸 | 비어 있지 않고 형식이 맞아야 함 |
| `AuthApi.validatePassword` | **로그인** 비밀번호 칸 | 비어 있지 않기만 하면 통과 |
| `AuthApi.validateNewPassword` | **가입/비밀번호 변경** 새 비밀번호 칸 | 8자 이상, 영문+숫자 포함 |
| `AuthApi.validatePasswordMatch(() => pwCtrl.text)` | 비밀번호 확인 칸 | 위 비밀번호와 같아야 함 |
| `AuthApi.validateName` | 이름 칸 | 1~20자 |

> 로그인 화면에는 `validatePassword`, 가입 화면에는 `validateNewPassword`를 씁니다. 헷갈리면 기존 사용자가 로그인을 못 하게 됩니다.

#### 가입 / 로그인 / 로그아웃

| 함수 | 설명 |
|---|---|
| `await AuthApi.signUp(email, password, {name, sendVerification = true})` | 이메일 가입. 성공하면 **자동 로그인**되고 인증 메일이 발송된다. 이름 저장/메일 발송이 실패해도 가입은 성공 처리 |
| `await AuthApi.signIn(email, password)` | 이메일 로그인 |
| `final ok = await AuthApi.signInWithGoogle()` | 구글 로그인. **`false` = 사용자가 취소** (오류창 띄우지 말 것) |
| `await AuthApi.signOut()` | 로그아웃 (구글 세션도 정리) |

#### 이메일 인증 / 비밀번호 재설정

| 함수 | 설명 |
|---|---|
| `await AuthApi.sendPasswordReset(email)` | 비밀번호 재설정 메일 발송 (로그인 전 사용 가능) |
| `await AuthApi.sendEmailVerification()` | 인증 메일 (재)발송. 너무 자주 누르면 `too-many-requests` |
| `final ok = await AuthApi.checkEmailVerified()` | 서버에서 최신 상태를 읽어 인증 완료 여부 반환 ("인증했어요" 버튼용) |

#### 계정 관리

| 함수 | 설명 |
|---|---|
| `await AuthApi.updateDisplayName(name)` | 표시 이름 변경 |
| `await AuthApi.changePassword(current, next)` | 비밀번호 변경. **이메일 계정만** (`isPasswordUser`일 때만 메뉴 노출) |
| `await AuthApi.reauthenticate({password})` | 본인 재확인. 보통 직접 안 쓰고 `changePassword`/`deleteAccount`가 내부에서 호출 |
| `await AuthApi.reload()` | 서버에서 계정 정보 다시 읽기 |

#### 에러 문구

```dart
String AuthApi.errorMessage(Object e)   // 모든 API 예외 → 사용자용 한국어 문구
```

### 4-2. `AccountApi` – 회원 탈퇴

```dart
// 이메일 계정: 비밀번호 필요
await AccountApi.deleteAccount(password: pw);
// 구글 계정: 비밀번호 없이 (구글 로그인 창이 다시 뜸)
await AccountApi.deleteAccount();
```

동작 순서: **본인 재확인 → 내 모든 여행/지출 삭제 → 계정 삭제.** 되돌릴 수 없으니 화면에서 반드시 확인 다이얼로그를 거칠 것.

### 4-3. `TripApi` – 여행

| 함수 | 반환 | 설명 |
|---|---|---|
| `TripApi.watchAll()` | `Stream<List<Trip>>` | 내 여행 목록. **시작일 최신순**, 실시간 |
| `TripApi.watch(tripId)` | `Stream<Trip?>` | 여행 1개 실시간. 삭제되었거나 없으면 `null` |
| `TripApi.get(tripId)` | `Future<Trip?>` | 여행 1개 한 번만 읽기 |
| `TripApi.add(name:, budget:, currency:, start:, end:)` | `Future<String>` | 여행 추가. **새 tripId 반환** |
| `TripApi.update(trip)` | `Future<void>` | 여행 수정. `trip.copyWith(...)` 결과를 전달 |
| `TripApi.updateBudget(tripId, budget)` | `Future<void>` | 예산만 변경 (원화 정수) |
| `TripApi.delete(tripId)` | `Future<void>` | 여행 삭제. **하위 지출도 함께 삭제** |
| `TripApi.deleteAll()` | `Future<void>` | 내 모든 여행 삭제 (탈퇴용, 화면에서 직접 쓸 일 없음) |

### 4-4. `ExpenseApi` – 지출

| 함수 | 반환 | 설명 |
|---|---|---|
| `ExpenseApi.watchAll(tripId)` | `Stream<List<Expense>>` | 지출 목록. **최근 결제가 위**, 실시간 |
| `ExpenseApi.add(tripId, category:, place:, amount:, currency:, {date})` | `Future<void>` | 지출 추가. `date` 생략 시 **지금 시각**, 환율은 **현재 환율 자동 적용**. 환율 정보가 없으면 `ApiException` |
| `ExpenseApi.update(tripId, expense)` | `Future<void>` | 지출 수정. `expense.copyWith(...)` 결과 전달. **저장 당시 환율/날짜는 그대로 유지** |
| `ExpenseApi.delete(tripId, expenseId)` | `Future<void>` | 지출 삭제 |
| `ExpenseApi.restore(tripId, expense)` | `Future<void>` | 삭제 취소 (같은 ID로 복원, "되돌리기" 스낵바용) |

```dart
// 추가
await ExpenseApi.add(trip.id,
    category: '식비', place: '이치란', amount: 1580, currency: trip.currency);

// 수정 (금액만 바꾸기 – 환율은 그대로)
await ExpenseApi.update(trip.id, old.copyWith(amount: 2000));

// 수정 + 현재 환율로 다시 계산하고 싶을 때
await ExpenseApi.update(trip.id, old.copyWith(rate: RateApi.krwPer(old.currency)));
```

### 4-5. `RateApi` – 환율

앱 시작 시 `await RateApi.load()`를 한 번 호출해 두면 된다. **오늘 이미 호출했으면 저장된 값을 쓰고**, 호출이 실패해도 이전에 저장된 값으로 계속 동작한다.

| 이름 | 반환 | 설명 |
|---|---|---|
| `RateApi.ready` | `bool` | 환율 정보가 하나라도 있는가 |
| `RateApi.krwPer('JPY')` | `double` | 1 JPY = 몇 원. **정보가 없으면 `0`** |
| `RateApi.toKrw(amount, 'JPY')` | `double` | 현지 금액 → 원화 (입력 중 미리보기용) |
| `RateApi.fromKrw(krw, 'JPY')` | `double` | 원화 → 현지 금액 (정보 없으면 `0`) |
| `RateApi.lastFetched` | `DateTime?` | 마지막으로 환율을 받아온 시각 |
| `await RateApi.load({force: true})` | `Future<void>` | 오늘 이미 받았어도 강제 갱신 (프로필의 "환율 새로고침" 등) |

### 4-6. `LedgerCalc` – 장부 계산 (Firebase 호출 없음)

모두 `Trip`과 그 여행의 `List<Expense>`를 받는 순수 함수다.

| 함수 | 반환 | 설명 |
|---|---|---|
| `LedgerCalc.spentKrw(list)` | `double` | 총 사용액 (원) |
| `LedgerCalc.remainingKrw(trip, list)` | `double` | 남은 예산 (원). **음수면 초과** |
| `LedgerCalc.remainingLocal(trip, list)` | `double` | 남은 예산을 현지 통화로 (현재 환율 기준) |
| `LedgerCalc.usedRatio(trip, list)` | `double` | 사용 비율 `0.0~1.0` (진행 바 `value`용) |
| `LedgerCalc.isOverBudget(trip, list)` | `bool` | 예산 초과 여부 |
| `LedgerCalc.byCategory(list)` | `Map<String,double>` | 카테고리별 사용액(원) |
| `LedgerCalc.recentFirst(list)` | `List<Expense>` | 최근 순으로 정렬한 새 리스트 |

### 4-7. 표시 도우미와 상수

| 이름 | 예 | 설명 |
|---|---|---|
| `won(num)` | `won(1234567)` → `1,234,567원` | 원화 표시 |
| `localAmt(num)` | `localAmt(1234.5)` → `1,234.5` | 현지 금액 표시 (소수 2자리까지) |
| `dateShort(DateTime)` | `10.03 14:20` | 지출 목록의 날짜 |
| `dayOnly(DateTime)` | `2026.10.03` | 여행 기간 표시 |
| `currencies` | `['USD','JPY',...]` | 통화 선택 드롭다운용 |
| `categoryIcons` | `{'식비': Icons.restaurant, ...}` | 카테고리 → 아이콘 맵 (키 목록으로 카테고리 선택 UI를 만들 수 있음) |
| `iconOfCategory('식비')` | `IconData` | 카테고리 아이콘 (목록에 없으면 `...` 아이콘) |

### 4-8. 예외 처리

```dart
try {
  await ExpenseApi.add(...);
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AuthApi.errorMessage(e))),
  );
}
```

`errorMessage`가 처리하는 예외: `ApiException`(문구가 이미 들어 있음), `FirebaseAuthException`, `FirebaseException`(권한/네트워크), `GoogleSignInException`. 그 외는 "알 수 없는 오류가 발생했어요".

Stream 오류는 `snap.hasError`일 때 `AuthApi.errorMessage(snap.error!)`로 같은 방식으로 표시한다.

---

## 5. 화면별 사용 레시피

### 5-1. 로그인 화면

```dart
final _form = GlobalKey<FormState>();
final _email = TextEditingController();
final _pw = TextEditingController();
bool _busy = false;

Future<void> _login() async {
  if (!_form.currentState!.validate()) return;
  setState(() => _busy = true);
  try {
    await AuthApi.signIn(_email.text, _pw.text);
    // 성공하면 AuthGate가 화면을 바꾼다. 여기서 Navigator 호출 금지
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
    }
  } finally {
    if (mounted) setState(() => _busy = false);   // 화면이 이미 사라졌을 수 있으니 mounted 확인
  }
}

Future<void> _google() async {
  try {
    final ok = await AuthApi.signInWithGoogle();
    if (!ok) return;   // 사용자가 취소 – 아무것도 하지 않음
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
    }
  }
}
```

```dart
TextFormField(controller: _email, validator: AuthApi.validateEmail)
TextFormField(controller: _pw, obscureText: true, validator: AuthApi.validatePassword)
```

비밀번호 찾기: `await AuthApi.sendPasswordReset(_email.text);` 후 "메일을 보냈어요" 안내.

### 5-2. 회원가입 화면

```dart
TextFormField(controller: _name,  validator: AuthApi.validateName)
TextFormField(controller: _email, validator: AuthApi.validateEmail)
TextFormField(controller: _pw,    obscureText: true, validator: AuthApi.validateNewPassword)
TextFormField(
  controller: _pw2, obscureText: true,
  validator: AuthApi.validatePasswordMatch(() => _pw.text),
)

await AuthApi.signUp(_email.text, _pw.text, name: _name.text);
// 성공하면 자동 로그인 → AuthGate가 화면 전환
```

### 5-3. 이메일 인증 안내 화면 (인증을 강제할 때만)

```dart
// AuthGate에서: if (AuthApi.needsEmailVerification) return const VerifyEmailPage();

await AuthApi.sendEmailVerification();            // "메일 다시 보내기"
final ok = await AuthApi.checkEmailVerified();    // "인증했어요" 버튼
if (!ok) { /* "아직 인증되지 않았어요" 안내 */ }
await AuthApi.signOut();                          // "다른 계정으로 로그인"
```

### 5-4. 메인 화면 (여행 목록)

```dart
class _TripsPageState extends State<TripsPage> {
  late final Stream<List<Trip>> _trips = TripApi.watchAll();   // 한 번만 생성

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Trip>>(
      stream: _trips,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(AuthApi.errorMessage(snap.error!)));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final trips = snap.data!;
        if (trips.isEmpty) return const Center(child: Text('여행을 추가해보세요'));
        return ListView.builder(
          itemCount: trips.length,
          itemBuilder: (context, i) {
            final t = trips[i];
            return ListTile(
              title: Text(t.name),
              subtitle: Text('${dayOnly(t.start)} ~ ${dayOnly(t.end)} · ${t.currency}'),
              trailing: Text(won(t.budget)),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => LedgerPage(tripId: t.id))),
            );
          },
        );
      },
    );
  }
}
```

여행 삭제: 확인 다이얼로그 후 `await TripApi.delete(t.id);` (지출도 같이 삭제됨을 안내할 것)

### 5-5. 여행 추가 / 수정 화면

```dart
// 추가 – 통화 드롭다운은 currencies 사용
DropdownButtonFormField<String>(
  initialValue: _currency,
  items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
  onChanged: _editing ? null : (v) => setState(() => _currency = v!),  // 수정 시 비활성화
)

final id = await TripApi.add(
  name: _name.text,
  budget: int.parse(_budget.text),     // 원화 정수
  currency: _currency,
  start: _range.start,
  end: _range.end,
);

// 수정
await TripApi.update(trip.copyWith(name: _name.text, budget: ..., start: ..., end: ...));
```

> **이미 지출이 있는 여행은 통화를 바꾸지 마세요.** 지출은 각자 기록 당시 통화로 저장되어 있어서, 통화를 바꾸면 한 여행에 서로 다른 통화가 섞입니다. 수정 화면에서는 통화 선택을 비활성화하세요.

### 5-6. 장부 화면

```dart
class _LedgerPageState extends State<LedgerPage> {
  late final Stream<Trip?> _trip = TripApi.watch(widget.tripId);
  late final Stream<List<Expense>> _expenses = ExpenseApi.watchAll(widget.tripId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: _trip,
      builder: (context, tripSnap) {
        if (!tripSnap.hasData) return const Center(child: CircularProgressIndicator());
        final trip = tripSnap.data;
        if (trip == null) return const Center(child: Text('삭제된 여행이에요'));

        return StreamBuilder<List<Expense>>(
          stream: _expenses,
          builder: (context, snap) {
            final list = snap.data ?? const <Expense>[];

            final remain = LedgerCalc.remainingKrw(trip, list);
            final ratio  = LedgerCalc.usedRatio(trip, list);
            final over   = LedgerCalc.isOverBudget(trip, list);
            // 남은 예산: Text(won(remain))                      (초과면 빨간색 등으로 표시)
            // 현지 통화: Text('≈ ${localAmt(LedgerCalc.remainingLocal(trip, list))} ${trip.currency}')
            // 진행 바:   LinearProgressIndicator(value: ratio)

            return ListView(
              children: [
                for (final e in list)
                  ListTile(
                    leading: Icon(iconOfCategory(e.category)),
                    title: Text(e.place),
                    subtitle: Text('${localAmt(e.amount)} ${e.currency} · ${dateShort(e.date)}'),
                    trailing: Text(won(e.amountKrw)),
                    onTap: () => _edit(trip, e),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
```

**삭제 + 되돌리기**

```dart
Future<void> _delete(Trip trip, Expense e) async {
  await ExpenseApi.delete(trip.id, e.id);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: const Text('삭제했어요'),
    action: SnackBarAction(
      label: '되돌리기',
      onPressed: () => ExpenseApi.restore(trip.id, e),
    ),
  ));
}
```

**예산 변경**

```dart
await TripApi.updateBudget(trip.id, newBudget);   // 화면은 스트림으로 자동 갱신
```

정렬은 API가 이미 **최근 순**으로 주므로 기본 화면에서는 따로 할 일이 없다. 카테고리 필터 등은 받은 `list`를 화면에서 `where(...)`로 거른다.

### 5-7. 지출 입력 / 수정 (바텀시트)

```dart
// 금액 입력 중 원화 미리보기
final krw = RateApi.toKrw(double.tryParse(_amount.text) ?? 0, trip.currency);
Text('≈ ${won(krw)}');

// 저장 (추가)
try {
  await ExpenseApi.add(trip.id,
      category: _category,                       // categoryIcons.keys 로 선택지를 만들 수 있음
      place: _place.text,
      amount: double.parse(_amount.text),
      currency: trip.currency);
  if (mounted) Navigator.pop(context);
} catch (e) {
  // 환율 정보가 없으면 여기로 옴 → AuthApi.errorMessage(e) 로 안내 + "환율 새로고침" 버튼 제공
}

// 저장 (수정)
await ExpenseApi.update(trip.id,
    old.copyWith(category: _category, place: _place.text, amount: double.parse(_amount.text)));
```

카테고리 선택지: `categoryIcons.keys` (식비/교통/숙박/쇼핑/관광/기타).

### 5-8. 내 정보 화면

```dart
StreamBuilder(
  stream: AuthApi.userChanges,                  // 이름 변경이 바로 반영되도록
  builder: (context, _) => Column(children: [
    Text(AuthApi.displayName),
    Text(AuthApi.email ?? ''),
    Text('로그인 방식: ${AuthApi.loginMethodLabel}'),
  ]),
)

// 환율 정보
Text('환율 갱신: ${RateApi.lastFetched}')
await RateApi.load(force: true);                // 새로고침 버튼 (이후 setState)

// 이름 변경
await AuthApi.updateDisplayName(name);

// 비밀번호 변경 – 이메일 계정에서만 메뉴 노출
if (AuthApi.isPasswordUser) { await AuthApi.changePassword(current, next); }

// 로그아웃
await AuthApi.signOut();                        // 이후 화면 전환은 AuthGate

// 회원 탈퇴 (확인 다이얼로그 필수)
await AccountApi.deleteAccount(password: AuthApi.isPasswordUser ? pw : null);
```

---

## 6. 자주 하는 실수

| 실수 | 증상 | 해결 |
|---|---|---|
| `build()` 안에서 `TripApi.watchAll()` 호출 | 화면이 깜빡이고 요청이 계속 늘어남 | `late final` 필드나 `initState`에서 한 번만 생성 |
| `await` 뒤에 `context` 사용 | "use context across async gaps" 경고/크래시 | `if (!mounted) return;` |
| 로그인 성공 후 `Navigator.push` | 화면이 이중으로 쌓임 | 이동은 AuthGate에 맡김 |
| 로그인 화면에 `validateNewPassword` 사용 | 예전 짧은 비밀번호 사용자가 로그인 못 함 | 로그인엔 `validatePassword` |
| 구글 로그인 취소 시 오류창 표시 | 사용자가 취소만 했는데 에러가 뜸 | `signInWithGoogle()`이 `false`면 그냥 종료 |
| 예산을 현지 통화로 저장 | 남은 예산 계산이 틀어짐 | 예산은 항상 **원화 정수** |
| 지출 추가 시 `date`, 환율을 직접 넣으려 함 | 불필요 | API가 자동 처리 (`date`는 특수한 경우에만 선택 사용) |
| 환율이 0으로 나옴 | 지출 추가 시 `ApiException` | 네트워크 확인 후 `RateApi.load(force: true)` 재시도 UI 제공 |
| 로그아웃 상태에서 API 호출 | `Null check operator` 크래시 | 로그인 후 화면(AuthGate 아래)에서만 호출 |
| Windows 데스크톱에서 구글 로그인 테스트 | 동작 안 함 | 안드로이드 에뮬레이터/실기기 사용 |

### 현재 지원하지 않는 것

- 지출 목록 페이징 (한 여행의 지출을 전부 불러옴 – MVP 규모에서는 문제없음)
- 카테고리 직접 추가/삭제 (6개 고정)
- 신용카드 결제 내역 API 연동 (선택 기능, 미구현)
- 카카오 로그인 (제외됨)

---

## 7. Firebase 콘솔 체크리스트

### 7-1. 최초 1회 (프로젝트 담당자)

- [ ] **Authentication → Sign-in method**: `이메일/비밀번호` 사용 설정
- [ ] **Authentication → Sign-in method**: `Google` 사용 설정
- [ ] **Firestore Database** 생성 (Standard 에디션, 위치 `asia-northeast3` 서울)
- [ ] Firestore **보안 규칙** 게시

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

### 7-2. 팀원 각자

- [ ] `flutterfire configure`로 `firebase_options.dart` 생성 (또는 팀 저장소의 파일 사용)
- [ ] **안드로이드 디버그 SHA-1**을 Firebase 프로젝트 설정 → 내 앱 → SHA 인증서 지문에 등록 (**PC마다 값이 다르므로 각자 등록**)
  ```powershell
  keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```
- [ ] 등록 후 `google-services.json` 다시 받기 (또는 `flutterfire configure` 재실행)
- [ ] 구글 로그인이 계속 "설정 오류"면 `lib/api/social_config.dart`의 `googleServerClientId`에 **웹 클라이언트 ID** 입력
  (Firebase 콘솔 → Authentication → Sign-in method → Google → 웹 SDK 구성)

### 7-3. 환율 API

`lib/api/rate_api.dart`의 `_url`(무키 환율 API)을 사용한다. 환율이 계속 0으로 나오면 이 URL의 응답 형식을 먼저 확인할 것. 실패 시 조용히 넘어가도록 되어 있어 오류 메시지가 뜨지 않는다.

---

## 8. API를 추가/수정할 때

1. **기능의 성격에 맞는 파일에 추가한다.** (로그인 → `auth_api.dart`, 여행 → `trip_api.dart`, 지출 → `expense_api.dart` …)
2. **Firestore 경로가 필요하면 `paths.dart`를 통해서만 접근한다.** 경로 문자열을 다른 파일에 흩어 쓰지 않는다.
3. 사용자에게 보여줄 오류는 `ApiException('한국어 문구')`로 던진다.
4. **`api.dart` 상단의 목록 주석과 이 문서를 함께 갱신한다.**
5. 화면 담당 팀원이 필요한 함수가 없다면 직접 Firebase를 호출하지 말고 **API 담당자에게 요청**한다.
6. DB 구조를 바꿀 때는 `models/`의 `toMap`/`fromDoc`과 `paths.dart`만 수정하면 화면은 그대로 동작해야 한다.
