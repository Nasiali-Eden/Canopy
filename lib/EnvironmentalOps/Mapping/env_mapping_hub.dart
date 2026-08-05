import 'package:flutter/material.dart';

import '../../Organization/Map/org_map_ops.dart';
import '../../Shared/theme/app_theme.dart';
import 'mapped_site_catalog.dart';

class EnvMappingHubScreen extends StatelessWidget {
  final Map<String, dynamic> orgData;
  final VoidCallback? onOpenCollectionZones;

  const EnvMappingHubScreen({
    super.key,
    required this.orgData,
    this.onOpenCollectionZones,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Mapping Hub',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF173728),
                  Color(0xFF2D7A4F),
                  Color(0xFF96BE95),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Map More Than Zones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Environmental operations often span dumpsites, collection points, scrap-buying partners, sorting hubs, and tree sites. This hub keeps those surfaces organized.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'BOUNDARIES',
            subtitle: 'Collection zones remain a polygon workflow because they describe territory, not a single point.',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              onOpenCollectionZones?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.polyline_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collection Zones',
                          style: TextStyle(
                            color: AppTheme.darkGreen,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Open Territory to walk, trace, and save polygon coverage areas.',
                          style: TextStyle(
                            color: AppTheme.darkGreen,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'SITE TYPES',
            subtitle: 'Point-based environmental sites you can start mapping now.',
          ),
          const SizedBox(height: 12),
          ...envMappedSiteDefinitions.map(
            (definition) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MappingTypeCard(
                definition: definition,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrgMapOpsScreen(
                        orgData: orgData,
                        initialPinTypeId: definition.orgMapPinTypeId,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.46),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.6),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MappingTypeCard extends StatelessWidget {
  final EnvMappedSiteDefinition definition;
  final VoidCallback onTap;

  const _MappingTypeCard({
    required this.definition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: definition.color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: definition.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(definition.icon, color: definition.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.title,
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    definition.subtitle,
                    style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.66),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    definition.workflowNote,
                    style: TextStyle(
                      color: definition.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: definition.color),
          ],
        ),
      ),
    );
  }
}
