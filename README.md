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

The default phone login uses the MSG91 OTP Widget. The app sends the widget access token to a server-side Supabase Edge Function, which verifies it with MSG91 and then establishes a normal Supabase Auth session. Existing email/password login remains available. The MSG91 main Auth Key and Supabase service-role key never enter the Flutter app.

Configure `MSG91_WIDGET_ID` and the widget token in your ignored local `config/production.json`; keep `MSG91_AUTH_KEY` as a server-side Supabase secret. Setup and verification steps are in [docs/msg91-supabase-setup.md](docs/msg91-supabase-setup.md).

## CI verification

GitHub Actions runs the Deno type-check for the MSG91 session function, Flutter dependency resolution, Dart analysis, tests, and a debug QA APK build. A passing debug build is not a production-signed release and does not prove live SMS delivery or a live Supabase deployment.

## Existing backend schema

The existing Supabase schema, RLS policies, migrations, and role-assignment trigger are preserved. No database migration is required for this widget integration. A new phone user is created only after MSG91 token verification, and the existing verified-user trigger assigns the `CUSTOMER` role. Existing accounts with another login method are not taken over by phone matching.
