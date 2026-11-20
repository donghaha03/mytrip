import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api/api.dart';
import 'ledger_page.dart';
import 'my_info_page.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  static const Color primary = Color(0xFF3478EF);
  static const Color background = Color(0xFFF7F9FD);
  static const Color textColor = Color(0xFF20242D);
  static const Color mutedColor = Color(0xFF8791A3);

  late final Stream<List<Trip>> _trips;

  // 삭제 애니메이션이 끝나고 서버 응답이 반영될 때까지 숨길 여행
  final Set<String> _hiddenTripIds = {};

  @override
  void initState() {
    super.initState();
    _trips = TripApi.watchAll();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _addTrip() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => const AddTripSheet(),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('새 여행이 추가되었습니다!');
    }
  }

  Future<void> _editTrip(Trip trip) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => EditTripSheet(trip: trip),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('여행 정보가 수정되었습니다.');
    }
  }

  Future<void> _deleteTripFromMenu(Trip trip) async {
    final confirmed = await _confirmDeleteTrip(trip);
    if (!confirmed || !mounted) return;

    await _deleteTrip(trip);
  }

  Future<void> _showGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trip Wallet 사용방법',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 22),
              const _GuideItem(
                icon: Icons.flight_takeoff_rounded,
                title: '1. 여행 추가',
                description: '여행 이름과 예산, 통화, 여행 기간을 입력하세요.',
              ),
              const _GuideItem(
                icon: Icons.receipt_long_rounded,
                title: '2. 소비 기록',
                description: '여행 중 발생한 지출을 기록하세요.',
              ),
              const _GuideItem(
                icon: Icons.currency_exchange_rounded,
                title: '3. 자동 환산',
                description: '현지 통화로 기록한 지출을 원화로 확인할 수 있어요.',
              ),
              const _GuideItem(
                icon: Icons.bar_chart_rounded,
                title: '4. 예산 관리',
                description: '여행 예산과 사용 금액을 비교해 보세요.',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await AuthApi.signOut();
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  Future<bool> _confirmDeleteTrip(Trip trip) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '여행 기록을 삭제하겠습니까?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: Text(
            '"${trip.name}" 여행과 해당 여행의 모든 지출 기록이 삭제됩니다.\n'
            '삭제한 데이터는 복구할 수 없습니다.',
            style: const TextStyle(
              color: mutedColor,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF8791A3),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                '삭제',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _deleteTrip(Trip trip) async {
    setState(() => _hiddenTripIds.add(trip.id));

    try {
      await TripApi.delete(trip.id);

      if (!mounted) return;
      _showMessage('여행 기록이 삭제되었습니다.');
    } catch (e) {
      if (!mounted) return;

      setState(() => _hiddenTripIds.remove(trip.id));
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  void _openMyInfo() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyInfoPage()));
  }

  void _openLedger(Trip trip) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LedgerPage(tripId: trip.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF3FF), Color(0xFFF8F9FC), Color(0xFFFFFFFF)],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<Trip>>(
            stream: _trips,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(AuthApi.errorMessage(snapshot.error!)),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primary),
                );
              }

              final trips = snapshot.data!
                  .where((trip) => !_hiddenTripIds.contains(trip.id))
                  .toList();

              if (trips.isEmpty) {
                return _buildEmptyPage();
              }

              return _buildTripList(trips);
            },
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // 여행이 하나도 없는 첫 화면
  // --------------------------------------------------

  Widget _buildEmptyPage() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      const Spacer(flex: 4),
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(painter: FlightPathPainter()),
                            ),
                            Container(
                              width: 116,
                              height: 116,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFDCE7FF),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.12),
                                    blurRadius: 35,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.flight_takeoff_rounded,
                                color: primary,
                                size: 43,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '첫 여행을 추가해 보세요',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '여행 일정과 지출을 한곳에서 관리해요',
                        style: TextStyle(color: mutedColor, fontSize: 13),
                      ),
                      const SizedBox(height: 34),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          children: [
                            Expanded(
                              child: _FeatureItem(emoji: '💱', title: '자동 환산'),
                            ),
                            _FeatureDivider(),
                            Expanded(
                              child: _FeatureItem(emoji: '📍', title: '소비 기록'),
                            ),
                            _FeatureDivider(),
                            Expanded(
                              child: _FeatureItem(emoji: '📊', title: '예산 관리'),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: _addTrip,
                  icon: const Icon(Icons.add_circle, size: 25),
                  label: const Text(
                    '여행 추가하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8EFFF),
                    foregroundColor: primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _showGuide,
                child: const Text(
                  '사용방법 다시 보기',
                  style: TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // 상단 바
  // --------------------------------------------------

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Row(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEFF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flight_takeoff_rounded, color: primary, size: 15),
                SizedBox(width: 7),
                Text(
                  '환율 걱정 없는 여행 장부',
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          PopupMenuButton<String>(
            tooltip: '계정 메뉴',
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF30343B),
            ),
            color: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            menuPadding: const EdgeInsets.symmetric(vertical: 6),
            constraints: const BoxConstraints(minWidth: 155, maxWidth: 155),
            offset: const Offset(0, 8),
            onSelected: (value) {
              if (value == 'my_info') {
                _openMyInfo();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'my_info',
                height: 44,
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 19,
                      color: Color(0xFF3478F6),
                    ),
                    const SizedBox(width: 11),
                    const Text(
                      '내 정보',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF30343B),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                height: 44,
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 19,
                      color: Color(0xFFE05252),
                    ),
                    const SizedBox(width: 11),
                    const Text(
                      '로그아웃',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE05252),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 여행 목록
  // --------------------------------------------------

  Widget _buildTripList(List<Trip> trips) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            children: [
              Text(
                '${AuthApi.displayName}님의 여행',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '여행 일정과 예산을 관리해 보세요.',
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
              const SizedBox(height: 26),

              for (final trip in trips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Dismissible(
                    key: ValueKey(trip.id),
                    direction: DismissDirection.startToEnd,
                    confirmDismiss: (_) => _confirmDeleteTrip(trip),
                    onDismissed: (_) => _deleteTrip(trip),
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '삭제',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Color(0xFFE9EDF5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(17),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.flight_rounded,
                            color: primary,
                          ),
                        ),
                        title: Text(
                          trip.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            '${dayOnly(trip.start)} ~ ${dayOnly(trip.end)}\n'
                            '${trip.currency} · 예산 ${won(trip.budget)}',
                            style: const TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              height: 1.7,
                            ),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: '여행 관리',
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: mutedColor,
                          ),
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          elevation: 10,
                          shadowColor: Colors.black.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          menuPadding: const EdgeInsets.symmetric(vertical: 6),
                          constraints: const BoxConstraints(
                            minWidth: 155,
                            maxWidth: 155,
                          ),
                          offset: const Offset(0, 8),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editTrip(trip);
                            } else if (value == 'delete') {
                              _deleteTripFromMenu(trip);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              height: 44,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 19,
                                    color: Color(0xFF3478F6),
                                  ),
                                  const SizedBox(width: 11),
                                  const Text(
                                    '수정하기',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF30343B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              height: 44,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: Color(0xFFE05252),
                                  ),
                                  const SizedBox(width: 11),
                                  const Text(
                                    '삭제하기',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFE05252),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openLedger(trip),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: _addTrip,
              icon: const Icon(Icons.add),
              label: const Text('새 여행 추가하기'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================================================
// 여행 추가 바텀시트
// ==================================================

class AddTripSheet extends StatefulWidget {
  const AddTripSheet({super.key});

  @override
  State<AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends State<AddTripSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  late String _currency;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 7)),
  );

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currency = currencies.contains('JPY') ? 'JPY' : currencies.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final result = await _showTripDateRangePicker(
      context: context,
      initialRange: _range,
    );

    if (result == null || !mounted) return;

    setState(() => _range = result);
  }

  Future<void> _selectCurrency() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencyPickerSheet(
        currencies: currencies,
        selectedCurrency: _currency,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _currency = result);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final budget = int.tryParse(
      _budgetController.text.replaceAll(',', '').trim(),
    );

    if (budget == null || budget <= 0) {
      _showMessage('올바른 예산을 입력해 주세요.');
      return;
    }

    setState(() => _busy = true);

    try {
      await TripApi.add(
        name: _nameController.text.trim(),
        budget: budget,
        currency: _currency,
        start: _range.start,
        end: _range.end,
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
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '새 여행 만들기',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '여행 정보를 입력하고 장부를 시작해 보세요.',
                style: TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),
              const _FieldLabel('여행 이름'),
              TextFormField(
                controller: _nameController,
                maxLength: 30,
                decoration: _inputDecoration(hint: '예: 오사카 3박 4일'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '여행 이름을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('여행 예산 (KRW)'),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  hint: '예: 1000000',
                  suffix: const Text('원'),
                ),
                validator: (value) {
                  final number = int.tryParse(
                    (value ?? '').replaceAll(',', '').trim(),
                  );
                  if (number == null || number <= 0) {
                    return '올바른 예산을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('현지 통화'),
              InkWell(
                onTap: _selectCurrency,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E9F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.currency_exchange_rounded,
                        color: Color(0xFF3478EF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currency,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF20242D),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF8791A3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('여행 기간'),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E9F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${dayOnly(_range.start)}  ~  ${dayOnly(_range.end)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
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
                          '여행 만들기',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.currencies,
    required this.selectedCurrency,
  });

  final List<String> currencies;
  final String selectedCurrency;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  static const Color primary = Color(0xFF3478EF);
  static const Color textColor = Color(0xFF20242D);
  static const Color mutedColor = Color(0xFF8791A3);

  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  static const Map<String, String> _currencyNames = {
    'JPY': '일본 엔',
    'USD': '미국 달러',
    'EUR': '유로',
    'GBP': '영국 파운드',
    'CNY': '중국 위안',
    'KRW': '대한민국 원',
    'TWD': '대만 달러',
    'HKD': '홍콩 달러',
    'SGD': '싱가포르 달러',
    'THB': '태국 바트',
    'VND': '베트남 동',
    'PHP': '필리핀 페소',
    'MYR': '말레이시아 링깃',
    'IDR': '인도네시아 루피아',
    'AUD': '호주 달러',
    'NZD': '뉴질랜드 달러',
    'CAD': '캐나다 달러',
    'CHF': '스위스 프랑',
    'INR': '인도 루피',
    'AED': '아랍에미리트 디르함',
    'TRY': '튀르키예 리라',
    'RUB': '러시아 루블',
    'SEK': '스웨덴 크로나',
    'NOK': '노르웨이 크로네',
    'DKK': '덴마크 크로네',
    'PLN': '폴란드 즈워티',
    'CZK': '체코 코루나',
    'HUF': '헝가리 포린트',
    'BRL': '브라질 헤알',
    'MXN': '멕시코 페소',
    'ZAR': '남아프리카 랜드',
  };

  static const Map<String, String> _currencyFlags = {
    'JPY': '🇯🇵',
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'CNY': '🇨🇳',
    'KRW': '🇰🇷',
    'TWD': '🇹🇼',
    'HKD': '🇭🇰',
    'SGD': '🇸🇬',
    'THB': '🇹🇭',
    'VND': '🇻🇳',
    'PHP': '🇵🇭',
    'MYR': '🇲🇾',
    'IDR': '🇮🇩',
    'AUD': '🇦🇺',
    'NZD': '🇳🇿',
    'CAD': '🇨🇦',
    'CHF': '🇨🇭',
    'INR': '🇮🇳',
    'AED': '🇦🇪',
    'TRY': '🇹🇷',
    'RUB': '🇷🇺',
    'SEK': '🇸🇪',
    'NOK': '🇳🇴',
    'DKK': '🇩🇰',
    'PLN': '🇵🇱',
    'CZK': '🇨🇿',
    'HUF': '🇭🇺',
    'BRL': '🇧🇷',
    'MXN': '🇲🇽',
    'ZAR': '🇿🇦',
  };

  List<String> get _filteredCurrencies {
    final query = _query.trim().toUpperCase();

    if (query.isEmpty) {
      return widget.currencies;
    }

    return widget.currencies.where((currency) {
      final code = currency.toUpperCase();
      final name = _currencyNames[code] ?? '';

      return code.contains(query) || name.toUpperCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCurrencyItem(String currency) {
    final isSelected = currency == widget.selectedCurrency;
    final code = currency.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: isSelected ? const Color(0xFFEEF3FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, currency),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD5E3FF)
                    : const Color(0xFFF0F2F6),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    _currencyFlags[code] ?? '🌐',
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: TextStyle(
                          color: isSelected ? primary : textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currencyNames[code] ?? '통화',
                        style: const TextStyle(color: mutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: primary,
                    size: 21,
                  )
                else
                  const Icon(
                    Icons.circle_outlined,
                    color: Color(0xFFD8DDE6),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCurrencies;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE1E5EB),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 25, 22, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TRIPER · CURRENCY',
                  style: TextStyle(
                    color: primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '현지 통화를 선택해 주세요',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '여행할 국가에서 사용하는 통화를 선택하세요.',
                  style: TextStyle(color: mutedColor, fontSize: 12),
                ),
                const SizedBox(height: 19),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _query = value);
                  },
                  decoration: InputDecoration(
                    hintText: '통화 코드 검색 (예: JPY, USD)',
                    hintStyle: const TextStyle(
                      color: Color(0xFFA0A8B6),
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: primary,
                      size: 21,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '검색 결과가 없습니다.',
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildCurrencyItem(filtered[index]);
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              8,
              22,
              MediaQuery.paddingOf(context).bottom + 14,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: mutedColor,
                  side: const BorderSide(color: Color(0xFFE5E9F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// 여행 정보 수정 바텀시트
// ==================================================

class EditTripSheet extends StatefulWidget {
  const EditTripSheet({super.key, required this.trip});

  final Trip trip;

  @override
  State<EditTripSheet> createState() => _EditTripSheetState();
}

class _EditTripSheetState extends State<EditTripSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  late DateTimeRange _range;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.trip.name);
    _budgetController = TextEditingController(
      text: widget.trip.budget.toString(),
    );
    _range = DateTimeRange(start: widget.trip.start, end: widget.trip.end);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final result = await _showTripDateRangePicker(
      context: context,
      initialRange: _range,
    );

    if (result == null || !mounted) return;

    setState(() => _range = result);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final budget = int.tryParse(
      _budgetController.text.replaceAll(',', '').trim(),
    );

    if (budget == null || budget <= 0) {
      _showMessage('올바른 예산을 입력해 주세요.');
      return;
    }

    setState(() => _busy = true);

    try {
      final updatedTrip = widget.trip.copyWith(
        name: _nameController.text.trim(),
        budget: budget,
        start: _range.start,
        end: _range.end,
      );

      await TripApi.update(updatedTrip);

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
                '여행 정보 수정',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '여행 이름, 예산, 일정을 변경할 수 있어요.',
                style: TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),
              const _FieldLabel('여행 이름'),
              TextFormField(
                controller: _nameController,
                maxLength: 30,
                decoration: _inputDecoration(hint: '여행 이름'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '여행 이름을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('여행 예산 (KRW)'),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  hint: '예: 1000000',
                  suffix: const Text('원'),
                ),
                validator: (value) {
                  final number = int.tryParse(
                    (value ?? '').replaceAll(',', '').trim(),
                  );
                  if (number == null || number <= 0) {
                    return '올바른 예산을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const _FieldLabel('여행 기간'),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E9F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${dayOnly(_range.start)}  ~  ${dayOnly(_range.end)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '현지 통화는 ${widget.trip.currency}로 유지됩니다. '
                  '기존 지출의 환율 기록을 보호하기 위한 설정입니다.',
                  style: const TextStyle(
                    color: Color(0xFF4268B2),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 25),
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
                          '변경사항 저장',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
}

Future<DateTimeRange?> _showTripDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialRange,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripDateRangePicker(initialRange: initialRange),
  );
}

class _TripDateRangePicker extends StatefulWidget {
  const _TripDateRangePicker({required this.initialRange});

  final DateTimeRange initialRange;

  @override
  State<_TripDateRangePicker> createState() => _TripDateRangePickerState();
}

class _TripDateRangePickerState extends State<_TripDateRangePicker> {
  static const Color primary = Color(0xFF3478EF);
  static const Color textColor = Color(0xFF20242D);
  static const Color mutedColor = Color(0xFF929BAA);
  static const Color rangeColor = Color(0xFFEAF1FF);

  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();

    _start = _dateOnly(widget.initialRange.start);
    _end = _dateOnly(widget.initialRange.end);

    _visibleMonth = DateTime(_start!.year, _start!.month);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _sameDay(DateTime? a, DateTime b) {
    return a != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '선택해 주세요';

    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void _changeMonth(int amount) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + amount);

    if (next.isBefore(DateTime(2020, 1)) || next.isAfter(DateTime(2100, 12))) {
      return;
    }

    setState(() => _visibleMonth = next);
  }

  void _selectDay(DateTime date) {
    final selected = _dateOnly(date);

    setState(() {
      // 첫 날짜를 선택하거나 이미 기간이 완성된 경우 새로 시작
      if (_start == null || _end != null) {
        _start = selected;
        _end = null;
      }
      // 종료일이 시작일보다 빠르면 시작일을 다시 설정
      else if (selected.isBefore(_start!)) {
        _start = selected;
        _end = null;
      }
      // 종료일 선택
      else {
        _end = selected;
      }
    });
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);

    final offset = firstDay.weekday % 7;

    final dates = List.generate(
      42,
      (index) =>
          DateTime(_visibleMonth.year, _visibleMonth.month, index - offset + 1),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dates.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final date = dates[index];

        final isCurrentMonth = date.month == _visibleMonth.month;

        final isValid =
            isCurrentMonth &&
            !date.isBefore(DateTime(2020, 1, 1)) &&
            !date.isAfter(DateTime(2100, 12, 31));

        final isStart = _sameDay(_start, date);
        final isEnd = _sameDay(_end, date);

        final isBetween =
            _start != null &&
            _end != null &&
            date.isAfter(_start!) &&
            date.isBefore(_end!);

        final isSelected = isStart || isEnd;

        final isToday = _sameDay(DateTime.now(), date);

        return GestureDetector(
          onTap: isValid ? () => _selectDay(date) : null,
          child: Container(
            decoration: BoxDecoration(
              color: isBetween ? rangeColor : Colors.transparent,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(isStart ? 24 : 0),
                right: Radius.circular(isEnd ? 24 : 0),
              ),
            ),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : !isValid
                        ? const Color(0xFFD4D9E1)
                        : isToday
                        ? primary
                        : textColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedDate({
    required String label,
    required DateTime? date,
    required bool active,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF1FF) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active ? const Color(0xFFD5E3FF) : const Color(0xFFEEF0F4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(date),
              style: TextStyle(
                color: active ? primary : textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = _visibleMonth.isAfter(DateTime(2020, 1));

    final canGoNext = _visibleMonth.isBefore(DateTime(2100, 12));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            12,
            22,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E5EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 27),

              const Text(
                'TRIPER · TRAVEL DATE',
                style: TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 9),

              const Text(
                '여행 기간을 선택해 주세요',
                style: TextStyle(
                  color: textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 7),

              const Text(
                '시작일과 종료일을 차례대로 선택하세요.',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
              const SizedBox(height: 26),

              Row(
                children: [
                  IconButton(
                    onPressed: canGoPrevious ? () => _changeMonth(-1) : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 27),
                    color: textColor,
                  ),
                  Expanded(
                    child: Text(
                      '${_visibleMonth.year}년 ${_visibleMonth.month}월',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: canGoNext ? () => _changeMonth(1) : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 27),
                    color: textColor,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  for (final day in ['일', '월', '화', '수', '목', '금', '토'])
                    Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            color: mutedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              _buildCalendar(),

              const SizedBox(height: 20),

              Row(
                children: [
                  _buildSelectedDate(
                    label: '시작일',
                    date: _start,
                    active: _start != null,
                  ),
                  const SizedBox(width: 10),
                  _buildSelectedDate(
                    label: '종료일',
                    date: _end,
                    active: _end != null,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: _start != null && _end != null
                      ? () {
                          Navigator.pop(
                            context,
                            DateTimeRange(start: _start!, end: _end!),
                          );
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: const Color(0xFFDCE5F5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '선택 완료',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
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
}

// ==================================================
// 빈 화면 장식
// ==================================================

class FlightPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9CBDFE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.76)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.32,
        size.width * 0.63,
        size.height * 0.18,
        size.width * 0.95,
        size.height * 0.25,
      );

    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;

      while (distance < metric.length) {
        final segment = metric.extractPath(
          distance,
          math.min(distance + 4, metric.length),
        );
        canvas.drawPath(segment, paint);
        distance += 9;
      }
    }

    final dotPaint = Paint()..color = const Color(0xFF9CBDFE);

    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.76),
      3.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FlightPathPainter oldDelegate) => false;
}

// ==================================================
// 작은 UI 컴포넌트
// ==================================================

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.emoji, required this.title});

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 19)),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF7D8798), fontSize: 11),
        ),
      ],
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 23, width: 1, color: const Color(0xFFDCE1EA));
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF3478EF), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF8791A3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

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
