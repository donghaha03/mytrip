# 여행 장부앱 (Flutter)

Figma `환율 여행 장부앱 - PBL1` 의 화면 8개를 옮긴 프로토타입.
외부 패키지 의존성 없이 Flutter SDK 만으로 돌아간다.

## 실행

이 PC 에는 Flutter 가 PATH 에 등록되어 있지 않고 `C:\Users\dongb\dev\flutter` 에만 풀려 있다.
터미널을 새로 열 때마다 먼저 환경을 잡아준다:

```powershell
. C:\Users\dongb\dev\flutter-env.ps1
```

그 다음:

```powershell
flutter pub get
flutter run            # 연결된 기기/에뮬레이터 선택
flutter run -d chrome  # 크롬으로 바로 보기
```

웹 빌드 결과만 훑어보려면:

```powershell
flutter build web
node tool/serve.js     # http://localhost:8099
```

## 화면 구성

| 파일 | Figma | 설명 |
|---|---|---|
| `screens/empty_home_screen.dart` | 00 | 여행이 없을 때의 첫 화면 |
| `screens/trip_list_screen.dart` | 01 | 내 여행 목록 (길게 눌러 편집) |
| `screens/add_trip_screen.dart` | 02 | 새 여행 추가 |
| `screens/trip_main_screen.dart` | 03 | 여행 메인 (예산 요약) |
| `widgets/sheets.dart` → `MoreCountrySheet` | 04 | 국가 더보기 |
| `widgets/sheets.dart` → `DateRangeSheet` | 05 | 기간 선택 (드래그) |
| `widgets/sheets.dart` → `TripEditSheet` | 06 | 이름 인라인 수정 + 삭제 |
| `widgets/rate_info_tooltip.dart` | 07 | 환율 갱신 안내 툴팁 |

## 확인해볼 것

- **빈 화면(00) 보기**: `main.dart` 의 `tripStore.seedMockTrips();` 를 주석 처리
- **여행완료 도장**: 목업의 미국 여행은 종료일이 지나 있어서 도장이 찍힌다
- **드래그 기간 선택**: 02 → 출발일 박스 탭 → 달력에서 손가락으로 쭉 드래그
- **이름 편집**: 01 에서 여행 카드를 길게 누르면 커서가 올라온 입력창이 뜬다
- **환율 툴팁**: 03 상단 `100엔 = 950원` 옆 `i` 아이콘 탭

## 테스트

```powershell
flutter analyze
flutter test
```

`test/smoke_test.dart` 가 8개 화면을 실제 사용 경로(칩 탭 → 시트 열림, 카드 롱프레스 →
편집 시트, 달력 드래그)로 한 번씩 돌려본다. 폰 사이즈(375×812)로 렌더링하기 때문에
레이아웃 overflow 도 여기서 잡힌다.

## 지금은 목업인 부분 (다음 단계)

1. **환율** — `models/country.dart` 의 `krwPerUnit` 이 하드코딩. 실제로는
   환율 API 를 호출하고, 마지막 호출 날짜를 저장해 두었다가 날짜가 바뀐 경우에만
   다시 호출하는 구조로 바꿔야 한다 (요구사항의 트래픽 절감 방식).
   `widgets/rate_info_tooltip.dart` 의 `lastUpdated` 에 그 시각을 넘기면 된다.

2. **저장소** — `data/trip_store.dart` 가 메모리에만 들고 있어서 앱을 끄면 날아간다.
   Firestore 를 붙일 때는 이 클래스의 메서드 본문만 바꾸면 화면 코드는 그대로 쓸 수 있게
   인터페이스를 맞춰 뒀다. 추천 구조:

   ```
   users/{uid}/trips/{tripId}
   users/{uid}/trips/{tripId}/records/{recordId}
   ```

   지출 기록은 `date` 를 날짜가 아니라 **타임스탬프(시분초 포함)** 로 저장해야
   같은 날 여러 건을 기록해도 정렬이 깨지지 않는다.

3. **장부 상세 페이지** — 03 의 "여행 장부 보기" 버튼은 아직 스낵바만 띄운다.

4. **폰트** — Figma 는 Inter 로 작업했지만 여기서는 시스템 기본 폰트를 쓴다.
   맞추려면 `google_fonts` 패키지를 추가하고 `theme/app_theme.dart` 에서
   `GoogleFonts.interTextTheme()` 을 적용하면 된다.
