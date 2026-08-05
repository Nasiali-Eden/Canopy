import 'package:flutter/material.dart';

enum EnvMappedSiteType {
  dumpsite,
  collectionSite,
  scrapBuyingSite,
  recyclingDropoff,
  sortingHub,
  treeSite,
  cleanupEvent,
}

enum EnvMappingGeometry {
  pin,
  polygon,
}

class EnvMappedSiteDefinition {
  final EnvMappedSiteType type;
  final String title;
  final String subtitle;
  final String workflowNote;
  final IconData icon;
  final Color color;
  final EnvMappingGeometry geometry;
  final String orgMapPinTypeId;

  const EnvMappedSiteDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.workflowNote,
    required this.icon,
    required this.color,
    required this.geometry,
    required this.orgMapPinTypeId,
  });
}

const envMappedSiteDefinitions = <EnvMappedSiteDefinition>[
  EnvMappedSiteDefinition(
    type: EnvMappedSiteType.dumpsite,
    title: 'Dumpsites',
    subtitle: 'Track active, cleared, or monitored dumping grounds.',
    workflowNote: 'Use for rehabilitation, transformation, and follow-up proof.',
    icon: Icons.delete_outline,
    color: Color(0xFFE05C45),
    geometry: EnvMappingGeometry.pin,
    orgMapPinTypeId: 'dumpsite',
  ),
  EnvMappedSiteDefinition(
    type: EnvMappedSiteType.collectionSite,
    title: 'Collection Sites',
    subtitle: 'Map household or community collection points.',
    workflowNote: 'Best for neighborhood pickup, aggregation, and tagging.',
    icon: Icons.location_on_outlined,
    color: Color(0xFF2D7A4F),
    geometry: EnvMappingGeometry.pin,
    orgMapPinTypeId: 'collection_site',
  ),
  EnvMappedSiteDefinition(
    type: EnvMappedSiteType.scrapBuyingSite,
    title: 'Scrap Buying Sites',
    subtitle: 'Tag partner yards and buy-back locations.',
    workflowNote: 'Useful for tracing material flow into recovery markets.',
    icon: Icons.point_of_sale_outlined,
    color: Color(0xFF8B5E34),
    geometry: EnvMappingGeometry.pin,
    orgMapPinTypeId: 'scrap_buying_site',
  ),
  EnvMappedSiteDefinition(
    type: EnvMappedSiteType.recyclingDropoff,
    title: 'Recycling Drop-Offs',
    subtitle: 'Mark public-facing drop-off or offload points.',
    workflowNote: 'Use for community delivery or low-touch collection intake.',
    icon: Icons.recycling,
    color: Color(0xFF3C8D5B),
    geometry: EnvMappingGeometry.pin,
    orgMapPinTypeId: 'recycling_dropoff',
  ),
  EnvMappedSiteDefinition(
    type: EnvMappedSiteType.sortingHub,
    title: 'Sorting Hubs',
    subtitle: 'Capture sorting, baling, and staging hubs.',
    workflowNote: 'Helpful when one org manages multiple processing touchpoints.',
    icon: Icons.warehouse_outlined,
    color: Color(0xFF4B6A88),
    geometry: EnvMappingGeometry.pin,
    orgMapPinTypeId: 'sorting_hub',
  ),
  EnvMappedSiteDefinition(
    type: EnvMappedSiteType.treeSite,
    title: 'Tree Sites',
    subtitle: 'Map planting or long-term stewardship locations.',
    workflowNote: 'Use alongside the tree verification trail.',
    icon: Icons.park_outlined,
    color: Color(0xFF3A7D44),
    geometry: EnvMappingGeometry.pin,
    orgMapPinTypeId: 'tree_site',
  ),
  EnvMappedSiteDefinition(
    type: EnvMappedSiteType.cleanupEvent,
    title: 'Cleanup Event Sites',
    subtitle: 'Log short-lived cleanup activation points.',
    workflowNote: 'Useful for campaign tracking and volunteer field events.',
    icon: Icons.cleaning_services_outlined,
    color: Color(0xFF167C80),
    geometry: EnvMappingGeometry.pin,
    orgMapPinTypeId: 'cleanup_event',
  ),
];
