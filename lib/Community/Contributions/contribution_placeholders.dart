import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class ContributionPlaceholders {
  static Widget buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_outlined,
              size: 60,
              color: AppTheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Contributions Yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start making a difference in your community.\nLog your first contribution today!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.darkGreen.withOpacity(0.6),
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.lightGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Log Contribution',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildPlaceholderCard(BuildContext context, int index) {
    final placeholderData = _getPlaceholderData(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: placeholderData['gradient'] as LinearGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (placeholderData['color'] as Color).withOpacity(0.3),
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
                        placeholderData['title'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
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
                              placeholderData['icon'] as IconData,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              placeholderData['workType'] as String,
                              style: TextStyle(
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
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Image comparison section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Before images
                _buildPlaceholderImageRow(
                  context,
                  'Before',
                  placeholderData['beforeImages'] as List<String>,
                ),
                const SizedBox(height: 12),
                // After images
                _buildPlaceholderImageRow(
                  context,
                  'After',
                  placeholderData['afterImages'] as List<String>,
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
                  placeholderData['date'] as String,
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
                      Icon(
                        Icons.eco,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${placeholderData['points']} pts',
                        style: TextStyle(
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
    );
  }

  static Widget _buildPlaceholderImageRow(
    BuildContext context,
    String label,
    List<String> imageUrls,
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
          children: List.generate(
            imageUrls.length,
            (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(
                    right: index < imageUrls.length - 1 ? 8 : 0),
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.white.withOpacity(0.15),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.white.withOpacity(0.5),
                          size: 32,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.white.withOpacity(0.15),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withOpacity(0.7),
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Map<String, dynamic> _getPlaceholderData(int index) {
    final placeholders = [
      {
        'title': 'Kibera Street Cleanup Initiative',
        'workType': 'Cleanup',
        'icon': Icons.cleaning_services,
        'color': AppTheme.primary,
        'gradient': LinearGradient(
          colors: [AppTheme.primary, AppTheme.lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'beforeImages': [
          'https://images.unsplash.com/photo-1611284446314-60a58ac0deb9?w=400',
          'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400',
          'https://images.unsplash.com/photo-1531746790731-6c087fecd65b?w=400',
        ],
        'afterImages': [
          'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400',
          'https://images.unsplash.com/photo-1560264280-88b68371db39?w=400',
          'https://images.unsplash.com/photo-1589758438368-0ad531db3366?w=400',
        ],
        'date': 'Jan 15, 2025',
        'points': 125,
      },
      {
        'title': 'Mathare Green Spaces Project',
        'workType': 'Tree Planting',
        'icon': Icons.park,
        'color': AppTheme.lightGreen,
        'gradient': LinearGradient(
          colors: [AppTheme.lightGreen, Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'beforeImages': [
          'https://images.unsplash.com/photo-1611273426858-450d8e3c9fce?w=400',
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
          'https://images.unsplash.com/photo-1586773860418-d37222d8fce3?w=400',
        ],
        'afterImages': [
          'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?w=400',
        ],
        'date': 'Jan 12, 2025',
        'points': 150,
      },
      {
        'title': 'Community School Renovation',
        'workType': 'School Upgrading',
        'icon': Icons.school,
        'color': AppTheme.tertiary,
        'gradient': LinearGradient(
          colors: [AppTheme.tertiary, Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'beforeImages': [
          'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=400',
          'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=400',
          'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=400',
        ],
        'afterImages': [
          'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=400',
          'https://images.unsplash.com/photo-1571260899304-425eee4c7efc?w=400',
          'https://images.unsplash.com/photo-1580537659466-0a9bfa916a54?w=400',
        ],
        'date': 'Jan 10, 2025',
        'points': 200,
      },
    ];

    return placeholders[index % placeholders.length];
  }
}
