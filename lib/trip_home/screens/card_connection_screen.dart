import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../services/backend.dart';
import '../services/card_sync_api.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';

class CardConnectionScreen extends StatefulWidget {
  const CardConnectionScreen({
    super.key,
    this.trip,
    this.client,
    this.auth,
    this.server,
  });
  final Trip? trip;
  final http.Client? client;
  final FirebaseAuth? auth;
  final Uri? server;

  @override
  State<CardConnectionScreen> createState() => _CardConnectionScreenState();
}

class _CardConnectionScreenState extends State<CardConnectionScreen> {
  final _form = GlobalKey<FormState>();
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  String _issuer = '0303';
  String? _selected;
  bool _consent = false;
  bool _busy = false;
  bool _checked = false;
  bool _connected = false;
  bool _pending = false;
  bool _otherTrip = false;
  bool _revoking = false;
  bool _automatic = false;
  String _cardLabel = '';
  List<Map<String, dynamic>> _cards = [];
  String? _message;
  bool _failed = false;
  String? _sessionUid;

  bool get _configured =>
      (widget.server != null || CardSyncApi.configured) &&
      Backend.isFirebase &&
      tripStore.isRemote;
  String? get _uid => _configured
      ? (widget.auth ?? FirebaseAuth.instance).currentUser?.uid
      : null;
  bool get _hasTrip =>
      widget.trip != null &&
      identical(tripStore.byId(widget.trip!.id), widget.trip);

  @override
  void initState() {
    super.initState();
    _sessionUid = _uid;
    tripStore.addListener(_sessionChanged);
    if (_configured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(_refresh));
    }
  }

  @override
  void dispose() {
    tripStore.removeListener(_sessionChanged);
    _loginId.dispose();
    _password.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    if (_sessionUid == _uid) return;
    _sessionUid = _uid;
    _password.clear();
    _loginId.clear();
    setState(() {
      _checked = false;
      _connected = false;
      _pending = false;
      _otherTrip = false;
      _revoking = false;
      _consent = false;
      _cards = [];
      _cardLabel = '';
    });
  }

  Future<String> _token() async {
    if (!_configured) throw StateError('실제 로그인과 HTTPS 연동 서버가 필요해요');
    final token = await (widget.auth ?? FirebaseAuth.instance).currentUser
        ?.getIdToken();
    if (token == null) throw StateError('더보기에서 mytrip에 먼저 로그인해주세요');
    return token;
  }

  Future<Map<String, dynamic>> _request(
    String action, [
    Map<String, Object> fields = const {},
  ]) async {
    final uid = _uid;
    final result = await CardSyncApi.connection(
      action: action,
      tripId: widget.trip?.id,
      idToken: await _token(),
      fields: fields,
      client: widget.client,
      base: widget.server,
    );
    if (_uid != uid) throw StateError('로그인 계정이 변경됐어요. 더보기에서 다시 열어주세요.');
    return result;
  }

  List<Map<String, dynamic>> _readCards(dynamic value) {
    if (value is! List || value.length > 100) {
      throw const FormatException('보유카드 응답 오류');
    }
    return value.map((card) {
      if (card is! Map<String, dynamic> ||
          card['key'] is! String ||
          card['name'] is! String ||
          card['masked'] is! String ||
          !RegExp(r'^(•••• \d{4}|마스킹된 카드)$').hasMatch(card['masked'])) {
        throw const FormatException('보유카드 응답 오류');
      }
      return card;
    }).toList();
  }

  Future<void> _refresh() async {
    final data = await _request('status');
    if (data['consentVersion'] != CardSyncApi.consentVersion ||
        [
          'connected',
          'pending',
          'otherTrip',
          'revoking',
          'automatic',
        ].any((key) => data[key] is! bool) ||
        data['cardName'] is! String ||
        data['masked'] is! String) {
      throw const FormatException('카드 상태 응답 오류');
    }
    final cards = _readCards(data['cards']);
    if (data['connected'] &&
        (data['cardName'].isEmpty ||
            !RegExp(r'^(•••• \d{4}|마스킹된 카드)$').hasMatch(data['masked']))) {
      throw const FormatException('연결된 카드 응답 오류');
    }
    if (!mounted) return;
    setState(() {
      _checked = true;
      _connected = data['connected'];
      _pending = data['pending'];
      _otherTrip = data['otherTrip'];
      _revoking = data['revoking'];
      _automatic = data['automatic'];
      _cards = cards;
      _selected = null;
      _cardLabel = '${data['cardName']} ${data['masked']}'.trim();
    });
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      await work();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = error is StateError
              ? error.message.toString()
              : '처리 결과를 확인하지 못했어요. 연결 상태를 확인해주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authenticate() async {
    if (!_hasTrip) throw StateError('더보기에서 본인 여행을 다시 선택해주세요.');
    if (!_consent || !_form.currentState!.validate()) return;
    final fields = {
      'organization': _issuer,
      'loginId': _loginId.text.trim(),
      'password': _password.text,
      'consent': true,
      'consentVersion': CardSyncApi.consentVersion,
    };
    _password.clear();
    final result = await _request('authenticate', fields);
    final cards = _readCards(result['cards']);
    _loginId.clear();
    if (mounted) {
      setState(() {
        _cards = cards;
        _pending = true;
        _selected = null;
      });
    }
  }

  Future<void> _select() async {
    final result = await _request('select', {'cardKey': _selected!});
    if (result['connected'] != true) throw const FormatException('연결 확인 실패');
    await _refresh();
    await _sync();
  }

  Future<void> _sync() async {
    if (!_hasTrip) throw StateError('더보기에서 본인 여행을 다시 선택해주세요.');
    final uid = _uid;
    final token = await _token();
    final result = await CardSyncApi.synchronize(
      tripId: widget.trip!.id,
      idToken: token,
      client: widget.client,
      endpoint: widget.server == null
          ? null
          : Uri.parse(
              '${widget.server.toString().replaceFirst(RegExp(r'/+$'), '')}/sync',
            ),
    );
    if (_uid != uid) throw StateError('로그인 계정이 변경됐어요. 더보기에서 다시 열어주세요.');
    if (mounted) {
      setState(
        () => _message =
            '${result.received}건 확인 · ${result.skipped}건 검토 보류. 새 내역은 장부에 반영돼요.',
      );
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카드 연결을 해제할까요?'),
        content: const Text(
          '조회를 중단하고 CODEF에 등록한 카드사 계정도 삭제해요. 장부에 저장한 지출은 유지돼요. 카드 결제 자체를 취소하지는 않아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('유지'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('연결 해제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _request('disconnect');
      _consent = false;
      _password.clear();
      _loginId.clear();
      await _refresh();
    });
  }

  Future<void> _openGuide() async {
    try {
      if (!await launchUrl(
        Uri.parse('https://developer.codef.io/products/card/common/p/approval'),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      )) {
        throw StateError('페이지 열기 실패');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공식 안내 페이지를 열지 못했어요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTopBar(title: '카드 연동'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Text(
                  '내 카드 사용내역 연결',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _connected ? _cardLabel : '실제 카드 미연결',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (!_configured)
                  const Text(
                    '현재 배포에는 실제 로그인·CODEF 서버가 설정되지 않았어요. 설정 전에는 금융정보를 입력하거나 전송할 수 없어요.',
                  ),
                if (_connected) ...[
                  Text(
                    _automatic
                        ? '서버가 승인된 주기로 조회하고 장부에 자동 반영해요.'
                        : '자동 조회는 꺼져 있어요. 내역을 확인하면 장부에 반영돼요.',
                  ),
                  const Text('카드사 반영 지연이 있어 결제 즉시 수신은 보장하지 않아요.'),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(_sync),
                    child: const Text('카드 내역 확인'),
                  ),
                ] else if (_cards.isNotEmpty) ...[
                  const Text('장부에 연결할 보유카드를 선택해주세요'),
                  const SizedBox(height: 12),
                  for (final card in _cards)
                    ListTile(
                      title: Text(card['name']),
                      subtitle: Text(card['masked']),
                      selected: _selected == card['key'],
                      selectedTileColor: AppColors.primarySoft,
                      leading: Icon(
                        _selected == card['key']
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: _busy
                          ? null
                          : () => setState(() => _selected = card['key']),
                    ),
                  FilledButton(
                    onPressed: _busy || _selected == null
                        ? null
                        : () => _run(_select),
                    child: const Text('선택한 카드 연결'),
                  ),
                ] else if (!_hasTrip && !_otherTrip && !_revoking)
                  const Text('로그인 후 여행을 추가하고 선택하면 카드를 연결할 수 있어요.')
                else if (!_pending && !_otherTrip && !_revoking)
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('card-issuer'),
                          initialValue: _issuer,
                          decoration: const InputDecoration(labelText: '카드사'),
                          items: [
                            for (final issuer in CardSyncApi.issuers.entries)
                              DropdownMenuItem(
                                value: issuer.key,
                                child: Text(issuer.value),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                  _issuer = value!;
                                  _consent = false;
                                  _loginId.clear();
                                  _password.clear();
                                }),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '삼성·신한 개인카드의 홈페이지 아이디 로그인을 지원해요. 토스뱅크·공동인증서·추가 PIN 인증은 지원하지 않아요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('card-login-id'),
                          controller: _loginId,
                          enabled: _configured && _checked && !_busy,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: '카드사 홈페이지 아이디',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '카드사 아이디를 입력해주세요'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('card-login-password'),
                          controller: _password,
                          enabled: _configured && _checked && !_busy,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: '카드사 홈페이지 비밀번호',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? '홈페이지 비밀번호를 입력해주세요'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            title: const Text('조회 동의 안내'),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '목적: ${widget.trip!.name} 장부 자동 기록\n조회 범위: 선택한 카드 · ${widget.trip!.dateRangeLabel} (국내·해외 포함)',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '인증 시 보유카드 목록을 조회하고, 선택 후 가맹점·금액·통화·사용시각·승인번호·취소 정보를 조회해요. 로그인 정보는 HTTPS로 서버에 전송하고 비밀번호는 CODEF 공개키로 암호화해 전달해요. 앱과 서버는 로그인 비밀번호를 보관하지 않아요.',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'CODEF는 이후 조회를 위해 카드사 인증정보를 보관해요. 연결 ID와 선택한 카드 식별정보는 연결 해제까지 서버에서 관리하며, 장부 기록은 여행 또는 기록을 삭제할 때까지 유지돼요. 동의는 이 화면의 연결 해제로 철회할 수 있어요. 동의하지 않아도 수동 기록은 사용할 수 있어요.',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '비밀번호 오류가 반복되면 카드사 계정이 잠길 수 있어요. 실패 시 자동 재시도하지 않아요. 실카드 개인 테스트용이며, 공개 운영 전 운영자 고지·제공자 약관 검토가 필요해요.',
                              ),
                            ],
                          ),
                        ),
                        CheckboxListTile(
                          key: const ValueKey('card-consent'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('인증정보 제공과 카드내역 조회·저장에 동의해요'),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _consent,
                          onChanged: _configured && _checked && !_busy
                              ? (value) => setState(() => _consent = value!)
                              : null,
                        ),
                        FilledButton(
                          key: const ValueKey('card-authenticate'),
                          onPressed:
                              _configured && _checked && _consent && !_busy
                              ? () => _run(_authenticate)
                              : null,
                          child: const Text('인증하고 보유카드 불러오기'),
                        ),
                      ],
                    ),
                  ),
                if (_pending && _cards.isEmpty)
                  const Text('보유카드 조회 또는 선택 시간이 만료됐어요. 연결 해제 후 다시 인증해주세요.'),
                if (_otherTrip)
                  const Text(
                    '다른 여행에 연결된 카드가 있어요. 기존 연결을 해제한 뒤 이 여행에서 다시 동의해주세요.',
                  ),
                if (_revoking)
                  const Text(
                    '조회는 중단됐지만 제공자 계정 삭제를 확인하지 못했어요. 연결 해제를 다시 시도해주세요.',
                  ),
                if (_configured)
                  TextButton(
                    onPressed: _busy ? null : () => _run(_refresh),
                    child: const Text('연결 상태 확인'),
                  ),
                if (_connected || _pending || _otherTrip || _revoking)
                  TextButton(
                    onPressed: _busy ? null : _disconnect,
                    child: const Text('연결 해제'),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '카드번호·CVC·카드 PIN·API 비밀키는 이 화면에서 받지 않아요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: _openGuide,
                  child: const Text('CODEF 공식 안내'),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _failed ? AppColors.danger : AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
