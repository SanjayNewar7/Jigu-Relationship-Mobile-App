import '../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../models/date_invitation.dart';
import '../../models/date_place.dart';
import '../../services/date_planner_service.dart';
import '../../services/date_place_service.dart';
import '../../services/date_heading_service.dart';
import '../../utils/date_maps.dart';
import 'widgets/invitation_card.dart';
import 'widgets/date_discovery.dart';
import 'widgets/date_place_editor.dart';
import 'widgets/lily_date_picker.dart';

class DateComposePage extends StatefulWidget {
  const DateComposePage({super.key, required this.coupleId});
  final String coupleId;
  @override
  State<DateComposePage> createState() => _DateComposePageState();
}

class _DateComposePageState extends State<DateComposePage> {
  final form = GlobalKey<FormState>();
  final venue = TextEditingController(),
      address = TextEditingController(),
      heading = TextEditingController(),
      message = TextEditingController();
  DateTime date = DateTime.now().add(const Duration(days: 1));
  String dress = 'Come as you are';
  String placeCategory = 'Our place';
  List<DatePlace> savedPlaces = [];
  double? latitude, longitude;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    try {
      final places = await DatePlaceService().places(widget.coupleId);
      if (mounted) setState(() => savedPlaces = places);
    } catch (_) {}
  }

  void selectPlace(DatePlace place, {String? suggestedHeading}) {
    venue.text = place.name;
    address.text = place.address;
    setState(() {
      latitude = place.latitude;
      longitude = place.longitude;
      placeCategory = place.category;
    });
    heading.text =
        suggestedHeading ??
        DateHeadingService().suggest(place.name, place.category, date).first;
  }

  Future<void> addOwnPlace() async {
    final place = await Navigator.push<DatePlace>(
      context,
      MaterialPageRoute(
        builder: (_) => DatePlaceEditor(coupleId: widget.coupleId),
      ),
    );
    if (place == null || !mounted) return;
    selectPlace(place);
    await loadPlaces();
  }

  Future<void> saveNearby(Map<String, dynamic> row) async {
    final place = DatePlace(
      name: row['name'] as String,
      address: row['address'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      category: row['category'] as String,
      source: 'nearby',
    );
    await DatePlaceService().save(widget.coupleId, place);
    await loadPlaces();
  }

  @override
  void dispose() {
    venue.dispose();
    address.dispose();
    heading.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final selected = await showLilyDatePicker(context, date);
    if (selected != null && mounted) {
      setState(() => date = selected);
      if (venue.text.isNotEmpty) {
        heading.text = DateHeadingService()
            .suggest(venue.text, placeCategory, date)
            .first;
      }
    }
  }

  Future<void> preview() async {
    if (!form.currentState!.validate()) return;
    if (!date.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a time in the future.')),
      );
      return;
    }
    final draft = DateInvitation({
      'id': '',
      'creator_id': '',
      'venue': venue.text.trim(),
      'heading': heading.text.trim(),
      'address': address.text.trim(),
      'dress_style': dress,
      'message': message.text.trim(),
      'status': 'pending',
      'starts_at': date.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    });
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InvitationCard(invitation: draft),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send to our space'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
            ],
          ),
        ),
      ),
    );
    if (send != true || !mounted) return;
    setState(() => saving = true);
    try {
      await DatePlannerService().create(
        widget.coupleId,
        date,
        venue.text,
        address.text,
        dress,
        message.text,
        latitude: latitude,
        longitude: longitude,
        heading: heading.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Your invitation was not sent. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('A date for us')),
      body: LilyBackdrop(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Make a little invitation',
                style: TextStyle(fontSize: 27, color: plum),
              ),
              const SizedBox(height: 18),
              DateDiscovery(
                onSelect: (place) {
                  selectPlace(
                    DatePlace.fromMap(place),
                    suggestedHeading: place['title'] as String?,
                  );
                },
                onFavorite: saveNearby,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: saving ? null : addOwnPlace,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Pin our own place on the map'),
              ),
              if (savedPlaces.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Our saved places', style: TextStyle(fontSize: 19)),
                ...savedPlaces
                    .take(8)
                    .map(
                      (place) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          place.isFavorite
                              ? Icons.favorite
                              : Icons.place_outlined,
                          color: coral,
                        ),
                        title: Text(place.name),
                        subtitle: Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => selectPlace(place),
                        trailing: IconButton(
                          tooltip: place.isFavorite
                              ? 'Remove favourite'
                              : 'Add to favourites',
                          icon: Icon(
                            place.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          onPressed: () async {
                            await DatePlaceService().setFavorite(
                              place.id!,
                              !place.isFavorite,
                            );
                            await loadPlaces();
                          },
                        ),
                      ),
                    ),
              ],
              OutlinedButton.icon(
                onPressed: saving ? null : pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${local.formatMediumDate(date)} \u00b7 ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: venue,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Our place',
                  hintText: 'Choose nearby, a favourite, or add your own',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Choose or add a place'
                    : null,
              ),
              if (latitude != null && longitude != null)
                TextButton.icon(
                  onPressed: () => openDateMap(
                    place: venue.text,
                    latitude: latitude,
                    longitude: longitude,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(address.text),
                ),
              if (venue.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'A heading for this date',
                  style: TextStyle(fontSize: 19),
                ),
                const SizedBox(height: 8),
                ...DateHeadingService()
                    .suggest(venue.text, placeCategory, date)
                    .map(
                      (idea) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ActionChip(
                          label: Text(idea),
                          onPressed: () => setState(() => heading.text = idea),
                        ),
                      ),
                    ),
                TextFormField(
                  controller: heading,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Invitation heading',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Choose or write a heading'
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              const Text('What shall we wear?', style: TextStyle(fontSize: 19)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    [
                          'Come as you are',
                          'Casual',
                          'Dressy',
                          'Matching colours',
                          'Adventure ready',
                        ]
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item),
                            selected: dress == item,
                            onSelected: saving
                                ? null
                                : (_) => setState(() => dress = item),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: message,
                maxLength: 1200,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'A little note for your person',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : preview,
                child: Text(saving ? 'Sending...' : 'Preview invitation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
