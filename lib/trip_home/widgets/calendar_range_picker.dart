import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  int get nights => end.difference(start).inDays;
  String get durationLabel => '$nights박 ${nights + 1}일';
}

/// 월 단위 달력. 탭해서 시작일을 잡고 드래그하면 종료일까지 이어서 칠해진다.
/// 선택 구간은 연한 파랑으로 연결되고, 양 끝만 진한 원으로 강조된다.
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
  DateTime? _anchor; // 드래그 시작점
  DateTime? _start;
  DateTime? _end;

  final _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
  }

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  /// 일요일 시작 기준으로 1일 앞에 비워야 하는 칸 수
  int get _leadingBlanks => DateTime(_month.year, _month.month, 1).weekday % 7;

  int get _rowCount => ((_leadingBlanks + _daysInMonth) / 7).ceil();

  void _emit() {
    if (_start != null && _end != null) {
      widget.onChanged(DateRange(_start!, _end!));
    } else {
      widget.onChanged(null);
    }
  }

  /// 터치 좌표 -> 날짜. 드래그 중 손가락 위치를 날짜로 환산한다.
  DateTime? _dateAt(Offset localPosition, Size size) {
    final cellW = size.width / 7;
    const cellH = 40.0;
    final col = (localPosition.dx / cellW).floor();
    final row = (localPosition.dy / cellH).floor();
    if (col < 0 || col > 6 || row < 0 || row >= _rowCount) return null;
    final dayNum = row * 7 + col - _leadingBlanks + 1;
    if (dayNum < 1 || dayNum > _daysInMonth) return null;
    return DateTime(_month.year, _month.month, dayNum);
  }

  void _handleDrag(Offset localPosition) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final date = _dateAt(localPosition, box.size);
    if (date == null) return;

    setState(() {
      if (widget.singleDay) {
        _start = date;
        _end = date;
        return;
      }
      _anchor ??= date;
      if (date.isBefore(_anchor!)) {
        _start = date;
        _end = _anchor;
      } else {
        _start = _anchor;
        _end = date;
      }
    });
  }

  bool _inRange(DateTime d) {
    if (_start == null || _end == null) return false;
    return !d.isBefore(_start!) && !d.isAfter(_end!);
  }

  bool _isEdge(DateTime d) =>
      (_start != null && _isSameDay(d, _start!)) ||
      (_end != null && _isSameDay(d, _end!));

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _monthHeader(),
        const SizedBox(height: 12),
        _weekdayLabels(),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            _anchor = null;
            _handleDrag(d.localPosition);
          },
          onPanUpdate: (d) => _handleDrag(d.localPosition),
          onPanEnd: (_) {
            _anchor = null;
            _emit();
          },
          onTapDown: (d) {
            _anchor = null;
            _handleDrag(d.localPosition);
          },
          onTapUp: (_) {
            _anchor = null;
            _emit();
          },
          child: SizedBox(
            key: _gridKey,
            height: _rowCount * 40.0,
            child: Column(children: List.generate(_rowCount, _buildWeekRow)),
          ),
        ),
      ],
    );
  }

  Widget _monthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _monthArrow(Icons.chevron_left_rounded, () {
          setState(() => _month = DateTime(_month.year, _month.month - 1));
        }),
        Text(
          '${_month.year}년 ${_month.month}월',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        _monthArrow(Icons.chevron_right_rounded, () {
          setState(() => _month = DateTime(_month.year, _month.month + 1));
        }),
      ],
    );
  }

  Widget _monthArrow(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Icon(icon, size: 24, color: AppColors.textSecondary),
    );
  }

  Widget _weekdayLabels() {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: labels
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildWeekRow(int row) {
    return SizedBox(
      height: 40,
      child: Row(
        children: List.generate(7, (col) {
          final dayNum = row * 7 + col - _leadingBlanks + 1;
          if (dayNum < 1 || dayNum > _daysInMonth) {
            return const Expanded(child: SizedBox.shrink());
          }
          final date = DateTime(_month.year, _month.month, dayNum);
          return Expanded(child: _buildDayCell(date, dayNum));
        }),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, int dayNum) {
    final inRange = _inRange(date);
    final isEdge = _isEdge(date);
    final isStart = _start != null && _isSameDay(date, _start!);
    final isEnd = _end != null && _isSameDay(date, _end!);

    return Semantics(
      button: true,
      selected: isEdge,
      label: '${date.year}년 ${date.month}월 ${date.day}일',
      onTap: () {
        setState(() {
          _start = date;
          _end = date;
        });
        _emit();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 선택 구간 연결 배경 — 양 끝만 둥글고 가운데는 직각이라 쭉 이어져 보인다
          if (inRange)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(isStart ? 18 : 0),
                      right: Radius.circular(isEnd ? 18 : 0),
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEdge ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isEdge ? FontWeight.w700 : FontWeight.w500,
                color: isEdge ? AppColors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
