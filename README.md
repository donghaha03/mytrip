# 팀 장부 통합본

`wannabb/tripledger`의 `main` (`b94f96c`, 로그인 통합 포함)을 기준으로 기존 mytrip 장부 기능을 이식했습니다. 공유 브랜치는 `donghaha03/mytrip`의 `codex/ledger-page-integration`입니다.

```text
lib/
  main.dart                 팀 앱 시작 / 로그인 화면
  login_screen.dart         팀 로그인
  ledger_page.dart          장부 진입점: LedgerPage(tripId: trip.id)
  ledger/                   장부 화면 · 입력 · 상세 · 영수증 · 위젯 구현
  api/                      팀 공용 API와 장부 저장 확장
  models/                   팀 Trip / Expense와 영수증 필드
  utils/                    팀 표시 함수
```

여행을 선택한 화면에서 다음과 같이 장부를 엽니다.

```dart
import 'package:tripapp/ledger_page.dart';

Navigator.of(context).push(MaterialPageRoute<void>(
  builder: (_) => LedgerPage(tripId: trip.id),
));
```

이 브랜치에는 내부 구현, API·모델, 패키지 설정, 웹 OCR 자산과 iOS 영수증 카메라 연결까지 포함되어 있습니다. `ledger_page.dart` 한 파일만 복사하면 동작하지 않습니다. API 사용법과 변경 범위는 [공용 API 사용법](lib/api/how%20to%20use.md)의 5–6절을 참고하세요.

장부는 팀의 `users/{uid}/trips/{tripId}/expenses` 경로를 사용합니다. 개인 mytrip의 로컬 데이터나 `records` 데이터는 자동으로 이전하지 않습니다. 팀 로그인 화면에는 아직 여행 선택 화면으로 이동하는 처리가 없으므로, 해당 화면 담당자가 선택한 여행 ID로 위 진입점을 호출해야 합니다.

검증 명령: `flutter analyze --no-pub`, `flutter test --no-pub`, `node --test test/receipt_camera_test.mjs`, `flutter build web --no-pub`. Windows에서 플러그인 심볼릭 링크 오류가 나면 개발자 모드를 켠 뒤 `flutter pub get`을 실행하세요. 실제 계정·운영 DB 저장과 네이티브 카메라는 별도 환경에서 확인해야 합니다.

---

# PBL1 - 실시간 환율 기반 해외 여행 장부앱

## 1. 프로젝트 개요
 - 주제: 실시간 환율 기반 해외 여행 장부앱 - 앱 이름 미정.
 - 기획 의도 및 해결하려는 문제: 해외 여행시 스마트한 예산 관리 가능
 - 타겟 사용자: 해외 여행을 가는 모든 사람들이 잠재적 유저층

## 2. 기술 스택 (Tech Stack)
 - `Flutter + FireBase`로 진행중. 
 - 각자 Flutter와 FireBase 활용한 실습을 통한 개인 공부 필요.

## 2. 역할 분담 (Role Assignment)
  - 김원하 (팀장): API 구현, DB생성 및 관리, ledger_page 보조
  - 김종호 (팀원): authentication 페이지 구현
  - 김동하 (팀원): my account page + setting page 구현
  - 최원준 (팀원): main page 구현
 

## 4. 협업 방식 및 일정 관리
 - 코드 협업: `GitHub`
 - 소통 채널: `KakaoTalk / Discord` (정기 미팅: 주 1회 정도 빈도로 디스코드로 진행할 예정)

## 5. 개발 요구사항 (Core Features)
 - [필수] MVP (최소 기능 제품) 요구사항:
   1) 새로운 여행 계획을 추가하고 삭제 및 수정등의 작업 가능. 여행기록은 최신 날짜기준으로 정렬
   2) 최신 환율 정보를 바탕으로 현재 사용액을 원화(main) 및 외화로 표기. 
   3) 여행 장부 페이지(ledger page)에서 expense(id[db측 자동생성], 사용처 이름, 비용, 카테고리 , 외화기준 금액, 날짜, 당시 환율)을 생성함. 
   4) expense는 정렬 및 모아보기도 가능해야함. 
 
 - [또한 필수] 추가 구현 요구사항 (시간 남을 시):
   1) 계정관련 기능



> [!NOTE]
> expense, trip등의 모델 설계와 백엔드 API 사용방법은 [lib/api/how to use.md](https://github.com/wannabb/tripledger/blob/main/lib/api/how%20to%20use.md) 를 참고해주세용







