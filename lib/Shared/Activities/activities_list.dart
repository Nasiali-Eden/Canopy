import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'activity.dart';
import 'activity_placeholders.dart';
import '../../../Models/user.dart';
import '../../../Services/Activities/activity_service.dart';
import '../../../Services/Community/community_service.dart';
import '../../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CONFIG
// ─────────────────────────────────────────────────────────────────────────────

class _FilterOption {
  final String label;
  final IconData icon;
  final Color color;

  const _FilterOption(
      {required this.label, required this.icon, required this.color});
}

const List<_FilterOption> _filters = [
  _FilterOption(
      label: 'All', icon: Icons.grid_view_rounded, color: AppTheme.primary),
  _FilterOption(
      label: 'Cleanup',
      icon: Icons.cleaning_services_outlined,
      color: AppTheme.accent),
  _FilterOption(
      label: 'Event',
      icon: Icons.celebration_outlined,
      color: AppTheme.tertiary),
  _FilterOption(
      label: 'Task', icon: Icons.task_alt_outlined, color: AppTheme.secondary),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ActivitiesListScreen extends StatefulWidget {
  final bool embedded;
  const ActivitiesListScreen({super.key, this.embedded = false});

  @override
  State<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'All';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this)
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _setFilter(String f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _fadeController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter bar ──────────────────────────────────────────────
        _FilterBar(selected: _filter, onSelect: _setFilter),

        // ── List ────────────────────────────────────────────────────
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: StreamBuilder<List<Activity>>(
              stream: ActivityService().watchActivities(type: _filter),
              builder: (context, snapshot) {
                // Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingState();
                }

                final activities = snapshot.data ?? const [];

                // Empty — show styled placeholders
                if (activities.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _EmptyBanner(filter: _filter),
                      const SizedBox(height: 16),
                      const ActivityPlaceholders(),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: activities.length,
                  itemBuilder: (context, i) => _ActivityCard(
                    activity: activities[i],
                    index: i,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('Activities',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () => _setFilter('All'),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.filter_list_rounded,
                  size: 18, color: AppTheme.darkGreen),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
        ),
      ),
      floatingActionButton: _OrganizerFab(user: user),
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: _filters.map((f) {
          final isSelected = selected == f.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(f.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? f.color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? f.color
                        : AppTheme.lightGreen.withOpacity(0.3),
                    width: isSelected ? 0 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: f.color.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.icon,
                      size: 14,
                      color:
                          isSelected ? Colors.white : f.color.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.darkGreen.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final int index;

  const _ActivityCard({required this.activity, required this.index});

  Color get _statusColor {
    switch (activity.status.toLowerCase()) {
      case 'ongoing':
        return AppTheme.accent;
      case 'completed':
        return AppTheme.tertiary;
      default:
        return AppTheme.secondary;
    }
  }

  String get _statusLabel {
    final s = activity.status;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ActivityTypeConfig.forType(activity.type);
    final pct = activity.requiredParticipants > 0
        ? (activity.currentParticipants / activity.requiredParticipants)
            .clamp(0.0, 1.0)
        : 0.0;
    final coverUrl = activity.images.isNotEmpty ? activity.images.first : null;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/activities/${activity.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: cfg.color.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover image ──────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image or placeholder
                    coverUrl != null
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _CoverPlaceholder(cfg: cfg),
                            loadingBuilder: (_, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _CoverPlaceholder(cfg: cfg);
                            },
                          )
                        : _CoverPlaceholder(cfg: cfg),

                    // Bottom scrim
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Registration badge — top left
                    Positioned(
                      top: 10,
                      left: 10,
                      child:
                          _RegistrationBadge(state: activity.registrationState),
                    ),

                    // Type badge — top right
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
                            Icon(cfg.icon, size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(activity.type.label,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                    // Participant count — bottom left
                    Positioned(
                      bottom: 9,
                      left: 12,
                      child: Row(children: [
                        const Icon(Icons.people_outline,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.currentParticipants} joined',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ]),
                    ),

                    // Status dot — bottom right
                    Positioned(
                      bottom: 9,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(_statusLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Card body ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    activity.title,
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
                      label: activity.location.shortLabel,
                      color: cfg.color,
                    ),
                    const SizedBox(width: 12),
                    _MetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: activity.dateTime == null
                          ? 'Date TBD'
                          : _formatDate(activity.dateTime!),
                      color: AppTheme.primary,
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // Participant progress
                  Row(children: [
                    Text(
                      '${activity.currentParticipants}/${activity.requiredParticipants}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cfg.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('participants',
                        style: TextStyle(fontSize: 11, color: Colors.black38)),
                    const Spacer(),
                    Text(
                      activity.isFull
                          ? 'Full'
                          : '${activity.requiredParticipants - activity.currentParticipants} spots left',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: activity.isFull
                              ? Colors.red.shade400
                              : Colors.black38),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: cfg.color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(cfg.color),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // View details row
                  Row(children: [
                    // Venue pill
                    if (activity.location.venue.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_outlined,
                                size: 11,
                                color: AppTheme.darkGreen.withOpacity(0.55)),
                            const SizedBox(width: 3),
                            Text(activity.location.venue,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.darkGreen.withOpacity(0.6),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // CTA button
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                          context, '/activities/${activity.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.darkGreen,
                              cfg.color,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: cfg.color.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('View',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 11, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COVER PLACEHOLDER (when no image)
// ─────────────────────────────────────────────────────────────────────────────

class _CoverPlaceholder extends StatelessWidget {
  final ActivityTypeConfig cfg;
  const _CoverPlaceholder({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cfg.lightColor,
      child: Center(
        child: Icon(cfg.icon, size: 40, color: cfg.color.withOpacity(0.3)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META CHIP
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
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.darkGreen.withOpacity(0.6)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRATION BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _RegistrationBadge extends StatelessWidget {
  final RegistrationState state;
  const _RegistrationBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final isOpen = state == RegistrationState.open;
    final color = isOpen ? const Color(0xFF2E7D32) : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          isOpen ? 'Open' : 'Closed',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY BANNER (shown above placeholders when no real data)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyBanner extends StatelessWidget {
  final String filter;
  const _EmptyBanner({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isFiltered = filter != 'All';
    final filterCfg = isFiltered
        ? _filters.firstWhere((f) => f.label == filter,
            orElse: () => _filters.first)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (filterCfg?.color ?? AppTheme.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isFiltered ? filterCfg!.icon : Icons.event_note_outlined,
            size: 22,
            color: filterCfg?.color ?? AppTheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFiltered
                    ? 'No ${filter.toLowerCase()} activities yet'
                    : 'No activities yet',
                style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                isFiltered
                    ? 'Be the first to create a ${filter.toLowerCase()} activity.'
                    : 'Activities will appear here once added by organizers.',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING STATE
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [ActivityPlaceholders()],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORGANIZER FAB
// ─────────────────────────────────────────────────────────────────────────────

class _OrganizerFab extends StatelessWidget {
  final F_User? user;
  const _OrganizerFab({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<String?>(
      future: CommunityService().getUserRole(userId: user!.uid),
      builder: (context, snapshot) {
        if (snapshot.data?.toLowerCase() != 'organizer') {
          return const SizedBox.shrink();
        }
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.darkGreen, AppTheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.pushNamed(context, '/activities/create'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('New Activity',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TYPE CONFIG
// ─────────────────────────────────────────────────────────────────────────────

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
          lightColor: AppTheme.accent.withOpacity(0.1),
          icon: Icons.cleaning_services_outlined,
          gradient: [AppTheme.accent, const Color(0xFF2EBFA5)],
        );
      case ActivityType.event:
        return ActivityTypeConfig(
          color: AppTheme.tertiary,
          lightColor: AppTheme.tertiary.withOpacity(0.1),
          icon: Icons.celebration_outlined,
          gradient: [AppTheme.tertiary, const Color(0xFFE8A020)],
        );
      case ActivityType.task:
        return ActivityTypeConfig(
          color: AppTheme.secondary,
          lightColor: AppTheme.secondary.withOpacity(0.1),
          icon: Icons.task_alt_outlined,
          gradient: [AppTheme.secondary, AppTheme.primary],
        );
    }
  }
}
