// 팀 저장소 규칙: lib/ 루트는 공용이고, 각자 작업은 lib/<파트>/ 안에 둔다.
// 이 파트(여행 선택 · 여행 홈)의 화면·상태는 모두 lib/trip_home/ 에 있다.
//
// 팀 저장소에 합칠 때 이 파일은 통합 담당이 쓰는 자리다. 로그인 화면이
// 붙으면 여기서 로그인 여부를 보고 trip_home 으로 넘기게 된다.
import 'trip_home/app.dart' as trip_home;

Future<void> main() => trip_home.main();
