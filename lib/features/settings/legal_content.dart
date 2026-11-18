class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

const childSafetySections = <LegalSection>[
  LegalSection(
    'Our standard',
    'Jigu, developed by Sanjaya Rajbhandari, prohibits child sexual abuse and exploitation (CSAE). This includes child sexual abuse material (CSAM), grooming, sexual exploitation, and attempts to use Jigu to harm a child.',
  ),
  LegalSection(
    'Reporting',
    'Signed-in users can open Settings > Child safety to send a report inside Jigu. Do not upload or resend abusive images. For urgent danger, contact local emergency services. You can also contact sanjaynewar007@gmail.com.',
  ),
  LegalSection(
    'How we respond',
    'We review reports, remove prohibited content when we become aware of it, and may suspend or remove accounts involved. We preserve and report information to relevant regional or national authorities when required by applicable law.',
  ),
  LegalSection(
    'Contact',
    'Sanjaya Rajbhandari is the child safety contact for Jigu. Email sanjaynewar007@gmail.com for questions about these standards or CSAM prevention practices.',
  ),
];

const privacySections = <LegalSection>[
  LegalSection(
    'Audio and video calls',
    'Calls use LiveKit to transmit live audio and video between current partners. Microphone and camera permissions are used during calls. Jigu does not record calls. LiveKit processes media and connection information to deliver the service. Calls use encrypted transport; Jigu does not provide end-to-end encryption. Supabase stores participant IDs, call type, status and timestamps; closed call history is removed after 30 days by scheduled cleanup. Firebase delivers incoming-call notifications without media access tokens. On Android, an answered call can continue with an ongoing notification while the app is in the background; the camera turns off when you leave the app.',
  ),
  LegalSection(
    'GIF search',
    'When you search GIPHY, your phone sends the search terms and ordinary network information to GIPHY and loads GIFs directly from its service. Jigu stores selected GIF IDs, not copies of GIPHY media. GIPHY handles this information under its own privacy policy at giphy.com/privacy.',
  ),
  LegalSection(
    'Partner chat',
    'Jigu stores chat text, photos, videos, GIFs, voice messages, shared theme preferences, read timestamps and activity status in Supabase. Chat is accessible to current members of your shared space. Microphone permission is used only when you record a voice message. Attachments expire after 30 days and their files are removed by scheduled cleanup, normally within the next hour. Text history remains until the shared space or account is deleted. Push notifications use Firebase and do not include message text. Chat uses authenticated access and is not end-to-end encrypted. Copies saved outside Jigu are not removed by attachment expiry.',
  ),
  LegalSection(
    'What Jigu is',
    'Jigu is a private relationship app for two people. Sanjaya Rajbhandari develops Jigu. This policy applies to the Android app com.sanjaya.jigu.',
  ),
  LegalSection(
    'Information you give us',
    'We store your email address, the name you choose to show your partner, and authentication details through Supabase Auth. Your six digit invitation code and membership in a shared space connect you with another account. You can add photos and captions, likes, relationship dates, date invitations and places, mood check-ins, and personal journal entries. Camera and gallery access is used when you choose a photo. Mood and journal entries are private by default. You can enable sharing with your current partner from Our reflections. They can read all your entries but cannot edit or delete them. Turning sharing off or leaving the space revokes access; copies already saved outside Jigu cannot be recalled.',
  ),
  LegalSection(
    'Location',
    'If you enable location sharing, Jigu sends your current coordinates, time, and available movement details to your shared space while you use the app. Your partner can view your latest shared place in the app and widget. You can turn sharing off in Settings or leave the space; Jigu then removes your latest shared location. With your permission, location can also help find nearby date ideas. That request is sent through our backend to Geoapify. Map tiles may be requested from OpenStreetMap providers. Opening a place in Google Maps sends that place to Google Maps.',
  ),
  LegalSection(
    'Photos, dates, and reminders',
    'Shared moments are stored in private Supabase Storage and are visible to members of the current shared space. A moment normally expires after 48 hours. Liked moments may remain in your private in-app gallery after that time. You can save a copy to your device. Shared date plans, invitations, places, and their images remain in the shared space until deleted or the related data is removed. Notifications about moments and dates use Firebase Cloud Messaging and local phone notifications; a device push token is stored to deliver them.',
  ),
  LegalSection(
    'How information is used and shared',
    'We use your information to sign you in, connect your shared space, show photos and places, prepare date ideas, and send reminders. Shared-space content is shown to your connected partner. Supabase hosts authentication, database records, and private photos; Firebase delivers push notifications; Geoapify helps find date ideas; map providers serve map tiles. We do not sell personal information or use it for advertising.',
  ),
  LegalSection(
    'Safety reports',
    'If you send a child safety report, we store its category, description, time, and your account ID for review. Your partner cannot see it. If your account is deleted, its ID is removed from the report; the report text may be retained to address safety concerns or meet legal duties. Do not include abusive images.',
  ),
  LegalSection(
    'Storage and control',
    'Your signed-in session, recent photos, and widget images can be cached on your device for speed. Logging out clears the app’s local shared caches. Leaving a space stops location sharing and hides that space from your account, but does not delete its shared history. You can rejoin with your partner’s code. You can change phone permissions in Android Settings. Settings > Delete account permanently removes your account and every shared space you belong to, including shared moments, date plans, places, and stored photos. Your partner is unpaired. The public deletion page also explains how to request help by email.',
  ),
  LegalSection(
    'Security and age',
    'Jigu uses authenticated access and database access rules to limit who can see shared data. Internet transmission and storage cannot be guaranteed completely secure. Jigu is intended for adults and is not designed for children under 13.',
  ),
  LegalSection(
    'Updates and contact',
    'We may update this policy as Jigu changes. The current version is dated 14 November 2026. For privacy questions or deletion requests, contact sanjaynewar007@gmail.com. Developer: Sanjaya Rajbhandari, sanjayarajbhandari.com.np.',
  ),
];

const termsSections = <LegalSection>[
  LegalSection(
    'Using Jigu',
    'Jigu is a personal space to share moments, places, and date plans with someone you choose. You must be able to form a valid account and use the app lawfully. Keep your password and six digit invitation code private.',
  ),
  LegalSection(
    'Sharing and consent',
    'Only share photos, text, and locations you have permission to share. Treat your partner’s private information respectfully. Location sharing is optional and can be turned off at any time. Leaving a space and logging out are separate actions.',
  ),
  LegalSection(
    'Your content',
    'You keep ownership of the content you add. You permit Jigu to store and display it as needed to provide the app to you and your connected partner. Your partner may save a copy of a shared moment, so deleting a shared item may not remove copies they already saved.',
  ),
  LegalSection(
    'Availability',
    'Jigu needs network access for syncing, pairing, maps, and notifications. Delivery and refresh may be delayed by connectivity or phone settings. Date suggestions are ideas, not guarantees of venue availability, quality, or safety; check a venue before visiting.',
  ),
  LegalSection(
    'Contact',
    'These terms are dated 14 November 2026. Questions: sanjaynewar007@gmail.com. Developer: Sanjaya Rajbhandari.',
  ),
];
