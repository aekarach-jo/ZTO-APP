# ZTO App (Phase 1)

Flutter mobile app foundation for the Member flow.

## What Is Implemented

- Feature-first project structure
- Riverpod state management
- go_router navigation
- easy_localization (EN / ZH / LO)
- flutter_screenutil responsive sizing
- Authentication UI (login/register) with validation
- Main layout with bottom navigation (Home/History/Profile)
- Role-based main layout scaffold (Customer/Staff) with switch role button
- Customer-first default role after login/register (API role mapping pending)
- Interactive first-tab search/filter for Customer parcel and Staff receive screens
- Customer Send tab (parcel selection step) with localized text and selection state
- Focused tests for auth role switching and first-tab filtering behavior
- HTTP foundation with `dio` + auth interceptor scaffold
- Secure token storage scaffold (`flutter_secure_storage`)
- Environment config scaffold (`flutter_dotenv`)
- Model codegen setup (`freezed` + `json_serializable`)

## Required Tools

- Flutter SDK (3.35.x or compatible with Dart 3.11.x)
- Xcode (for iOS simulator on macOS)
- Android Studio + Android SDK (for Android emulator)
- Chrome (optional, for web run)

## Project Structure

```text
lib/
  core/
    router/
      app_router.dart
    theme/
      app_theme.dart
  features/
    auth/
      application/
        auth_provider.dart
      presentation/
        screens/
          login_screen.dart
          register_screen.dart
    home/
      presentation/
        screens/
          home_screen.dart
    history/
      presentation/
        screens/
          history_screen.dart
    profile/
      presentation/
        screens/
          profile_screen.dart
    main_layout/
      presentation/
        screens/
          main_layout_screen.dart
  shared/
    widgets/
      custom_text_field.dart
      primary_button.dart
      language_toggle_button.dart
  main.dart
assets/
  translations/
    en.json
    zh.json
    lo.json
```

## Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Environment Files

- `.env` (default)
- `.env.dev`
- `.env.staging`
- `.env.prod`

Current keys used:

- `API_BASE_URL`
- `APP_ENV`

## Test

```bash
flutter test
```
# ZTO-APP
