import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/notifications/fcm_notification_service.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';
import 'package:zto_app/features/notifications/data/notification_repository.dart';
import 'package:zto_app/features/parcel_status/data/parcel_status_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'refreshFcmRelatedProviders invalidates notification and parcel providers',
    () {
      final invalidatedProviders = <ProviderOrFamily>[];

      refreshFcmRelatedProviders(invalidatedProviders.add);

      expect(
        invalidatedProviders,
        equals(<ProviderOrFamily>[
          notificationsProvider,
          homeParcelsProvider,
          parcelStatusProvider,
        ]),
      );
    },
  );

  group('shouldRefreshOnResume', () {
    final now = DateTime(2026, 7, 26, 20, 39);

    test('refreshes when the app has never refreshed on resume', () {
      expect(shouldRefreshOnResume(now: now, lastRefreshAt: null), isTrue);
    });

    test('skips a resume that follows a recent refresh', () {
      expect(
        shouldRefreshOnResume(
          now: now,
          lastRefreshAt: now.subtract(const Duration(seconds: 5)),
        ),
        isFalse,
      );
    });

    test('refreshes once the throttle window has elapsed', () {
      expect(
        shouldRefreshOnResume(
          now: now,
          lastRefreshAt: now.subtract(resumeRefreshMinInterval),
        ),
        isTrue,
      );
    });
  });
}
