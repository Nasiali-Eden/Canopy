// lib/Community/Heritage/category_browse_screen.dart
//
// Phase 3 — generic "Show all" grid for cultural entries. One screen serves
// both a category (e.g. all Food in Kenya) and a community filter (e.g. all
// entries from the Luhya), driven entirely by HeritageDataService. Empty
// streams show a glass empty state; nothing is invented.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../Shared/theme/glass.dart';
import 'heritage_item_screen.dart';
import 'heritage_widgets.dart';

class HeritageBrowseScreen extends StatelessWidget {
  final String countryId;
  final String title;
  final String? subtitle;
  final Color accent;
  final IconData icon;

  /// Filter by content type (category browse) and/or community.
  final String? contentType;
  final String? communityId;

  /// Background node id (defaults to the country node).
  final String? bgNodeId;

  const HeritageBrowseScreen({
    super.key,
    required this.countryId,
    required this.title,
    required this.accent,
    required this.icon,
    this.subtitle,
    this.contentType,
    this.communityId,
    this.bgNodeId,
  });

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
            stream: service.streamNodeBg(bgNodeId ?? countryId),
            builder: (_, snap) =>
                GlassBackground(imageUrl: snap.data, tint: accent),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                Expanded(
                  child: StreamBuilder<List<HeritageItem>>(
                    stream: service.streamItems(
                      countryId: countryId,
                      contentType: contentType,
                      communityId: communityId,
                    ),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white70, strokeWidth: 2),
                        );
                      }
                      final items = snap.data ?? const <HeritageItem>[];
                      if (items.isEmpty) {
                        return GlassEmptyState(
                          icon: icon,
                          title: 'Nothing here yet',
                          message:
                              'No entries have been added here yet. Check back later.',
                        );
                      }
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) => HeritageItemCard(
                          item: items[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HeritageItemScreen(item: items[i]),
                            ),
                          ),
                        ),
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          if ((subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
