import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../Shared/theme/app_theme.dart';

class ContributionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> contribution;
  const ContributionDetailSheet({super.key, required this.contribution});

  static Map<String, dynamic> _typeConfig(String type) {
    switch (type) {
      case 'Cleanup':
        return {'icon': Icons.cleaning_services, 'color': AppTheme.primary};
      case 'Tree Planting':
        return {'icon': Icons.park, 'color': AppTheme.lightGreen};
      case 'School Upgrading':
        return {'icon': Icons.school, 'color': AppTheme.tertiary};
      case 'Waste Management':
        return {'icon': Icons.recycling, 'color': const Color(0xFF9C27B0)};
      case 'Water & Sanitation':
        return {'icon': Icons.water_drop, 'color': const Color(0xFF2196F3)};
      case 'Infrastructure':
        return {'icon': Icons.construction, 'color': const Color(0xFFFF9800)};
      default:
        return {'icon': Icons.volunteer_activism, 'color': AppTheme.primary};
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = contribution['workType'] as String? ??
        contribution['type'] as String? ??
        'Other';
    final title = contribution['title'] as String? ?? 'Untitled';
    final description = contribution['description'] as String? ?? '';
    final locationName = contribution['locationName'] as String? ??
        contribution['location'] as String? ??
        '';
    final pointsEarned = contribution['pointsEarned'] as int? ??
        contribution['points'] as int? ??
        0;
    final status = contribution['status'] as String? ?? 'pending';
    final mediaUrls = List<String>.from(
        (contribution['mediaUrls'] as List?) ??
            (contribution['beforeImages'] as List?) ??
            []);
    final createdAt = contribution['createdAt'];

    final config = _typeConfig(type);
    final typeIcon = config['icon'] as IconData;
    final typeColor = config['color'] as Color;

    String formattedDate = '';
    if (createdAt is Timestamp) {
      formattedDate =
          DateFormat('dd MMM yyyy · HH:mm').format(createdAt.toDate());
    }

    final (statusColor, statusLabel) = switch (status) {
      'verified' => (Colors.green.shade600, 'Verified'),
      'rejected' => (Colors.red.shade600, 'Rejected'),
      _ => (Colors.amber.shade700, 'Pending'),
    };

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 14, color: typeColor),
                            const SizedBox(width: 6),
                            Text(type,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: typeColor,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            fontSize: 18,
                          )),
                  if (mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mediaUrls.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 10),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            mediaUrls[i],
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 140,
                              height: 140,
                              color: AppTheme.lightGreen.withOpacity(0.15),
                              child: Icon(Icons.broken_image_outlined,
                                  color: AppTheme.lightGreen),
                            ),
                            loadingBuilder: (_, child, prog) => prog == null
                                ? child
                                : Container(
                                    width: 140,
                                    height: 140,
                                    color:
                                        AppTheme.lightGreen.withOpacity(0.1),
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primary)),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (description.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 16, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        Text('Description',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkGreen.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.darkGreen.withOpacity(0.85),
                              height: 1.5,
                            )),
                    const SizedBox(height: 16),
                  ],
                  if (locationName.isNotEmpty) ...[
                    _DetailRow(
                        icon: Icons.location_on_outlined, text: locationName),
                    const SizedBox(height: 12),
                  ],
                  _DetailRow(
                    icon: Icons.eco_outlined,
                    text: '$pointsEarned points earned',
                    color: AppTheme.tertiary,
                  ),
                  if (formattedDate.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.access_time_outlined,
                        text: formattedDate),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _DetailRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.darkGreen.withOpacity(0.75);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 14,
                  color: c,
                  fontWeight:
                      color != null ? FontWeight.w600 : FontWeight.w400)),
        ),
      ],
    );
  }
}
