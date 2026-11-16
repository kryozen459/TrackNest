import 'dart:convert';
import 'dart:io';

import '../models/playlist_link.dart';

class PlaylistLinkRepository {
  PlaylistLinkRepository({this.directory});

  static const _fileName = 'playlist_links_v1.json';

  final Directory? directory;

  Future<List<PlaylistLink>> load() async {
    final file = await _file();
    if (!await file.exists()) return const [];

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('The saved playlist file is not a list.');
    }

    final links = <PlaylistLink>[];
    for (final entry in decoded) {
      try {
        if (entry is Map<String, dynamic>) {
          links.add(PlaylistLink.fromJson(entry));
        }
      } on FormatException {
        // Skip malformed entries while keeping the rest of the library usable.
      } on TypeError {
        // Skip entries written by an incompatible earlier version.
      } on ArgumentError {
        // Skip entries with an unknown source name.
      }
    }
    return links;
  }

  Future<void> saveAll(Iterable<PlaylistLink> links) async {
    final file = await _file();
    final serialized = jsonEncode(links.map((link) => link.toJson()).toList());
    await file.writeAsString(serialized, flush: true);
  }

  Future<File> _file() async {
    final storageDirectory = directory ?? _defaultDirectory();
    await storageDirectory.create(recursive: true);
    return File('${storageDirectory.path}${Platform.pathSeparator}$_fileName');
  }

  Directory _defaultDirectory() {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw const FileSystemException(
        'Windows roaming application data directory is unavailable.',
      );
    }
    return Directory('$appData${Platform.pathSeparator}TrackNest');
  }
}
