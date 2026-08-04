import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/application/user_language_sync.dart';

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      tooltip: 'switch_language'.tr(),
      onSelected: (locale) async {
        final container = ProviderScope.containerOf(context, listen: false);
        await context.setLocale(locale);
        // No-op while signed out; the sign-in reconcile pushes it afterwards.
        await pushUserLanguage(container, locale.languageCode);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: Locale('en'),
          child: Text('English'),
        ),
        PopupMenuItem(
          value: Locale('zh'),
          child: Text('中文'),
        ),
        PopupMenuItem(
          value: Locale('lo'),
          child: Text('ລາວ'),
        ),
      ],
    );
  }
}
