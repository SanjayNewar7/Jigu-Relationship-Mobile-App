# Jigu release preparation

Developer: Sanjaya Rajbhandari  
Support: sanjaynewar007@gmail.com  
Application ID: com.sanjaya.jigu  
Version: 1.0.2 (3)

## Child safety release built on 14 November 2026
- Upload `jigu-1.0.2-3.aab` for the Play Console child safety declaration. It includes Settings > Child safety with a report form and published standards link.
- Its JAR signature and certificate match the previous upload key; ZIP integrity and package/version metadata were verified.
- Store `release-symbols/1.0.2-3` with this release for crash decoding.
- Public standards URL: https://sanjaynewar7.github.io/Jigu-/child-safety.html

## Signed upload bundle built on 14 November 2026
- Upload `jigu-1.0.1-2.aab` to Google Play Console. It contains the current name onboarding and the combined name setting.
- `jarsigner` verified the bundle. Its upload certificate SHA-256 matches the previous signed bundle.
- ZIP integrity passed. The matching SHA-256 is in `jigu-1.0.1-2.sha256`.
- Flutter obfuscation symbols are kept in `release-symbols/1.0.1-2` for crash decoding.

## Verified on 10 November 2026
- Local signing configuration successfully signed the final bundle. Signature verified against Sanjaya Rajbhandari's upload certificate.
- Final artifact: jigu-1.0.0-1.aab (new lily launcher artwork included).
- Eight 64-bit native libraries passed ELF 16 KB alignment checks on the initial release build; Play-generated APK alignment and device testing remain open.
- Production Firebase Android registration is configured.
- All 43 Flutter regression tests pass.
- Release configuration targets API 36, uses resource shrinking and release signing without a debug fallback.

## Verified on 14 November 2026
- Settings includes native privacy, terms, developer, change password, forgot password, and permanent account deletion screens.
- Supabase account deletion function and migration are deployed. Disposable-user tests verified password rejection, removal of an uploaded photo, account and journal deletion, and partner unpairing.
- Password change now verifies the current password with a separate sign-in. Live disposable-user tests verified wrong-password rejection and sign-in with the new password.
- Public GitHub Pages privacy and deletion pages are live and reflect in-app deletion.
- Flutter settings tests, the full regression suite, and Supabase security advisors pass.

## Public release gates still open
- Verify the published privacy policy and account deletion URLs in Play Console.
- Verify the production auth redirect allowlist and email verification end to end for the new package.
- Configure custom SMTP for Supabase Auth before public release; the default sender cannot deliver verification or password reset emails to addresses outside the project team. A non-team password-reset email remains unverified until this is configured.
- Verify Play-generated APK 16 KB packaging and test the final signed release on a device.
- Capture final screenshots using sample data and complete Play Data safety, content rating and app access declarations.
- Complete any testing requirements shown by the developer Play Console account.

A signed artifact does not mean these gates are complete. Do not publish until they are verified.

## Signing and symbols
Keep android/key.properties and upload-keystore.jks private and backed up securely. Keep release-symbols with the matching release for crash symbolication. Never include these credentials in the store upload assets.
