import 'package:flutter/material.dart';

import '../../ledger/models/country.dart';
import '../../ledger/theme/app_colors.dart';
import '../../ledger/widgets/app_sheet.dart';

/// 04. 국가 더보기
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
