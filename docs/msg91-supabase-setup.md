# Nokha Ride: MSG91 + Supabase phone OTP

This integration uses **Supabase Auth to generate and verify the OTP** and MSG91 to deliver that OTP by SMS. The app receives a normal Supabase Auth session after `verifyOTP`; it does not rotate passwords, mint a session from a client-supplied token, or expose MSG91 credentials in Flutter.

## Required account setup

You need access to the existing Supabase project and an active MSG91 account. Do not paste credentials into GitHub issues, source files, or this chat.

### 1. Create/verify the MSG91 SMS Flow

1. In MSG91, create an approved SMS Flow/template for the OTP message.
2. For Indian numbers, make sure the sender/template is approved for the applicable DLT requirements.
3. Add a variable for the six-digit code. The default variable name used here is `VAR1`; if your approved template uses another variable name, set `MSG91_OTP_VARIABLE` to that exact case-sensitive name.
4. Copy the Flow/Template ID and Auth Key from MSG91.

Example message text to adapt and get approved in your own MSG91 account:

`Your Nokha Ride verification code is {{VAR1}}. Do not share this code with anyone.`

The exact placeholder syntax in the MSG91 panel must match the variable name configured for your Flow.

### 2. Deploy the Edge Function

From the repository root, with the Supabase CLI logged into the correct project:

```powershell
supabase login
supabase link --project-ref YOUR_SUPABASE_PROJECT_REF
supabase secrets set MSG91_AUTH_KEY=YOUR_MSG91_AUTH_KEY MSG91_TEMPLATE_ID=YOUR_MSG91_FLOW_ID MSG91_OTP_VARIABLE=VAR1 SEND_SMS_HOOK_SECRET=YOUR_WEBHOOK_SECRET
supabase functions deploy send-sms --no-verify-jwt
```

Replace placeholders locally; never commit the real values. Generate a high-entropy webhook secret and configure the **same value** in both the Edge Function secret `SEND_SMS_HOOK_SECRET` and the Supabase Auth Send SMS Hook signing secret. Use the Supabase-standard `v1,whsec_<base64-secret>` format. For rotation, the function accepts multiple pipe-separated secrets.

The function verifies the signed Auth Hook request before reading or forwarding the OTP. It only accepts Indian E.164 mobile numbers and never logs the OTP, provider key, or provider response body.

### 3. Enable the Auth hook in the hosted Supabase project

In the Supabase Dashboard for the correct project:

1. Enable Phone provider / phone signups and ensure phone confirmation requires OTP.
2. Under **Authentication → Hooks**, configure **Send SMS Hook** as an HTTP endpoint:
   - Endpoint: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-sms`
   - Signing secret: the same `v1,whsec_...` secret used for `SEND_SMS_HOOK_SECRET`.
3. Save the hook and confirm the function is deployed.
4. Ensure the project's OTP expiry and rate limits are appropriate for production.

The local `supabase/config.toml` contains a local development hook URI. Hosted dashboard configuration is separate; committing the file does **not** change the live project's settings.

### 4. Configure the Flutter app

Build/run with the existing Supabase publishable key and URL using the app's documented Dart defines. Do not put a Supabase service-role key or MSG91 Auth Key in the mobile app.

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

The login screen requests a phone OTP and verifies it using Supabase Auth. Existing email/password login remains available as a fallback so current users are not locked out during rollout.

## Production verification checklist

- [ ] Auth Hook is enabled in the correct hosted Supabase project.
- [ ] A real MSG91 OTP SMS is received on an authorized test number.
- [ ] Correct OTP produces a non-null Supabase session and verified phone.
- [ ] Incorrect/expired OTP is rejected.
- [ ] Rate limits are tested; no OTP or provider secret appears in logs.
- [ ] Profile completion, app restart/session restore, and logout are tested on a real Android device.
- [ ] Release APK is signed with the production signing key.

**This repository change alone does not deploy the function or configure the hosted Supabase project.** Live OTP verification requires the account secrets and dashboard hook configuration above.
