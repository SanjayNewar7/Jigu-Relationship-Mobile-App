# Jigu partner chat

## Delivery order
1. Private couple-scoped messages, membership RLS, immutable sender identity, read state and shared theme.
2. Realtime conversation with chronological history, own/right and partner/left bubbles, send failures and retry, active status and typing state.
3. Photo/GIF/video uploads, voice recording and playback, emoji picker, media preview and explicit send.
4. Server-enforced 30-day attachment expiry and scheduled Storage API deletion, including orphan uploads. Text stays until the conversation/account is removed.
5. Generic push notifications without message text, account deletion integration, and security/Flutter/build checks.

## Design
Lily pink, cream and sage; compact header; generous bubble spacing; quiet timestamps; rounded composer. Shared themes: Lily, Sage, Midnight. Preserve the central moment action; open chat from the home header.

References reviewed:
- https://dribbble.com/shots/26827477-Minimal-Pastel-Chat-App-Design
- https://www.behance.net/gallery/223587657/Mio-Minimal-Messaging-App-UI-%28Light-Dark%29
- https://supabase.com/docs/guides/realtime/postgres-changes
- https://supabase.com/docs/guides/storage/security/access-control

## Boundaries
One conversation per shared space. This is authenticated, access-controlled messaging, not end-to-end encryption. Attachment uploads are capped at 25 MB each; retention reduces accumulated storage but does not guarantee the free quota will never be exceeded. Voice recordings also expire after 30 days. GIF files can be selected from the phone; hosted GIF search requires a provider key.

GIPHY integration: configure GIPHY_API_KEY in Edge Function secrets. An authenticated config endpoint supplies this client API key to paired users. The app calls GIPHY directly as required by its API guidelines. Only GIF IDs are persisted; URLs are resolved anew and media is not copied to Supabase. GIPHY results use a PG rating filter and attribution. API limits and production approval belong to the GIPHY account.

## Verification
Check cross-space reads and writes are denied, sender identity cannot be forged, expiry cannot be extended, and storage objects cannot be read after expiry. Test send/reconnect/history ordering, background recording cancellation, media failures and small-screen layouts. Build Android; device tests require a connected phone or emulator and two test accounts.

## Delivery status — 15 November 2026

- Implemented the conversation UI, text, recording/voice playback, photos, videos, phone GIFs, GIPHY search, emoji picker, shared themes, typing/read state and active timestamps.
- Deployed chat migrations, private Storage policies, notification worker, GIPHY configuration endpoint, hourly attachment cleanup and account-deletion integration.
- Passed live tests with disposable accounts: partner access, outsider denial, forged sender denial, leave-space access revocation, text/read/typing/theme state, real attachment upload, expiry, actual Storage deletion and GIPHY requests.
- Passed all 10 Flutter chat/layout tests and targeted static analysis. Android debug APK builds successfully.
- Android API 31 emulator: signed in, opened history, displayed hosted GIF, sent text, changed theme, recorded/reviewed/sent voice, uploaded and opened portrait video. Fixed portrait video constraints and Midnight media/composer contrast during review.
- Test accounts and uploaded test media are removed after testing. No personal relationship content was used.

### Remaining release verification

Two physical phones should verify background push delivery, microphone sound quality and reconnect behavior under real mobile networks. iOS has not been built or tested. Local privacy-policy updates still need publishing to the public policy site. This debug APK is for testing, not a Play Store upload bundle.
