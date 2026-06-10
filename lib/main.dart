import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/config/app_env.dart';
import 'core/notifications/fcm_token_sync_provider.dart';
import 'core/notifications/push_token_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await loadAppEnv();

  runApp(
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
}

class ZtoApp extends ConsumerWidget {
  const ZtoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushTokenBootstrapProvider);
    ref.watch(fcmTokenSyncProvider);
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'app_name'.tr(),
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final isDesktop = !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(isDesktop ? 0.82 : 1),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
        );
      },
    );
  }
}
