# Nokha Ride

Nokha Ride is a Flutter app for local car ride booking in Nokha and nearby areas. Bikes and self-drive rentals are not supported.

## Development in VS Code

1. Install Flutter and Android Studio (Android SDK/emulator).
2. Open this repository folder in VS Code. Install the recommended Dart and Flutter extensions when prompted.
3. Copy `config/production.example.json` to `config/production.json` and replace the placeholders with the existing Supabase project URL and publishable key. Keep `config/production.json` local; it is ignored by Git.
4. Use **Terminal → Run Task** to run:
   - `Nokha Ride: Get dependencies`
   - `Nokha Ride: Analyze`
   - `Nokha Ride: Run tests`
   - `Nokha Ride: Build QA APK`

The publishable/anon key is designed for client use when Row Level Security is correctly configured. Never put a Supabase service-role key or MSG91 Auth Key in Flutter, config JSON, or source control.

## Phone OTP with MSG91

The default login screen uses Supabase Auth phone OTP. Supabase generates/verifies the OTP and the signed Send SMS Auth Hook sends it through MSG91, so a successful verification returns a normal Supabase session. Existing email/password login is retained as a fallback during rollout.

Setup instructions, secret names, MSG91 Flow/DLT requirements, hosted Auth Hook configuration, and smoke tests are in [docs/msg91-supabase-setup.md](docs/msg91-supabase-setup.md).

## CI verification

GitHub Actions runs the Deno type-check for the MSG91 hook, Flutter dependency resolution, Dart analysis, tests, and a debug QA APK build. A passing debug build is not a production-signed release and does not prove live SMS delivery or a live Supabase deployment.

## Existing backend schema

The existing Supabase schema and RLS migration are preserved. The new phone-auth migration is additive and provisions a profile plus the least-privileged `CUSTOMER` role for newly created users. Do not seed fake vehicles or bookings into production.
