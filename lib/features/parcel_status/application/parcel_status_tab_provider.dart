import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/refresh/in_place_refresh.dart';
import '../../orders/data/order_repository.dart';
import '../data/parcel_status_repository.dart';

/// Summary card currently selected on the status section.
enum ParcelStatusTab {
  inProgress,
  selfPickup,
  forwarded,
  orders;

  /// Parcel category this tab lists, or null for the orders tab — which reads
  /// a different endpoint instead of filtering the parcel page.
  ParcelStatusCategory? get category {
    switch (this) {
      case ParcelStatusTab.inProgress:
        return ParcelStatusCategory.inProgress;
      case ParcelStatusTab.selfPickup:
        return ParcelStatusCategory.selfPickup;
      case ParcelStatusTab.forwarded:
        return ParcelStatusCategory.forwarded;
      case ParcelStatusTab.orders:
        return null;
    }
  }
}

/// Selected tab, held outside the widget for two reasons: the selection has to
/// survive the rebuilds a refetch causes, and the pull-to-refresh handlers that
/// sit above the section need to know which tab to reload.
final parcelStatusTabProvider = StateProvider<ParcelStatusTab>(
  (ref) => ParcelStatusTab.inProgress,
);

/// Refetches whatever backs [tab]: the three parcel tabs all come from
/// `GET /parcels/status`, the orders tab from `GET /orders`. The summary cards
/// stay on screen while it runs — see [isRefreshingInPlaceProvider].
Future<void> refreshParcelStatusTab(WidgetRef ref, ParcelStatusTab tab) {
  final Future<Object> reload = tab == ParcelStatusTab.orders
      ? ref.refresh(ordersProvider.future)
      : ref.refresh(parcelStatusProvider.future);
  return runInPlaceRefresh(
    ref.read(inPlaceRefreshCountProvider.notifier),
    reload,
  );
}
