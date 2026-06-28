import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/contact/data/contact_repository.dart';
import 'package:zto_app/features/contact/presentation/screens/contact_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _FakeContactRepository extends ContactRepository {
  _FakeContactRepository() : super(dio: Dio());

  @override
  Future<List<ContactMessage>> fetchMessages() async {
    return [
      ContactMessage(
        id: 'welcome',
        role: ContactMessageRole.agent,
        text: 'Welcome to support. Ask parcel status now!',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<ContactMessage>> sendMessage({required String text}) async {
    return [
      ContactMessage(
        id: 'reply',
        role: ContactMessageRole.agent,
        text: 'Support received: $text',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

Widget _buildTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'unused',
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    assetLoader: const MockAssetLoader(kTestTranslations),
    child: Builder(
      builder: (context) {
        return ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: ProviderScope(
                overrides: [
                  contactRepositoryProvider.overrideWith(
                    (ref) => _FakeContactRepository(),
                  ),
                ],
                child: Scaffold(body: child),
              ),
            );
          },
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sends a message and shows support auto-reply', (tester) async {
    await tester.pumpWidget(_buildTestApp(const ContactScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      find.text('Welcome to support. Ask parcel status now!'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Where is parcel #FW123');
    await tester.tap(find.byKey(const ValueKey('contact-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('Where is parcel #FW123'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(
      find.text('Support received: Where is parcel #FW123'),
      findsOneWidget,
    );

    final bubbleFinder = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey &&
          (widget.key! as ValueKey).value.toString().startsWith(
            'contact-bubble-',
          ),
    );

    expect(bubbleFinder, findsAtLeastNWidgets(2));
  });
}
