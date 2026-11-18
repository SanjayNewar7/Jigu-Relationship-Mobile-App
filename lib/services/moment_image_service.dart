import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../core/config.dart';

/// Full-resolution photos stay in app-private storage after their first download.
class MomentImageService {
  static final Map<String, Future<File>> _downloads = {};

  Future<Directory> _directory() async {
    final user = db.auth.currentUser?.id;
    if (user == null) throw StateError('Sign in to see your moments.');
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/moment-images/$user');
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> localFile(Map<String, dynamic> moment) async {
    final user = db.auth.currentUser?.id;
    if (user == null) throw StateError('Sign in to see your moments.');
    final id = moment['id'].toString();
    final cacheKey = '$user:$id';
    final directory = await _directory();
    final file = File('${directory.path}/$id.jpg');
    if (await file.exists() && await file.length() > 0) return file;
    return _downloads.putIfAbsent(cacheKey, () async {
      try {
        final bytes = await db.storage
            .from('moments')
            .download(moment['storage_path'])
            .timeout(const Duration(seconds: 20));
        if (db.auth.currentUser?.id != user) {
          throw StateError('The signed-in account changed.');
        }
        final temporary = File('${file.path}.part');
        await temporary.writeAsBytes(bytes, flush: true);
        return temporary.rename(file.path);
      } finally {
        _downloads.remove(cacheKey);
      }
    });
  }

  Future<void> seed(Map<String, dynamic> moment, Uint8List bytes) async {
    final directory = await _directory();
    final file = File('${directory.path}/${moment['id']}.jpg');
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> prune(Iterable<Map<String, dynamic>> visibleMoments) async {
    final directory = await _directory();
    final keep = visibleMoments.map((moment) => '${moment['id']}.jpg').toSet();
    await for (final entry in directory.list()) {
      if (entry is File &&
          !entry.path.endsWith('.part') &&
          !keep.contains(entry.uri.pathSegments.last)) {
        await entry.delete();
      }
    }
  }

  Future<void> clear() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/moment-images');
    if (await directory.exists()) await directory.delete(recursive: true);
    _downloads.clear();
  }
}
