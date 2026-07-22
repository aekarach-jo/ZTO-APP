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
}
