import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_theme.dart';

/// Path of the bundled policy document rendered by [showPrivacyPolicySheet].
const String kPrivacyPolicyAsset = 'assets/legal/privacy_policy.md';

/// Shows the privacy policy as a draggable bottom sheet inside the app, so the
/// user never leaves it. The Play Console listing still needs the same document
/// published at a public URL, but the in-app presentation is up to us.
Future<void> showPrivacyPolicySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const _PrivacyPolicySheet(),
  );
}

class _PrivacyPolicySheet extends StatefulWidget {
  const _PrivacyPolicySheet();

  @override
  State<_PrivacyPolicySheet> createState() => _PrivacyPolicySheetState();
}

class _PrivacyPolicySheetState extends State<_PrivacyPolicySheet> {
  late final Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = rootBundle.loadString(kPrivacyPolicyAsset);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 44.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD5E6FF),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 8.w, 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'privacy_policy_title'.tr(),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandBlueDark,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('privacy-policy-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'common_close'.tr(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<String>(
                future: _document,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Text(
                          'privacy_policy_open_failed'.tr(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
                    children: _buildMarkdown(context, snapshot.data!),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders the subset of Markdown the policy document uses: `##`/`###`
/// headings, `-` bullets, `**bold**` runs, `---` rules and plain paragraphs.
/// The top-level `#` title is dropped because the sheet header already shows it.
List<Widget> _buildMarkdown(BuildContext context, String source) {
  final bodyStyle = TextStyle(
    fontSize: 14.sp,
    height: 1.55,
    color: const Color(0xFF33475B),
  );
  final widgets = <Widget>[];

  for (final rawLine in source.split('\n')) {
    final line = rawLine.trimRight();

    if (line.trim().isEmpty) {
      widgets.add(SizedBox(height: 10.h));
      continue;
    }
    if (line.startsWith('# ')) {
      continue;
    }
    if (line.startsWith('---')) {
      widgets.add(Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: const Divider(height: 1),
      ));
      continue;
    }
    if (line.startsWith('### ')) {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: 10.h, bottom: 4.h),
        child: Text(
          line.substring(4),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF33475B),
          ),
        ),
      ));
      continue;
    }
    if (line.startsWith('## ')) {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: 16.h, bottom: 6.h),
        child: Text(
          line.substring(3),
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: AppTheme.brandBlueDark,
          ),
        ),
      ));
      continue;
    }
    if (line.startsWith('- ')) {
      widgets.add(Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: bodyStyle),
            Expanded(
              child: Text.rich(_inlineSpan(line.substring(2), bodyStyle)),
            ),
          ],
        ),
      ));
      continue;
    }

    widgets.add(Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text.rich(_inlineSpan(line, bodyStyle)),
    ));
  }

  return widgets;
}

/// Splits a line on `**` pairs so the bold runs render inline.
TextSpan _inlineSpan(String text, TextStyle baseStyle) {
  final parts = text.split('**');
  return TextSpan(
    style: baseStyle,
    children: [
      for (var i = 0; i < parts.length; i++)
        TextSpan(
          text: parts[i],
          // Odd segments sit between a pair of markers, so they are the bold
          // ones. An unpaired trailing marker just renders as plain text.
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
    ],
  );
}
