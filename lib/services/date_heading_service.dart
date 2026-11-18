class DateHeadingService {
  const DateHeadingService();

  List<String> suggest(String name, String category, DateTime when) {
    final place = name.trim();
    if (place.isEmpty) return const [];
    final context = '$place $category'.toLowerCase();
    final hour = when.hour;
    final morning = hour < 12;
    final evening = hour >= 17;
    final type = switch (category) {
      'Dining' => 'dining',
      'Resort' => 'resort',
      'Nature' => 'nature',
      'Riverside' => 'riverside',
      'Culture' => 'culture',
      'Hills' => 'hills',
      'Outdoors' => 'outdoors',
      'Playful' => 'playful',
      'Bike ride' => 'ride',
      _ => RegExp(r'cafe|coffee|restaurant|diner|bistro|food').hasMatch(context)
          ? 'dining'
          : RegExp(r'river|lake|beach|water|ghat').hasMatch(context)
          ? 'riverside'
          : RegExp(r'hill|peak|viewpoint|mountain').hasMatch(context)
          ? 'hills'
          : RegExp(r'park|garden|forest|nature').hasMatch(context)
          ? 'nature'
          : RegExp(r'cinema|game|arcade|bowling|zoo').hasMatch(context)
          ? 'playful'
          : 'general',
    };
    final headings = switch (type) {
      'dining' => [
        if (morning || context.contains('cafe') || context.contains('coffee'))
          'Coffee date at $place',
        if (evening) 'An evening at $place',
        'A table for two at $place',
        'Something delicious at $place',
      ],
      'resort' => [
        'A little escape to $place',
        'An unhurried day at $place',
        'Just us at $place',
      ],
      'nature' => [
        'A slow walk at $place',
        'Fresh air and us at $place',
        'A quiet day together at $place',
      ],
      'riverside' => [
        'By the water at $place',
        'A riverside date at $place',
        'Watch the day drift by at $place',
      ],
      'hills' => [
        'A view from $place',
        'Up the hill together at $place',
        'The best view is with you at $place',
      ],
      'culture' => [
        'Explore $place together',
        'A little culture at $place',
        'Something beautiful at $place',
      ],
      'outdoors' => [
        'An open-air date at $place',
        'A little adventure at $place',
        'Our day outside at $place',
      ],
      'playful' => [
        'A playful date at $place',
        'Laugh with me at $place',
        'A little fun at $place',
      ],
      'ride' => [
        'Ride together to $place',
        'The long way to $place',
        'Two helmets, one lovely ride to $place',
      ],
      _ => [
        if (evening) 'An evening at $place',
        'A date, just us at $place',
        'A little more us at $place',
        'Our next memory at $place',
      ],
    };
    return headings.toSet().take(3).toList();
  }
}
