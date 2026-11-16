import 'package:flutter/material.dart';

import '../../api/api.dart' show AuthApi;
import '../data/trip_store.dart';
import '../models/country.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import 'card_drafts.dart';
import 'card_inbox.dart';
import 'card_message_parser.dart';

/// 장부 맨 위의 카드 알림 배너. Android가 아니거나 보여줄 것이 없으면 자리를 차지하지 않는다.
/// 화면을 열 때와 앱으로 돌아올 때 수집 큐를 읽는다.
class CardInboxBanner extends StatefulWidget {
  const CardInboxBanner({super.key, required this.trip, required this.store});
  final Trip trip;
  final TripStore store;

  @override
  State<CardInboxBanner> createState() => _CardInboxBannerState();
}

class _CardInboxBannerState extends State<CardInboxBanner>
    with WidgetsBindingObserver {
  final _inbox = CardInbox();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inbox.refresh(widget.trip.expenses);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inbox.refresh(widget.trip.expenses);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inbox.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    try {
      await _inbox.openSettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _inbox,
    builder: (context, _) {
      if (!_inbox.supported) return const SizedBox.shrink();
      final count = _inbox.pending.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_inbox.enabled && !_inbox.introDismissed)
            Container(
              key: const ValueKey('card-inbox-intro'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '카드 알림 접근 허용',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '카드 승인 문자·알림을 읽어 지출 초안을 만들어요. 승인·취소·결제 알림만 '
                    '이 기기에 보관하고, 확인한 지출만 장부에 저장해요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _inbox.dismissIntro,
                        child: const Text('나중에'),
                      ),
                      TextButton(
                        onPressed: _openSettings,
                        child: const Text('설정 열기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (count > 0 || _inbox.unreadable > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: const ValueKey('card-inbox-banner'),
                  leading: const Icon(
                    Icons.credit_card_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    count > 0
                        ? '새 카드 승인 $count건'
                        : '형식을 읽지 못한 카드 알림 ${_inbox.unreadable}건',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: count > 0 ? const Text('확인하면 장부에 저장해요') : null,
                  trailing: count > 0
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                  onTap: count > 0
                      ? () => showAppSheet<void>(
                          context: context,
                          builder: (_) => _CardInboxSheet(
                            inbox: _inbox,
                            trip: widget.trip,
                            store: widget.store,
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// 확인 목록. 승인은 "저장", 승인취소는 짝이 되는 지출을 찾아 "취소로 변경"을 제안한다.
class _CardInboxSheet extends StatefulWidget {
  const _CardInboxSheet({
    required this.inbox,
    required this.trip,
    required this.store,
  });
  final CardInbox inbox;
  final Trip trip;
  final TripStore store;

  @override
  State<_CardInboxSheet> createState() => _CardInboxSheetState();
}

class _CardInboxSheetState extends State<_CardInboxSheet> {
  bool _busy = false;
  String? _error;

  /// [expense]가 있으면 저장한 뒤, 없으면(무시) 바로 대기 목록에서 지운다.
  Future<void> _resolve(ParsedCardPayment payment, [Expense? expense]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      if (expense != null) {
        await widget.store.saveExpense(widget.trip.id, expense);
      }
      await widget.inbox.remove(payment);
    } catch (e) {
      error = AuthApi.errorMessage(e);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null && widget.inbox.pending.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  Widget _item(ParsedCardPayment p) {
    final target = p.cancelled
        ? findCancelTarget(p, widget.trip.expenses)
        : null;
    final draft = p.cancelled ? null : draftExpense(p);
    final time =
        '${formatShortDateWithWeekday(p.date)} '
        '${p.date.hour.toString().padLeft(2, '0')}:'
        '${p.date.minute.toString().padLeft(2, '0')}';
    final note = p.cancelled
        ? target == null
              ? '장부에서 취소할 지출을 찾지 못했어요'
              : '${formatShortDateWithWeekday(target.date)} 지출을 취소로 바꿀까요?'
        : outsideTrip(widget.trip, p.date)
        ? '여행 기간 밖의 결제예요. 이 여행에 저장할지 확인해주세요'
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.cancelled ? '${p.merchant} · 승인취소' : p.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                countryByCode(p.currency)?.formatForeign(p.amount) ??
                    '${p.amount} ${p.currency}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (draft != null) '${draft.icon} ${draft.category}',
              time,
              '${p.issuer}카드',
              if (p.installmentMonths > 0) '${p.installmentMonths}개월 할부',
            ].join(' · '),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _resolve(p),
                child: const Text('무시'),
              ),
              if (draft != null)
                FilledButton(
                  onPressed: _busy ? null : () => _resolve(p, draft),
                  child: const Text('저장'),
                ),
              if (target != null)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _resolve(
                          p,
                          target.copyWith(
                            status: ExpenseStatus.cancelled,
                            originalAmount:
                                target.originalAmount ?? target.amount,
                          ),
                        ),
                  child: const Text('취소로 변경'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.inbox, widget.store]),
    builder: (context, _) => AppSheet(
      title: '카드 알림 확인',
      children: [
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        if (widget.inbox.unreadable > 0)
          Text(
            '형식을 읽지 못한 카드 알림 ${widget.inbox.unreadable}건은 건너뛰었어요',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in widget.inbox.pending) ...[
                _item(p),
                const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
