import 'dart:convert';
import 'dart:io';

class YouTubeApiKeyStore {
  static const _environmentKey = String.fromEnvironment('YOUTUBE_DATA_API_KEY');

  Future<String?> load() async {
    if (_environmentKey.trim().isNotEmpty) return _environmentKey.trim();

    final file = await _settingsFile();
    if (!await file.exists()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic> && decoded['apiKey'] is String) {
        final apiKey = (decoded['apiKey'] as String).trim();
        return apiKey.isEmpty ? null : apiKey;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> save(String apiKey) async {
    final file = await _settingsFile();
    await file.writeAsString(
      jsonEncode({'apiKey': apiKey.trim()}),
      flush: true,
    );
  }

  Future<File> _settingsFile() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw const FileSystemException(
        'TrackNest could not find the Windows app data folder.',
      );
    }
    final directory = Directory('$appData${Platform.pathSeparator}TrackNest');
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}youtube_api_key.json',
    );
  }
}
