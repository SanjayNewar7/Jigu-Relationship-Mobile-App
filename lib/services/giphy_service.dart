import 'dart:convert';
import 'dart:io';
import '../core/config.dart';

class GiphyGif {
  const GiphyGif(this.id, this.url, this.title);
  final String id, url, title;
  factory GiphyGif.fromJson(Map<String, dynamic> row) => GiphyGif(
    row['id'] as String,
    (row['images']['fixed_height']['url']) as String,
    row['title'] as String? ?? 'GIF',
  );
}

class GiphyService {
  static String? _key;
  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    _key ??= (await db.functions.invoke('giphy-config')).data['key'] as String;
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await http.getUrl(
        Uri.https('api.giphy.com', '/v1/gifs/$path', {
          'api_key': _key!,
          ...params,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw StateError(
          response.statusCode == 429
              ? 'GIF search limit reached. Please try later.'
              : 'GIFs could not load. Please retry.',
        );
      }
      return jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    } finally {
      http.close(force: true);
    }
  }

  Future<List<GiphyGif>> search(String query, {int offset = 0}) async {
    final result = await _get(query.isEmpty ? 'trending' : 'search', {
      'rating': 'pg',
      'limit': '20',
      'offset': '$offset',
      if (query.isNotEmpty) 'q': query,
    });
    return (result['data'] as List)
        .map((r) => GiphyGif.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<String> resolve(String id) async {
    final result = await _get(id, {});
    return GiphyGif.fromJson(Map<String, dynamic>.from(result['data'])).url;
  }
}
