import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../services/auth_service.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';
import 'card_connection_screen.dart';

/// 실제 로그인과 카드 연결에 필요한 입력은 더보기 아래에 모은다.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, this.trip});
  final Trip? trip;
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String? _tripId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([authService, tripStore]),
    builder: (context, _) {
      final trips = tripStore.trips;
      final selected =
          tripStore.byId(_tripId ?? widget.trip?.id ?? '') ??
          (trips.isEmpty ? null : trips.first);
      final user = Backend.isFirebase ? authService.currentUser : null;
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenTopBar(title: '더보기'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(user?.email ?? 'mytrip 로그인'),
                        subtitle: Text(
                          Backend.isFirebase
                              ? '본인 계정의 장부에만 카드 내역을 저장해요'
                              : '실제 로그인 미설정 · 화면 확인용',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => const _SignInDialog(),
                        ),
                      ),
                    ),
                    if (user != null) ...[
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: user.uid),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('테스트 계정 UID를 복사했어요'),
                              ),
                            );
                          }
                        },
                        child: const Text('테스트 계정 UID 복사'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await authService.signOut();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('로그아웃하지 못했어요. 다시 시도해주세요.'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('로그아웃'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (trips.length > 1)
                      DropdownButton<Trip>(
                        isExpanded: true,
                        value: selected,
                        items: [
                          for (final trip in trips)
                            DropdownMenuItem(
                              value: trip,
                              child: Text(
                                trip.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (trip) => setState(() => _tripId = trip?.id),
                      ),
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(
                          Icons.credit_card_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text('카드 연동'),
                        subtitle: const Text('삼성·신한 · 인증 및 조회 동의'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CardConnectionScreen(trip: selected),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selected == null
                          ? '로그인 후 여행을 추가하면 카드를 연결할 수 있어요.'
                          : '${selected.name} · ${selected.dateRangeLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CODEF API 비밀키는 공개 앱에서 입력받지 않아요. 서버의 비밀 저장소에 설정해야 해요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SignInDialog extends StatefulWidget {
  const _SignInDialog();
  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(bool create) async {
    if (_busy || !Backend.isFirebase) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final password = _password.text;
    _password.clear();
    try {
      if (create) {
        await authService.signUp(_email.text.trim(), password);
      } else {
        await authService.signIn(_email.text.trim(), password);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AuthException
              ? error.message
              : '로그인하지 못했어요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('mytrip 로그인'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('카드사 계정과는 별도의 mytrip 계정이에요.'),
          if (!Backend.isFirebase)
            const Text('현재 화면은 임시 모드라 실제 로그인을 사용할 수 없어요. 비밀번호를 입력하지 마세요.'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('mytrip-login-email'),
            controller: _email,
            enabled: Backend.isFirebase && !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'mytrip 이메일'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('mytrip-login-password'),
            controller: _password,
            enabled: Backend.isFirebase && !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'mytrip 비밀번호'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
      TextButton(
        onPressed: Backend.isFirebase && !_busy ? () => _submit(true) : null,
        child: const Text('계정 만들기'),
      ),
      FilledButton(
        onPressed: Backend.isFirebase && !_busy ? () => _submit(false) : null,
        child: const Text('로그인'),
      ),
    ],
  );
}
