import 'package:flutter_riverpod/flutter_riverpod.dart';

// One-shot signal used by feature tabs to request customer-tab navigation.
final customerTabJumpTargetProvider = StateProvider<int?>((ref) => null);

