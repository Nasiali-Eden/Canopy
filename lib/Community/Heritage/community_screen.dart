// lib/Community/Heritage/community_screen.dart
//
// Phase 3 — the "Communities" destination for a country. Lists the communities
// that actually have public entries (parity-safe; derived from entries by
// HeritageDataService), each opening a community-filtered browse. No hardcoded
// tribe list.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../Shared/theme/glass.dart';
import 'category_browse_screen.dart';

class CommunitiesListScreen extends StatelessWidget {
  final String countryId;
  final String countryName;

  const CommunitiesListScreen({
    super.key,
    required this.countryId,
    required this.countryName,
  });

  static const Color _accent = HeritageContentTypes.communitiesAccent;

  @override
  Widget build(BuildContext context) {
    final service = HeritageDataService();
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: GlassPalette.base,
      body: Stack(
        children: [
          StreamBuilder<String?>(
            stream: service.streamNodeBg(countryId),
            builder: (_, snap) =>
                GlassBackground(imageUrl: snap.data, tint: _accent),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accent.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.groups_outlined,
                            size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Communities',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4)),
                            Text(countryName,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<CommunitySummary>>(
                    stream: service.streamCommunitiesForCountry(countryId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white70, strokeWidth: 2),
                        );
                      }
                      final communities =
                          snap.data ?? const <CommunitySummary>[];
                      if (communities.isEmpty) {
                        return const GlassEmptyState(
                          icon: Icons.groups_outlined,
                          title: 'No communities yet',
                          message:
                              'Community entries will appear here as soon as they\'re added.',
                        );
                      }
                      return ListView.separated(
                        padding:
                            EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 24),
                        itemCount: communities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _CommunityRow(c: communities[i], onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HeritageBrowseScreen(
                                countryId: countryId,
                                communityId: communities[i].id,
                                title: communities[i].name,
                                subtitle: 'Community in $countryName',
                                accent: _accent,
                                icon: Icons.groups_outlined,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 16,
            child: CircleGlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  final CommunitySummary c;
  final VoidCallback onTap;
  const _CommunityRow({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CommunitiesListScreen._accent.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: CommunitiesListScreen._accent.withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${c.entryCount} ${c.entryCount == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: Colors.white.withOpacity(0.5), size: 22),
        ],
      ),
    );
  }
}
