import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../AppColors.dart';
import '../api/api.dart';
import 'api/ocr_api.dart';
import 'ocr_style.dart';

/// 앱 화면 안에서 영수증을 찍는다 (기기의 카메라 앱으로 넘어가지 않는다).
///
/// 미리보기 → [촬영] → 찍은 사진 확인 → [재촬영 | 이 사진으로 인식].
/// "이 사진으로 인식"을 누르면 그 사진(`Uint8List`)으로 닫히고, 그냥 나가면 null이다.
/// 카메라를 열지 못하면 이유와 함께 사진 선택으로 이어준다.
class OcrCameraScreen extends StatefulWidget {
  const OcrCameraScreen({super.key});

  @override
  State<OcrCameraScreen> createState() => _OcrCameraScreenState();
}

class _OcrCameraScreenState extends State<OcrCameraScreen>
    with WidgetsBindingObserver {
  OcrCamera? _camera; // 켜져 있는 카메라
  Uint8List? _shot; // 찍었거나 고른 사진
  String? _error; // 카메라를 열지 못한 이유
  bool _busy = false;
  bool _suspended = false; // 화면이 가려져 카메라를 놓은 상태
  int _attempt = 0; // 늦게 끝난 예전 open() 결과를 버리는 데 쓴다

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attempt++;
    _camera?.close();
    super.dispose();
  }

  /// 화면이 가려지면(다른 앱·다른 탭) 카메라를 놓고, 돌아오면 촬영 중이었을 때만 다시 켠다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_suspended) return;
      _suspended = false;
      if (_shot == null) _open();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_shot != null || _error != null || _suspended) return;
      _suspended = true;
      _attempt++;
      final camera = _camera;
      setState(() => _camera = null);
      camera?.close();
    }
  }

  Future<void> _open() async {
    final attempt = ++_attempt;
    final previous = _camera;
    setState(() {
      _camera = null;
      _shot = null;
      _error = null;
      _busy = true;
    });
    await previous?.close();
    try {
      final camera = await OcrCamera.open();
      if (!mounted || attempt != _attempt) {
        await camera.close();
        return;
      }
      setState(() => _camera = camera);
    } catch (e) {
      if (mounted && attempt == _attempt) {
        setState(() => _error = AuthApi.errorMessage(e));
      }
    } finally {
      if (mounted && attempt == _attempt) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await camera.capture();
      if (!mounted || camera != _camera) return;
      // 찍은 뒤에는 카메라를 놓는다. 재촬영하면 다시 켠다.
      setState(() {
        _shot = shot;
        _camera = null;
      });
      await camera.close();
    } catch (e) {
      if (mounted) showOcrMessage(context, AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final photo = await OcrApi.pickPhoto(camera: false);
      if (photo == null || !mounted) return; // 선택 취소
      setState(() {
        _shot = photo;
        _error = null;
      });
    } catch (e) {
      if (mounted) showOcrMessage(context, AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera, shot = _shot, error = _error;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ocrAppBar('영수증 촬영'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error == null || shot != null) ...[
                Text(
                  shot != null
                      ? '사진을 확인해주세요. 글자가 흐리면 다시 촬영해주세요.'
                      : '밝은 곳에서 영수증을 펼쳐, 테두리 안에 전체가 보이게 촬영해주세요.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: Center(
                  child: shot != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.memory(
                            shot,
                            fit: BoxFit.contain,
                            semanticLabel: '촬영한 영수증',
                            errorBuilder: (_, _, _) =>
                                const Text('미리보기를 표시할 수 없는 사진이에요'),
                          ),
                        )
                      : error != null
                      ? _Notice(Icons.no_photography_outlined, error)
                      : camera != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Semantics(
                            label: '후면 카메라 미리보기',
                            child: camera.preview(overlay: const _Guide()),
                          ),
                        )
                      : _suspended
                      ? const _Notice(
                          Icons.pause_circle_outline,
                          '카메라를 멈췄어요. 돌아오면 다시 켜져요.',
                        )
                      : const _Notice(null, '카메라 권한과 연결을 기다리고 있어요…'),
                ),
              ),
              const SizedBox(height: 16),
              if (shot != null)
                _Pair(
                  OutlinedButton(
                    key: const ValueKey('camera-retake'),
                    onPressed: _busy ? null : _open,
                    style: ocrOutlinedButton,
                    child: const Text('재촬영'),
                  ),
                  FilledButton(
                    key: const ValueKey('camera-use'),
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(shot),
                    style: ocrPrimaryButton,
                    child: const Text('이 사진으로 인식'),
                  ),
                )
              else if (error != null)
                _Pair(
                  OutlinedButton(
                    key: const ValueKey('camera-retry'),
                    onPressed: _busy ? null : _open,
                    style: ocrOutlinedButton,
                    child: const Text('다시 시도'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('camera-choose'),
                    onPressed: _busy ? null : _choose,
                    style: ocrPrimaryButton,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('사진 선택'),
                  ),
                )
              else
                FilledButton.icon(
                  key: const ValueKey('camera-shot'),
                  onPressed: camera == null || _busy ? null : _capture,
                  style: ocrPrimaryButton,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('촬영'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 영수증을 맞춰 넣을 테두리. 미리보기 위에 겹쳐 그린다.
class _Guide extends StatelessWidget {
  const _Guide();

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: 0.82,
    heightFactor: 0.88,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.white, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

/// 미리보기 자리에 보여주는 안내. 아이콘이 없으면 로딩 표시를 쓴다.
class _Notice extends StatelessWidget {
  const _Notice(this.icon, this.text);
  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon == null)
        const CircularProgressIndicator(color: AppColors.primary)
      else
        Icon(icon, color: AppColors.textTertiary, size: 44),
      const SizedBox(height: 16),
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ],
  );
}

/// 같은 높이의 버튼 두 개.
class _Pair extends StatelessWidget {
  const _Pair(this.left, this.right);
  final Widget left, right;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    ),
  );
}
