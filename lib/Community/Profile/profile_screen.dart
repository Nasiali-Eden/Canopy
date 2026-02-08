import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Authentication/auth.dart';
import '../../Services/Impact/impact_service.dart';
import '../../Services/Profile/profile_service.dart';
import '../../Shared/Pages/login.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    return StreamBuilder<ProfileData>(
      stream: ProfileService().watchProfile(userId: user!.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: (profile?.photoUrl == null ||
                              (profile?.photoUrl ?? '').isEmpty)
                          ? null
                          : CachedNetworkImageProvider(profile!.photoUrl!),
                      child: (profile?.photoUrl == null ||
                              (profile?.photoUrl ?? '').isEmpty)
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (profile?.name ?? '').isEmpty
                                ? 'Community Member'
                                : profile!.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (profile?.location ?? '').isEmpty
                                ? 'Location not set'
                                : profile!.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: ImpactService().watchUserImpactPoints(userId: user!.uid),
              builder: (context, snapshot) {
                final points = snapshot.data ?? 0;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bolt_outlined),
                    title: const Text('Impact Points'),
                    subtitle: Text('$points total points'),
                    onTap: () => Navigator.pushNamed(context, '/impact'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: const Text('Badges'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.pushNamed(context, '/recognition/badges'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.favorite_outline),
                    title: const Text('Acknowledgements'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                        context, '/recognition/acknowledgements'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('Announcements'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/announcements'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
