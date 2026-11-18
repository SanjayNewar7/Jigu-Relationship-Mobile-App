import '../../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/config.dart';
import '../../../models/date_place.dart';
import '../../../services/date_place_service.dart';
import 'date_place_map_picker.dart';

class DatePlaceEditor extends StatefulWidget {
  const DatePlaceEditor({super.key, required this.coupleId});
  final String coupleId;

  @override
  State<DatePlaceEditor> createState() => _DatePlaceEditorState();
}

class _DatePlaceEditorState extends State<DatePlaceEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final address = TextEditingController();
  LatLng? pin;
  String category = 'Our place';
  bool favorite = true, busy = false;

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose the exact spot on the map first.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final place = await DatePlaceService().save(
        widget.coupleId,
        DatePlace(
          name: name.text.trim(),
          address: address.text.trim(),
          latitude: pin!.latitude,
          longitude: pin!.longitude,
          category: category,
          isFavorite: favorite,
        ),
      );
      if (mounted) Navigator.pop(context, place);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                e,
                fallback: 'Could not save this place. Please retry.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add our own place')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Somewhere only we know',
              style: TextStyle(fontSize: 26, color: plum),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add the place and address, then pin its exact spot for your invitation.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Place name'),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Enter the place name'
                  : null,
            ),
            TextFormField(
              controller: address,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter the full address'
                  : null,
            ),
            DatePlaceMapPicker(onChanged: (point) => pin = point),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Kind of date'),
              items:
                  const [
                        'Our place',
                        'Dining',
                        'Resort',
                        'Nature',
                        'Riverside',
                        'Culture',
                        'Hills',
                        'Outdoors',
                        'Playful',
                        'Bike ride',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => category = value!),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: favorite,
              onChanged: (value) => setState(() => favorite = value),
              title: const Text('Keep in our favourites'),
              subtitle: const Text('Easy to choose for another date.'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.favorite_outline),
              label: Text(busy ? 'Saving...' : 'Save and choose this place'),
            ),
          ],
        ),
      ),
    ),
  );
}
