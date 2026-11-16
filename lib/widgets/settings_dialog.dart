import 'package:flutter/material.dart';

import '../data/app_settings_repository.dart';
import 'glowing_mouse_icon.dart';

class TrackNestSettingsDialog extends StatefulWidget {
  const TrackNestSettingsDialog({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<TrackNestSettingsDialog> createState() =>
      _TrackNestSettingsDialogState();
}

class _TrackNestSettingsDialogState extends State<TrackNestSettingsDialog> {
  late AppSettings _settings = widget.settings;

  void _update(AppSettings Function(AppSettings current) change) {
    final next = change(_settings);
    setState(() => _settings = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GlowingMouseIcon(size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Make TrackNest feel right for you.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close settings',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SettingsSectionLabel('APPEARANCE'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  _settings.darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                ),
                title: const Text('Dark mode'),
                subtitle: Text(
                  _settings.darkMode
                      ? 'Use the night palette'
                      : 'Use the light palette',
                ),
                value: _settings.darkMode,
                onChanged: (value) =>
                    _update((current) => current.copyWith(darkMode: value)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.motion_photos_off_rounded),
                title: const Text('Reduce motion'),
                subtitle: const Text('Shorten screen and theme animations'),
                value: _settings.reduceMotion,
                onChanged: (value) =>
                    _update((current) => current.copyWith(reduceMotion: value)),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _update((_) => const AppSettings()),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset to defaults'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 3),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
  );
}
