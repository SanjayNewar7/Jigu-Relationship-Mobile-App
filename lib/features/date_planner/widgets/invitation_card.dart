import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../core/widgets/lily_bloom.dart';
import '../../../models/date_invitation.dart';
import '../../../utils/date_maps.dart';
import 'date_selfie.dart';

class InvitationCard extends StatelessWidget {
  const InvitationCard({
    super.key,
    required this.invitation,
    this.actions,
    this.showMapAction = true,
    this.viewerId,
  });
  final DateInvitation invitation;
  final Widget? actions;
  final bool showMapAction;
  final String? viewerId;
  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final completed = invitation.status == 'completed';
    final status = switch (invitation.status) {
      'accepted' => 'It is a date',
      'completed' => 'A memory we made',
      'declined' =>
        invitation.creator == viewerId
            ? 'Your person could not make it'
            : 'Maybe another lovely time',
      'cancelled' => 'Until another day',
      _ =>
        invitation.creator == viewerId
            ? 'Waiting for your person to answer'
            : 'You are invited',
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: coral.withValues(alpha: .12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFCF9), Color(0xFFFFEAF1), Color(0xFFFFF9FB)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 226,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: -30,
                      left: -38,
                      child: Transform.rotate(
                        angle: -.35,
                        child: const LilyBloom(size: 154, opacity: .68),
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      right: -32,
                      child: Transform.rotate(
                        angle: math.pi / 5,
                        child: const LilyBloom(size: 128, opacity: .65),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 26,
                      child: Icon(
                        CupertinoIcons.heart_fill,
                        size: 12,
                        color: coral.withValues(alpha: .3),
                      ),
                    ),
                    Positioned(
                      bottom: 26,
                      left: 32,
                      child: Icon(
                        CupertinoIcons.heart_fill,
                        size: 9,
                        color: coral.withValues(alpha: .4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .8),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'FOR MY FAVOURITE PERSON',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.3,
                                color: inkSoft,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            invitation.heading?.isNotEmpty == true
                                ? invitation.heading!
                                : completed
                                ? 'A little more us.'
                                : 'A date, just us',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: invitation.heading?.isNotEmpty == true
                                  ? 24
                                  : 31,
                              height: 1.15,
                              color: plum,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.heart_fill,
                                color: coral,
                                size: 14,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  status,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: plum,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 12,
                child: CustomPaint(painter: _TicketSeam()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _detail(
                      CupertinoIcons.calendar,
                      'OUR DAY',
                      local.formatFullDate(invitation.startsAt),
                    ),
                    _detail(
                      CupertinoIcons.clock,
                      'OUR TIME',
                      local.formatTimeOfDay(
                        TimeOfDay.fromDateTime(invitation.startsAt),
                      ),
                    ),
                    _detail(
                      CupertinoIcons.location_solid,
                      'OUR LITTLE ESCAPE',
                      invitation.venue,
                    ),
                    if (invitation.address.isNotEmpty &&
                        invitation.address != invitation.venue)
                      Padding(
                        padding: const EdgeInsets.only(left: 34, bottom: 14),
                        child: Text(
                          invitation.address,
                          style: const TextStyle(color: inkSoft, fontSize: 13),
                        ),
                      ),
                    _detail(
                      CupertinoIcons.sparkles,
                      'COME DRESSED IN',
                      invitation.dress,
                    ),
                    if (invitation.message.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          invitation.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.5,
                            color: plum,
                          ),
                        ),
                      ),
                    if (invitation.selfiePath != null) ...[
                      const SizedBox(height: 12),
                      DateSelfie(path: invitation.selfiePath!),
                      const SizedBox(height: 8),
                      const Text(
                        'Proof that the best place is together.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: inkSoft),
                      ),
                    ],
                    if (showMapAction && invitation.latitude != null)
                      TextButton.icon(
                        onPressed: () => openDateMap(
                          place: invitation.venue,
                          latitude: invitation.latitude,
                          longitude: invitation.longitude,
                        ),
                        icon: const Icon(CupertinoIcons.map, size: 17),
                        label: const Text('Explore on Google Maps'),
                      ),
                    if (actions != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: actions!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: coral, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.3,
                  color: inkSoft,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(fontSize: 17, height: 1.35, color: plum),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TicketSeam extends CustomPainter {
  const _TicketSeam();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = coral.withValues(alpha: .25)
      ..strokeWidth = 1;
    for (double x = 18; x < size.width - 18; x += 10) {
      canvas.drawLine(Offset(x, 6), Offset(x + 4, 6), paint);
    }
    canvas.drawCircle(Offset(0, 6), 8, Paint()..color = cream);
    canvas.drawCircle(Offset(size.width, 6), 8, Paint()..color = cream);
  }

  @override
  bool shouldRepaint(covariant _TicketSeam oldDelegate) => false;
}
