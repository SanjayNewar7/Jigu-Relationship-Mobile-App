import '../calls/call_page.dart';
import '../../services/call_service.dart';
import '../../core/errors/app_error.dart';
import 'dart:async';
import 'dart:typed_data';
import '../moment_editor/moment_editor_page.dart';
import '../chat/chat_page.dart';
import '../../services/chat_unread_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pairing/connection_dialog.dart';
import '../settings/settings_page.dart';
import '../../controllers/location_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/location_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../pairing/pairing_view.dart';
import 'views/today_view.dart';
import 'views/moments_view.dart';
import 'views/places_view.dart';
import 'widgets/glass_tab_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../date_planner/date_planner_page.dart';
import '../../services/couple_service.dart';
import '../../services/moment_service.dart';
import '../../services/relationship_service.dart';
import '../../services/widget_service.dart';
import '../../services/moment_image_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  Map<String, dynamic>? profile, partnerPlace, ownPlace, partnerProfile;
  bool foreground = true, refreshing = false, signingOut = false;
  StreamSubscription<Uri?>? widgetClicks;
  List<Map<String, dynamic>> moments = [], likedMoments = [];
  DateTime? startedOn;
  bool refreshQueued = false;
  int membershipRevision = 0;
  Timer? timer;
  Timer? callTimer;
  bool checkingCall = false;
  final locationController = LocationController();
  final notificationController = NotificationController();
  RealtimeChannel? updates;
  RealtimeChannel? profileUpdates;
  bool greetingBusy = false;
  bool chatOpen = false;
  int unreadChat = 0;
  final chatUnreadService = ChatUnreadService();
  String? greetedCoupleId;
  bool busy = false;
  int tab = 0;
  final PageController pageController = PageController();
  String? loadError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final userId = db.auth.currentUser?.id;
    if (userId != null) {
      profileUpdates = db
          .channel('profile:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
    }
    refresh();
    notificationController
        .start(
          (screen) => screen == 'calls'
              ? checkIncomingCall()
              : screen == 'chat'
              ? openChat()
              : goToTab(
                  screen == 'dates'
                      ? 2
                      : screen == 'anniversary'
                      ? 0
                      : 1,
                ),
        )
        .catchError((_) {});
    HomeWidget.initiallyLaunchedFromHomeWidget().then(openWidget);
    widgetClicks = HomeWidget.widgetClicked.listen(openWidget);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (foreground && !signingOut) {
        presence();
        refresh();
      }
    });
    callTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (foreground) checkIncomingCall();
    });
    checkIncomingCall();
    presence();
  }

  Future<void> checkIncomingCall() async {
    if (checkingCall || CallPage.isOpen || signingOut || !mounted) return;
    checkingCall = true;
    try {
      final call = await CallService().incoming();
      if (call != null && mounted && !CallPage.isOpen) {
        await CallPage.open(context, call);
      }
    } catch (_) {
      /* Retry on the next poll; do not interrupt other screens. */
    } finally {
      checkingCall = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    callTimer?.cancel();
    widgetClicks?.cancel();
    pageController.dispose();

    locationController.dispose();
    notificationController.dispose();
    if (updates != null) db.removeChannel(updates!);
    if (profileUpdates != null) db.removeChannel(profileUpdates!);
    super.dispose();
  }

  void openWidget(Uri? uri) {
    if (mounted && uri != null) {
      goToTab(uri.host == 'places' ? 3 : 1);
    }
  }

  void goToTab(int value) {
    if (!mounted) return;
    setState(() => tab = value);
    if (pageController.hasClients) {
      pageController.animateToPage(
        value,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> openChat() async {
    if (chatOpen) return;
    chatOpen = true;
    try {
      final user = db.auth.currentUser;
      if (user == null) return;
      final me = await db
          .from('profiles')
          .select('couple_id')
          .eq('id', user.id)
          .single();
      final space = me['couple_id'] as String?;
      if (space == null) {
        if (mounted) note('Connect with your person to start chatting.');
        return;
      }
      if (mounted) setState(() => unreadChat = 0);
      final people = await db
          .from('profiles')
          .select('display_name')
          .eq('couple_id', space)
          .neq('id', user.id);
      final name = people.isEmpty
          ? 'Your person'
          : people.first['display_name'] as String? ?? 'Your person';
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(space: space, partnerName: name),
        ),
      );
    } catch (e) {
      if (mounted) note(AppError.message(e));
    } finally {
      chatOpen = false;
      unawaited(loadUnreadChat());
    }
  }

  Future<void> loadUnreadChat() async {
    final space = profile?['couple_id'] as String?;
    if (space == null || chatOpen || signingOut) {
      if (mounted && unreadChat != 0) setState(() => unreadChat = 0);
      return;
    }
    try {
      final count = await chatUnreadService.count(space);
      if (mounted && !chatOpen && profile?['couple_id'] == space) {
        setState(() => unreadChat = count);
      }
    } catch (_) {
      // Keep the last count while offline; the next refresh will reconcile it.
    }
  }

  Future<void> presence() async {
    try {
      await db.rpc('touch_presence');
    } catch (_) {
      /* Try on the next heartbeat. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && !signingOut) {
      presence();
      refresh();
    }
  }

  Future<void> resumeLocation() async {
    if (!foreground ||
        signingOut ||
        profile?['location_enabled'] != true ||
        profile?['couple_id'] == null) {
      return;
    }
    try {
      await locationController.start(
        profile!['couple_id'],
        requestPermission: false,
      );
    } catch (_) {
      /* Settings provides permission recovery; do not nag on each resume. */
    }
  }

  Future<void> changeSharing(bool enabled) async {
    if (enabled) {
      await locationController.start(profile!['couple_id']);
    } else {
      await locationController.stop();
    }
    await refresh();
  }

  Future<void> logout() async {
    signingOut = true;
    try {
      await locationController.suspend();
      await notificationController.logout();
      await db.auth.signOut(scope: SignOutScope.local);
      await WidgetService().clear();
      await MomentImageService().clear();
    } catch (_) {
      signingOut = false;
      rethrow;
    }
  }

  void settings() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SettingsPage(
        email: db.auth.currentUser?.email ?? '',
        name: profile?['display_name'] as String? ?? '',
        partnerName: partnerProfile == null
            ? null
            : partnerProfile!['display_name'] as String? ?? '',
        sharing: profile?['location_enabled'] == true,
        paired: profile?['couple_id'] != null,
        onSharing: changeSharing,
        onLogout: logout,
        onDelete: logout,
        inviteCode: profile?['invite_code'] ?? '',
        onLeave: leaveSpace,
        onNotifications: notificationController.service.enable,
        onNameChanged: refresh,
      ),
    ),
  );

  Future<void> leaveSpace() async {
    membershipRevision++;
    await locationController.suspend();
    await CoupleService().leave();
    await notificationController.manager.clear();
    if (updates != null) await db.removeChannel(updates!);
    updates = null;
    await WidgetService().clear();
    await MomentImageService().clear();
    greetedCoupleId = null;
    final userId = db.auth.currentUser?.id;
    if (userId != null) {
      await (await SharedPreferences.getInstance()).remove(
        'greeted_space_$userId',
      );
    }
    if (mounted) {
      setState(() {
        tab = 0;
        moments = [];
        likedMoments = [];
        partnerPlace = null;
        unreadChat = 0;
      });
    }
    await refresh();
  }

  void note(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> action(Future<void> Function() callback) async {
    setState(() => busy = true);
    try {
      await callback();
      await refresh();
    } catch (e) {
      note(AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    if (signingOut || db.auth.currentUser == null) return;
    if (refreshing) {
      refreshQueued = true;
      return;
    }
    refreshing = true;
    final revision = membershipRevision;
    try {
      final data = await CoupleService().load().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (revision != membershipRevision) {
        refreshQueued = true;
        return;
      }
      setState(() {
        loadError = null;
        profile = data.profile;
        moments = data.moments;
        likedMoments = data.likedMoments;
        startedOn = data.startedOn;
        partnerPlace = data.partnerPlace;
        ownPlace = data.ownPlace;
        partnerProfile = data.partnerProfile;
      });
      final coupleId = data.profile['couple_id'] as String?;
      unawaited(loadUnreadChat());
      final ownName = data.profile['display_name'] as String?;
      final otherName = data.partnerProfile?['display_name'] as String?;
      if (coupleId != null && ownName != null && otherName != null) {
        unawaited(showConnectionOnce(coupleId, ownName, otherName));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            pageController.hasClients &&
            pageController.page?.round() != tab) {
          pageController.jumpToPage(tab);
        }
      });
      unawaited(
        MomentImageService()
            .prune([...data.moments, ...data.likedMoments])
            .catchError((_) {}),
      );
      if (data.profile['couple_id'] != null && updates == null) {
        final coupleId = data.profile['couple_id'] as String;
        updates = db
            .channel('jigu:$coupleId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'chat_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'couple_id',
                value: coupleId,
              ),
              callback: (event) {
                final row = event.newRecord;
                if (!mounted ||
                    chatOpen ||
                    row['sender_id'] == db.auth.currentUser?.id) {
                  return;
                }
                unawaited(loadUnreadChat());
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'moments',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'couple_id',
                value: coupleId,
              ),
              callback: (_) => refresh(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'locations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'couple_id',
                value: coupleId,
              ),
              callback: (event) {
                final row = event.newRecord;
                if (event.eventType == PostgresChangeEvent.delete) {
                  refresh();
                  return;
                }
                if (!mounted || row.isEmpty) return;
                setState(() {
                  if (row['user_id'] == db.auth.currentUser?.id) {
                    ownPlace = row;
                  } else {
                    partnerPlace = row;
                  }
                });
                if (row['user_id'] != db.auth.currentUser?.id) {
                  unawaited(
                    WidgetService()
                        .sync(
                          moments,
                          placeText,
                          place: row,
                          activity: activityLabel(
                            partnerProfile?['last_active_at'],
                          ),
                        )
                        .catchError((Object e) {
                          debugPrint('Jigu widget sync failed: $e');
                        }),
                  );
                }
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'moment_likes',
              callback: (_) => refresh(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'couples',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: coupleId,
              ),
              callback: (_) => refresh(),
            )
            .subscribe();
      }
      unawaited(resumeLocation());
      unawaited(
        WidgetService()
            .sync(
              moments,
              placeText,
              place: partnerPlace,
              activity: activityLabel(partnerProfile?['last_active_at']),
            )
            .catchError((Object e) {
              debugPrint('Jigu widget sync failed: $e');
            }),
      );
    } catch (e) {
      if (mounted && profile == null) {
        setState(
          () => loadError = AppError.message(
            e,
            fallback: 'Your space could not load. Please retry.',
          ),
        );
      }
      if (foreground) note(AppError.message(e));
    } finally {
      refreshing = false;
      if (refreshQueued && mounted && !signingOut) {
        refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  String get placeText => locationLabel(partnerPlace);

  Future<void> showConnectionOnce(
    String coupleId,
    String ownName,
    String otherName,
  ) async {
    if (greetingBusy || greetedCoupleId == coupleId || signingOut) return;
    greetingBusy = true;
    try {
      final userId = db.auth.currentUser?.id;
      if (userId == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'greeted_space_$userId';
      if (prefs.getString(key) == coupleId) {
        greetedCoupleId = coupleId;
        return;
      }
      await prefs.setString(key, coupleId);
      greetedCoupleId = coupleId;
      if (!mounted || signingOut) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            ConnectionDialog(yourName: ownName, partnerName: otherName),
      );
    } finally {
      greetingBusy = false;
    }
  }

  Future<void> upload() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.photo_on_rectangle),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2560,
    );
    if (photo == null) return;
    if (!mounted) return;
    var selected = photo;
    if (source == ImageSource.camera) {
      final edited = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => MomentEditorPage(path: photo.path)),
      );
      if (edited == null || !mounted) return;
      selected = XFile.fromData(
        edited,
        mimeType: 'image/jpeg',
        name: 'jigu-moment.jpg',
      );
    }
    await action(() => MomentService().upload(selected, profile!['couple_id']));
  }

  Future<void> likeMoment(Map<String, dynamic> moment) async {
    final liked = (moment['moment_likes'] as List? ?? const []).any(
      (item) => item is Map && item['user_id'] == db.auth.currentUser?.id,
    );
    await MomentService().like(moment['id'], liked: liked);
    await refresh();
  }

  Future<void> saveMoment(Map<String, dynamic> moment) =>
      MomentService().save(moment);

  Future<void> deleteMoment(Map<String, dynamic> moment) async {
    await MomentService().remove(moment['id']);
    await refresh();
  }

  Future<void> setStartedOn(DateTime date) async {
    await RelationshipService().setStartedOn(profile!['couple_id'], date);
    await refresh();
  }

  Future<void> togglePlace(bool enabled) async {
    await action(() async {
      if (enabled) {
        await locationController.start(profile!['couple_id']);
      } else {
        await locationController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final paired = profile?['couple_id'] != null;
    return Scaffold(
      body: LilyBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.asset(
                            'assets/jigu_logo.png',
                            width: 34,
                            height: 34,
                            cacheWidth: 102,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'jigu',
                          style: TextStyle(fontSize: 28, color: plum),
                        ),
                        const Spacer(),
                        if (paired) ...[
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GlassSurface(
                                radius: 17,
                                padding: EdgeInsets.zero,
                                child: IconButton(
                                  tooltip: 'Chat with your person',
                                  onPressed: openChat,
                                  icon: const Icon(
                                    CupertinoIcons.chat_bubble_2,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (unreadChat > 0)
                                Positioned(
                                  right: -5,
                                  top: -7,
                                  child: IgnorePointer(
                                    child: Semantics(
                                      label: '$unreadChat unread messages',
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCE3553),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          unreadChat > 5 ? '5+' : '$unreadChat',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 10),
                        ],
                        GlassSurface(
                          radius: 17,
                          padding: EdgeInsets.zero,
                          child: IconButton(
                            tooltip: 'Refresh',
                            onPressed: refresh,
                            icon: const Icon(
                              CupertinoIcons.arrow_clockwise,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GlassSurface(
                          radius: 17,
                          padding: EdgeInsets.zero,
                          child: IconButton(
                            tooltip: 'Settings',
                            onPressed: settings,
                            icon: const Icon(CupertinoIcons.gear, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: profile == null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: loadError == null
                                        ? const CupertinoActivityIndicator()
                                        : GlassSurface(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  CupertinoIcons
                                                      .wifi_exclamationmark,
                                                  color: inkSoft,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  loadError!,
                                                  textAlign: TextAlign.center,
                                                ),
                                                TextButton(
                                                  onPressed: refresh,
                                                  child: const Text(
                                                    'Try again',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                )
                              : !paired
                              ? PairingView(
                                  code: profile!['invite_code'] ?? '',
                                  busy: busy,
                                  onJoin: (code) =>
                                      action(() => CoupleService().join(code)),
                                )
                              : PageView(
                                  controller: pageController,
                                  onPageChanged: (value) =>
                                      setState(() => tab = value),
                                  children: [
                                    TodayView(
                                      moments: moments,
                                      startedOn: startedOn,
                                      onSetDate: setStartedOn,
                                      onLike: likeMoment,
                                      onSave: saveMoment,
                                      onDelete: deleteMoment,
                                      placeLabel: placeText,
                                      place: partnerPlace,
                                      busy: busy,
                                      onUpload: upload,
                                      onRefresh: refresh,
                                    ),
                                    MomentsView(
                                      moments: moments,
                                      likedMoments: likedMoments,
                                      onLike: likeMoment,
                                      onSave: saveMoment,
                                      onDelete: deleteMoment,
                                      onRefresh: refresh,
                                    ),
                                    DatePlannerPage(
                                      key: ValueKey(profile!['couple_id']),
                                      coupleId: profile!['couple_id'],
                                    ),
                                    PlacesView(
                                      label: placeText,
                                      place: partnerPlace,
                                      ownPlace: ownPlace,
                                      activity: activityLabel(
                                        partnerProfile?['last_active_at'],
                                      ),
                                      sharing:
                                          profile?['location_enabled'] == true,
                                      busy: busy,
                                      onChanged: togglePlace,
                                    ),
                                  ],
                                ),
                        ),
                        if (paired)
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 12,
                            child: GlassTabBar(
                              onShare: busy ? null : upload,
                              selected: tab,
                              onChanged: goToTab,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
