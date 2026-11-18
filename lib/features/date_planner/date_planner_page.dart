import '../../core/errors/app_error.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../models/date_invitation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../../controllers/date_planner_controller.dart';
import '../../services/date_invitation_export_service.dart';
import '../../utils/date_maps.dart';
import 'date_compose_page.dart';
import 'widgets/invitation_card.dart';

class DatePlannerPage extends StatefulWidget {
  const DatePlannerPage({super.key, required this.coupleId});
  final String coupleId;
  @override
  State<DatePlannerPage> createState() => _DatePlannerPageState();
}

class _DatePlannerPageState extends State<DatePlannerPage>
    with AutomaticKeepAliveClientMixin {
  late final controller = DatePlannerController(widget.coupleId);
  RealtimeChannel? channel;
  bool responding = false;
  bool exporting = false;
  final cardKeys = <String, GlobalKey>{};
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    controller.refresh();
    channel = db
        .channel('dates:${widget.coupleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'date_invitations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: widget.coupleId,
          ),
          callback: (_) => controller.refresh(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (channel != null) db.removeChannel(channel!);
    controller.dispose();
    super.dispose();
  }

  Future<void> respond(String id, String answer) async {
    setState(() => responding = true);
    try {
      await controller.service.respond(id, answer);
      await controller.refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Could not update the invitation. Please retry.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => responding = false);
    }
  }

  Future<void> complete(DateInvitation invitation) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'One selfie, one lovely memory',
                style: TextStyle(fontSize: 24, color: plum),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Capture the two of you and keep it with this date.',
                textAlign: TextAlign.center,
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a selfie together'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Choose our photo'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'skip'),
                child: const Text('Complete without a photo'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    XFile? photo;
    try {
      if (choice != 'skip') {
        photo = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 2000,
          imageQuality: 90,
        );
        if (photo == null || !mounted) return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep this date in our memories?'),
          content: photo == null
              ? const Text('You can find it in Our memories.')
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(photo.path),
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save our memory'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => responding = true);
      await controller.service.complete(invitation, photo);
      await controller.changeSection(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Could not save this memory. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => responding = false);
    }
  }

  Widget? invitationActions(DateInvitation invite) {
    if (invite.status == 'completed' ||
        invite.status == 'cancelled' ||
        invite.status == 'declined') {
      return null;
    }
    return Column(
      children: [
        if (invite.creator == db.auth.currentUser?.id) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: invite.status == 'accepted'
                    ? const Color(0xFFE7F4E9)
                    : const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    invite.status == 'accepted'
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: invite.status == 'accepted'
                        ? const Color(0xFF327B5A)
                        : plum,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    invite.status == 'accepted'
                        ? 'Your person said yes'
                        : 'Waiting for your person to answer',
                    style: const TextStyle(color: plum),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (invite.canComplete)
          FilledButton.icon(
            onPressed: responding ? null : () => complete(invite),
            icon: const Icon(Icons.favorite_outline),
            label: const Text('Complete our date'),
          ),
        if (invite.creator == db.auth.currentUser?.id)
          TextButton(
            onPressed: responding
                ? null
                : () => respond(invite.id, 'cancelled'),
            child: const Text('Cancel invitation'),
          ),
        if (invite.creator != db.auth.currentUser?.id &&
            invite.status == 'pending' &&
            !invite.canComplete)
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: responding
                    ? null
                    : () => respond(invite.id, 'accepted'),
                child: const Text('Yes, let us go'),
              ),
              TextButton(
                onPressed: responding
                    ? null
                    : () => respond(invite.id, 'declined'),
                child: const Text('Another time'),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> saveCard(DateInvitation invitation) async {
    final boundary = cardKeys[invitation.id]?.currentContext
        ?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    setState(() => exporting = true);
    try {
      await DateInvitationExportService().save(boundary, invitation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation saved to your gallery as JPEG.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Could not save the invitation. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 116),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              'Time for us',
              style: TextStyle(fontSize: 30, color: plum),
            ),
            const Text(
              'A little plan. Something to look forward to.',
              style: TextStyle(color: inkSoft),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DateComposePage(coupleId: widget.coupleId),
                  ),
                );
                await controller.refresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('Plan a date'),
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Our plans')),
                ButtonSegment(value: true, label: Text('Our memories')),
              ],
              selected: {controller.history},
              onSelectionChanged: controller.loading
                  ? null
                  : (values) => controller.changeSection(values.first),
            ),
            const SizedBox(height: 20),
            if (controller.loading && controller.invitations.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (controller.error != null) Text(controller.error!),
            if (!controller.loading &&
                controller.error == null &&
                controller.invitations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Your next lovely memory starts with an invitation.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final invite in controller.invitations)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: cardKeys.putIfAbsent(invite.id, GlobalKey.new),
                      child: ColoredBox(
                        color: const Color(0xFFFFF9FB),
                        child: InvitationCard(
                          invitation: invite,
                          viewerId: db.auth.currentUser?.id,
                          actions: invitationActions(invite),
                          showMapAction: invite.status != 'completed',
                        ),
                      ),
                    ),
                    if (invite.status == 'completed')
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: exporting
                                ? null
                                : () => saveCard(invite),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Save invitation JPEG'),
                          ),
                          if (invite.latitude != null)
                            TextButton.icon(
                              onPressed: () => openDateMap(
                                place: invite.venue,
                                latitude: invite.latitude,
                                longitude: invite.longitude,
                              ),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Open in Maps'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous 10 dates',
                  onPressed: controller.loading || controller.page == 0
                      ? null
                      : () => controller.changePage(controller.page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page ${controller.page + 1}'),
                IconButton(
                  tooltip: 'Next 10 dates',
                  onPressed: controller.loading || !controller.hasNext
                      ? null
                      : () => controller.changePage(controller.page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
