import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/trip_store.dart';
import '../models/country.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/calendar_range_picker.dart';
import '../widgets/country_chip.dart';
import '../widgets/sheets.dart';

/// 02. 새 여행 추가.
class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  Country? _selected;
  Country? _fromMoreSheet; // 더보기에서 고른 국가
  DateRange? _range;
  final _budgetController = TextEditingController();

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selected != null && _range != null && _budgetValue > 0;

  int get _budgetValue =>
      int.tryParse(_budgetController.text.replaceAll(',', '')) ?? 0;

  Future<void> _openMoreCountries() async {
    final picked = await showAppSheet<Country>(
      context: context,
      builder: (_) => MoreCountrySheet(initialSelected: _fromMoreSheet),
    );
    if (picked == null) return;
    setState(() {
      _fromMoreSheet = picked;
      _selected = picked;
    });
  }

  Future<void> _openDatePicker() async {
    final picked = await showAppSheet<DateRange>(
      context: context,
      builder: (_) => DateRangeSheet(initialRange: _range),
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  void _submit() {
    if (!_canSubmit) return;
    tripStore.add(Trip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '${_selected!.name} 여행',
      country: _selected!,
      start: _range!.start,
      end: _range!.end,
      budgetKrw: _budgetValue,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel('여행 국가 선택'),
                    const SizedBox(height: 12),
                    _countryGrid(),
                    const SizedBox(height: 28),
                    _sectionLabel('여행 기간'),
                    const SizedBox(height: 12),
                    _dateRow(),
                    const SizedBox(height: 28),
                    _sectionLabel('예산 (원화)'),
                    const SizedBox(height: 12),
                    _budgetField(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _submitButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
      child: Row(
        children: [
          InkResponse(
            onTap: () => Navigator.of(context).pop(),
            radius: 22,
            child: const Icon(Icons.arrow_back_rounded,
                size: 24, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          const Text(
            '새 여행 추가',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  Widget _countryGrid() {
    // 기본 7개국 + 마지막 칸은 "더보기"
    final cells = <Widget>[
      for (final c in kPrimaryCountries)
        CountryChip(
          country: c,
          selected: _selected?.currency == c.currency,
          onTap: () => setState(() {
            _selected = c;
            _fromMoreSheet = null;
          }),
        ),
      MoreCountryChip(
        selectedCountry: _fromMoreSheet,
        onTap: _openMoreCountries,
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: cells,
    );
  }

  Widget _dateRow() {
    return Row(
      children: [
        Expanded(
          child: _dateBox(
            '출발일',
            _range == null ? '선택' : formatDate(_range!.start),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dateBox(
            '도착일',
            _range == null ? '선택' : formatDate(_range!.end),
          ),
        ),
      ],
    );
  }

  Widget _dateBox(String label, String value) {
    final isEmpty = value == '선택';
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _openDatePicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _budgetField() {
    return TextField(
      controller: _budgetController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      cursorColor: AppColors.primary,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '1,200,000',
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w500,
        ),
        suffixText: '원',
        suffixStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return Opacity(
      opacity: _canSubmit ? 1 : 0.4,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _canSubmit ? _submit : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: const Text(
              '여행 만들기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
