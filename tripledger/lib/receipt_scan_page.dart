// [OCR] 영수증 OCR 기능 (feature/receipt-ocr)
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'AppColors.dart';
import 'api/api.dart';

/// 영수증을 찍거나 골라서 인식하는 화면.
///
/// 동의(처음 한 번) → 앱 안 촬영 또는 앨범 선택 → 사진 확인 → 인식.
/// 인식에 성공하면 [Receipt]로 닫히고, 그냥 나가면 null이다.
/// 저장은 하지 않는다. 받은 쪽(LedgerPage)이 지출 추가 시트를 채워서 연다.
/// 카메라·앨범·인식 서버는 모두 api.dart(ReceiptCamera, ReceiptApi)를 거친다.
class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage>
    with WidgetsBindingObserver {
  bool? _consent; // null이면 확인 중
  ReceiptCamera? _camera; // 켜져 있는 카메라
  Uint8List? _shot; // 찍었거나 고른 사진
  String? _cameraError; // 카메라를 열지 못한 이유
  bool _busy = false; // 카메라 여는 중·촬영 중·사진 고르는 중
  bool _scanning = false; // 인식 중
  bool _suspended = false; // 화면이 가려져 카메라를 놓은 상태
  int _attempt = 0; // 늦게 끝난 예전 카메라 열기 결과를 버리는 데 쓴다

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConsent();
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
      if (_shot == null) _openCamera();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_consent != true || _shot != null || _cameraError != null) return;
      if (_suspended) return;
      _suspended = true;
      _attempt++;
      final camera = _camera;
      setState(() => _camera = null);
      camera?.close();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // --------------------------------------------------
  // 동의
  // --------------------------------------------------

  Future<void> _loadConsent() async {
    var consent = false;
    try {
      consent = await ReceiptApi.hasConsent();
    } catch (_) {
      // 저장소를 읽지 못하면 다시 동의받는다.
    }
    if (!mounted) return;
    setState(() => _consent = consent);
    if (consent) _openCamera();
  }

  Future<void> _agree() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ReceiptApi.saveConsent();
      if (!mounted) return;
      setState(() => _consent = true);
      _openCamera();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  // --------------------------------------------------
  // 카메라
  // --------------------------------------------------

  Future<void> _openCamera() async {
    final attempt = ++_attempt;
    final previous = _camera;
    setState(() {
      _camera = null;
      _shot = null;
      _cameraError = null;
      _busy = true;
    });

    try {
      await previous?.close();
      final camera = await ReceiptCamera.open();
      if (!mounted || attempt != _attempt) {
        await camera.close();
        return;
      }
      setState(() => _camera = camera);
    } catch (e) {
      if (mounted && attempt == _attempt) {
        setState(() => _cameraError = AuthApi.errorMessage(e));
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
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------
  // 앨범 선택 / 인식
  // --------------------------------------------------

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final photo = await ReceiptApi.pickPhoto();
      if (photo == null || !mounted) return; // 선택 취소
      _attempt++; // 고르는 동안 다시 켜지던 카메라는 버린다
      final camera = _camera;
      setState(() {
        _shot = photo;
        _camera = null;
        _cameraError = null;
      });
      await camera?.close();
    } catch (e) {
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final shot = _shot;
    if (shot == null || _scanning) return;
    setState(() => _scanning = true);
    try {
      final receipt = await ReceiptApi.scan(shot);
      if (mounted) Navigator.pop(context, receipt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  // --------------------------------------------------
  // 화면
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '영수증 OCR',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: switch (_consent) {
            null => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            false => _buildConsent(),
            true => _buildScan(),
          },
        ),
      ),
    );
  }

  Widget _buildConsent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  SizedBox(height: 14),
                  Text(
                    '영수증 사진을 외부 서버로 보내요',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '촬영하거나 고른 영수증 사진은 글자를 읽기 위해 영수증 인식 서버를 거쳐 '
                    'Anthropic의 Claude AI로 전송됩니다.\n\n'
                    '인식 결과는 지출 입력 칸을 채우는 데만 쓰이고, 저장하기 전에 직접 확인하고 '
                    '고칠 수 있어요.\n\n'
                    '카드번호·전화번호처럼 보내고 싶지 않은 내용은 가리고 촬영해주세요.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: _busy ? null : _agree,
            style: _filledStyle,
            child: const Text('동의하고 계속', style: _buttonText),
          ),
        ),
      ],
    );
  }

  Widget _buildScan() {
    final camera = _camera, shot = _shot, error = _cameraError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shot != null || error == null) ...[
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
            child: _scanning
                ? const _ScanNotice(null, '영수증을 읽고 있어요…')
                : shot != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      shot,
                      fit: BoxFit.contain,
                      semanticLabel: '선택한 영수증 사진',
                      errorBuilder: (_, _, _) =>
                          const Text('미리보기를 표시할 수 없는 사진이에요'),
                    ),
                  )
                : error != null
                ? _ScanNotice(Icons.no_photography_outlined, error)
                : camera != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Semantics(
                      label: '카메라 미리보기',
                      child: camera.preview(overlay: _guide),
                    ),
                  )
                : _suspended
                ? const _ScanNotice(
                    Icons.pause_circle_outline,
                    '카메라를 멈췄어요. 돌아오면 다시 켜져요.',
                  )
                : const _ScanNotice(null, '카메라를 준비하고 있어요…'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: shot != null || error != null
                    ? OutlinedButton(
                        onPressed: _busy || _scanning ? null : _openCamera,
                        style: _outlinedStyle,
                        child: Text(
                          shot != null ? '재촬영' : '다시 시도',
                          style: _buttonText,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _busy ? null : _pick,
                        style: _outlinedStyle,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('앨범에서 선택', style: _buttonText),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: shot != null
                    ? FilledButton(
                        onPressed: _busy || _scanning ? null : _scan,
                        style: _filledStyle,
                        child: const Text('이 사진으로 인식', style: _buttonText),
                      )
                    : error != null
                    ? FilledButton.icon(
                        onPressed: _busy ? null : _pick,
                        style: _filledStyle,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('앨범에서 선택', style: _buttonText),
                      )
                    : FilledButton.icon(
                        onPressed: camera == null || _busy ? null : _capture,
                        style: _filledStyle,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('촬영', style: _buttonText),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 미리보기 위에 겹쳐 그리는, 영수증을 맞춰 넣을 테두리.
  static const _guide = FractionallySizedBox(
    widthFactor: 0.82,
    heightFactor: 0.88,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.white, width: 2),
        ),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );

  // 버튼은 LedgerPage 하단 버튼과 같은 모양(높이 54, 모서리 15, 14pt w800)
  static const _buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  static final _filledStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );

  static final _outlinedStyle = OutlinedButton.styleFrom(
    backgroundColor: AppColors.white,
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );
}

/// 미리보기 자리에 보여주는 안내. 아이콘이 없으면 로딩 표시를 쓴다.
class _ScanNotice extends StatelessWidget {
  const _ScanNotice(this.icon, this.text);

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
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
}
