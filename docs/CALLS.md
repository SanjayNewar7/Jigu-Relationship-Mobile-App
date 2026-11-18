# Jigu partner calls

## Configuration
Supabase secrets: LIVEKIT_URL (wss project URL), LIVEKIT_API_KEY, LIVEKIT_API_SECRET, plus the existing Firebase configuration. The three LiveKit values must belong to the same project.

## Architecture
- CallController and CallService manage Flutter lifecycle and authenticated Edge Function requests.
- partner-call validates membership, creates/accepts/ends calls, sends FCM and issues short-lived room-scoped LiveKit tokens.
- partner_calls exposes participant-only reads; mutation RPCs are service-role only.
- cleanup-calls expires unanswered and stale calls and removes closed history after 30 days.
- Android uses a microphone foreground service during answered calls. Camera is disabled when the app leaves the foreground.
- Incoming calls use notifications and foreground polling. Native lock-screen CallKit/full-screen ringing is not implemented.
- No call recordings or end-to-end encryption are provided.

## Verification
Run flutter test test/call_and_theme_test.dart test/chat_ui_test.dart test/shared_reflections_test.dart.
Run python -X utf8 tool/test_calls_live.py --media for disposable-account authorization and bidirectional synthetic audio/video checks. Tokens are held temporarily and removed; test accounts are cleaned up.

On 2026-11-18, after updating the matching LiveKit credentials, the live test passed call start/acceptance, participant token issuance, outsider denial, actual bidirectional synthetic audio/video frames, hang-up and ended-call token denial. Disposable accounts and token files were removed. Eight targeted Flutter tests passed on 2026-11-17. Physical-device ringing, microphone, camera and background behavior still need two-device verification; ADB has no connected device.
