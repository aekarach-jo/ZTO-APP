import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      tooltip: 'switch_language'.tr(),
      onSelected: context.setLocale,
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

