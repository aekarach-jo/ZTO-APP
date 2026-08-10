import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot signal used by the Parcel tab to pre-select parcels in the Send
/// flow. Carries only the parcel ids — the Send flow resolves the rest of the
/// parcel details from [sendParcelsProvider], keeping a single source of truth.
final sendForwardPrefillProvider = StateProvider<List<String>?>((ref) => null);

/// Bumped when the customer taps the Send tab while already on it, which means
/// "take me back to the start of the flow". A counter rather than a flag so a
/// second tap fires again without anyone having to clear it.
final sendFlowResetSignalProvider = StateProvider<int>((ref) => 0);
