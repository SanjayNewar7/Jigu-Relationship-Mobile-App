import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import 'moment_image_service.dart';

class MomentService {
  Future<List<Map<String, dynamic>>> active(String coupleId) => db
      .from('moments')
      .select('*,moment_likes(user_id)')
      .eq('couple_id', coupleId)
      .isFilter('deleted_at', null)
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .order('created_at', ascending: false)
      .limit(48);

  Future<List<Map<String, dynamic>>> liked() => db
      .from('moments')
      .select('*,moment_likes!inner(user_id)')
      .eq('moment_likes.user_id', db.auth.currentUser!.id)
      .order('created_at', ascending: false)
      .limit(100);

  Future<void> upload(XFile photo, String coupleId) async {
    final bytes = await photo.readAsBytes();
    final path =
        '$coupleId/${DateTime.now().microsecondsSinceEpoch}-${db.auth.currentUser!.id}.jpg';
    await db.storage
        .from('moments')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      await db.from('moments').insert({
        'couple_id': coupleId,
        'author_id': db.auth.currentUser!.id,
        'storage_path': path,
      });
      final moment = await db
          .from('moments')
          .select('id,storage_path')
          .eq('storage_path', path)
          .single();
      try {
        await MomentImageService().seed(moment, bytes);
      } catch (_) {
        // The upload succeeded; a later view can fill the local cache.
      }
    } catch (_) {
      try {
        await db.storage.from('moments').remove([path]);
      } catch (_) {
        /* Cron removes orphan uploads. */
      }
      rethrow;
    }
  }

  Future<void> like(String id, {required bool liked}) async {
    final userId = db.auth.currentUser!.id;
    if (liked) {
      await db
          .from('moment_likes')
          .delete()
          .eq('moment_id', id)
          .eq('user_id', userId);
    } else {
      await db.from('moment_likes').insert({
        'moment_id': id,
        'user_id': userId,
      });
    }
  }

  Future<void> remove(String id) async {
    final own = await db
        .from('moments')
        .select('id')
        .eq('id', id)
        .eq('author_id', db.auth.currentUser!.id)
        .maybeSingle();
    if (own == null) {
      throw StateError('Only the person who shared this photo can remove it.');
    }
    // A removed row is deliberately hidden from its unliking author.
    await db
        .from('moments')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('author_id', db.auth.currentUser!.id);
  }

  Future<void> save(Map<String, dynamic> moment) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw StateError('Allow Jigu to save photos in your phone settings.');
    }
    final bytes = await (await MomentImageService().localFile(
      moment,
    )).readAsBytes();
    await Gal.putImageBytes(bytes, name: 'jigu-${moment['id']}.jpg');
  }
}
