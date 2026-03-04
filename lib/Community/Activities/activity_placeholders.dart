import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Models/activity.dart';
import 'activity.dart';

/// Type-specific visual config used by both real cards and placeholders.
class ActivityTypeConfig {
  final Color color;
  final Color lightColor;
  final IconData icon;
  final List<Color> gradient;

  const ActivityTypeConfig({
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.gradient,
  });

  static ActivityTypeConfig forType(ActivityType type) {
    switch (type) {
      case ActivityType.cleanup:
        return ActivityTypeConfig(
          color: AppTheme.accent,
          lightColor: AppTheme.accent.withOpacity(0.12),
          icon: Icons.cleaning_services_outlined,
          gradient: [AppTheme.accent, const Color(0xFF2EBFA5)],
        );
      case ActivityType.event:
        return ActivityTypeConfig(
          color: AppTheme.tertiary,
          lightColor: AppTheme.tertiary.withOpacity(0.12),
          icon: Icons.celebration_outlined,
          gradient: [AppTheme.tertiary, const Color(0xFFE8A020)],
        );
      case ActivityType.task:
        return ActivityTypeConfig(
          color: AppTheme.secondary,
          lightColor: AppTheme.secondary.withOpacity(0.12),
          icon: Icons.task_alt_outlined,
          gradient: [AppTheme.secondary, AppTheme.primary],
        );
    }
  }

  static ActivityTypeConfig byIndex(int index) =>
      forType(ActivityType.values[index % ActivityType.values.length]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder data per card slot
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderData {
  final String imageUrl;
  final String title;
  final String location;
  final String date;
  final ActivityType type;
  final int participants;
  final int required;

  const _PlaceholderData({
    required this.imageUrl,
    required this.title,
    required this.location,
    required this.date,
    required this.type,
    required this.participants,
    required this.required,
  });
}

const List<_PlaceholderData> _placeholders = [
  _PlaceholderData(
    imageUrl:
        'https://images.unsplash.com/photo-1618477461853-cf6ed80faba5?w=800&auto=format&fit=crop',
    title: 'Nairobi River Cleanup Drive',
    location: 'Westlands, Nairobi',
    date: 'Sat 22 Feb · 7:00 AM',
    type: ActivityType.cleanup,
    participants: 14,
    required: 30,
  ),
  _PlaceholderData(
    imageUrl:
        'https://images.unsplash.com/photo-1561414927-6d86591d0c4f?w=800&auto=format&fit=crop',
    title: 'Community Tree Planting Festival',
    location: 'Karen, Nairobi',
    date: 'Sun 23 Feb · 9:00 AM',
    type: ActivityType.event,
    participants: 38,
    required: 50,
  ),
  _PlaceholderData(
    imageUrl:
        'https://images.unsplash.com/photo-1542601906897-ecd6e3a4d808?w=800&auto=format&fit=crop',
    title: 'Karura Forest Trail Restoration',
    location: 'Gigiri, Nairobi',
    date: 'Mon 24 Feb · 8:00 AM',
    type: ActivityType.task,
    participants: 7,
    required: 20,
  ),
  _PlaceholderData(
    imageUrl:
        'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=800&auto=format&fit=crop',
    title: 'Plastic-Free Kibera Campaign',
    location: 'Kibera, Nairobi',
    date: 'Tue 25 Feb · 6:30 AM',
    type: ActivityType.cleanup,
    participants: 21,
    required: 40,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class ActivityPlaceholders extends StatelessWidget {
  const ActivityPlaceholders({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        _placeholders.length,
        (i) => _PlaceholderCard(index: i),
      ),
    );
  }

  static Widget buildCard(BuildContext context, int index) =>
      _PlaceholderCard(index: index % _placeholders.length);
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE PLACEHOLDER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderCard extends StatefulWidget {
  final int index;
  const _PlaceholderCard({required this.index});

  @override
  State<_PlaceholderCard> createState() => _PlaceholderCardState();
}

class _PlaceholderCardState extends State<_PlaceholderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;
  late Animation<double> _anim;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _shimmer, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _placeholders[widget.index % _placeholders.length];
    final cfg = ActivityTypeConfig.forType(data.type);
    final pct = (data.participants / data.required).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmerOpacity = 0.04 + _anim.value * 0.06;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppTheme.lightGreen.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: cfg.color.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover image ─────────────────────────────────────────
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Shimmer base shown while image loads
                      if (!_imageLoaded)
                        AnimatedBuilder(
                          animation: _anim,
                          builder: (_, __) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  cfg.lightColor,
                                  cfg.color.withOpacity(
                                      0.06 + _anim.value * 0.08),
                                  cfg.lightColor,
                                ],
                                stops: [
                                  (_anim.value - 0.4).clamp(0.0, 1.0),
                                  _anim.value.clamp(0.0, 1.0),
                                  (_anim.value + 0.4).clamp(0.0, 1.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Real image
                      Image.network(
                        data.imageUrl,
                        fit: BoxFit.cover,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                          if (frame != null && !_imageLoaded) {
                            WidgetsBinding.instance.addPostFrameCallback(
                                (_) {
                              if (mounted) {
                                setState(() => _imageLoaded = true);
                              }
                            });
                          }
                          return AnimatedOpacity(
                            opacity: frame != null ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: child,
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: cfg.lightColor,
                          child: Center(
                            child: Icon(cfg.icon,
                                size: 36,
                                color: cfg.color.withOpacity(0.35)),
                          ),
                        ),
                      ),

                      // Gradient overlay for badge legibility
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 70,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Open badge — top left ────────────────────────
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('Open',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32))),
                            ],
                          ),
                        ),
                      ),

                      // ── Type badge — top right ───────────────────────
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: cfg.color.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cfg.icon,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                data.type.label,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Participant count — bottom left on image ──────
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: Row(children: [
                          _AvatarRow(color: cfg.color, onImage: true),
                          const SizedBox(width: 6),
                          Text(
                            '${data.participants} joined',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Card body ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),

                    // Location + date row
                    Row(children: [
                      _MetaChip(
                        icon: Icons.location_on_outlined,
                        label: data.location,
                        color: cfg.color,
                      ),
                      const SizedBox(width: 10),
                      _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: data.date,
                        color: AppTheme.primary,
                      ),
                    ]),

                    const SizedBox(height: 12),

                    // Progress bar + counts
                    Row(children: [
                      Text(
                        '${data.participants}/${data.required} participants',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cfg.color,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${data.required - data.participants} spots left',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: cfg.color.withOpacity(0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(cfg.color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color.withOpacity(0.75)),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.darkGreen.withOpacity(0.65),
        ),
      ),
    ]);
  }
}

class _AvatarRow extends StatelessWidget {
  final Color color;
  final bool onImage;
  const _AvatarRow({required this.color, this.onImage = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 22,
      child: Stack(
        children: List.generate(
          3,
          (i) => Positioned(
            left: i * 14.0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: onImage
                    ? Colors.white.withOpacity(0.3)
                    : color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: onImage ? Colors.white : Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}