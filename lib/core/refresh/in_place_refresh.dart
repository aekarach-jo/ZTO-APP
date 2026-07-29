import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Number of refreshes in flight that must leave the current data on screen.
/// A counter rather than a flag so two overlapping reloads don't clear each
/// other's state.
final inPlaceRefreshCountProvider = StateProvider<int>((ref) => 0);

/// True while a refresh that reloads the *same* data is running — a tab tap,
/// pull-to-refresh, an arriving push, or coming back to the app. Screens keep
/// what they already drew for these.
///
/// Reloads that are not flagged this way replace the data with something else
/// (a branch switch is the one that matters), so those still blank the screen
/// rather than leave the previous branch's parcels sitting there.
final isRefreshingInPlaceProvider = Provider<bool>(
  (ref) => ref.watch(inPlaceRefreshCountProvider) > 0,
);

/// Marks [reload] as in-place for as long as it runs.
///
/// [reload] has to be started by the caller before this is awaited: both happen
/// in the same synchronous block, so no frame can render between the reload
/// starting and the flag going up.
Future<void> runInPlaceRefresh(
  StateController<int> counter,
  Future<Object?> reload,
) async {
  counter.state++;
  try {
    await reload;
  } catch (_) {
    // Screens render the provider's own error state with a retry action;
    // rethrowing here would surface it as an unhandled error instead.
  } finally {
    counter.state--;
  }
}
