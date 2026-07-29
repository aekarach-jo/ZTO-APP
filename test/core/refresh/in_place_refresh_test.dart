import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/refresh/in_place_refresh.dart';

void main() {
  test('flags the refresh while it runs and clears it afterwards', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reload = Completer<void>();

    final refresh = runInPlaceRefresh(
      container.read(inPlaceRefreshCountProvider.notifier),
      reload.future,
    );
    expect(container.read(isRefreshingInPlaceProvider), isTrue);

    reload.complete();
    await refresh;

    expect(container.read(isRefreshingInPlaceProvider), isFalse);
  });

  test('a failed reload clears the flag without rethrowing', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await runInPlaceRefresh(
      container.read(inPlaceRefreshCountProvider.notifier),
      Future<void>.error(StateError('reload failed')),
    );

    expect(container.read(isRefreshingInPlaceProvider), isFalse);
  });

  test(
    'overlapping refreshes keep the flag up until the last one ends',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final counter = container.read(inPlaceRefreshCountProvider.notifier);
      final first = Completer<void>();
      final second = Completer<void>();

      final firstRefresh = runInPlaceRefresh(counter, first.future);
      final secondRefresh = runInPlaceRefresh(counter, second.future);

      first.complete();
      await firstRefresh;
      expect(container.read(isRefreshingInPlaceProvider), isTrue);

      second.complete();
      await secondRefresh;
      expect(container.read(isRefreshingInPlaceProvider), isFalse);
    },
  );
}
