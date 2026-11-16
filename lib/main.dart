import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'widgets/direct_media_downloader.dart';
import 'widgets/creator_sections.dart';
import 'widgets/glass_surface.dart';
import 'widgets/local_music_player.dart';

import 'package:flutter/services.dart';

import 'data/playlist_link_repository.dart';
import 'data/app_settings_repository.dart';
import 'platform/windows_link_opener.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/sign_in_dialog.dart';

void main() => runApp(const TrackNestApp());

class TrackNestApp extends StatefulWidget {
  const TrackNestApp({super.key, this.repository});

  final PlaylistLinkRepository? repository;

  @override
  State<TrackNestApp> createState() => _TrackNestAppState();
}

class _TrackNestAppState extends State<TrackNestApp> {
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final saved = await _settingsRepository.load();
    if (mounted) setState(() => _settings = saved);
  }

  void _updateSettings(AppSettings settings) {
    setState(() => _settings = settings);
    unawaited(_saveSettings(settings));
  }

  Future<void> _saveSettings(AppSettings settings) async {
    try {
      await _settingsRepository.save(settings);
    } on FileSystemException {
      // Keep the selected preference for this session if disk storage is unavailable.
    }
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const mint = Color(0xFF70E5CB);
    final primary = dark ? mint : const Color(0xFF087E72);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          surface: dark ? const Color(0xFF142630) : const Color(0xFFF9FCFD),
        ).copyWith(
          primary: primary,
          onPrimary: dark ? const Color(0xFF06251F) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF17483F)
              : const Color(0xFFBDEFE5),
          onPrimaryContainer: dark
              ? const Color(0xFFB7F4E7)
              : const Color(0xFF064D45),
          secondary: dark ? const Color(0xFF96C9FF) : const Color(0xFF386A9B),
          onSecondary: dark ? const Color(0xFF10243A) : Colors.white,
          tertiary: dark ? const Color(0xFFFFC987) : const Color(0xFF9A5B00),
          surface: dark ? const Color(0xFF142630) : const Color(0xFFF9FCFD),
          onSurface: dark ? const Color(0xFFF1F7F8) : const Color(0xFF14252C),
          onSurfaceVariant: dark
              ? const Color(0xFFB3C5CE)
              : const Color(0xFF50636D),
          outline: (dark ? Colors.white : const Color(0xFF29434D)).withValues(
            alpha: dark ? .28 : .3,
          ),
          outlineVariant: (dark ? Colors.white : const Color(0xFF29434D))
              .withValues(alpha: dark ? .14 : .16),
        );
    final fieldFill = dark
        ? Colors.white.withValues(alpha: .045)
        : Colors.white.withValues(alpha: .78);
    final fieldBorder = (dark ? Colors.white : const Color(0xFF38535E))
        .withValues(alpha: dark ? .17 : .2);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0A1721)
          : const Color(0xFFEDF3F5),
      canvasColor: dark ? const Color(0xFF0A1721) : const Color(0xFFEDF3F5),
      textTheme: (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark
            ? const Color(0xF0192B36)
            : const Color(0xFFF9FCFD),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark
            ? const Color(0xEE1A2C37)
            : const Color(0xFF20343C),
        contentTextStyle: const TextStyle(color: Color(0xFFF1F7F8)),
        actionTextColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackNest',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: _settings.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeInOutCubic,
      builder: (context, child) {
        final media = MediaQuery.maybeOf(context);
        if (media == null || child == null)
          return child ?? const SizedBox.shrink();
        return MediaQuery(
          data: media.copyWith(disableAnimations: _settings.reduceMotion),
          child: child,
        );
      },
      home: LibraryPage(
        repository: widget.repository,
        settings: _settings,
        onSettingsChanged: _updateSettings,
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    this.repository,
    this.settings = const AppSettings(),
    this.onSettingsChanged,
  });

  final PlaylistLinkRepository? repository;
  final AppSettings settings;
  final ValueChanged<AppSettings>? onSettingsChanged;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final ScrollController _scrollController = ScrollController();
  final LocalPlaybackController _playbackController = LocalPlaybackController();
  int _selectedSection = 0;

  bool get _hasWindowsMediaTools =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _playbackController.dispose();
    super.dispose();
  }

  void _selectSection(int index) {
    setState(() => _selectedSection = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  Future<void> _showSettings() => showDialog<void>(
    context: context,
    builder: (_) => TrackNestSettingsDialog(
      settings: widget.settings,
      onChanged: (settings) => widget.onSettingsChanged?.call(settings),
    ),
  );

  Future<void> _showSignIn() => showDialog<void>(
    context: context,
    builder: (_) => const TrackNestSignInDialog(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _hasWindowsMediaTools
          ? ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).width < 820 ? 196 : 112,
              ),
              child: LocalNowPlayingBar(controller: _playbackController),
            )
          : null,
      body: GlassBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 900;
              final content = _content(context, wide);
              if (!wide) return content;
              return Row(
                children: [
                  _SideRail(
                    selectedSection: _selectedSection,
                    onSelect: _selectSection,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool wide) {
    final horizontal = wide ? 42.0 : 20.0;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!wide) ...[
                    const Icon(Icons.graphic_eq),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TrackNest',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'by Kryozen',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ] else
                    Expanded(
                      child: Text(
                        const [
                          'Media tools',
                          'About the maker',
                          'Donations',
                        ][_selectedSection],
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  IconButton.filledTonal(
                    tooltip: 'Settings',
                    onPressed: _showSettings,
                    icon: const Icon(Icons.settings_rounded),
                  ),
                  const SizedBox(width: 10),
                  if (wide)
                    OutlinedButton.icon(
                      onPressed: _showSignIn,
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text('Sign in'),
                    )
                  else
                    IconButton(
                      tooltip: 'Sign in',
                      onPressed: _showSignIn,
                      icon: const Icon(Icons.person_outline_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Media tools'),
                    selected: _selectedSection == 0,
                    onSelected: (_) => _selectSection(0),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.person_outline_rounded, size: 18),
                    label: const Text('About the maker'),
                    selected: _selectedSection == 1,
                    onSelected: (_) => _selectSection(1),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.favorite_border_rounded, size: 18),
                    label: const Text('Donations'),
                    selected: _selectedSection == 2,
                    onSelected: (_) => _selectSection(2),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_selectedSection == 0) ...[
                GlassSurface(
                  tint: const Color(0xFF43D4BA),
                  padding: const EdgeInsets.all(22),
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRACKNEST MEDIA TOOLS',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Play, download, and convert media',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Play songs saved on your PC, download from supported media links, or convert files already on your device.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.windows) ...[
                  DirectMediaDownloader(
                    key: const ValueKey('direct-media-downloader'),
                  ),
                  const SizedBox(height: 18),
                  LocalMusicPlayer(controller: _playbackController),
                  const SizedBox(height: 18),
                  const _LocalAudioConverter(),
                  const SizedBox(height: 18),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showAppPolicies(context),
                    icon: const Icon(Icons.policy_outlined),
                    label: const Text('Privacy and terms'),
                  ),
                ),
              ],
              if (_selectedSection == 1)
                AboutMakerSection(onOpenLink: _openCreatorLink),
              if (_selectedSection == 2) const DonationsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreatorLink(Uri uri) async {
    final opened = await openExternalUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open that social profile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.selectedSection, required this.onSelect});

  final int selectedSection;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 230,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassSurface(
          radius: 26,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      child: const Icon(Icons.graphic_eq),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TrackNest',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'by Kryozen',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 44),
                _NavItem(
                  icon: Icons.tune_rounded,
                  label: 'Media tools',
                  selected: selectedSection == 0,
                  onTap: () => onSelect(0),
                ),
                const SizedBox(height: 8),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'About the maker',
                  selected: selectedSection == 1,
                  onTap: () => onSelect(1),
                ),
                const SizedBox(height: 8),
                _NavItem(
                  icon: Icons.favorite_border_rounded,
                  label: 'Donations',
                  selected: selectedSection == 2,
                  onTap: () => onSelect(2),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: .15) : null,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: colors.primary.withValues(alpha: .26))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 11),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAppPolicies(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _AppPoliciesDialog(),
);

class _AppPoliciesDialog extends StatelessWidget {
  const _AppPoliciesDialog();

  Future<void> _open(String url) async {
    await openExternalUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy and terms'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Privacy notice',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'On Windows, media links you submit are sent to the selected provider to retrieve the requested media. TrackNest saves downloads to the folder you choose. Files selected for local conversion are processed on this device and are not uploaded.',
              ),
              const SizedBox(height: 10),
              Text(
                'Terms of use',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'TrackNest plays local music, downloads media from supported links, and converts audio or video files already on this device.',
              ),
              TextButton(
                onPressed: () => _open('https://www.youtube.com/t/terms'),
                child: const Text('YouTube Terms of Service'),
              ),
              TextButton(
                onPressed: () => _open('https://developer.spotify.com/terms'),
                child: const Text('Spotify Developer Terms'),
              ),
              TextButton(
                onPressed: () => _open(
                  'https://developers.soundcloud.com/docs/api/terms-of-use',
                ),
                child: const Text('SoundCloud API Terms'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _LocalAudioConverter extends StatefulWidget {
  const _LocalAudioConverter();

  @override
  State<_LocalAudioConverter> createState() => _LocalAudioConverterState();
}

class _LocalAudioConverterState extends State<_LocalAudioConverter> {
  static const MethodChannel _channel = MethodChannel(
    'tracknest/audio_converter',
  );

  List<String> _files = [];
  String? _outputDirectory;
  bool _converting = false;
  int _bitrateKbps = 192;
  String? _message;
  bool _messageIsError = false;

  String _fileName(String path) {
    final separator = String.fromCharCode(92);
    return path.replaceAll('/', separator).split(separator).last;
  }

  Future<void> _chooseFiles() async {
    try {
      final files = await _channel.invokeListMethod<String>('selectAudioFiles');
      if (!mounted || files == null || files.isEmpty) return;
      setState(() {
        _files = files;
        _message = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message ?? 'Could not open the audio file picker.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _chooseOutputFolder() async {
    try {
      final folder = await _channel.invokeMethod<String>('selectOutputFolder');
      if (!mounted || folder == null || folder.isEmpty) return;
      setState(() {
        _outputDirectory = folder;
        _message = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message ?? 'Could not open the folder picker.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _convert() async {
    final directory = _outputDirectory;
    if (_files.isEmpty || directory == null) return;
    setState(() {
      _converting = true;
      _message = 'Converting selected files on this device…';
      _messageIsError = false;
    });

    try {
      final results = await _channel.invokeListMethod<Object?>('convertToMp3', {
        'inputPaths': _files,
        'outputDirectory': directory,
        'bitrateKbps': _bitrateKbps,
      });
      if (!mounted) return;
      final conversions = results ?? const <Object?>[];
      final converted = conversions
          .where((result) => result is Map && result['success'] == true)
          .length;
      final failed = conversions.length - converted;
      String? firstError;
      for (final result in conversions) {
        if (result is Map && result['success'] != true) {
          firstError = result['error']?.toString();
          break;
        }
      }
      final summary = failed == 0
          ? 'Converted $converted file(s). MP3 files are saved in the selected folder.'
          : firstError == null || firstError.isEmpty
          ? '$converted converted; $failed failed.'
          : '$converted converted; $failed failed. $firstError';
      setState(() {
        _message = summary;
        _messageIsError = converted == 0;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message ?? 'The conversion could not be started.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final names = _files.take(3).map(_fileName).join(', ');
    final remaining = _files.length - 3;
    final fileCount = _files.length;
    final fileSummary = _files.isEmpty
        ? 'No media files selected'
        : remaining > 0
        ? '$names and $remaining more'
        : names;

    return GlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      radius: 20,
      tint: const Color(0xFF82ACFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Convert local audio or video to MP3',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose audio or video files already on this device and a save folder. Playlist and watch-page links are not used for conversion.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Text(
            fileSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (_outputDirectory != null) ...[
            const SizedBox(height: 4),
            Text(
              'Save to: $_outputDirectory',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _converting ? null : _chooseFiles,
                icon: const Icon(Icons.audio_file_outlined),
                label: Text(
                  _files.isEmpty
                      ? 'Choose media files'
                      : '$fileCount files selected',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _converting ? null : _chooseOutputFolder,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Choose save folder'),
              ),
              DropdownButton<int>(
                value: _bitrateKbps,
                onChanged: _converting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _bitrateKbps = value);
                        }
                      },
                items: const [128, 192, 256, 320]
                    .map(
                      (bitrate) => DropdownMenuItem<int>(
                        value: bitrate,
                        child: Text('$bitrate kbps'),
                      ),
                    )
                    .toList(),
              ),
              FilledButton.icon(
                onPressed:
                    _converting || _files.isEmpty || _outputDirectory == null
                    ? null
                    : _convert,
                icon: const Icon(Icons.library_music_outlined),
                label: const Text('Convert to MP3'),
              ),
            ],
          ),
          if (_converting) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(
                color: _messageIsError ? colors.error : colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
