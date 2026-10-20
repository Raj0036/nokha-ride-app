# Nokha Ride: MSG91 OTP Widget + Supabase session

This integration uses the **MSG91 OTP Widget** to send and verify OTPs. The Flutter app sends the widget access token to a Supabase Edge Function; the function validates that token with MSG91 and establishes a normal Supabase Auth session. Supabase does not generate or send the OTP in this flow.

## 1. Configure the MSG91 Widget

1. In the MSG91 dashboard, create or select the OTP Widget.
2. Configure the widget's allowed channel, OTP length, expiry, and resend limits.
3. Copy the Widget ID and the Widget Auth Token. The Widget Auth Token is not the main MSG91 Auth Key.
4. This implementation hosts MSG91's Web SDK inside a Flutter WebView, so keep the widget's **Mobile Integration** option disabled. If you enable MSG91 Mobile Integration, replace this WebView bridge with MSG91's native mobile SDK flow instead.
5. Do not put the main MSG91 Auth Key in the app. It must remain a server-side Supabase secret.

This integration does not set up a separate MSG91 SMS Flow or a Supabase Send SMS Auth Hook. Configure the supported channel in the widget dashboard according to your existing account setup.

## 2. Configure local Flutter values

Copy `config/production.example.json` to `config/production.json` and fill in the actual project values locally:

- `SUPABASE_URL`: existing Nokha Ride Supabase project URL
- `SUPABASE_PUBLISHABLE_KEY`: existing Supabase publishable key
- `MSG91_WIDGET_ID`: Widget ID from MSG91
- `MSG91_WIDGET_TOKEN`: Widget Auth Token from MSG91

`config/production.json` is ignored by Git. Do not commit it or paste credentials into source control or chat. The Widget Auth Token is intended for client-side widget initialization; the main MSG91 Auth Key and Supabase service-role key are server-side only.

Run/build with the existing VS Code task, which uses `--dart-define-from-file=config/production.json`.

For the GitHub Actions QA APK to include the widget configuration, add these two **repository Actions secrets** under GitHub → Settings → Secrets and variables → Actions:

- `MSG91_WIDGET_ID`
- `MSG91_WIDGET_TOKEN`

The QA workflow already supplies the existing public Supabase URL and publishable key. If the two MSG91 secrets are not configured, the APK still builds, but the phone OTP screen will show that MSG91 is not configured until you add the Widget ID and Widget Auth Token.

## 3. Deploy the session function

The function is `supabase/functions/msg91-widget-session/index.ts`. It expects the existing server-side secret `MSG91_AUTH_KEY`. Supabase provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions at runtime.

Add the MSG91 main Auth Key as the Edge Function secret `MSG91_AUTH_KEY` through Supabase's server-side secret manager. This value is not included in this repository and must never be placed in Flutter, `config/production.json`, source control, or chat.

Deploy from the repository root after linking the correct project:

```powershell
supabase login
supabase link --project-ref nmjqfjyoviohqykzyvsx
supabase functions deploy msg91-widget-session --no-verify-jwt
```

The function has JWT verification disabled because a user has not signed in yet. It performs its own server-side verification by sending the widget access token to MSG91's `/api/v5/widget/verifyAccessToken` endpoint. The function rejects requests unless MSG91 confirms a valid Indian mobile number.

## 4. Session and account safety

- No database migration or RLS policy change is required.
- The function creates a phone-auth user only after MSG91 verifies the access token.
- The existing Supabase Auth trigger remains responsible for creating the profile and assigning the least-privileged `CUSTOMER` role to a verified phone user.
- The function does not take over an existing email/password account with the same phone number. It returns a conflict so the user can use their existing login.
- Supabase service-role credentials and the main MSG91 Auth Key are never returned to the app.
- The function creates a random internal password server-side only for accounts explicitly marked as created by this MSG91 widget flow; the password is never shown to the user. After each successful widget verification, the internal password is rotated and a Supabase Auth session is issued.

## 5. Smoke test checklist

- [ ] The MSG91 Widget ID and Widget Auth Token are configured in the local ignored JSON file.
- [ ] The server-side `MSG91_AUTH_KEY` secret is present.
- [ ] The `msg91-widget-session` Edge Function is deployed.
- [ ] A test user receives and verifies an OTP through the configured MSG91 Widget channel.
- [ ] A successful verification returns a Supabase session and opens the existing profile-completion/home flow.
- [ ] Invalid or expired widget access tokens are rejected.
- [ ] Existing email/password login still works.
- [ ] A phone number already owned by a different login method is not silently taken over.
- [ ] No OTP, access token, MSG91 Auth Key, service-role key, or internal password appears in logs.

A passing CI build verifies code analysis/tests and a debug APK build. It does not by itself prove live delivery; complete the real-number smoke test before treating OTP login as production-ready.
