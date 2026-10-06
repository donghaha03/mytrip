import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripapp/trip_home/receipts/receipt_client.dart';
import 'package:tripapp/trip_home/receipts/receipt_draft.dart';
import 'package:tripapp/trip_home/receipts/receipt_platform_native.dart';
import 'package:tripapp/trip_home/receipts/receipt_screen.dart';

const code = 'fixture-access-code-0123456789-abcd';
const config = '{"serverUrl":"https://receipt.example.invalid"}';
final draft = {
  'merchant': '페이히어 카페',
  'date': null,
  'currency': 'KRW',
  'amount': 5000,
  'items': [
    {'name': 'Americano', 'quantity': 1, 'unit_price': 5000, 'amount': 5000},
  ],
  'warnings': ['날짜 확인 필요'],
};
const tinyImage = 'data:image/png;base64,YQ==';
final configUrl = Uri.parse(
  'https://donghaha03.github.io/mytrip/receipt-config.json',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Gemini provider is shared by native/web configuration and unknown providers are rejected',
    () async {
      var provider = 'gemini';
      final client = ReceiptClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'serverUrl': 'https://receipt.example.invalid',
              'provider': provider,
            }),
            200,
          ),
        ),
      );
      addTearDown(client.close);
      expect((await client.connection(configUrl: configUrl))!.isGemini, isTrue);
      expect(
        (await client.connection(
          configUrl: configUrl,
          serverUrl: 'https://receipt.example.invalid',
          provider: 'gemini',
        ))!.isGemini,
        isTrue,
      );
      provider = 'unknown';
      await expectLater(
        client.connection(configUrl: configUrl),
        throwsA(isA<ReceiptConnectionException>()),
      );
    },
  );
  test(
    'one HTTPS configuration serves browser and native clients without secrets',
    () async {
      final client = ReceiptClient(
        client: MockClient((request) async {
          expect(request.url.path, endsWith('receipt-config.json'));
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(config, 200);
        }),
      );
      addTearDown(client.close);
      final connection = await client.connection(configUrl: configUrl);
      expect(
        connection!.url.toString(),
        'https://receipt.example.invalid/receipt/recognize',
      );
      expect(connection.needsAccessCode, isTrue);
      for (final url in [
        'http://receipt.example.invalid',
        'https://user:secret@receipt.example.invalid',
        'https://receipt.example.invalid/?key=secret',
        'https://receipt.example.invalid/path',
      ]) {
        await expectLater(
          client.connection(configUrl: configUrl, serverUrl: url),
          throwsA(isA<ReceiptConnectionException>()),
        );
      }
    },
  );

  test(
    'public and local transports share the image payload and validated review fields',
    () async {
      final requests = <http.Request>[];
      final client = ReceiptClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'draft': draft}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      final public = await client.connection(
        configUrl: configUrl,
        serverUrl: 'https://receipt.example.invalid',
      );
      final local = await client.connection(
        configUrl: configUrl,
        localRuntime: jsonEncode({
          'url': 'http://127.0.0.1:8765/receipt/recognize',
          'csrf': 'fixture-csrf',
        }),
      );
      for (final connection in [public!, local!]) {
        final result = await client.recognize(
          connection,
          tinyImage,
          accessCode: code,
        );
        expect(result.merchant, '페이히어 카페');
        expect(result.amount, 5000);
        expect(result.items.single.name, 'Americano');
        expect(result.items.single.quantity, 1);
        expect(result.items.single.amount, 5000);
        expect(result.date, isNull);
      }
      expect(requests[0].body, requests[1].body);
      expect(requests[0].headers['Authorization'], 'Bearer $code');
      expect(requests[1].headers['X-mytrip-csrf'], 'fixture-csrf');
      expect(requests[1].headers['Authorization'], isNull);
    },
  );

  test(
    'bad access codes, provider errors and partial drafts do not become success',
    () async {
      var calls = 0, status = 401;
      final client = ReceiptClient(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            status == 200 ? '{"draft":{}}' : 'private-provider-error',
            status,
          );
        }),
      );
      addTearDown(client.close);
      final connection = await client.connection(
        configUrl: configUrl,
        serverUrl: 'https://receipt.example.invalid',
      );
      await expectLater(
        client.recognize(
          connection!,
          tinyImage,
          accessCode: 'sk-private-api-key',
        ),
        throwsA(isA<ReceiptConnectionException>()),
      );
      expect(calls, 0);
      for (final value in [401, 403, 429, 504, 502, 200]) {
        status = value;
        await expectLater(
          client.recognize(connection, tinyImage, accessCode: code),
          throwsA(isA<ReceiptConnectionException>()),
        );
      }
      expect(calls, 6);
    },
  );

  test('double recognition clicks do not send a second request', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final client = ReceiptClient(
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    addTearDown(client.close);
    final connection = await client.connection(
      configUrl: configUrl,
      serverUrl: 'https://receipt.example.invalid',
    );
    final first = client.recognize(connection!, tinyImage, accessCode: code);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      client.recognize(connection, tinyImage, accessCode: code),
      throwsA(isA<ReceiptConnectionException>()),
    );
    expect(calls, 1);
    pending.complete(
      http.Response.bytes(utf8.encode(jsonEncode({'draft': draft})), 200),
    );
    await first;
  });

  test(
    'unconfigured is explicit; offline configuration is not a silent device fallback',
    () async {
      final unconfigured = ReceiptClient(
        client: MockClient(
          (_) async => http.Response('{"serverUrl":null}', 200),
        ),
      );
      addTearDown(unconfigured.close);
      expect(await unconfigured.connection(configUrl: configUrl), isNull);
      final offline = ReceiptClient(
        client: MockClient((_) async => http.Response('offline', 503)),
      );
      addTearDown(offline.close);
      await expectLater(
        offline.connection(configUrl: configUrl),
        throwsA(isA<ReceiptConnectionException>()),
      );
    },
  );

  testWidgets(
    'iPhone photo needs consent; failure retains photo and review cancel does not save',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final image =
          'data:image/png;base64,${base64Encode(File('test/fixtures/receipt_en.png').readAsBytesSync())}';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(receiptChannel, (call) async {
            if (call.method == 'close') return null;
            expect(call.arguments['captureOnly'], isTrue);
            return jsonEncode({'image': image});
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(receiptChannel, null),
      );
      var posts = 0, fail = true;
      ReceiptDraft? saved;
      final client = ReceiptClient(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '{"serverUrl":"https://receipt.example.invalid","provider":"gemini"}',
              200,
            );
          }
          posts++;
          expect(jsonDecode(request.body)['image'], image);
          return http.Response.bytes(
            utf8.encode(fail ? '{}' : jsonEncode({'draft': draft})),
            fail ? 401 : 200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<ReceiptDraft>(
                    MaterialPageRoute(
                      builder: (_) => ReceiptScreen(client: client),
                    ),
                  );
                },
                child: const Text('촬영 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('촬영 열기'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      expect(find.text('영수증 사진 확인'), findsOneWidget);
      expect(find.text('Google 데이터 처리·보관 정책'), findsOneWidget);
      expect(find.text('OpenAI 데이터 보관 정책'), findsNothing);
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('이 사진으로 인식'));
      await tester.tap(find.text('이 사진으로 인식'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('접속 코드를 확인해주세요.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      fail = false;
      await tester.ensureVisible(find.text('인식 재시도'));
      await tester.tap(find.text('인식 재시도'));
      await tester.pumpAndSettle();
      expect(posts, 2);
      expect(find.text('영수증 내용 확인'), findsOneWidget);
      expect(saved, isNull);
      Navigator.of(tester.element(find.text('영수증 내용 확인'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('영수증 사진 확인'), findsOneWidget);
      expect(saved, isNull);
      await tester.ensureVisible(find.text('인식한 내용 확인'));
      await tester.tap(find.text('인식한 내용 확인'));
      await tester.pumpAndSettle();
      expect(
        posts,
        2,
        reason: 'Reviewing the same photo must not incur another request',
      );
      expect(find.text('영수증 내용 확인'), findsOneWidget);
      Navigator.of(tester.element(find.text('영수증 내용 확인'))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('수동 입력으로 돌아가기'));
      await tester.tap(find.text('수동 입력으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('촬영 열기'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
