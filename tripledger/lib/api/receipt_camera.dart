// [OCR] 영수증 OCR 기능 (feature/receipt-ocr)
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';

import 'api_exception.dart';

/// 카메라 오류를 사용자에게 보여줄 문구로 바꾼다. 코드는 camera 플러그인(웹·Android·iOS)이 주는 값.
@visibleForTesting
String cameraErrorMessage(Object error) => switch (error is CameraException
    ? error.code
    : '') {
  'CameraAccessDenied' ||
  'CameraAccessDeniedWithoutPrompt' ||
  'CameraAccessRestricted' ||
  'NotAllowedError' => '카메라 권한이 거부되었어요. 기기 설정에서 카메라를 허용하거나 앨범에서 사진을 골라주세요.',
  'cameraNotFound' || 'NotFoundError' => '사용할 수 있는 카메라가 없어요. 앨범에서 사진을 골라주세요.',
  'cameraNotReadable' ||
  'NotReadableError' => '다른 앱이 카메라를 사용 중일 수 있어요. 다른 앱을 닫고 다시 시도해주세요.',
  'cameraSecurity' ||
  'cameraType' ||
  'cameraNotSupported' ||
  'SecurityError' => '이 환경에서는 카메라를 사용할 수 없어요. 앨범에서 사진을 골라주세요.',
  _ => '카메라를 열지 못했어요. 다시 시도하거나 앨범에서 사진을 골라주세요.',
};

/// 후면 카메라를 고르고, 없으면 첫 카메라를 쓴다. 카메라가 없으면 null.
@visibleForTesting
CameraDescription? backCamera(List<CameraDescription> cameras) =>
    cameras.isEmpty
    ? null
    : cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

/// 좌우가 뒤집힌 사진을 바로잡아 PNG로 돌려준다.
@visibleForTesting
Future<Uint8List> unmirror(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..translate(image.width.toDouble(), 0)
    ..scale(-1, 1)
    ..drawImage(image, ui.Offset.zero, ui.Paint());
  final flipped = await recorder.endRecording().toImage(
    image.width,
    image.height,
  );
  final data = await flipped.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  flipped.dispose();
  return data!.buffer.asUint8List();
}

/// 앱 화면 안에서 영수증을 찍는 카메라. `camera` 패키지는 이 파일에서만 쓴다.
///
///   final camera = await ReceiptCamera.open();   후면 카메라 켜기 (권한 요청 포함)
///   camera.preview(overlay: ...)                 미리보기 위젯
///   await camera.capture()                       촬영 -> 사진 바이트
///   await camera.close()                         카메라 놓기 (화면을 나가거나 가려질 때)
///
/// 실패하면 사용자에게 보여줄 문구가 담긴 [ApiException]
class ReceiptCamera {
  @visibleForTesting
  ReceiptCamera({
    required this.preview,
    required this.capture,
    required this.close,
  });

  /// 미리보기. [overlay]는 영상 위에 영상과 같은 크기로 겹쳐 그린다.
  final Widget Function({Widget? overlay}) preview;
  final Future<Uint8List> Function() capture;
  final Future<void> Function() close;

  /// 테스트에서 가짜 카메라를 끼울 때만 바꾼다.
  @visibleForTesting
  static Future<ReceiptCamera> Function()? openForTest;

  static Future<ReceiptCamera> open() async {
    final fake = openForTest;
    if (fake != null) return fake();

    CameraController? controller;
    try {
      // 브라우저는 HTTPS(또는 localhost)가 아니면 카메라를 주지 않는다.
      if (kIsWeb &&
          Uri.base.scheme != 'https' &&
          !['localhost', '127.0.0.1', '::1'].contains(Uri.base.host)) {
        throw CameraException('cameraSecurity', null);
      }
      final camera = backCamera(await availableCameras());
      if (camera == null) throw CameraException('cameraNotFound', null);
      // veryHigh = 1920×1080. 앨범 선택(ReceiptApi.pickPhoto)의 긴 변 2000px 제한과 맞춘다.
      // 소리는 쓰지 않으므로 마이크 권한은 묻지 않는다.
      final opened = controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await opened.initialize();
      // 웹 플러그인은 후면이 아닌 카메라(노트북 웹캠 등)의 미리보기와 사진을 좌우로 뒤집는다.
      // 영수증 글자가 거꾸로 찍히므로 둘 다 되돌린다.
      final mirrored =
          kIsWeb && camera.lensDirection != CameraLensDirection.back;
      return ReceiptCamera(
        preview: ({overlay}) => _preview(opened, overlay, mirrored),
        capture: () async {
          try {
            final shot = await (await opened.takePicture()).readAsBytes();
            return mirrored ? await unmirror(shot) : shot;
          } catch (_) {
            throw const ApiException('촬영하지 못했어요. 잠시 후 다시 촬영해주세요.');
          }
        },
        close: opened.dispose,
      );
    } catch (e) {
      try {
        await controller?.dispose();
      } catch (_) {}
      throw ApiException(cameraErrorMessage(e));
    }
  }

  static Widget _preview(
    CameraController controller,
    Widget? overlay,
    bool mirrored,
  ) {
    if (!kIsWeb) return CameraPreview(controller, child: overlay);

    // 웹은 브라우저가 이미 화면 방향에 맞춘 영상을 준다. CameraPreview는 세로 화면에서 비율을
    // 한 번 더 뒤집어 영상을 크게 잘라내므로, 영상 크기 그대로의 비율로 직접 그린다.
    final size = controller.value.previewSize;
    return AspectRatio(
      aspectRatio: size == null || size.isEmpty ? 3 / 4 : size.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.flip(flipX: mirrored, child: controller.buildPreview()),
          ?overlay,
        ],
      ),
    );
  }
}
