import 'package:flutter/material.dart';

import '../models/country.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import 'app_sheet.dart';
import 'calendar_range_picker.dart';
import 'country_chip.dart';

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

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '국가 더보기',
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: kMoreCountries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: kCountryChipHeight,
          ),
          itemBuilder: (_, i) {
            final c = kMoreCountries[i];
            return CountryChip(
              country: c,
              compact: true,
              selected: _selected?.currency == c.currency,
              onTap: () => setState(() => _selected = c),
            );
          },
        ),
        const SizedBox(height: 16),
        SheetPrimaryButton(
          label: '선택 완료',
          onTap: () => Navigator.of(context).pop(_selected),
        ),
      ],
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
    return AppSheet(
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
                      ? '날짜를 드래그해 기간을 정해 주세요'
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
          onTap: () => Navigator.of(context).pop(_range),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 06. 여행 편집 (이름 인라인 수정 + 삭제)
// ---------------------------------------------------------------------------
enum TripEditAction { save, delete }

class TripEditResult {
  const TripEditResult(this.action, [this.name]);
  final TripEditAction action;
  final String? name;
}

class TripEditSheet extends StatefulWidget {
  const TripEditSheet({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends State<TripEditSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  static const _maxLength = 20;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.trip.name)
      ..addListener(() => setState(() {}));
    // 시트가 열리자마자 바로 수정할 수 있도록 커서를 올려 둔다.
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 키보드가 올라와도 시트가 가려지지 않게
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AppSheet(
        title: '여행 편집',
        children: [
          const Text(
            '여행 이름',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLength: _maxLength,
            cursorColor: AppColors.primary,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.cancel,
                          size: 20, color: AppColors.handle),
                      onPressed: () => _controller.clear(),
                    ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
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
          const SizedBox(height: 16),
          SheetPrimaryButton(
            label: '저장',
            onTap: () {
              final name = _controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context)
                  .pop(TripEditResult(TripEditAction.save, name));
            },
          ),
          const SizedBox(height: 8),
          Material(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.of(context)
                  .pop(const TripEditResult(TripEditAction.delete)),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.danger),
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
    );
  }
}
