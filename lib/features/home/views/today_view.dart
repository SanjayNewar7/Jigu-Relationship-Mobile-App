import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../models/daily_whisper.dart';
import '../widgets/moment_carousel.dart';
import '../widgets/mood_quote_card.dart';
import '../widgets/place_card.dart';
import '../widgets/relationship_card.dart';

class TodayView extends StatelessWidget {
  const TodayView({
    super.key,
    required this.moments,
    required this.placeLabel,
    required this.place,
    required this.busy,
    required this.onUpload,
    required this.onRefresh,
    this.startedOn,
    this.onSetDate,
    this.onLike,
    this.onSave,
    this.onDelete,
  });
  final List<Map<String, dynamic>> moments;
  final Map<String, dynamic>? place;
  final String placeLabel;
  final bool busy;
  final DateTime? startedOn;
  final Future<void> Function(DateTime date)? onSetDate;
  final Future<void> Function(Map<String, dynamic>)? onLike, onSave, onDelete;
  final VoidCallback onUpload;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      key: const PageStorageKey('today'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 130),
      children: [
        RelationshipCard(startedOn: startedOn, onSetDate: onSetDate),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
          child: Text(
            dailyWhisper(DateTime.now()),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: inkSoft),
          ),
        ),
        const SizedBox(height: 18),
        MomentCarousel(
          moments: moments,
          onLike: onLike,
          onSave: onSave,
          onDelete: onDelete,
        ),
        const SizedBox(height: 18),
        const MoodQuoteCard(),
        const SizedBox(height: 18),
        PlaceCard(label: placeLabel, place: place),
        const SizedBox(height: 18),
        const GlassSurface(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(CupertinoIcons.square_grid_2x2, size: 21, color: inkSoft),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keep us close. Add Jigu to your home screen widgets.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
