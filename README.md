# mytrip

해외여행 예산과 지출을 한눈에 확인하는 Flutter 앱 프로토타입입니다.

[앱 실행](https://donghaha03.github.io/mytrip/) · [개발 안내](CONTRIBUTING.md)

## 주요 기능

- 여행 추가·편집·삭제와 기간별 여행 목록
- 사용한 금액·남은 예산·여행 일정 요약
- 오늘 예산과 최근 지출 확인
- 원화 ↔ 현지 통화 빠른 환산

## 이용 안내

- 기본 화면은 샘플 여행 3건으로 시작합니다. 데이터는 임시로 저장되며 새로고침하면 초기화됩니다.
- 로그인·지출 입력·전체 장부·계정 및 설정 화면은 준비 중입니다.
- 모든 환산은 상단의 정수 환율을 기준으로 계산합니다. 입력과 결과의 소수점은 반올림 없이 버립니다.

## 환율

앱을 닫아도 매일 오전 6시(한국 시간)에 서버에서 갱신합니다.
환율 기준일과 마지막 수집 시각은 여행 홈의 `ⓘ`에서 확인할 수 있습니다.

예약 실행과 배포는 지연될 수 있습니다. 갱신에 실패하면 이전 환율을 사용하며,
저장된 환율이 없으면 환산할 수 없습니다. 카드사 수수료와 실제 결제 환율은 반영하지 않습니다.

## 로컬 실행

Flutter 3.47.5 기준입니다.

```sh
flutter pub get
flutter run -d chrome
```

## 출처

- 환율: [Currency API](https://github.com/fawazahmed0/exchange-api) · [CC0](https://github.com/fawazahmed0/exchange-api/blob/main/LICENSE)
- 글꼴: [Pretendard · SIL Open Font License 1.1](assets/fonts/OFL.txt)
