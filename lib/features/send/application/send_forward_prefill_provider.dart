import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot signal used by the Parcel tab to pre-select a parcel in the Send
/// flow. Carries only the parcel id — the Send flow resolves the rest of the
/// parcel details from [sendParcelsProvider], keeping a single source of truth.
final sendForwardPrefillProvider = StateProvider<String?>((ref) => null);
