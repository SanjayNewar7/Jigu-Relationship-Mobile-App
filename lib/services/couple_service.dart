import 'package:geolocator/geolocator.dart';
import '../core/config.dart';
import '../models/couple_snapshot.dart';
import '../models/space_join_result.dart';
import 'moment_service.dart';

class CoupleService {
  Future<void> leave() => db.rpc('leave_couple');
  Future<CoupleSnapshot> load() async {
    final user = db.auth.currentUser!.id;
    final profile = await db.from('profiles').select().eq('id', user).single();
    List<Map<String, dynamic>> moments = [], likedMoments = [];
    DateTime? startedOn;
    Map<String, dynamic>? partnerPlace, ownPlace, partnerProfile;
    if (profile['couple_id'] != null) {
      moments = await MomentService().active(profile['couple_id']);
      likedMoments = await MomentService().liked();
      ownPlace = await db
          .from('locations')
          .select()
          .eq('user_id', user)
          .maybeSingle();
      final couple = await db
          .from('couples')
          .select()
          .eq('id', profile['couple_id'])
          .single();
      startedOn = DateTime.tryParse(couple['started_on']?.toString() ?? '');
      final other = couple['person_a'] == user
          ? couple['person_b']
          : couple['person_a'];
      if (other != null) {
        partnerProfile = await db
            .from('profiles')
            .select('display_name,last_active_at')
            .eq('id', other)
            .maybeSingle();
        final rows = await db
            .from('locations')
            .select()
            .eq('user_id', other)
            .limit(1);
        if (rows.isNotEmpty) partnerPlace = rows.first;
      }
    }
    return CoupleSnapshot(
      profile,
      moments,
      partnerPlace,
      ownPlace: ownPlace,
      partnerProfile: partnerProfile,
      likedMoments: likedMoments,
      startedOn: startedOn,
    );
  }

  Future<void> join(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const FormatException('Enter the six digit secret code.');
    }
    final result = await db.rpc(
      'join_couple_v2',
      params: {'invite': code.trim()},
    );
    final message = SpaceJoinResult.errorMessage(
      Map<String, dynamic>.from(result as Map),
    );
    if (message != null) throw FormatException(message);
  }

  Future<String> photoUrl(String path) =>
      db.storage.from('moments').createSignedUrl(path, 3600);
  Future<void> setLocationEnabled(bool enabled) async {
    await db
        .from('profiles')
        .update({'location_enabled': enabled})
        .eq('id', db.auth.currentUser!.id);
    if (!enabled) {
      await db
          .from('locations')
          .delete()
          .eq('user_id', db.auth.currentUser!.id);
    }
  }

  Future<void> sendPosition(Position p, String coupleId) =>
      db.from('locations').upsert({
        'user_id': db.auth.currentUser!.id,
        'couple_id': coupleId,
        'speed_mps': p.speed >= 0 && p.speed <= 100 && p.speedAccuracy <= 5
            ? p.speed
            : null,
        'accuracy_m': p.accuracy,
        'heading': p.heading >= 0 && p.heading <= 360 ? p.heading : null,
        'recorded_at': p.timestamp.toUtc().toIso8601String(),
        'latitude': p.latitude,
        'longitude': p.longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
}
