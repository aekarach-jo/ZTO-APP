import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot signal used by the Parcel tab to pre-select parcels in the Send
/// flow. Carries only the parcel ids — the Send flow resolves the rest of the
/// parcel details from [sendParcelsProvider], keeping a single source of truth.
final sendForwardPrefillProvider = StateProvider<List<String>?>((ref) => null);
