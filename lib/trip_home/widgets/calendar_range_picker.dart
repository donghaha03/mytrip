import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
  bool get isValid =>
      !DateUtils.dateOnly(end).isBefore(DateUtils.dateOnly(start));
  int get nights => DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  String get durationLabel => '$nights박 ${nights + 1}일';
}

/// Six rows keep navigation stationary. Browsing never changes the selection.
class CalendarRangePicker extends StatefulWidget {
  const CalendarRangePicker({
    super.key,
    required this.initialMonth,
    required this.onChanged,
    this.initialRange,
    this.singleDay = false,
  });
  final DateTime initialMonth;
  final DateRange? initialRange;
  final ValueChanged<DateRange?> onChanged;
  final bool singleDay;
  @override
  State<CalendarRangePicker> createState() => _CalendarRangePickerState();
}

class _CalendarRangePickerState extends State<CalendarRangePicker> {
  late DateTime _month;
  DateTime? _start, _end, _anchor;
  bool _awaitingEnd = false;
  final _gridKey = GlobalKey();
  final _titleFocus = FocusNode();
  final _daysFocus = <DateTime, FocusNode>{};
  static const _cellHeight = 44.0;
  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    if (widget.initialRange?.isValid == true) {
      _start = DateUtils.dateOnly(widget.initialRange!.start);
      _end = DateUtils.dateOnly(widget.initialRange!.end);
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    for (final node in _daysFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;
  int get _leading => _month.weekday % 7;
  void _emit() => widget.onChanged(
    _start == null || _end == null ? null : DateRange(_start!, _end!),
  );
  void _select(DateTime date) {
    setState(() {
      if (widget.singleDay || !_awaitingEnd) {
        _anchor = _start = _end = date;
        _awaitingEnd = !widget.singleDay;
      } else {
        _setRange(date);
        _awaitingEnd = false;
      }
    });
    _focus(date).requestFocus();
    _emit();
  }

  void _setRange(DateTime date) {
    final anchor = _anchor ?? date;
    _start = date.isBefore(anchor) ? date : anchor;
    _end = date.isBefore(anchor) ? anchor : date;
  }

  void _drag(Offset position, {bool start = false}) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final col = (position.dx / (box.size.width / 7)).floor();
    final row = (position.dy / _cellHeight).floor();
    final day = row * 7 + col - _leading + 1;
    if (col < 0 ||
        col > 6 ||
        row < 0 ||
        row > 5 ||
        day < 1 ||
        day > _daysInMonth) {
      return;
    }
    final date = DateTime(_month.year, _month.month, day);
    setState(() {
      if (start || widget.singleDay) _anchor = date;
      _setRange(date);
    });
  }

  void _browse(int offset) {
    final next = DateTime(_month.year, _month.month + offset);
    if (next.year < 1 || next.year > 9999) return;
    setState(() => _month = next);
  }

  Future<void> _chooseMonth() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthDialog(initial: _month),
    );
    if (!mounted) return;
    if (result != null) setState(() => _month = result);
    _titleFocus.requestFocus();
  }

  FocusNode _focus(DateTime date) =>
      _daysFocus.putIfAbsent(date, FocusNode.new);
  KeyEventResult _key(DateTime date, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    DateTime? next;
    if (key == LogicalKeyboardKey.arrowLeft) {
      next = date.subtract(const Duration(days: 1));
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      next = date.add(const Duration(days: 1));
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      next = date.subtract(const Duration(days: 7));
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      next = date.add(const Duration(days: 7));
    }
    if (key == LogicalKeyboardKey.home) {
      next = date.subtract(Duration(days: date.weekday % 7));
    }
    if (key == LogicalKeyboardKey.end) {
      next = date.add(Duration(days: 6 - date.weekday % 7));
    }
    if (key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      final month = DateTime(
        date.year,
        date.month + (key == LogicalKeyboardKey.pageUp ? -1 : 1),
      );
      final last = DateTime(month.year, month.month + 1, 0).day;
      next = DateTime(month.year, month.month, date.day.clamp(1, last));
    }
    if (next == null || next.year < 1 || next.year > 9999) {
      return KeyEventResult.ignored;
    }
    final target = next;
    setState(() => _month = DateTime(target.year, target.month));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus(target).requestFocus();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _browse(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: TextButton(
                focusNode: _titleFocus,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _chooseMonth,
                child: Text(
                  '${_month.year}년 ${_month.month}월',
                  semanticsLabel: '${_month.year}년 ${_month.month}월, 연도와 월 선택',
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 달',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _browse(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final label in ['일', '월', '화', '수', '목', '금', '토'])
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      GestureDetector(
        onPanStart: (d) => _drag(d.localPosition, start: true),
        onPanUpdate: (d) => _drag(d.localPosition),
        onPanEnd: (_) {
          _awaitingEnd = false;
          _emit();
        },
        child: SizedBox(
          key: _gridKey,
          height: 6 * _cellHeight,
          child: Column(
            children: [
              for (var row = 0; row < 6; row++)
                SizedBox(
                  height: _cellHeight,
                  child: Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(child: _day(row * 7 + col - _leading + 1)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        '오늘은 테두리 · 선택한 날짜는 파란색',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );
  Widget _day(int day) {
    if (day < 1 || day > _daysInMonth) return const SizedBox.shrink();
    final date = DateTime(_month.year, _month.month, day);
    final today = DateUtils.isSameDay(date, DateTime.now());
    final edge = date == _start || date == _end;
    final selected =
        _start != null &&
        _end != null &&
        !date.isBefore(_start!) &&
        !date.isAfter(_end!);
    return Focus(
      onKeyEvent: (_, event) => _key(date, event),
      child: Semantics(
        selected: selected,
        label:
            '${date.year}년 ${date.month}월 ${date.day}일${today ? ', 오늘' : ''}',
        child: InkWell(
          focusNode: _focus(date),
          onTap: () => _select(date),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.center,
            color: selected ? AppColors.primaryLight : null,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: edge ? AppColors.primary : null,
                border: today
                    ? Border.all(
                        color: edge ? Colors.white : AppColors.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: ExcludeSemantics(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: edge ? FontWeight.w700 : FontWeight.w500,
                    color: edge ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthDialog extends StatefulWidget {
  const _MonthDialog({required this.initial});
  final DateTime initial;
  @override
  State<_MonthDialog> createState() => _MonthDialogState();
}

class _MonthDialogState extends State<_MonthDialog> {
  late final _year = TextEditingController(text: '${widget.initial.year}');
  late int _month = widget.initial.month;
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(DateTime(int.parse(_year.text), _month));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('연도와 월 선택'),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('calendar-year'),
                controller: _year,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(labelText: '연도 (1~9999)'),
                validator: (s) =>
                    (int.tryParse(s ?? '') ?? 0) < 1 ? '올바른 연도를 입력해주세요' : null,
                onFieldSubmitted: (_) => _confirm(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var m = 1; m <= 12; m++)
                    ChoiceChip(
                      label: Text('$m월'),
                      selected: _month == m,
                      onSelected: (_) => setState(() => _month = m),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('취소'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('이동')),
    ],
  );
}
