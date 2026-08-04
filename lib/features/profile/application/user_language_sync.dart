import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../home/data/home_parcel_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../parcel_status/data/parcel_status_repository.dart';
import '../../send/data/send_repository.dart';
import '../data/profile_repository.dart';

/// These take a [ProviderContainer] rather than a `WidgetRef` because the
/// language switcher lives inside a popup menu that is torn down as soon as a
/// language is picked — the container outlives that widget, a `WidgetRef` does
/// not. Grab it with `ProviderScope.containerOf(context)` while still mounted.

/// Sends the UI language to `PATCH /users/me/language` so the backend can send
/// push notifications in the language the customer picked. Signed-out callers
/// (the auth screens have a language switcher too) are a silent no-op — the
/// choice is pushed again by [reconcileUserLanguage] once a session exists.
Future<void> pushUserLanguage(
  ProviderContainer container,
  String languageCode,
) async {
  final code = normalizeUserLanguage(languageCode);
  if (code.isEmpty) {
    return;
  }

  final tokens = await container.read(tokenStorageProvider).read();
  final accessToken = tokens?.accessToken;
  if (accessToken == null || accessToken.isEmpty) {
    _log('Skip push: no access token yet (language=$code)');
    return;
  }

  try {
    await container.read(profileRepositoryProvider).updateLanguage(code);
    container.invalidate(userProfileProvider);
    invalidateServerLocalizedData(container);
    _log('Pushed language=$code');
  } catch (error) {
    // Nothing to surface: the next switch or app start reconciles the value.
    _log('Push failed for language=$code: $error');
  }
}

/// Drops the cached payloads whose text the backend localizes off the user's
/// stored language (notification titles/bodies, parcel status labels). Calling
/// `setLocale` only re-renders the app's own translations, so without this the
/// lists keep showing whatever language they were fetched in. Must run *after*
/// `PATCH /users/me/language` succeeds, otherwise the refetch races the change
/// and comes back in the previous language.
void invalidateServerLocalizedData(ProviderContainer container) {
  container.invalidate(notificationsProvider);
  container.invalidate(homeParcelsProvider);
  container.invalidate(parcelStatusProvider);
  container.invalidate(sendParcelsProvider);
}

/// Lines the backend language up with the app language once a session exists.
///
/// The app locale wins whenever the customer has already picked one in the UI
/// (easy_localization only has a `savedLocale` after an explicit `setLocale`);
/// otherwise the stored `language` from `GET /users/me` seeds the UI so a
/// returning customer sees the language their pushes arrive in.
Future<void> reconcileUserLanguage(
  BuildContext context,
  ProviderContainer container,
) async {
  final String serverLanguage;
  try {
    serverLanguage = (await container.read(userProfileProvider.future)).language;
  } catch (error) {
    _log('Skip reconcile: profile unavailable ($error)');
    return;
  }

  if (!context.mounted) {
    return;
  }

  final appLanguage = context.locale.languageCode;
  final hasPickedInApp = EasyLocalization.of(context)?.savedLocale != null;

  if (!hasPickedInApp && serverLanguage.isNotEmpty) {
    if (serverLanguage != appLanguage) {
      _log('Adopting server language=$serverLanguage');
      await context.setLocale(Locale(serverLanguage));
    }
    return;
  }

  if (serverLanguage != appLanguage) {
    await pushUserLanguage(container, appLanguage);
  }
}

void _log(String message) {
  if (kDebugMode) {
    debugPrint('[USER_LANGUAGE] $message');
  }
}
