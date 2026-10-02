import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../models/country.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_converter.dart';
import '../widgets/screen_top_bar.dart';

class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key, required this.country});
  final Country country;
  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  late Country _selected = widget.country;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: RateApi.changes,
    builder: (context, _) {
      final fetched = RateApi.lastFetched?.toUtc().add(
        const Duration(hours: 9),
      );
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ScreenTopBar(title: '환율 현황'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    const Text(
                      '대한민국 원 기준 · 매일 06:00 KST 자동 갱신',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (fetched != null)
                      Text(
                        '마지막 수집 ${formatDate(fetched)} ${fetched.hour.toString().padLeft(2, '0')}:${fetched.minute.toString().padLeft(2, '0')} KST',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (RateApi.hasError || RateApi.isStale)
                      const Text(
                        '갱신 대기 · 마지막 정상 환율 사용',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    QuickConverter(
                      key: ValueKey(_selected.currency),
                      country: _selected,
                    ),
                    const SizedBox(height: 16),
                    for (final c in [...kPrimaryCountries, ...kMoreCountries])
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: AppColors.white,
                        elevation: 0,
                        child: ListTile(
                          leading: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text('${c.currency} · ${c.unitLabel}'),
                          subtitle: Text(currentRateLabel(c)),
                          selected: _selected.currency == c.currency,
                          trailing: _selected.currency == c.currency
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () => setState(() => _selected = c),
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
