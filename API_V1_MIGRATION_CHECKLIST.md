# API v1 Migration Checklist

Reference: `http://14.207.141.82/api/v1/docs#/`

> Note: This checklist reflects what is already implemented in the app codebase now.

## 1) Core configuration and auth

- [x] Set default base URL to `http://14.207.141.82/api/v1`
  - File: `lib/core/config/app_env.dart`
- [x] Remove mock auth toggle (`USE_MOCK_AUTH`) and keep API auth only
  - File: `lib/core/config/app_env.dart`
- [x] Use `ApiAuthRepository` as default auth repository
  - File: `lib/features/auth/data/auth_repository.dart`
- [x] Attach `Authorization: Bearer <token>` automatically via interceptor
  - File: `lib/core/network/interceptors/auth_interceptor.dart`
- [x] Handle token refresh on `401` and clear tokens on refresh failure
  - Files:
    - `lib/core/network/interceptors/auth_interceptor.dart`
    - `lib/core/network/network_providers.dart`

## 2) Feature migration: Mock -> API

### Home
- [x] Replace mock parcel list with API data
- [x] Use `/parcels` as data source
- [x] Keep search/filter behavior on real data
- [x] Add loading/empty/error states
- Files:
  - `lib/features/home/data/home_parcel_repository.dart`
  - `lib/features/home/presentation/screens/home_screen.dart`

### Notifications
- [x] Replace static notifications with API data
- [x] Use `/notifications` as data source
- [x] Add loading/empty/error + retry
- Files:
  - `lib/features/notifications/data/notification_repository.dart`
  - `lib/features/notifications/presentation/screens/notifications_screen.dart`

### Profile
- [x] Replace static summary/history cards with API-backed parcel grouping
- [x] Reuse parcel provider (from `/parcels`) for profile sections
- [x] Add loading/error + retry
- Files:
  - `lib/features/profile/presentation/screens/profile_screen.dart`
  - `lib/features/home/data/home_parcel_repository.dart`

### Send
- [x] Replace static selectable items with real parcels from API (`/parcels`)
- [x] Submit forward request to API
- [x] Keep multi-step flow (select -> recipient -> map -> payment)
- [x] Add loading/error + retry for parcel load
- [x] Add submission in-progress handling
- Files:
  - `lib/features/send/data/send_repository.dart`
  - `lib/features/send/presentation/screens/send_screen.dart`

### Staff Receive
- [x] Replace static incoming list with API parcel list
- [x] Add confirm inspected action via API call
- [x] Add loading/empty/error + retry
- Files:
  - `lib/features/staff/data/staff_parcel_repository.dart`
  - `lib/features/staff/presentation/screens/staff_receive_screen.dart`

### Staff Scan Pay
- [x] Replace local ready list with API-backed ready-to-handover list
- [x] Add confirm handover action via API call
- [x] Add loading/empty/error + retry
- Files:
  - `lib/features/staff/data/staff_parcel_repository.dart`
  - `lib/features/staff/presentation/screens/staff_scan_pay_screen.dart`

### Contact
- [x] Replace local mock conversation with API-backed thread
- [x] Add API send message action
- [x] Remove mock auto-reply logic
- [x] Add loading/error + retry and send-in-progress state
- Files:
  - `lib/features/contact/data/contact_repository.dart`
  - `lib/features/contact/presentation/screens/contact_screen.dart`

### History
- [x] Connect screen to API-backed parcel provider (completed/delivered filter)
- [x] Add loading/error + retry
- File:
  - `lib/features/history/presentation/screens/history_screen.dart`

## 3) Endpoint usage map (currently in code)

### Auth
- [x] `POST /auth/send-otp`
- [x] `POST /auth/login`
- [x] `POST /auth/register`
- [x] `PATCH /auth/fcm-token`
- [x] `POST /auth/refresh`

### Parcels and derived screens
- [x] `GET /parcels` (Home, Profile, Send source, Staff source)
- [x] `GET /notifications`

### Send actions
- [x] `POST /forwards` (primary)
- [x] `POST /forwarding-requests` (fallback)
- [x] `POST /parcels/{id}/forward` (fallback)

### Staff actions
- [x] `POST /staff/parcels/{id}/inspect` (primary)
- [x] `PATCH /parcels/{id}` with `status=ready_to_ship` (fallback)
- [x] `POST /staff/parcels/{id}/handover` (primary)
- [x] `PATCH /parcels/{id}` with `status=picked_up` (fallback)

### Contact actions
- [x] `GET /contact/messages` (primary)
- [x] `GET /chat/messages` (fallback)
- [x] `POST /contact/messages` (primary)
- [x] `POST /chat/messages` (fallback)

## 4) Test migration status

- [x] Updated widget tests to override providers/repositories (instead of static mock UI data)
- [x] Verified tests pass for migrated features
- Updated tests:
  - `test/features/home/home_screen_test.dart`
  - `test/features/notifications/notifications_screen_test.dart`
  - `test/features/profile/profile_screen_test.dart`
  - `test/features/send/send_screen_test.dart`
  - `test/features/staff/staff_receive_screen_test.dart`
  - `test/features/staff/staff_scan_pay_screen_test.dart`
  - `test/features/contact/contact_screen_test.dart`
  - `test/features/main_layout/main_layout_screen_test.dart`

## 5) Remaining items (to fully lock to Swagger)

- [ ] Replace fallback endpoints with strict final Swagger endpoints only
- [ ] Verify request/response schema field-by-field against latest docs
- [ ] Add end-to-end flow test: customer send -> staff inspect -> staff handover -> history/profile reflects final state
- [ ] Confirm all backend status enums and map UI chips/colors strictly to final enum contract

