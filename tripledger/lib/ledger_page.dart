import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'expense_detail_page.dart';
import 'api/api.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, required this.tripId});

  final String tripId;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  static const Color primary = Color(0xFF3478EF);
  static const Color background = Color(0xFFF5F7FB);
  static const Color muted = Color(0xFF8791A3);

  late final Stream<Trip?> _trip;
  late final Stream<List<Expense>> _expenses;

  final TextEditingController _exchangeController = TextEditingController();

  bool _exchangeFromKrw = true;
  String _paymentFilter = 'all';
  String _viewMode = 'date';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _trip = TripApi.watch(widget.tripId);
    _expenses = ExpenseApi.watchAll(widget.tripId);
  }

  @override
  void dispose() {
    _exchangeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _addExpense(Trip trip) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => AddExpenseSheet(trip: trip),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('지출이 추가되었습니다.');
    }
  }

  // --------------------------------------------------
  // 필터링
  // --------------------------------------------------

  List<Expense> _filteredExpenses(List<Expense> expenses) {
    return expenses.where((expense) {
      if (_paymentFilter != 'all' && expense.paymentMethod != _paymentFilter) {
        return false;
      }

      if (_categoryFilter != null && expense.category != _categoryFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _showFilterSheet() async {
    String payment = _paymentFilter;
    String view = _viewMode;
    String? category = _categoryFilter;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget choice(String label, bool selected, VoidCallback onTap) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEAF0FF) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? primary : const Color(0xFFE2E7F0),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? primary : const Color(0xFF596579),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '목록 설정',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '결제수단',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      choice('전체', payment == 'all', () {
                        setSheetState(() => payment = 'all');
                      }),
                      choice('현금', payment == 'cash', () {
                        setSheetState(() => payment = 'cash');
                      }),
                      choice('카드', payment == 'card', () {
                        setSheetState(() => payment = 'card');
                      }),
                    ],
                  ),
                  const SizedBox(height: 23),
                  const Text(
                    '카테고리',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      choice('전체', category == null, () {
                        setSheetState(() => category = null);
                      }),
                      for (final item in categoryIcons.keys)
                        choice(item, category == item, () {
                          setSheetState(() => category = item);
                        }),
                    ],
                  ),
                  const SizedBox(height: 23),
                  const Text(
                    '보기 방식',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      choice('날짜별', view == 'date', () {
                        setSheetState(() => view = 'date');
                      }),
                      choice('카테고리별', view == 'category', () {
                        setSheetState(() => view = 'category');
                      }),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            payment = 'all';
                            category = null;
                            view = 'date';
                          });
                        },
                        child: const Text('초기화'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext, true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('적용'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      setState(() {
        _paymentFilter = payment;
        _categoryFilter = category;
        _viewMode = view;
      });
    }
  }

  // --------------------------------------------------
  // 지출 분석
  // --------------------------------------------------

  void _showAnalytics(List<Expense> expenses, Trip trip) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExpenseAnalyticsSheet(expenses: expenses, trip: trip),
    );
  }

  // --------------------------------------------------
  // 환전 계산
  // --------------------------------------------------

  double get _exchangeAmount {
    return double.tryParse(
          _exchangeController.text.trim().replaceAll(',', ''),
        ) ??
        0;
  }

  double _convertedAmount(String currency) {
    if (_exchangeFromKrw) {
      return RateApi.fromKrw(_exchangeAmount, currency);
    }

    return RateApi.toKrw(_exchangeAmount, currency);
  }

  // --------------------------------------------------
  // 메인 화면
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '여행 장부',
          style: TextStyle(
            color: Color(0xFF20242D),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<Trip?>(
        stream: _trip,
        builder: (context, tripSnapshot) {
          if (tripSnapshot.hasError) {
            return Center(
              child: Text(AuthApi.errorMessage(tripSnapshot.error!)),
            );
          }

          if (!tripSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          final trip = tripSnapshot.data;

          if (trip == null) {
            return const Center(child: Text('여행 정보를 찾을 수 없습니다.'));
          }

          return StreamBuilder<List<Expense>>(
            stream: _expenses,
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError) {
                return Center(
                  child: Text(AuthApi.errorMessage(expenseSnapshot.error!)),
                );
              }

              if (!expenseSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primary),
                );
              }

              final allExpenses = expenseSnapshot.data!;
              final expenses = _filteredExpenses(allExpenses);

              final spent = LedgerCalc.spentKrw(allExpenses);
              final remaining = LedgerCalc.remainingKrw(trip, allExpenses);
              final ratio = LedgerCalc.usedRatio(trip, allExpenses);
              final overBudget = LedgerCalc.isOverBudget(trip, allExpenses);

              final today = DateUtils.dateOnly(DateTime.now());
              final start = DateUtils.dateOnly(trip.start);
              final end = DateUtils.dateOnly(trip.end);

              final daysLeft = today.isBefore(start)
                  ? start.difference(today).inDays
                  : end.difference(today).inDays;

              final tripStatus = today.isBefore(start)
                  ? 'upcoming'
                  : today.isAfter(end)
                  ? 'finished'
                  : 'ongoing';

              final todayExpenses = allExpenses.where((e) {
                return DateUtils.isSameDay(e.date, today);
              }).toList();

              final todaySpent = todayExpenses.fold<double>(
                0,
                (sum, e) => sum + e.amountKrw,
              );

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 105),
                    children: [
                      _buildHeroCard(
                        trip,
                        spent,
                        remaining,
                        ratio,
                        overBudget,
                        daysLeft,
                        todaySpent,
                        tripStatus,
                      ),
                      const SizedBox(height: 13),
                      _buildPaymentSummary(allExpenses),
                      const SizedBox(height: 23),
                      _buildSectionHeader(
                        '최근 지출',
                        '전체 ${allExpenses.length}건',
                        onTap: () => _showAnalytics(allExpenses, trip),
                      ),
                      const SizedBox(height: 12),
                      _buildRecentChart(allExpenses, trip),
                      const SizedBox(height: 23),
                      _buildSectionHeader('빠른 환전', '${trip.currency} ↔ KRW'),
                      const SizedBox(height: 10),
                      _buildExchangeCard(trip),
                      const SizedBox(height: 23),
                      _buildSectionHeader(
                        '여행 장부',
                        '${expenses.length}건',
                        onTap: _showFilterSheet,
                        trailingIcon: Icons.tune_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildExpenseList(expenses),
                    ],
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: () => _addExpense(trip),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              '지출 추가하기',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // 상단 파란색 대시보드
  // --------------------------------------------------

  Widget _buildHeroCard(
    Trip trip,
    double spent,
    double remaining,
    double ratio,
    bool overBudget,
    int daysLeft,
    double todaySpent,
    String tripStatus,
  ) {
    final progress = ratio.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3478EF), Color(0xFF2865D9)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tripStatus == 'finished' ? '여행 종료' : 'D-$daysLeft',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${dayOnly(trip.start)} ~ ${dayOnly(trip.end)}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            trip.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '사용한 금액',
            style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            won(spent),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(ratio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 15),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _HeroValue(label: '예산', value: won(trip.budget)),
                  ),
                  Expanded(
                    child: _HeroValue(
                      label: overBudget ? '초과 금액' : '남은 금액',
                      value: won(remaining.abs()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroValue(label: '오늘 지출', value: won(todaySpent)),
                  ),
                  Expanded(
                    child: _HeroValue(
                      label: '남은 일정',
                      value: tripStatus == 'finished' ? '종료' : 'D-$daysLeft',
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (overBudget) ...[
            const SizedBox(height: 13),
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFD5D5),
                  size: 15,
                ),
                SizedBox(width: 5),
                Text(
                  '여행 예산을 초과했습니다.',
                  style: TextStyle(
                    color: Color(0xFFFFE0E0),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(List<Expense> expenses) {
    final cash = expenses
        .where((e) => e.paymentMethod == 'cash')
        .fold<double>(0, (sum, e) => sum + e.amountKrw);

    final card = expenses
        .where((e) => e.paymentMethod == 'card')
        .fold<double>(0, (sum, e) => sum + e.amountKrw);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: primary, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '현금 ${won(cash)}',
              style: const TextStyle(
                color: Color(0xFF46536B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(width: 1, height: 17, color: const Color(0xFFD4DDF0)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '카드 ${won(card)}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF46536B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String trailing, {
    VoidCallback? onTap,
    IconData? trailingIcon,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF20242D),
            ),
          ),
        ),
        if (onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: Row(
                children: [
                  if (trailingIcon != null) ...[
                    Icon(trailingIcon, size: 16, color: primary),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    trailing,
                    style: const TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Text(trailing, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    );
  }

  // --------------------------------------------------
  // 최근 7일 지출 그래프
  // --------------------------------------------------

  Widget _buildRecentChart(List<Expense> expenses, Trip trip) {
    final today = DateUtils.dateOnly(DateTime.now());

    final dailyTotals = List<double>.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));

      return expenses
          .where((e) => DateUtils.isSameDay(e.date, date))
          .fold<double>(0, (sum, e) => sum + e.amountKrw);
    });

    final maxValue = dailyTotals.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    final total = dailyTotals.fold<double>(0, (sum, value) => sum + value);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '최근 7일',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                won(total),
                style: const TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          SizedBox(
            height: 105,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final date = today.subtract(Duration(days: 6 - index));
                final value = dailyTotals[index];

                final barHeight = maxValue == 0
                    ? 3.0
                    : (value / maxValue * 66).clamp(3.0, 66.0);

                final isToday = index == 6;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 69,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 24,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? primary
                                  : const Color(0xFFD8E3FA),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isToday ? primary : muted,
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '최근 지출을 기준으로 표시합니다.',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 빠른 환전
  // --------------------------------------------------

  Widget _buildExchangeCard(Trip trip) {
    final output = _convertedAmount(trip.currency);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _exchangeFromKrw
                ? 'KRW → ${trip.currency}'
                : '${trip.currency} → KRW',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF596579),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _exchangeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: _exchangeFromKrw ? '₩ ' : '',
                    hintText: '0',
                    filled: true,
                    fillColor: background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    _exchangeFromKrw = !_exchangeFromKrw;
                    _exchangeController.clear();
                  });
                },
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF0FF),
                  foregroundColor: primary,
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Text('환산 결과', style: TextStyle(color: muted, fontSize: 11)),
              const Spacer(),
              Text(
                _exchangeFromKrw
                    ? '${localAmt(output)} ${trip.currency}'
                    : won(output),
                style: const TextStyle(
                  color: primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 지출 목록
  // --------------------------------------------------

  Widget _buildExpenseList(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 35),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF3)),
        ),
        child: const Center(
          child: Text(
            '표시할 지출 내역이 없습니다.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      );
    }

    if (_viewMode == 'category') {
      final grouped = <String, List<Expense>>{};

      for (final expense in expenses) {
        grouped.putIfAbsent(expense.category, () => []).add(expense);
      }

      return Column(
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 13, 3, 9),
              child: Row(
                children: [
                  Icon(iconOfCategory(entry.key), color: primary, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    won(
                      entry.value.fold<double>(
                        0,
                        (sum, e) => sum + e.amountKrw,
                      ),
                    ),
                    style: const TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            for (final expense in entry.value) _buildExpenseTile(expense),
          ],
        ],
      );
    }

    final grouped = <DateTime, List<Expense>>{};

    for (final expense in expenses) {
      final date = DateUtils.dateOnly(expense.date);
      grouped.putIfAbsent(date, () => []).add(expense);
    }

    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 13, 3, 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayOnly(date),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF596579),
                    ),
                  ),
                ),
                Text(
                  won(
                    grouped[date]!.fold<double>(
                      0,
                      (sum, e) => sum + e.amountKrw,
                    ),
                  ),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          for (final expense in grouped[date]!) _buildExpenseTile(expense),
        ],
      ],
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    final payment = expense.paymentMethod == 'card' ? '카드' : '현금';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        leading: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            iconOfCategory(expense.category),
            color: primary,
            size: 19,
          ),
        ),
        title: Text(
          expense.place,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${expense.category} · $payment · '
            '${expense.date.hour.toString().padLeft(2, '0')}:'
            '${expense.date.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${localAmt(expense.amount)} ${expense.currency}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              won(expense.amountKrw),
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
        onTap: () async {
          final deleted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ExpenseDetailPage(tripId: widget.tripId, expense: expense),
            ),
          );

          if (deleted == true && mounted) {
            _showMessage('지출 기록이 삭제되었습니다.');
          }
        },
      ),
    );
  }
}

// ==================================================
// 대시보드 숫자 표시
// ==================================================

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFDCE8FF), fontSize: 9),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ==================================================
// 지출 분석 Bottom Sheet
// ==================================================

class _ExpenseAnalyticsSheet extends StatelessWidget {
  const _ExpenseAnalyticsSheet({required this.expenses, required this.trip});

  final List<Expense> expenses;
  final Trip trip;

  static const List<Color> colors = [
    Color(0xFF80D0EB),
    Color(0xFF83D8BD),
    Color(0xFFF49BB1),
    Color(0xFFFFD477),
    Color(0xFF9AABF5),
    Color(0xFFB9A1E8),
    Color(0xFF80B7F0),
  ];

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};

    for (final expense in expenses) {
      totals.update(
        expense.category,
        (value) => value + expense.amountKrw,
        ifAbsent: () => expense.amountKrw,
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '지출 한눈에 보기',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              trip.name,
              style: const TextStyle(color: Color(0xFF8791A3), fontSize: 12),
            ),
            const SizedBox(height: 24),
            const Text(
              '총 지출',
              style: TextStyle(color: Color(0xFF8791A3), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              won(total),
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 25),
            if (total > 0)
              SizedBox(
                height: 190,
                child: Center(
                  child: CustomPaint(
                    size: const Size(190, 190),
                    painter: _DonutPainter(
                      values: entries.map((e) => e.value).toList(),
                      colors: List.generate(
                        entries.length,
                        (index) => colors[index % colors.length],
                      ),
                    ),
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '총 지출',
                            style: TextStyle(
                              color: Color(0xFF8791A3),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            won(total),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(
                height: 170,
                child: Center(
                  child: Text(
                    '분석할 지출 내역이 없습니다.',
                    style: TextStyle(color: Color(0xFF8791A3)),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            for (int i = 0; i < entries.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entries[i].key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${total == 0 ? 0 : entries[i].value / total * 100 ~/ 1}%',
                      style: const TextStyle(
                        color: Color(0xFF8791A3),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      won(entries[i].value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================================================
// 도넛 차트 CustomPainter
// ==================================================

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);

    if (total <= 0) return;

    final rect = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 23
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = values[i] / total * math.pi * 2;

      paint.color = colors[i % colors.length];

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
// ==================================================
// 지출 추가 바텀시트
// ==================================================

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, required this.trip});

  final Trip trip;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _amountController = TextEditingController();

  late String _category;
  String _paymentMethod = 'cash';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _category = categoryIcons.keys.first;
  }

  @override
  void dispose() {
    _placeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Widget _buildSelectField({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E9F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: primary, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF303846),
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8791A3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseOptionPickerSheet(
        title: '카테고리 선택',
        selectedValue: _category,
        options: [
          for (final category in categoryIcons.keys)
            _ExpensePickerOption(
              value: category,
              label: category,
              icon: iconOfCategory(category),
            ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _category = result);
    }
  }

  Future<void> _selectPaymentMethod() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseOptionPickerSheet(
        title: '결제수단 선택',
        selectedValue: _paymentMethod,
        options: const [
          _ExpensePickerOption(
            value: 'cash',
            label: '현금',
            icon: Icons.payments_outlined,
          ),
          _ExpensePickerOption(
            value: 'card',
            label: '카드',
            icon: Icons.credit_card_rounded,
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _paymentMethod = result);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (amount == null || amount <= 0) {
      _showMessage('올바른 금액을 입력해 주세요.');
      return;
    }

    setState(() => _busy = true);

    try {
      await ExpenseApi.add(
        widget.trip.id,
        category: _category,
        place: _placeController.text.trim(),
        amount: amount,
        currency: widget.trip.currency,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '새 지출 기록하기',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '금액은 ${widget.trip.currency} 기준으로 입력하세요.',
                style: const TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),

              const _ExpenseFieldLabel('카테고리'),
              _buildSelectField(
                icon: iconOfCategory(_category),
                label: _category,
                onTap: _selectCategory,
              ),

              const SizedBox(height: 17),
              const _ExpenseFieldLabel('결제수단'),
              _buildSelectField(
                icon: _paymentMethod == 'cash'
                    ? Icons.payments_outlined
                    : Icons.credit_card_rounded,
                label: _paymentMethod == 'cash' ? '현금' : '카드',
                onTap: _selectPaymentMethod,
              ),

              const SizedBox(height: 17),
              const _ExpenseFieldLabel('장소 / 사용처'),
              TextFormField(
                controller: _placeController,
                maxLength: 50,
                decoration: _inputDecoration(hint: '예: 편의점, 식당, 지하철'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '사용처를 입력해 주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 13),
              _ExpenseFieldLabel('금액 (${widget.trip.currency})'),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration(
                  hint: '예: 1500',
                  suffix: Text(widget.trip.currency),
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );

                  if (amount == null || amount <= 0) {
                    return '올바른 금액을 입력해 주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '지출 저장하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffix: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
    );
  }
}

class _ExpenseFieldLabel extends StatelessWidget {
  const _ExpenseFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
// ==================================================
// 지출 항목 선택 Bottom Sheet
// ==================================================

class _ExpensePickerOption {
  const _ExpensePickerOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _ExpenseOptionPickerSheet extends StatelessWidget {
  const _ExpenseOptionPickerSheet({
    required this.title,
    required this.selectedValue,
    required this.options,
  });

  final String title;
  final String selectedValue;
  final List<_ExpensePickerOption> options;

  static const Color primary = Color(0xFF3478EF);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 손잡이
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E5EC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 22),

              // 제목
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF20242D),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF8791A3),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 선택 항목
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option.value == selectedValue;

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context, option.value);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEAF0FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? primary : const Color(0xFFE8ECF3),
                            width: selected ? 1.3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFDCE7FF)
                                    : const Color(0xFFF3F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                option.icon,
                                color: selected
                                    ? primary
                                    : const Color(0xFF697589),
                                size: 20,
                              ),
                            ),

                            const SizedBox(width: 13),

                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected
                                      ? primary
                                      : const Color(0xFF303846),
                                ),
                              ),
                            ),

                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: primary,
                                size: 21,
                              )
                            else
                              const Icon(
                                Icons.circle_outlined,
                                color: Color(0xFFD5DBE5),
                                size: 21,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              // 닫기 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF596579),
                    side: const BorderSide(color: Color(0xFFE5E9F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
