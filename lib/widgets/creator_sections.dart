import 'package:flutter/material.dart';

import 'glass_surface.dart';

class AboutMakerSection extends StatelessWidget {
  const AboutMakerSection({super.key, required this.onOpenLink});

  final Future<void> Function(Uri uri) onOpenLink;

  static const _profiles =
      <({String name, String handle, String url, IconData icon})>[
        (
          name: 'YouTube',
          handle: '@Kryozen_24',
          url: 'https://www.youtube.com/@Kryozen_24',
          icon: Icons.play_circle_outline_rounded,
        ),
        (
          name: 'Instagram',
          handle: 'yougotgames.on.yo.phone',
          url: 'https://www.instagram.com/yougotgames.on.yo.phone/',
          icon: Icons.camera_alt_outlined,
        ),
        (
          name: 'Discord',
          handle: '741339338524196976',
          url: 'https://discord.com/users/741339338524196976',
          icon: Icons.forum_outlined,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT THE MAKER',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.primary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Made by Kryozen.',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'TrackNest lets you play songs saved on your PC, download media from supported links, and convert files on your device.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: colors.onSurfaceVariant, height: 1.6),
        ),
        const SizedBox(height: 22),
        GlassSurface(
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primary.withValues(alpha: .16),
                  foregroundColor: colors.primary,
                  child: const Text(
                    'K',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kryozen',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'The maker behind TrackNest',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.graphic_eq_rounded, color: colors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Find Kryozen online',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth < 580
                ? box.maxWidth
                : (box.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final profile in _profiles)
                  SizedBox(
                    width: width,
                    child: GlassSurface(
                      radius: 18,
                      child: ListTile(
                        leading: Icon(profile.icon, color: colors.primary),
                        title: Text(profile.name),
                        subtitle: Text(profile.handle),
                        trailing: const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                        ),
                        onTap: () => onOpenLink(Uri.parse(profile.url)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class DonationsSection extends StatelessWidget {
  const DonationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUPPORT THE PROJECT',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.primary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Donations',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        GlassSurface(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_rounded, color: colors.primary, size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support TrackNest',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thanks for checking out the app. Donation options will be added here soon.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Chip(
                        avatar: Icon(
                          Icons.schedule_rounded,
                          color: colors.primary,
                        ),
                        label: const Text('Donation links coming soon'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
