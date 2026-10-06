import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/trip_home/data/device_trip_repository.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/receipt_item.dart';
import 'package:tripapp/trip_home/models/spending_summary.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/receipts/receipt_platform_native.dart';
import 'package:tripapp/trip_home/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'budget gradient preserves small white text contrast and no purple category',
    () {
      for (final color in AppColors.budgetGradient.colors) {
        expect(
          1.05 / (color.computeLuminance() + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(categoryColor('숙박'), const Color(0xFFA4DDF4));
      expect(categoryColor('숙소'), categoryColor('숙박'));
      expect(categoryColors.values.toSet().length, categoryColors.length);
    },
  );

  test(
    'device trips and receipt items survive reopen, edit and delete',
    () async {
      final repo = await DeviceTripRepository.open();
      final t = Trip(
        id: 'jp',
        name: '일본',
        country: countryByIso('JP')!,
        start: DateTime(2027, 5, 1),
        end: DateTime(2027, 5, 8),
        budgetKrw: 1000000,
      );
      await repo.saveTrip(t);
      final receipt = Expense(
        id: 'receipt',
        icon: '🍜',
        place: '페이히어 카페',
        amount: 5000,
        date: DateTime(2027, 5, 2, 12),
        category: '식비',
        currency: 'KRW',
        paymentMethod: PaymentMethod.card,
        isTaxFree: true,
        memo: '커피',
        recordedQuote: 1,
        receiptFingerprint: 'sample',
        receiptItems: const [
          ReceiptItem(
            name: 'Americano',
            quantity: 1,
            amount: 5000,
            unitPrice: 5000,
          ),
        ],
        receiptTaxes: const [
          ReceiptTax(
            label: '부가세',
            amount: 455,
            currency: 'KRW',
            included: true,
          ),
        ],
        receiptAdjustments: const ReceiptAdjustments(
          taxFree: true,
          exemptedTax: 455,
          currency: 'KRW',
          details: [
            ReceiptAdjustmentLine(
              label: '포장비',
              kind: 'surcharge',
              amount: 500,
              currency: 'KRW',
            ),
          ],
        ),
      );
      await repo.saveExpense(t.id, receipt);
      await Future.wait([
        repo.renameTrip(t.id, '봄 여행'),
        repo.saveExpense(
          t.id,
          Expense(
            id: 'refund',
            icon: '💸',
            place: '취소',
            amount: 10,
            originalAmount: 10,
            date: DateTime(2027, 5, 3),
            status: ExpenseStatus.cancelled,
            source: 'codef',
          ),
        ),
      ]);
      await repo.close();
      final restored = await DeviceTripRepository.open();
      expect((await restored.watchTrips().first).single.name, '봄 여행');
      final expenses = await restored.watchExpenses(t.id).first;
      final e = expenses.firstWhere((e) => e.id == receipt.id);
      expect(e.currency, 'KRW');
      expect(e.paymentMethod, PaymentMethod.card);
      expect(e.isTaxFree, isTrue);
      expect(e.memo, '커피');
      expect(e.recordedQuote, 1);
      expect(e.receiptFingerprint, 'sample');
      expect(e.receiptItems.single.name, 'Americano');
      expect(e.receiptItems.single.quantity, 1);
      expect(e.receiptItems.single.amount, 5000);
      expect(e.receiptTaxes.single.amount, 455);
      expect(e.receiptTaxes.single.included, isTrue);
      expect(e.receiptAdjustments!.taxFree, isTrue);
      expect(e.receiptAdjustments!.exemptedTax, 455);
      expect(e.receiptAdjustments!.details.single.label, '포장비');
      expect(e.receiptAdjustments!.details.single.amount, 500);
      expect(e.amount, 5000);
      expect(expenses.last.status, ExpenseStatus.cancelled);
      expect(expenses.last.originalAmount, 10);
      t.budgetKrw = 2000000;
      await restored.updateTrip(t);
      expect((await restored.watchExpenses(t.id).first).length, 2);
      await restored.deleteExpense(t.id, e.id);
      expect((await restored.watchExpenses(t.id).first).single.id, 'refund');
      await restored.deleteTrip(t.id);
      expect(await restored.watchTrips().first, isEmpty);
      await restored.close();
      final empty = await DeviceTripRepository.open();
      expect(await empty.watchTrips().first, isEmpty);
      await empty.close();
    },
  );

  test(
    'device store is not reported as a remote account and streams update',
    () async {
      final repo = await DeviceTripRepository.open();
      final store = TripStore()..connect(repo, remote: false);
      await Future<void>.delayed(Duration.zero);
      expect(store.isRemote, isFalse);
      expect(store.isLoading, isFalse);
      final trip = Trip(
        id: 'kr',
        name: '여행',
        country: countryByIso('KR')!,
        start: DateTime(2027),
        end: DateTime(2027, 1, 2),
        budgetKrw: 100000,
      );
      store.add(trip);
      await Future<void>.delayed(Duration.zero);
      await store.saveExpense(
        trip.id,
        Expense(
          id: '1',
          icon: '💸',
          place: '카페',
          amount: 5000,
          date: DateTime(2027),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.byId(trip.id)!.expenses.length, 1);
      await store.deleteExpense(trip.id, '1');
      await Future<void>.delayed(Duration.zero);
      expect(store.byId(trip.id)!.expenses, isEmpty);
      store.connect(null);
      await repo.close();
      store.dispose();
    },
  );

  test(
    'corrupt device records are not overwritten with an empty list',
    () async {
      SharedPreferences.setMockInitialValues({
        DeviceTripRepository.storageKey: 'broken',
      });
      await expectLater(DeviceTripRepository.open(), throwsFormatException);
      expect(
        (await SharedPreferences.getInstance()).getString(
          DeviceTripRepository.storageKey,
        ),
        'broken',
      );
    },
  );

  test(
    'iOS receipt channel returns native OCR, cancel and errors without fake results',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(receiptChannel, (call) async {
            calls++;
            if (call.method == 'close') return null;
            expect(call.arguments['gallery'], calls == 2);
            if (calls == 1) {
              return jsonEncode({
                'text': '페이히어 카페\n결제금액 5,000원',
                'confidence': 95,
              });
            }
            if (calls == 2) return null;
            throw PlatformException(
              code: 'receipt',
              message: '카메라 권한이 꺼져 있어요.',
            );
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(receiptChannel, null),
      );
      expect(
        jsonDecode((await openReceiptCamera())!)['text'],
        contains('5,000원'),
      );
      expect(await openReceiptCamera(gallery: true), isNull);
      await expectLater(openReceiptCamera(), throwsA(isA<PlatformException>()));
      closeReceiptCamera();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 4);
    },
  );
}
