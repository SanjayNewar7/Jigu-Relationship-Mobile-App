import '../core/config.dart';
import '../models/date_place.dart';

class DatePlaceService {
  Future<List<DatePlace>> places(String coupleId) async {
    final rows = await db.from('date_places').select()
        .eq('couple_id', coupleId)
        .order('created_at', ascending: false).limit(40);
    return rows.map((row) => DatePlace.fromMap(row)).toList();
  }

  Future<DatePlace> save(String coupleId, DatePlace place) async {
    final userId = db.auth.currentUser!.id;
    final row = await db.from('date_places')
        .insert(place.toInsert(coupleId, userId)).select().single();
    return DatePlace.fromMap(row);
  }

  Future<void> setFavorite(String id, bool value) async {
    await db.from('date_places').update({'is_favorite': value}).eq('id', id);
  }
}
