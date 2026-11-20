# OCR (영수증 인식)

영수증 사진을 찍거나 골라 상호·날짜·총액·품목·세금·할인을 읽어 보여주는 기능입니다.

쓰는 곳은 두 군데입니다.

- 장부 아래쪽 버튼: 기존 "지출 추가하기" 옆에 같은 모양의 "영수증 OCR" 버튼이 있습니다.
  영수증을 인식한 내용을 확인·수정한 뒤 `ExpenseApi.add`로 지금 열린 여행에 저장합니다.
- 단독 실행(`main_ocr.dart`): 결과만 보여주고 저장하지 않습니다.

저장소 README의 "파일 생성 시 구조도와 관련 문서를 함께 수정" 규칙은 이 문서로 대신합니다.
OCR은 기존 파일을 거의 고치지 않는 조건(장부 버튼 영역만 예외)으로 만들었기 때문에, 루트 `README.md`와
`api_howtouse.md`는 그대로 두었습니다.

## 실행

```powershell
cd tripledger
flutter pub get
flutter run -t lib/OCR/main_ocr.dart
```

Firebase 초기화나 로그인은 필요 없습니다.

## 구조

```text
tripledger/
├── lib/OCR/
│   ├── api/
│   │   └── ocr_api.dart             # OcrApi: 사진 선택, 전송 동의, 인식, 번역 (외부 의존성은 여기만)
│   ├── models/
│   │   ├── ocr_receipt.dart         # OcrReceipt 등 인식 결과 모델
│   │   └── expense_draft.dart       # ExpenseDraft: 인식 결과 → 지출 초안
│   ├── ocr_screen.dart              # 인식 화면 + 장부 버튼이 부르는 openReceiptOcr
│   ├── receipt_expense_screen.dart  # 영수증 내용 확인·수정 후 저장
│   ├── consent_screen.dart          # 사진 전송 동의 화면
│   ├── ocr_style.dart               # 앱바·버튼·카드·입력칸 공통 모양 (AppColors 사용)
│   ├── main_ocr.dart                # 단독 실행 진입점 (OcrApp)
│   └── README.md
└── test/OCR/
    ├── ocr_test.dart
    └── expense_draft_test.dart
```

## 지출 추가 흐름

```text
LedgerPage 아래쪽 버튼 [ 지출 추가하기 | 영수증 OCR ]
  ├ 지출 추가하기 → AddExpenseSheet (기존 그대로)
  └ 영수증 OCR   → openReceiptOcr(context, trip)
                    → OcrScreen(trip): 사진 → 동의 → 인식
                    → "이 내용으로 지출 추가" → ReceiptExpenseScreen → ExpenseApi.add
                    → 저장되면 장부로 돌아와 "지출이 추가되었습니다." 표시
```

기존 파일에서 바꾼 곳은 `lib/ledger_page.dart`의 버튼 영역 한 곳과 import 한 줄입니다.
버튼 하나를 `Row` 안의 `Expanded` 두 개로 나눴고, 기존 버튼의 동작과 모양은 그대로입니다.

인식 결과를 지출로 옮기는 규칙(`ExpenseDraft.fromReceipt`)은 다음과 같습니다.

- 금액: 영수증의 최종 결제액. 못 읽었으면 비워 두고 사용자가 입력합니다.
- 통화: 영수증 통화가 `KRW`이거나 `currencies`에 있으면 그대로, 아니면 여행 통화로 채우고 알려줍니다.
  여행 통화와 달라도 기존 방식대로 지출마다 자기 통화와 저장 시점 환율로 기록됩니다.
- 날짜: 영수증 날짜 + 지금 시각. 날짜가 없거나 미래면 지금으로 채우고 알려줍니다.
- 가맹점 → 사용처(최대 50자), 카테고리는 인식된 값, 결제수단은 기본값 현금.
- `Expense` 모델에 출처(source) 필드가 없어 영수증으로 추가했다는 표시는 저장하지 않습니다.

## 지킨 규칙

| 저장소 규칙 | OCR에서 |
|---|---|
| 화면에서 Firebase SDK 직접 호출 금지 | 저장은 `ExpenseApi.add`만 부릅니다. OCR 화면은 Firebase SDK를 직접 쓰지 않습니다. |
| 화면은 `lib/api/api.dart`로 접근 | 화면은 `api/api.dart`와 `OCR/api/ocr_api.dart`만 import합니다. |
| 외부 서비스 의존성은 API 계층 | HTTP 호출, `image_picker`, `SharedPreferences`는 `OcrApi` 안에만 있습니다. |
| 모델은 분리 | `OCR/models/ocr_receipt.dart` |
| 중복 구현 금지 | 오류 문구는 `ApiException` + `AuthApi.errorMessage`, 금액·날짜는 `localAmt`·`dayOnly`, 카테고리는 `categoryIcons`·`iconOfCategory`를 그대로 씁니다. |
| 기존 디자인 시스템 | 색은 `AppColors`, 글꼴은 Pretendard, 앱바·버튼·카드 모양은 여행 장부·내 정보 화면 기준입니다. |
| 오류·로딩·빈 상태 처리 | 오류는 SnackBar, 처리 중에는 버튼 로딩 표시, 사진이 없을 때 안내 카드를 보여줍니다. |
| 민감한 키 업로드 금지 | 키가 없습니다. 인식 키는 서버에만 있습니다. |
| `flutter analyze` 실행, 테스트 작성 | `flutter analyze`, `flutter test test/OCR` |

## 저장소 규칙과 다른 점

OCR은 폴더 하나에 추가만 하는 조건이라 아래 두 가지는 저장소 규칙과 다릅니다.

- API와 모델이 `lib/api/`, `lib/models/`가 아니라 `lib/OCR/api/`, `lib/OCR/models/`에 있습니다.
  `lib/api/api.dart`에 export를 추가하려면 기존 파일을 고쳐야 해서, 화면이
  `OCR/api/ocr_api.dart`를 따로 import합니다.
- 루트 `README.md`의 구조도와 `api_howtouse.md`에 OCR 내용을 넣지 않았습니다.

팀 코드에 합칠 때는 `ocr_api.dart` → `lib/api/`, `ocr_receipt.dart` → `lib/models/`로 옮기고
`api.dart`에 export 두 줄을 추가하면 됩니다.

## OcrApi 사용법

```dart
import 'OCR/api/ocr_api.dart';

final photo = await OcrApi.pickPhoto(camera: true); // 취소하면 null
if (await OcrApi.consent() != true) {
  // OcrConsentScreen을 띄워 동의를 받는다
}
final receipt = await OcrApi.recognize(photo!);      // OcrReceipt
final names = await OcrApi.translate(['Americano'], 'ko');
```

실패하면 사용자에게 보여줄 문구가 담긴 `ApiException`을 던집니다.

```dart
try {
  final receipt = await OcrApi.recognize(photo);
} catch (e) {
  final message = AuthApi.errorMessage(e);
}
```

`OcrReceipt.amount`는 최종 결제액입니다. 세금·할인·면세는 이미 반영된 값이므로 다시 더하거나
빼지 않습니다. `category`는 `constants.dart`의 지출 카테고리 중 하나입니다.

## 서버

- 중계 서버: `https://mytrip-receipt.mytrip-local-receipt.workers.dev` (Cloudflare Worker → Claude Haiku)
- 다른 서버를 쓰려면 `--dart-define=RECEIPT_SERVER_URL=https://...`
- 요청 헤더 `X-Receipt-Consent: claude-haiku-v1`. 사용자가 동의하기 전에는 아무것도 보내지 않습니다.
- 사용 한도: 전체 하루 200건, 기기당 하루 50건·분당 5건
- 인식에는 Firebase를 쓰지 않습니다. 지출 저장만 기존 `ExpenseApi`(Firestore)를 거칩니다.

## 제약

- 웹: 서버가 허용한 주소(`https://donghaha03.github.io`)에서만 인식됩니다. `localhost`에서는
  서버가 403을 돌려줍니다. Android 앱은 그대로 동작합니다.
- iOS: `ios/Runner/Info.plist`에 카메라·사진 사용 설명이 없어 사진 촬영이 동작하지 않습니다.
  기존 파일이라 추가하지 않았습니다.
