# Jigu

A private Flutter relationship app for two people: shared photos, a home screen moment widget, and optional location sharing.

## Structure

- `lib/core/theme` and `lib/core/widgets`: Sniglet typography, lily background, reusable glass surfaces and controls
- `lib/features/auth`: sign in, signup, and confirmation recovery
- `lib/features/home/views`: Today, Moments, and Places screens
- `lib/features/pairing` and `lib/features/splash`: invitation and animated entry screens
- `lib/controllers`: location permission and foreground updates
- `lib/services`: Supabase data and widget cache
- `lib/models`: couple snapshot
- `lib/utils`: location age label
- `supabase/migrations`: ordered database schema, storage policies, triggers, and pairing rules

## Setup

1. The repository is linked to Supabase project `dtjasplpglevmtagkrfp`. Jigu's schema is tracked in [migrations](supabase/migrations) and has been applied to that project.
2. Email confirmation is enabled. Configure a custom SMTP provider in Supabase Auth before inviting external addresses. Supabase's built-in sender only reaches project team members; keep confirmation enabled.
3. Run:

   ```powershell
   flutter pub get
   flutter run
   ```

The app defaults to this project's URL and **publishable** key in [config.dart](lib/core/config.dart). Use `--dart-define` to override them for another project. Never put a service role key in mobile code. Both people sign up, then one shares their random six digit secret code with the other. The database limits failed pairing attempts to five per ten minutes.

`supabase/schema.sql` is an older snapshot. Apply the ordered migrations for the current six digit code schema.

## Current behavior

- Either partner can upload a photo. The newest one appears for both users while the app is open. Supabase Realtime signals changes, with a two minute refresh fallback.
- The Android widget shows the last downloaded photo and last shared location text. Its photo remains cached without internet and updates when the app next syncs. Add it from the phone's home screen widget picker.
- Location sharing is opt in and foreground only. Turning it off deletes the last shared position. Locations older than 30 minutes are labeled as unavailable.
- Photos live in a private Supabase Storage bucket with signed reads and couple member policies.

## Remaining device work

The iOS home screen widget target is not yet wired into the Xcode project. Android and iOS also need push/background refresh for immediate widget changes while both apps are closed; mobile operating systems may delay widget refresh even with push. Current live refresh applies while the app is running. Test pairing, uploads, permissions, and two devices against your own Supabase project before distributing.

## Brand

Jigu uses a six petal lily, ivory/lilac/sage colors, and locally bundled [Sniglet](https://fonts.google.com/specimen/Sniglet) under the SIL Open Font License in `assets/fonts/OFL.txt`. Clipped Flutter `BackdropFilter` surfaces provide real background blur with translucent fills and bright borders. Cupertino segmented controls, switches, and a floating glass tab bar keep interactions consistent. The Android 8+ launcher and Android launch screen use the lily mark; older Android and iOS launcher assets retain the original heart.

Render all screen previews without an account with `flutter test --no-pub --update-goldens tool/render_design.dart`. Images are written to `docs/design`.

## Email confirmation

The hosted Auth Site URL and allowed redirect are `com.sanjaya.jigulove://login-callback`. Signup and resend requests explicitly use that callback. Android and iOS register the scheme, and Supabase Flutter handles the PKCE exchange. Open confirmation emails on the phone that requested them. A link can only be used once; if the account is already confirmed, sign in with its password. The sign-in screen can request a fresh confirmation for an unconfirmed account.

## October 2026 update

- Sessions persist and refresh automatically. Normal restarts and `adb install -r` updates keep the login. Settings contains local logout, location sharing, permission recovery, widget pinning, and app licenses. Reinstallation or revoked credentials can still require login.
- Places uses an interactive OpenStreetMap map with separate partner/self markers, accuracy radius, fresh estimated speed, last shared time, and partner activity. Sharing remains opt-in; its preference survives closing the app. A fresh fix is sent on opening/resuming and while active, with movement updates throttled to five seconds and a thirty-second refresh fallback. Collection pauses in the background without removing the last shared place.
- Android Moments widget caches previews and offers previous/next controls. Android Places widget has a single-tile cached map preview and opens the app's Places screen. Both refresh when the app syncs; this does not add background push delivery while Jigu is closed. Widget previews are cleared on logout.
- The splash runs one 3.1-second timeline: lily fade/pop, staggered JIGU letters, subtitle, hold, then session routing. Reduced-motion mode skips movement.
- Use `flutter build apk --debug`, then `adb -s DEVICE install -r build/app/outputs/flutter-apk/app-debug.apk`. Do not uninstall to work around low storage; that clears the saved session.
