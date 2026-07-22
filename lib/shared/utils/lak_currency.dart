import 'package:easy_localization/easy_localization.dart';

/// Formats an amount in Lao Kip, e.g. `₭16,050`. Amounts are always whole kip.
String formatLak(num amount) {
  return '₭${NumberFormat('#,##0').format(amount)}';
}
