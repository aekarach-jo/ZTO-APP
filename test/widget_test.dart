// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zto_app/main.dart';

void main() {
  testWidgets('App shows login screen', (WidgetTester tester) async {
    await EasyLocalization.ensureInitialized();

    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
            Locale('lo'),
          ],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          child: const ZtoApp(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
