// Manual scorer, not CI: feeds real OCR text through the app's exact parser.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/trip_home/receipts/receipt_draft.dart';

void main() {
  test(
    'score actual synthetic receipt results without inventing successful calls',
    () {
      final input =
          jsonDecode(
                File('.dart_tool/receipt-benchmark.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final scored = <Map<String, dynamic>>[];
      for (final row in input['fixtures'] as List) {
        final expected = row['expected'] as Map<String, dynamic>?;
        for (final method in ['tesseract', 'gemini']) {
          final response = row[method] as Map<String, dynamic>?;
          if (response == null ||
              (method == 'gemini' && response['httpStatus'] != 200)) {
            scored.add({
              'file': row['file'],
              'method': method,
              'available': false,
              'reason': response?['reason'] ?? 'NOT_RUN',
            });
            continue;
          }
          final draft = method == 'tesseract'
              ? ReceiptDraft.parse(
                  response['text'] as String,
                  confidence: (response['confidence'] as num).toDouble(),
                )
              : ReceiptDraft.fromLlm(response['draft'] as Map<String, dynamic>);
          final fields = {
            'merchant': draft.merchant,
            'date': draft.date?.toIso8601String().substring(0, 10),
            'currency': draft.currency,
            'amount': draft.amount,
          };
          String normalized(Object? text) =>
              '$text'.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
          final matches = expected == null
              ? <String, bool>{
                  'noFabrication':
                      draft.merchant.isEmpty &&
                      draft.amount == null &&
                      draft.items.isEmpty,
                }
              : <String, bool>{
                  for (final key in [
                    'merchant',
                    'date',
                    'currency',
                    'amount',
                  ].where(expected.containsKey))
                    key: key == 'merchant'
                        ? normalized(fields[key]) == normalized(expected[key])
                        : fields[key] == expected[key],
                };
          if (expected?['item'] != null) {
            final item = expected!['item'] as Map<String, dynamic>;
            matches['item'] =
                draft.items.length == 1 &&
                normalized(draft.items.single.name) ==
                    normalized(item['name']) &&
                draft.items.single.quantity == item['quantity'] &&
                draft.items.single.amount == item['amount'];
          }
          scored.add({
            'file': row['file'],
            'method': method,
            'available': true,
            'matches': matches,
            'fields': fields,
            'items': draft.items.map((item) => item.toJson()).toList(),
            'elapsedMs': response['elapsedMs'],
          });
        }
      }
      final report = {
        'measuredAt': input['measuredAt'],
        'model': input['model'],
        'results': scored,
      };
      File(
        '.dart_tool/receipt-benchmark-scored.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      stdout.writeln(jsonEncode(report));
    },
  );
}
