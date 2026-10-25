import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_mate/models/expense.dart';
import 'package:expense_mate/services/database_service.dart';
import 'package:expense_mate/services/ai_service.dart';
import 'package:expense_mate/state/expense_store.dart';
import 'package:expense_mate/screens/review_screen.dart';

class MemoryDb extends DatabaseService {
  final List<Expense> saved = [];
  @override
  Future<List<Expense>> all() async => [];
  @override
  Future<void> save(Expense item) async {
    saved.add(item);
  }
}

void main() {
  for (final size in const [Size(800, 600), Size(430, 932)]) {
    testWidgets(
      'AI proposals do not overwrite or save until the user applies selected fields (${size.width}x${size.height})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        SharedPreferences.setMockInitialValues({
          'ai_token': 'a' * 32,
          'ai_url': 'http://127.0.0.1:8787',
        });
        final db = MemoryDb();
        final client = MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'source': 'gemini',
                'merchant': {'value': 'CÀ PHÊ AN', 'evidence': 'CÀ PHÊ AN'},
                'amount': {'value': 65000, 'evidence': 'Phải trả 65000'},
                'date': {'value': '2026-10-25', 'evidence': '2026-10-25'},
                'warnings': <String>[],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
        addTearDown(client.close);
        final active = ExpenseStore(db);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: active,
            child: MaterialApp(
              home: ReviewScreen(
                rawText: 'CÀ PHÊ AN\n2026-10-25\nPhải trả 65000',
                aiService: AiService(client: client),
              ),
            ),
          ),
        );
        final fields = tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .toList();
        final merchant = fields[0].controller!, amount = fields[1].controller!;
        expect(amount.text, isEmpty);
        merchant.text = 'Tên người dùng đã sửa';
        final originalMerchant = merchant.text;
        Finder buttonWithLabel(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        Future<void> tapReviewButton(Finder button) async {
          await tester.scrollUntilVisible(
            button,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ReviewScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          // A text label may be partly visible behind the fixed save bar.
          // Center the whole button in the ListView's viewport before tapping.
          await Scrollable.ensureVisible(
            tester.element(button),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          expect(button.hitTestable(), findsOneWidget);
          await tester.tap(button.hitTestable());
          await tester.pumpAndSettle();
        }

        await tapReviewButton(buttonWithLabel('AI hỗ trợ hóa đơn khó'));
        expect(find.byType(AlertDialog), findsOneWidget);
        final consent = buttonWithLabel('Đồng ý gửi');
        expect(consent.hitTestable(), findsOneWidget);
        await tester.tap(consent.hitTestable());
        await tester.pumpAndSettle();
        expect(amount.text, isEmpty);
        expect(merchant.text, originalMerchant);
        expect(db.saved, isEmpty);
        await tapReviewButton(buttonWithLabel('Áp dụng mục đã chọn'));
        expect(amount.text, '65000');
        expect(merchant.text, originalMerchant);
        expect(db.saved, isEmpty);
        await tester.pumpWidget(const SizedBox());
        active.dispose();
      },
    );
  }
}
