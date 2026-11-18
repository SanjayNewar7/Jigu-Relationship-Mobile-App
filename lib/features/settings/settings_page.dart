import '../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../core/widgets/glass_surface.dart';
import 'legal_content.dart';
import 'legal_page.dart';
import 'developer_page.dart';
import 'delete_account_page.dart';
import 'child_safety_page.dart';
import '../auth/password_page.dart';
import '../../services/profile_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.email,
    this.name = '',
    this.partnerName,
    required this.sharing,
    required this.paired,
    required this.onSharing,
    required this.onLogout,
    this.onDelete,
    this.onLeave,
    this.inviteCode = '',
    this.onNotifications,
    this.onNameChanged,
  });
  final String email;
  final String name;
  final String? partnerName;
  final bool sharing, paired;
  final Future<void> Function(bool) onSharing;
  final Future<void> Function() onLogout;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onLeave;
  final String inviteCode;
  final Future<bool> Function()? onNotifications;
  final Future<void> Function()? onNameChanged;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool sharing = widget.sharing;
  late String displayName = widget.name;
  late String? partnerName = widget.partnerName;
  bool busy = false;
  Future<void> run(Future<void> Function() operation) async {
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pin(String name) async {
    if (await HomeWidget.isRequestPinWidgetSupported() == true) {
      await HomeWidget.requestPinWidget(name: name);
    } else {
      throw StateError(
        'Long press your home screen, choose Widgets, then Jigu.',
      );
    }
  }

  void open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> chooseName() async {
    final partner = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set names',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Your name'),
                  subtitle: Text(
                    displayName.isEmpty ? 'Add your name' : displayName,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext, false),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Your partner’s name'),
                  subtitle: Text(
                    partnerName == null
                        ? 'Connect your shared space first'
                        : partnerName!.isEmpty
                        ? 'Choose a name for your partner'
                        : partnerName!,
                  ),
                  trailing: partnerName == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: partnerName == null
                      ? null
                      : () => Navigator.pop(sheetContext, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (partner != null && mounted) await editName(partner: partner);
  }

  Future<void> editName({bool partner = false}) async {
    var enteredName = partner ? partnerName ?? '' : displayName;
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          partner
              ? 'What will you call your partner?'
              : 'What should your partner call you?',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: enteredName,
            autofocus: true,
            maxLength: 40,
            onChanged: (value) => enteredName = value,
            textCapitalization: TextCapitalization.words,
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? 'Please enter at least two characters.'
                : null,
            decoration: InputDecoration(
              labelText: partner ? 'Your partner’s name' : 'Your name',
              helperText: 'This name is visible to both of you.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, enteredName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await run(() async {
      if (partner) {
        final saved = await ProfileService().renamePartner(value);
        if (mounted) setState(() => partnerName = saved);
      } else {
        await ProfileService().saveName(value);
        if (mounted) setState(() => displayName = value.trim());
      }
      await widget.onNameChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated for both of you.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: LilyBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GlassSurface(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_outline),
              title: const Text('Your account'),
              subtitle: Text(widget.email),
            ),
          ),
          const SizedBox(height: 10),
          GlassSurface(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Set names'),
              subtitle: const Text('Your name and your partner’s name'),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy ? null : chooseName,
            ),
          ),
          const SizedBox(height: 18),
          if (widget.paired) ...[
            GlassSurface(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.favorite_border),
                    title: const Text('Your shared space'),
                    subtitle: Text(
                      'Your invitation code: ${widget.inviteCode}\nKeep each other’s code to return.',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.door_back_door_outlined),
                    title: const Text('Leave shared space'),
                    subtitle: const Text(
                      'Stay signed in. Rejoin with your partner’s code.',
                    ),
                    onTap: busy || widget.onLeave == null
                        ? null
                        : () async {
                            final leave = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Leave this space?'),
                                content: const Text(
                                  'Your location sharing stops and shared photos disappear from this phone. Your space and saved likes remain, so you can return with your partner’s six-digit code.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Stay'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Leave space'),
                                  ),
                                ],
                              ),
                            );
                            if (leave == true && mounted) {
                              await run(() async {
                                await widget.onLeave!();
                                if (context.mounted) Navigator.pop(context);
                              });
                            }
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          GlassSurface(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Share my location'),
                  subtitle: Text(
                    widget.paired
                        ? 'Automatically while Jigu is open'
                        : 'Pair with your person first',
                  ),
                  value: sharing,
                  onChanged: busy || !widget.paired
                      ? null
                      : (value) => run(() async {
                          await widget.onSharing(value);
                          if (mounted) setState(() => sharing = value);
                        }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Phone location permissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Geolocator.openAppSettings(),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Moment notifications'),
                  subtitle: const Text('Know when your person shares a photo'),
                  onTap: busy || widget.onNotifications == null
                      ? null
                      : () => run(() async {
                          final enabled = await widget.onNotifications!();
                          if (!enabled) await Geolocator.openAppSettings();
                          if (!context.mounted) return;
                          if (enabled) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Moment notifications are on.'),
                              ),
                            );
                          }
                        }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassSurface(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Add Moments widget'),
                  subtitle: const Text('Browse your shared photos'),
                  onTap: busy
                      ? null
                      : () => run(() => pin('JiguWidgetProvider')),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Add Places widget'),
                  subtitle: const Text('Your partner’s latest shared place'),
                  onTap: busy
                      ? null
                      : () => run(() => pin('JiguLocationWidgetProvider')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassSurface(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  subtitle: const Text('How Jigu cares for your information'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    const LegalPage(
                      title: 'Privacy policy',
                      sections: privacySections,
                      publicUrl:
                          'https://sanjaynewar7.github.io/Jigu-/privacy.html',
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of use'),
                  subtitle: const Text('A few gentle ground rules'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    const LegalPage(
                      title: 'Terms of use',
                      sections: termsSections,
                      publicUrl:
                          'https://sanjaynewar7.github.io/Jigu-/terms.html',
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Child safety'),
                  subtitle: const Text('Standards and report a concern'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(const ChildSafetyPage()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About Jigu & developer'),
                  subtitle: const Text('The person behind this little space'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(const DeveloperPage()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Delete account'),
                  subtitle: const Text(
                    'Permanently remove your account and shared spaces',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    DeleteAccountPage(
                      email: widget.email,
                      onDeleted: widget.onDelete ?? widget.onLogout,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  subtitle: const Text('Protect your Jigu account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    PasswordPage(
                      recovery: false,
                      onFinished: () {
                        if (mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
                const Divider(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  subtitle: const Text('On this phone only'),
                  onTap: busy
                      ? null
                      : () => run(() async {
                          await widget.onLogout();
                          if (context.mounted) Navigator.of(context).pop();
                        }),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ),
  );
}
