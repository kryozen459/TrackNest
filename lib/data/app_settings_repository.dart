import 'dart:convert';
import 'dart:io';

class AppSettings {
  const AppSettings({
    this.darkMode = true,
    this.reduceMotion = false,
    this.confirmBeforeRemoving = true,
  });

  final bool darkMode;
  final bool reduceMotion;
  final bool confirmBeforeRemoving;

  AppSettings copyWith({
    bool? darkMode,
    bool? reduceMotion,
    bool? confirmBeforeRemoving,
  }) => AppSettings(
    darkMode: darkMode ?? this.darkMode,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    confirmBeforeRemoving: confirmBeforeRemoving ?? this.confirmBeforeRemoving,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    darkMode: json['darkMode'] is bool ? json['darkMode'] as bool : true,
    reduceMotion: json['reduceMotion'] is bool
        ? json['reduceMotion'] as bool
        : false,
    confirmBeforeRemoving: json['confirmBeforeRemoving'] is bool
        ? json['confirmBeforeRemoving'] as bool
        : true,
  );

  Map<String, Object> toJson() => {
    'darkMode': darkMode,
    'reduceMotion': reduceMotion,
    'confirmBeforeRemoving': confirmBeforeRemoving,
  };
}

class AppSettingsRepository {
  AppSettingsRepository({this.directory});

  static const _fileName = 'app_settings_v1.json';

  final Directory? directory;

  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const AppSettings();
      return AppSettings.fromJson(decoded);
    } on FileSystemException {
      return const AppSettings();
    } on FormatException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
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
