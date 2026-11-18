class DatePlace {
  const DatePlace({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.source = 'manual',
    this.isFavorite = true,
  });

  final String? id;
  final String name, address, category, source;
  final double latitude, longitude;
  final bool isFavorite;

  factory DatePlace.fromMap(Map<String, dynamic> value) => DatePlace(
    id: value['id'] as String?,
    name: value['name'] as String,
    address: value['address'] as String,
    latitude: (value['latitude'] as num).toDouble(),
    longitude: (value['longitude'] as num).toDouble(),
    category: value['category'] as String? ?? 'Our place',
    source: value['source'] as String? ?? 'manual',
    isFavorite: value['is_favorite'] as bool? ?? true,
  );

  Map<String, dynamic> toInsert(String coupleId, String userId) => {
    'couple_id': coupleId,
    'created_by': userId,
    'name': name.trim(),
    'address': address.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
    'source': source,
    'is_favorite': isFavorite,
  };
}
