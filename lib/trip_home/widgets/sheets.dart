import 'package:flutter/material.dart';

import '../models/country.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_sheet.dart';
import 'calendar_range_picker.dart';
import 'won_input_formatter.dart';

// ---------------------------------------------------------------------------
// 04. 국가 더보기
// ---------------------------------------------------------------------------
class MoreCountrySheet extends StatefulWidget {
  const MoreCountrySheet({super.key, this.initialSelected});

  final Country? initialSelected;

  @override
  State<MoreCountrySheet> createState() => _MoreCountrySheetState();
}

class _MoreCountrySheetState extends State<MoreCountrySheet> {
  Country? _selected;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final results = kCountries.where((c) => c.matches(_search.text)).toList();
    final height =
        (media.size.height - media.viewInsets.bottom - media.padding.top - 12)
            .clamp(200.0, 720.0);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: AppSheet(
          title: '국가 더보기',
          children: [
            TextField(
              key: const ValueKey('country-search'),
              controller: _search,
              decoration: InputDecoration(
                labelText: '국가 검색',
                hintText: '한국어 · English',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색어 지우기',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (_selected != null)
              Text(
                '선택: ${_selected!.name}',
                style: const TextStyle(color: AppColors.primary),
              ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('검색 결과가 없어요'))
                  : ListView.builder(
                      key: const ValueKey('country-list'),
                      itemCount: results.length,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemBuilder: (_, i) {
                        final c = results[i];
                        final selected = _selected?.code == c.code;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            selected: selected,
                            selectedTileColor: AppColors.primarySoft,
                            leading: Text(
                              c.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(c.name),
                            subtitle: Text('${c.english} · ${c.currency}'),
                            trailing: selected
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => setState(() => _selected = c),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            SheetPrimaryButton(
              label: '선택 완료',
              onTap: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 05. 여행 기간 선택
// ---------------------------------------------------------------------------
class DateRangeSheet extends StatefulWidget {
  const DateRangeSheet({super.key, this.initialRange});

  final DateRange? initialRange;

  @override
  State<DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<DateRangeSheet> {
  DateRange? _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
  }

  String _label(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '(${weekdays[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    return SingleChildScrollView(
      child: AppSheet(
        title: '여행 기간 선택',
        children: [
          CalendarRangePicker(
            initialMonth: range?.start ?? DateTime.now(),
            initialRange: range,
            onChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 좁은 화면에서 날짜 라벨이 "4박 5일" 을 밀어내지 않도록 Flexible.
                Flexible(
                  child: Text(
                    range == null
                        ? '시작일과 종료일을 선택해주세요'
                        : '${_label(range.start)} - ${_label(range.end)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (range != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      range.durationLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SheetPrimaryButton(
            label: '선택 완료',
            onTap: _range?.isValid == true
                ? () => Navigator.of(context).pop(_range)
                : null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 06. 여행 편집 (이름 · 기간 · 예산 수정 + 삭제)
// ---------------------------------------------------------------------------
enum TripEditAction { save, delete }

Future<bool> confirmTripDeletion(BuildContext context, Trip trip) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 여행을 삭제할까요?'),
        content: Text('${trip.name}\n여행과 이 여행의 지출 기록이 함께 삭제돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    ) ==
    true;

class TripEditResult {
  const TripEditResult.save({
    required String this.name,
    required DateRange this.range,
    required int this.budgetKrw,
  }) : action = TripEditAction.save;

  const TripEditResult.delete()
    : action = TripEditAction.delete,
      name = null,
      range = null,
      budgetKrw = null;

  final TripEditAction action;

  /// save 일 때만 채워진다
  final String? name;
  final DateRange? range;
  final int? budgetKrw;
}

class TripEditSheet extends StatefulWidget {
  const TripEditSheet({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends State<TripEditSheet> {
  late final TextEditingController _controller;
  late final TextEditingController _budget;
  late final FocusNode _focusNode;
  late DateRange _range;
  static const _maxLength = 20;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _controller = TextEditingController(text: t.name)
      ..addListener(() => setState(() {}));
    _budget = TextEditingController(text: formatNumber(t.budgetKrw))
      ..addListener(() => setState(() {}));
    _range = DateRange(t.start, t.end);
    // 시트가 열리자마자 바로 이름을 고칠 수 있도록 커서를 올려 둔다.
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _budget.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _budgetValue => parseAmount(_budget.text).round();

  bool get _canSave =>
      _controller.text.trim().isNotEmpty && _budgetValue > 0 && _range.isValid;

  Future<void> _pickRange() async {
    final picked = await showAppSheet<DateRange>(
      context: context,
      builder: (_) => DateRangeSheet(initialRange: _range),
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 키보드가 올라와도 시트가 가려지지 않게
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      // 칸이 늘어서 작은 화면 + 키보드면 넘칠 수 있다 -> 스크롤
      child: SingleChildScrollView(
        child: AppSheet(
          title: '여행 편집',
          children: [
            const _FieldLabel('여행 이름'),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: _maxLength,
              cursorColor: AppColors.primary,
              style: _fieldText,
              decoration: _fieldDecoration(
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          size: 20,
                          color: AppColors.handle,
                        ),
                        onPressed: () => _controller.clear(),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_controller.text.length} / $_maxLength자',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('여행 기간'),
            Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _pickRange,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatShortDateWithWeekday(_range.start)} – '
                          '${formatShortDateWithWeekday(_range.end)}',
                          style: _fieldText,
                        ),
                      ),
                      Text(
                        _range.durationLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('예산 (원화)'),
            TextField(
              controller: _budget,
              keyboardType: TextInputType.number,
              inputFormatters: const [WonInputFormatter()],
              cursorColor: AppColors.primary,
              style: _fieldText,
              decoration: _fieldDecoration(suffixText: '원'),
            ),
            const SizedBox(height: 18),
            Opacity(
              opacity: _canSave ? 1 : 0.4,
              child: SheetPrimaryButton(
                label: '저장',
                onTap: () {
                  if (!_canSave) return;
                  Navigator.of(context).pop(
                    TripEditResult.save(
                      name: _controller.text.trim(),
                      range: _range,
                      budgetKrw: _budgetValue,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () =>
                    Navigator.of(context).pop(const TripEditResult.delete()),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '여행 삭제',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _fieldText = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
);

InputDecoration _fieldDecoration({Widget? suffixIcon, String? suffixText}) =>
    InputDecoration(
      counterText: '',
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
