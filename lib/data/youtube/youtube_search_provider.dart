import 'dart:convert';

import 'package:http/http.dart' as http;

class YouTubeSearchResult {
  const YouTubeSearchResult({
    required this.videoId,
    required this.title,
    required this.channel,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String channel;
  final String? thumbnailUrl;

  Uri get watchUrl => Uri.https('www.youtube.com', '/watch', {'v': videoId});
}

class YouTubeSearchProvider {
  YouTubeSearchProvider({required String apiKey, http.Client? client})
    : _apiKey = apiKey.trim(),
      _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  void close() => _client.close();

  Future<List<YouTubeSearchResult>> search(String query) async {
    if (_apiKey.isEmpty) {
      throw const YouTubeSearchException(
        'Add your YouTube API key to search for songs.',
      );
    }

    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'type': 'video',
      'videoEmbeddable': 'true',
      'maxResults': '12',
      'q': query.trim(),
      'key': _apiKey,
    });
    final response = await _client.get(uri);
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      final message = error is Map<String, dynamic> ? error['message'] : null;
      throw YouTubeSearchException(
        message is String && message.isNotEmpty ? message : 'YouTube search could not be completed. Check your connection and API key.',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      throw const YouTubeSearchException(
        'YouTube returned an unexpected search response.',
      );
    }

    final results = <YouTubeSearchResult>[];
    for (final rawItem in decoded['items'] as List) {
      if (rawItem is! Map<String, dynamic>) continue;
      final id = rawItem['id'];
      final snippet = rawItem['snippet'];
      if (id is! Map<String, dynamic> || snippet is! Map<String, dynamic>) {
        continue;
      }
      final videoId = id['videoId'];
      final title = snippet['title'];
      if (videoId is! String || videoId.isEmpty || title is! String) continue;

      final thumbnails = snippet['thumbnails'];
      final high = thumbnails is Map<String, dynamic>
          ? thumbnails['high']
          : null;
      final medium = thumbnails is Map<String, dynamic>
          ? thumbnails['medium']
          : null;
      final thumbnail = high is Map<String, dynamic>
          ? high['url']
          : medium is Map<String, dynamic>
          ? medium['url']
          : null;
      final channel = snippet['channelTitle'];
      results.add(
        YouTubeSearchResult(
          videoId: videoId,
          title: title,
          channel: channel is String ? channel : 'YouTube',
          thumbnailUrl: thumbnail is String ? thumbnail : null,
        ),
      );
    }
    return results;
  }
}

class YouTubeSearchException implements Exception {
  const YouTubeSearchException(this.message);

  final String message;
}
