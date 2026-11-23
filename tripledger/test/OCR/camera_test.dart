import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/OCR/api/ocr_api.dart';
import 'package:tripapp/OCR/camera_screen.dart';
import 'package:tripapp/OCR/ocr_screen.dart';
import 'package:tripapp/api/api_exception.dart';

const server = 'https://receipt.example.invalid';

/// 1×1 PNG. 개인정보 없는 합성 이미지.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

CameraDescription lens(String name, CameraLensDirection direction) =>
    CameraDescription(name: name, lensDirection: direction, sensorOrientation: 0);

/// 가짜 카메라를 끼우고, 켠 횟수·놓은 횟수를 센다.
class FakeCameras {
  int opened = 0, closed = 0;

  void install() {
    OcrCamera.openForTest = () async {
      opened++;
      return OcrCamera(
        preview: ({overlay}) => Stack(
          children: [const Text('미리보기'), ?overlay],
        ),
        capture: () async => png,
        close: () async => closed++,
      );
    };
    addTearDown(() => OcrCamera.openForTest = null);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'receipt_consent:$ocrConsentVersion:$server': true,
    });
    OcrApi.server = Uri.parse(server);
    OcrApi.pickPhotoForTest = null;
  });

  test('후면 카메라를 먼저 고르고, 없으면 첫 카메라를 쓴다', () {
    final front = lens('front', CameraLensDirection.front);
    final back = lens('back', CameraLensDirection.back);
    final external = lens('webcam', CameraLensDirection.external);
    expect(backCamera([front, back]), back);
    expect(backCamera([external, front]), external);
    expect(backCamera([]), isNull);
  });

  test('카메라 오류를 사용자 문구로 바꾼다', () {
    String message(String code) =>
        cameraErrorMessage(CameraException(code, null));
    for (final code in [
      'CameraAccessDenied', // 웹·Android·iOS
      'CameraAccessDeniedWithoutPrompt', // iOS: 설정에서 꺼 둠
      'CameraAccessRestricted', // iOS: 보호자 제한
      'NotAllowedError', // 웹: 브라우저 오류 이름 그대로
    ]) {
      expect(message(code), contains('권한이 거부'), reason: code);
      expect(message(code), contains('사진 선택'), reason: code);
    }
    expect(message('cameraNotFound'), contains('카메라가 없어요'));
    expect(message('cameraNotReadable'), contains('다른 앱이 카메라를 사용 중'));
    expect(message('cameraSecurity'), contains('HTTPS'));
    expect(message('cameraType'), contains('HTTPS'));
    expect(message('somethingElse'), contains('카메라를 열지 못했어요'));
    expect(cameraErrorMessage(StateError('x')), contains('사진 선택'));
  });

  testWidgets('좌우가 뒤집힌 사진을 바로잡는다', (tester) async {
    await tester.runAsync(() async {
      // 왼쪽 빨강, 오른쪽 파랑인 2×1 사진.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..drawRect(
          const Rect.fromLTWH(0, 0, 1, 1),
          Paint()..color = const Color(0xFFFF0000),
        )
        ..drawRect(
          const Rect.fromLTWH(1, 0, 1, 1),
          Paint()..color = const Color(0xFF0000FF),
        );
      final source = await recorder.endRecording().toImage(2, 1);
      final bytes = (await source.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();

      final flipped = await unmirror(bytes);
      expect(receiptDataUrl(flipped), startsWith('data:image/png;base64,'));
      final image = (await (await ui.instantiateImageCodec(
        flipped,
      )).getNextFrame()).image;
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      expect((image.width, image.height), (2, 1));
      expect(pixels.sublist(0, 4), [0, 0, 255, 255]); // 왼쪽이 파랑
      expect(pixels.sublist(4, 8), [255, 0, 0, 255]); // 오른쪽이 빨강
    });
  });

  group('촬영 화면', () {
    testWidgets('사진 촬영 → 앱 안 미리보기 → 촬영 → 재촬영 → 이 사진으로 인식', (tester) async {
      final cameras = FakeCameras()..install();
      final paths = <String>[];
      OcrApi.client = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'draft': {
                'merchant': 'SAMPLE CAFE',
                'currency': 'KRW',
                'amount': 12000,
                'category': '식비',
                'items': <Object>[],
                'warnings': <Object>[],
              },
            }),
          ),
          200,
        );
      });
      // 기기 카메라 앱(image_picker)으로는 넘어가지 않는다.
      OcrApi.pickPhotoForTest = (_) async => fail('사진 선택기를 열면 안 된다');

      await tester.pumpWidget(const MaterialApp(home: OcrScreen()));
      await tester.tap(find.text('사진 촬영'));
      await tester.pumpAndSettle();
      expect(find.byType(OcrCameraScreen), findsOneWidget);
      expect(find.text('미리보기'), findsOneWidget);
      expect(cameras.opened, 1);

      await tester.tap(find.byKey(const ValueKey('camera-shot')));
      await tester.pumpAndSettle();
      // 찍은 뒤에는 카메라를 놓고 사진을 보여준다.
      expect(cameras.closed, 1);
      expect(find.text('미리보기'), findsNothing);
      expect(find.byKey(const ValueKey('camera-use')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('camera-retake')));
      await tester.pumpAndSettle();
      expect(cameras.opened, 2);
      expect(find.text('미리보기'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('camera-shot')));
      await tester.pumpAndSettle();
      expect(paths, isEmpty); // 확인하기 전에는 아무것도 보내지 않는다.
      await tester.tap(find.byKey(const ValueKey('camera-use')));
      await tester.pumpAndSettle();

      // 인식 화면으로 돌아와 바로 인식한다.
      expect(find.byType(OcrCameraScreen), findsNothing);
      expect(paths, ['/receipt/recognize']);
      expect(find.text('SAMPLE CAFE'), findsOneWidget);
      expect(cameras.closed, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('카메라를 열지 못하면 이유를 보여주고 사진 선택으로 이어준다', (tester) async {
      OcrCamera.openForTest = () async => throw ApiException(
        cameraErrorMessage(CameraException('CameraAccessDenied', null)),
      );
      addTearDown(() => OcrCamera.openForTest = null);
      OcrApi.pickPhotoForTest = (camera) async {
        expect(camera, isFalse);
        return png;
      };
      Uint8List? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute(builder: (_) => const OcrCameraScreen()),
                  ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('카메라 권한이 거부되었어요'), findsOneWidget);
      expect(find.byKey(const ValueKey('camera-shot')), findsNothing);
      expect(find.byKey(const ValueKey('camera-retry')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('camera-choose')));
      await tester.pumpAndSettle();
      expect(find.textContaining('카메라 권한이 거부되었어요'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('camera-use')));
      await tester.pumpAndSettle();
      expect(result, png);
    });

    testWidgets('화면이 가려지면 카메라를 놓고, 돌아오면 다시 켠다. 나가면 놓는다', (tester) async {
      final cameras = FakeCameras()..install();
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: OcrCameraScreen()));
      await tester.pumpAndSettle();
      expect((cameras.opened, cameras.closed), (1, 0));

      // 권한 창처럼 잠깐 포커스만 잃는 것(inactive)으로는 끄지 않는다.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect((cameras.opened, cameras.closed), (1, 0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect((cameras.opened, cameras.closed), (1, 1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect((cameras.opened, cameras.closed), (2, 1));
      expect(find.text('미리보기'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect((cameras.opened, cameras.closed), (2, 2));
    });
  });
}
