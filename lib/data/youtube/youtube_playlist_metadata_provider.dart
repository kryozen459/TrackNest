import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/playlist_link.dart';
import '../../models/playlist_metadata.dart';
import '../playlist_metadata_provider.dart';

class YouTubePlaylistMetadataProvider implements PlaylistMetadataProvider {
  YouTubePlaylistMetadataProvider({required String apiKey, http.Client? client})
    : _apiKey = apiKey.trim(),
      _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  void close() => _client.close();

  @override
  PlaylistSource get source => PlaylistSource.youtube;

  @override
  Future<PlaylistMetadataSnapshot> importPlaylist(Uri playlistUrl) async {
    if (_apiKey.isEmpty) {
      throw const MetadataImportException(
        'YouTube metadata is not configured. Add a restricted YouTube Data API key.',
      );
    }

    final playlistId = _playlistIdFrom(playlistUrl);
    if (playlistId == null) {
      throw const MetadataImportException(
        'This is not a YouTube playlist link with a playlist ID.',
      );
    }

    final playlistResponse = await _get('playlists', {
      'part': 'snippet,contentDetails',
      'id': playlistId,
    });
    final playlistItems = playlistResponse['items'];
    if (playlistItems is! List || playlistItems.isEmpty) {
      throw const MetadataImportException(
        'The playlist was not found or is not available through the public API.',
      );
    }

    final playlist = _asMap(playlistItems.first);
    final snippet = _asMap(playlist?['snippet']);
    final title = snippet?['title'];
    if (title is! String || title.isEmpty) {
      throw const MetadataImportException(
        'The YouTube API returned a playlist without a title.',
      );
    }

    final tracks = <PlaylistTrackMetadata>[];
    String? pageToken;
    do {
      final parameters = <String, String>{
        'part': 'snippet,contentDetails',
        'playlistId': playlistId,
        'maxResults': '50',
      };
      if (pageToken != null) parameters['pageToken'] = pageToken;

      final page = await _get('playlistItems', parameters);
      final items = page['items'];
      if (items is List) {
        for (final item in items) {
          final itemSnippet = _asMap(_asMap(item)?['snippet']);
          final resource = _asMap(itemSnippet?['resourceId']);
          final videoId = resource?['videoId'];
          final itemTitle = itemSnippet?['title'];
          if (videoId is! String ||
              videoId.isEmpty ||
              itemTitle is! String ||
              itemTitle.isEmpty) {
            continue;
          }

          final owner = itemSnippet?['videoOwnerChannelTitle'];
          tracks.add(
            PlaylistTrackMetadata(
              sourceItemId: videoId,
              title: itemTitle,
              artistNames: owner is String && owner.isNotEmpty
                  ? [owner]
                  : const [],
              sourceUrl: Uri.https('www.youtube.com', '/watch', {'v': videoId}),
              artworkUrl: _thumbnail(itemSnippet?['thumbnails']),
            ),
          );
        }
      }
      final next = page['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
    } while (pageToken != null);

    return PlaylistMetadataSnapshot(
      source: source,
      sourcePlaylistId: playlistId,
      title: title,
      sourceUrl: playlistUrl,
      artworkUrl: _thumbnail(snippet?['thumbnails']),
      fetchedAt: DateTime.now().toUtc(),
      tracks: tracks,
    );
  }

  Future<Map<String, dynamic>> _get(
    String resource,
    Map<String, String> parameters,
  ) async {
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/$resource', {
      ...parameters,
      'key': _apiKey,
    });
    final response = await _client.get(
      uri,
      headers: const {'Cache-Control': 'no-store'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _asMap(_asMap(decoded)?['error']);
      final message = error?['message'];
      throw MetadataImportException(
        message is String ? message : 'YouTube API request failed.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const MetadataImportException(
        'The YouTube API returned an invalid response.',
      );
    }
    return decoded;
  }

  String? _playlistIdFrom(Uri uri) {
    final host = uri.host.toLowerCase();
    final isYouTube =
        host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com';
    if (uri.scheme != 'https' || !isYouTube) return null;
    final id = uri.queryParameters['list'];
    return id == null || id.isEmpty ? null : id;
  }

  Map<String, dynamic>? _asMap(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  Uri? _thumbnail(Object? value) {
    final sizes = _asMap(value);
    if (sizes == null) return null;
    for (final size in ['maxres', 'standard', 'high', 'medium', 'default']) {
      final url = _asMap(sizes[size])?['url'];
      if (url is String) return Uri.tryParse(url);
    }
    return null;
  }
}
