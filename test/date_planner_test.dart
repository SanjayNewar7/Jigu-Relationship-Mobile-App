import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/core/theme/lily_theme.dart';
import 'package:jigulove/features/home/widgets/glass_tab_bar.dart';
import 'package:jigulove/features/date_planner/widgets/invitation_card.dart';
import 'package:jigulove/models/date_invitation.dart';
import 'package:jigulove/utils/date_maps.dart';
import 'package:jigulove/features/date_planner/widgets/lily_date_picker.dart';

void main() {
  test('Google Maps preserves selected coordinates', () {
    final uri = dateMapUri(
      place: 'A cafe',
      latitude: 27.683,
      longitude: 84.433,
    );
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], '27.683,84.433');
  });
  testWidgets('lily picker returns the selected future date and time', (
    tester,
  ) async {
    DateTime? selected;
    final initial = DateTime.now().add(const Duration(days: 2));
    await tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showLilyDatePicker(context, initial);
              },
              child: const Text('Pick'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose our time'));
    await tester.tap(find.text('Choose our time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep this lovely time'));
    await tester.pumpAndSettle();
    expect(selected?.day, initial.day);
    expect(selected?.hour, initial.hour);
    expect(tester.takeException(), isNull);
  });

  testWidgets('centre share opens capture without changing the active tab', (
    tester,
  ) async {
    var shares = 0;
    var selected = 2;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GlassTabBar(
                selected: selected,
                onChanged: (value) => selected = value,
                onShare: () => shares++,
              ),
            ),
          ),
        ),
      ),
    );
    final share = find.byTooltip('Share a moment');
    final bar = tester.getRect(find.byType(GlassTabBar));
    expect(tester.getCenter(share).dx, closeTo(bar.center.dx, 1));
    await tester.tap(share);
    expect(shares, 1);
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'invitation keeps long venue and message readable on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final invite = DateInvitation({
        'id': 'qa',
        'creator_id': 'qa',
        'venue': 'A garden cafe beside the riverside walking path',
        'address': 'Our meeting place by the entrance to the garden',
        'dress_style': 'Adventure ready',
        'message': 'Looking forward to a little time together.',
        'status': 'pending',
        'starts_at': DateTime.now()
            .add(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: LilyTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: InvitationCard(invitation: invite),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(invite.venue), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('date creator sees a clear reply on the invitation', (
    tester,
  ) async {
    final data = <String, dynamic>{
      'id': 'qa',
      'creator_id': 'creator',
      'venue': 'The garden',
      'address': 'Garden gate',
      'dress_style': 'Casual',
      'message': '',
      'status': 'pending',
      'starts_at': DateTime.now()
          .add(const Duration(days: 2))
          .toUtc()
          .toIso8601String(),
    };
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        theme: LilyTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvitationCard(
              invitation: DateInvitation(Map.of(data)),
              viewerId: 'creator',
            ),
          ),
        ),
      ),
    );
    await show();
    expect(find.text('Waiting for your person to answer'), findsOneWidget);
    data['status'] = 'accepted';
    await show();
    expect(find.text('It is a date'), findsOneWidget);
    data['status'] = 'declined';
    await show();
    expect(find.text('Your person could not make it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
