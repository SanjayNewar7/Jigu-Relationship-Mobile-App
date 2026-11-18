# Jigu Privacy Policy

**Effective date:** 14 November 2026  
**App:** Jigu (`com.sanjaya.jigu`)  
**Developer:** Sanjaya Rajbhandari  
**Contact:** [sanjaynewar007@gmail.com](mailto:sanjaynewar007@gmail.com)  
**Website:** [sanjayarajbhandari.com.np](https://sanjayarajbhandari.com.np)

Jigu is a private relationship app for two people to share moments, see a mutually shared place, plan dates, and reflect on their days together. This policy explains what information Jigu handles and your choices.

## Information Jigu collects

- **Partner chat:** Message text, uploaded photos, videos, GIFs and voice recordings, send times, read timestamps, typing/activity status and shared chat themes. Microphone access is requested when you choose to record a voice message. Chat is protected by authenticated membership rules and is not end-to-end encrypted.
- **Chat retention:** Uploaded chat attachments expire after 30 days. A scheduled worker deletes the actual files, normally within the next hour. Text remains until account or shared-space deletion. This does not remove copies saved outside Jigu.
- **GIF search:** When you use GIPHY search, your phone sends your search terms and ordinary network information to GIPHY and loads its GIFs directly. Jigu stores the selected GIF ID, not a copy of GIPHY's media. GIPHY's privacy policy applies to its service: https://giphy.com/privacy.

- **Account and pairing:** Your email address, the name you choose to show your partner, authentication information handled by Supabase Auth, a six digit invitation code, and your current and past shared-space memberships. Do not post your code publicly.
- **Shared names:** You and your currently connected partner can change each other's displayed name in Settings. A change is visible to both of you and remains until changed again. Leaving the shared space removes the partner's ability to rename you.
- **Shared moments:** Photos, edited photo text, captions, upload times, likes, and saved items that you choose to share. A photo selected from the gallery or captured with the camera is used for the action you choose.
- **Places and dates:** Optional location coordinates, accuracy and movement details supplied by the phone, timestamps, date invitations, chosen venues, dress style, messages, custom or favourite places, and a date selfie if added.
- **Personal reflections:** Moods and journal entries you create. These are private by default. You may enable sharing of all your mood and journal entries with your current partner from Our reflections. Only the author can edit or delete entries. Disabling sharing or leaving the space revokes partner access; copies made outside Jigu cannot be recalled.
- **Notifications and device data:** A device push token for notifications, notification choices, and local app/widget caches. Service providers may receive normal network information such as IP address when your phone contacts them.
- **Safety reports:** If you submit a child safety concern in the app, we store the category, description, submission time, and your account ID so the developer can review and respond. Reports are not shown to your partner. If you delete your account, its account ID is removed from the report; the report text may be retained as needed to address safety concerns or comply with law. Do not include abusive images in a report.

## How Jigu uses and shares information

Jigu uses this data to sign you in, connect your shared space, show and sync your moments, display your partner's latest shared place, find date ideas, send invitations and reminders, and keep your personal reflections. Shared-space content and location are visible to the partner you pair with. Your mood and journal entries are visible to your current partner only when you enable reflection sharing. Sharing does not carry over to a new shared space.

The app uses these service providers to provide its features:

- **Supabase:** authentication, database, and private photo storage.
- **Firebase Cloud Messaging:** delivery of push notifications to your device.
- **Geoapify:** finding nearby date ideas through Jigu's backend when you use discovery. Location coordinates may be sent for that request.
- **OpenStreetMap tile providers:** map images; map requests may reveal normal network information to the provider.
- **Google Maps:** only when you choose to open a place in Google Maps, Jigu passes that place's coordinates or address to the Maps app or website.

Jigu does not sell your personal information and does not use it for advertising. No end-to-end encryption claim is made.

## Location choices

Location sharing is optional. When enabled and you use Jigu, your current coordinates, timestamp, and available movement details can be uploaded and shown to your connected partner, including in a home-screen widget. Turn it off in Settings to stop sharing and remove the latest location record. Leaving your shared space also stops sharing and removes that record. Date idea discovery can request location separately with your permission; you can instead choose a place manually. Android location permission can be changed in phone settings.

## Retention and local copies

Shared moments normally expire after **48 hours**. A moment that someone likes can remain in that person's in-app gallery beyond 48 hours. A person may also save a copy to their phone; Jigu cannot erase copies saved outside the app. Shared dates and places remain until removed or the relevant data is deleted. Your journal and mood entries remain until you edit or delete them or your account deletion request is processed.

Jigu caches some photos, session information, and widget content on your device to load quickly. Logging out clears Jigu's local shared caches. Leaving a shared space hides that space from your account and stops location sharing, but it does **not** delete the space's history; you can return by entering your partner's code.

## Account and data deletion

You can permanently delete your account in **Jigu > Settings > Delete account** after entering your current password. This removes your account and personal data, plus every shared space you belong to, including its moments, date plans, places, and stored photos; your partner is unpaired. See the [public account deletion instructions](DELETE_ACCOUNT.md) for an email request option if you cannot access the app. Deleting an account is separate from logging out or leaving a shared space. Copies saved to either person's phone gallery remain outside Jigu. Contact us if you want particular shared content reviewed for removal.

## Security and children

Jigu uses authenticated access and database access rules for private data. No internet service can guarantee perfect security. Jigu is intended for adults and is not designed for children under 13.

## Updates and contact

We may update this policy as Jigu changes. The effective date at the top shows the current version. For privacy questions or requests, email **sanjaynewar007@gmail.com**.

## Audio and video calls

Calls use LiveKit to transmit live audio and video between current partners. Microphone and camera permissions are used during calls; microphone access is also used for voice messages. Jigu does not record calls. LiveKit processes media and connection information to deliver calls. Calls use encrypted transport; Jigu does not provide end-to-end encryption.

Supabase stores participant IDs, call type, status and timestamps. Closed call history is removed after 30 days by scheduled cleanup. Firebase delivers incoming-call notifications without media access tokens. On Android, an answered call can continue with an ongoing notification while the app is in the background. The camera turns off when you leave the app. End the call to stop transmitting audio.
