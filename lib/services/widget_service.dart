import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../core/config.dart';
import 'widget_map_service.dart';
import 'moment_image_service.dart';

class WidgetService {
  static Future<void> _pending = Future.value();
  Future<void> sync(
    List<Map<String, dynamic>> moments,
    String locationText, {
    Map<String, dynamic>? place,
    String activity = '',
  }) {
    final user = db.auth.currentUser?.id;
    final result = _pending.then((_) async {
      if (user == null || db.auth.currentUser?.id != user) return;
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/widget-photos',
      );
      await directory.create(recursive: true);
      final photos = <Map<String, dynamic>>[];
      for (final moment in moments) {
        if (db.auth.currentUser?.id != user) return;
        final expiry =
            DateTime.tryParse(moment['expires_at']?.toString() ?? '') ??
            DateTime.parse(moment['created_at']).add(const Duration(hours: 48));
        if (!expiry.isAfter(DateTime.now())) continue;
        final file = File('${directory.path}/${moment['id']}-original.jpg');
        try {
          if (!await file.exists() || await file.length() == 0) {
            final original = await MomentImageService().localFile(moment);
            final temporary = File('${file.path}.part');
            await original.copy(temporary.path);
            await temporary.rename(file.path);
          }
          photos.add({
            'path': file.path,
            'expires': expiry.millisecondsSinceEpoch,
          });
        } catch (error) {
          debugPrint(
            'Jigu widget photo preparation failed: ${error.runtimeType}',
          );
        }
      }
      if (db.auth.currentUser?.id != user) return;
      await HomeWidget.saveWidgetData<String>('photos', jsonEncode(photos));
      debugPrint(
        'Jigu widget prepared ${photos.length} of ${moments.length} moments',
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.sanjaya.jigu.JiguWidgetProvider',
      );
      final keep = photos.map((p) => p['path']).toSet();
      await for (final file in directory.list()) {
        if (file is File && !keep.contains(file.path)) await file.delete();
      }
      await HomeWidget.saveWidgetData<String>('location_text', locationText);
      await HomeWidget.saveWidgetData<String>('partner_activity', activity);
      await HomeWidget.saveWidgetData<String>(
        'location_sync_time',
        DateTime.tryParse(
              place?['updated_at']?.toString() ?? '',
            )?.millisecondsSinceEpoch.toString() ??
            '0',
      );
      await HomeWidget.saveWidgetData<String>(
        'location_coordinates',
        place == null ? '' : '${place['latitude']}, ${place['longitude']}',
      );
      final mapPath = await WidgetMapService().snapshot(place);
      if (db.auth.currentUser?.id != user) return;
      await HomeWidget.saveWidgetData<String>(
        'location_map_path',
        mapPath ?? '',
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.sanjaya.jigu.JiguLocationWidgetProvider',
      );
    });
    _pending = result.catchError((_) {});
    return result;
  }

  static Future<void> _update() async {
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.sanjaya.jigu.JiguWidgetProvider',
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.sanjaya.jigu.JiguLocationWidgetProvider',
    );
  }

  Future<void> clear() async {
    await _pending;
    for (final name in [
      'location_map_path',
      'photos',
      'photo_path',
      'cached_storage_path',
      'location_coordinates',
      'partner_activity',
    ]) {
      await HomeWidget.saveWidgetData<String>(
        name,
        name == 'photos' ? '[]' : '',
      );
    }
    await HomeWidget.saveWidgetData<String>(
      'location_text',
      'Open Jigu to share your world',
    );
    await HomeWidget.saveWidgetData<String>('location_sync_time', '0');
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/widget-photos',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
    final support = (await getApplicationSupportDirectory()).path;
    final mapCache = Directory('$support/widget-map');
    if (await mapCache.exists()) await mapCache.delete(recursive: true);
    final legacyPhoto = File('$support/jigu-widget.jpg');
    if (await legacyPhoto.exists()) await legacyPhoto.delete();
    await _update();
  }
}
