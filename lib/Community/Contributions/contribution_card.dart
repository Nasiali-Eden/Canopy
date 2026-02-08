import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../Shared/theme/app_theme.dart';

class ContributionCard extends StatelessWidget {
  final Map<String, dynamic> contribution;

  const ContributionCard({
    super.key,
    required this.contribution,
  });

  @override
  Widget build(BuildContext context) {
    final workType = contribution['workType'] ?? 'Cleanup';
    final title = contribution['title'] ?? 'Untitled Contribution';
    final beforeImages = List<String>.from(contribution['beforeImages'] ?? []);
    final afterImages = List<String>.from(contribution['afterImages'] ?? []);
    final createdAt = contribution['createdAt'];
    final points = contribution['points'] ?? 0;

    final workTypeConfig = _getWorkTypeConfig(workType);

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to expanded view with all images from different months
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: workTypeConfig['gradient'] as LinearGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (workTypeConfig['color'] as Color).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and work type badge
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                workTypeConfig['icon'] as IconData,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                workType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.expand_more,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Swipeable image comparison section
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildImageComparisonColumn(
                    context,
                    beforeImages,
                    afterImages,
                  ),
                ],
              ),
            ),

            // Footer with date and points
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.eco,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$points pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageComparisonColumn(
    BuildContext context,
    List<String> beforeImages,
    List<String> afterImages,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Before images
        _buildImageRow(context, 'Before', beforeImages, true),
        const SizedBox(height: 12),
        // After images (or placeholder if none)
        if (afterImages.isNotEmpty)
          _buildImageRow(context, 'After', afterImages, false)
        else
          _buildEmptyAfterPlaceholder(context),
      ],
    );
  }

  Widget _buildImageRow(
    BuildContext context,
    String label,
    List<String> imageUrls,
    bool isBefore,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: imageUrls.take(4).map((url) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              width: 110,
              height: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.white.withOpacity(0.2),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.white.withOpacity(0.2),
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyAfterPlaceholder(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'After',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        CustomPaint(
          painter: DashedBorderPainter(
            color: Colors.white.withOpacity(0.3),
            strokeWidth: 1.5,
            dashWidth: 5,
            dashSpace: 3,
          ),
          child: Container(
            width: 340,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.update,
                    color: Colors.white.withOpacity(0.6),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update coming this month',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Recently';
    
    try {
      if (date is DateTime) {
        return DateFormat('MMM dd, yyyy').format(date);
      } else if (date is String) {
        final parsedDate = DateTime.parse(date);
        return DateFormat('MMM dd, yyyy').format(parsedDate);
      }
    } catch (e) {
      return 'Recently';
    }
    
    return 'Recently';
  }

  Map<String, dynamic> _getWorkTypeConfig(String workType) {
    switch (workType) {
      case 'Cleanup':
        return {
          'color': AppTheme.primary,
          'gradient': LinearGradient(
            colors: [AppTheme.primary, AppTheme.lightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'icon': Icons.cleaning_services,
        };
      case 'Tree Planting':
        return {
          'color': AppTheme.lightGreen,
          'gradient': LinearGradient(
            colors: [AppTheme.lightGreen, const Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'icon': Icons.park,
        };
      case 'School Upgrading':
        return {
          'color': AppTheme.tertiary,
          'gradient': LinearGradient(
            colors: [AppTheme.tertiary, const Color(0xFFFF6B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'icon': Icons.school,
        };
      case 'Waste Management':
        return {
          'color': const Color(0xFF9C27B0),
          'gradient': const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'icon': Icons.recycling,
        };
      case 'Water & Sanitation':
        return {
          'color': const Color(0xFF2196F3),
          'gradient': const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'icon': Icons.water_drop,
        };
      case 'Infrastructure':
        return {
          'color': const Color(0xFFFF9800),
          'gradient': const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'icon': Icons.construction,
        };
      default:
        return {
          'color': AppTheme.primary,
          'gradient': LinearGradient(
            colors: [AppTheme.primary, AppTheme.lightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'icon': Icons.volunteer_activism,
        };
    }
  }
}

/// Custom painter for dashed borders
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(8),
        ),
      );

    final dashPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final dest = Path();
    final metric = source.computeMetrics().first;
    double distance = 0.0;

    while (distance < metric.length) {
      final nextDash = distance + dashWidth;
      final nextSpace = nextDash + dashSpace;

      if (nextDash > metric.length) {
        dest.addPath(
          metric.extractPath(distance, metric.length),
          Offset.zero,
        );
        break;
      }

      dest.addPath(
        metric.extractPath(distance, nextDash),
        Offset.zero,
      );

      distance = nextSpace;
    }

    return dest;
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}