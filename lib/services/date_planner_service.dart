import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../models/date_invitation.dart';

class DatePlannerService {
  Future<List<DateInvitation>> load(
    String coupleId, {
    int page = 0,
    bool history = false,
  }) async {
    final rows = await db
        .from('date_invitations')
        .select()
        .eq('couple_id', coupleId)
        .inFilter(
          'status',
          history
              ? ['completed', 'cancelled', 'declined']
              : ['pending', 'accepted'],
        )
        .order('starts_at', ascending: !history)
        .order('id')
        .range(page * 10, page * 10 + 10);
    return rows.map(DateInvitation.new).toList();
  }

  Future<void> create(
    String coupleId,
    DateTime date,
    String venue,
    String address,
    String dress,
    String message, {
    double? latitude,
    double? longitude,
    String? heading,
  }) async {
    await db.from('date_invitations').insert({
      'couple_id': coupleId,
      'creator_id': db.auth.currentUser!.id,
      'starts_at': date.toUtc().toIso8601String(),
      'venue': venue.trim(),
      'address': address.trim(),
      'dress_style': dress,
      'message': message.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading?.trim().isEmpty == true ? null : heading?.trim(),
    });
  }

  Future<void> complete(DateInvitation invitation, XFile? photo) async {
    String? path;
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw StateError('Choose a photo smaller than 10 MB.');
      }
      path =
          '${invitation.data['couple_id']}/${invitation.id}/${db.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await db.storage
          .from('date-memories')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    }
    try {
      await db.rpc(
        'complete_date',
        params: {'invitation_id': invitation.id, 'photo_path': path},
      );
    } catch (_) {
      if (path != null) {
        try {
          await db.storage.from('date-memories').remove([path]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> respond(String id, String status) async {
    await db.rpc(
      'respond_to_date',
      params: {'invitation_id': id, 'answer': status},
    );
  }

  Future<Map<String, dynamic>> discover(
    double latitude,
    double longitude,
    int radius,
  ) async {
    final result = await db.functions.invoke(
      'date-discovery',
      body: {'latitude': latitude, 'longitude': longitude, 'radius': radius},
    );
    return Map<String, dynamic>.from(result.data);
  }
}
