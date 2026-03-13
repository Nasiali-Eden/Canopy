import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/activity.dart' as ModelActivity;
import '../../Models/user.dart';
import '../../Services/Activities/activity_service.dart';
import '../theme/app_theme.dart';
import 'activity.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  int _activeImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    return FutureBuilder<Activity?>(
      future: ActivityService().getActivity(widget.activityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        final activity = snapshot.data;
        if (activity == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: const Text('Activity'),
            ),
            body: const Center(child: Text('Activity not found')),
          );
        }

        final cfg = ActivityTypeConfig.forType(activity.type);
        final joined =
            user != null && activity.participantIds.contains(user.uid);
        final slots = activity.gallerySlots; // always 4

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              // ── Hero image carousel ──────────────────────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: AppTheme.darkGreen),
                    ),
                  ),
                ),
                actions: [
                  // Registration state badge
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8),
                    child: _RegistrationBadge(state: activity.registrationState),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Paged image carousel
                      PageView.builder(
                        controller: _pageController,
                        itemCount: slots.length,
                        onPageChanged: (i) =>
                            setState(() => _activeImageIndex = i),
                        itemBuilder: (context, i) {
                          final url = slots[i];
                          return url != null
                              ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: cfg.lightColor,
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: cfg.color, strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) =>
                                _ImagePlaceholder(cfg: cfg),
                          )
                              : _ImagePlaceholder(cfg: cfg);
                        },
                      ),
                      // Bottom gradient for text legibility
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 90,
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
                      // Dot indicator
                      Positioned(
                        bottom: 14,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            slots.length,
                                (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _activeImageIndex == i ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _activeImageIndex == i
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Body ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + type chip
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              style: const TextStyle(
                                color: AppTheme.darkGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: cfg.lightColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: cfg.color.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cfg.icon, size: 12, color: cfg.color),
                                const SizedBox(width: 4),
                                Text(activity.type.label,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: cfg.color)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Image thumbnail strip ────────────────────────
                      _ThumbnailStrip(
                        slots: slots,
                        activeIndex: _activeImageIndex,
                        cfg: cfg,
                        onTap: (i) {
                          _pageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Location + Date info cards ───────────────────
                      Row(children: [
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.location_on_outlined,
                            color: AppTheme.accent,
                            label: 'Location',
                            value: activity.location.shortLabel,
                            sub: activity.location.venue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.calendar_today_outlined,
                            color: AppTheme.primary,
                            label: 'Date & Time',
                            value: activity.dateTime == null
                                ? 'TBD'
                                : _formatDate(activity.dateTime!),
                            sub: activity.dateTime == null
                                ? ''
                                : _formatTime(activity.dateTime!),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 10),

                      Row(children: [
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.people_outline,
                            color: AppTheme.secondary,
                            label: 'Participants',
                            value:
                            '${activity.currentParticipants} / ${activity.requiredParticipants}',
                            sub: activity.isFull ? 'Full' : 'Spots left',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.flag_outlined,
                            color: AppTheme.tertiary,
                            label: 'Status',
                            value: activity.status[0].toUpperCase() +
                                activity.status.substring(1),
                            sub: activity.registrationState.label,
                          ),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // ── Participant progress ─────────────────────────
                      _ParticipantProgress(activity: activity, cfg: cfg),

                      const SizedBox(height: 24),

                      // ── About ────────────────────────────────────────
                      _SectionLabel(
                          icon: Icons.info_outline,
                          label: 'About',
                          color: AppTheme.primary),
                      const SizedBox(height: 10),
                      Text(
                        activity.description,
                        style: TextStyle(
                          color: AppTheme.darkGreen.withOpacity(0.75),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Map placeholder ──────────────────────────────
                      _SectionLabel(
                          icon: Icons.map_outlined,
                          label: 'Location',
                          color: AppTheme.accent),
                      const SizedBox(height: 10),
                      _MapTile(
                          location: activity.location, color: AppTheme.accent),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom action bar ────────────────────────────────────────
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: _BottomAction(
              user: user,
              activity: activity,
              activityId: widget.activityId,
              joined: joined,
              cfg: cfg,
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
    final bg = isOpen ? const Color(0xFFE8F5E9) : Colors.red.shade50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(state.label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE PLACEHOLDER TILE
// ─────────────────────────────────────────────────────────────────────────────
class _ImagePlaceholder extends StatelessWidget {
  final ActivityTypeConfig cfg;
  const _ImagePlaceholder({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cfg.lightColor,
      child: Center(
        child: Icon(cfg.icon, size: 48, color: cfg.color.withOpacity(0.35)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THUMBNAIL STRIP (4 thumbnails)
// ─────────────────────────────────────────────────────────────────────────────
class _ThumbnailStrip extends StatelessWidget {
  final List<String?> slots;
  final int activeIndex;
  final ActivityTypeConfig cfg;
  final ValueChanged<int> onTap;

  const _ThumbnailStrip({
    required this.slots,
    required this.activeIndex,
    required this.cfg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: List.generate(slots.length, (i) {
          final url = slots[i];
          final isActive = i == activeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i < slots.length - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? cfg.color : Colors.transparent,
                    width: isActive ? 2 : 0,
                  ),
                  boxShadow: isActive
                      ? [
                    BoxShadow(
                        color: cfg.color.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: url != null
                      ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: cfg.lightColor),
                    errorWidget: (_, __, ___) =>
                        Container(color: cfg.lightColor,
                            child: Icon(cfg.icon,
                                size: 18,
                                color: cfg.color.withOpacity(0.4))),
                  )
                      : Container(
                    color: cfg.lightColor,
                    child: Icon(cfg.icon,
                        size: 20, color: cfg.color.withOpacity(0.35)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (sub.isNotEmpty)
              Text(sub,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.black38,
                      fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICIPANT PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ParticipantProgress extends StatelessWidget {
  final Activity activity;
  final ActivityTypeConfig cfg;
  const _ParticipantProgress(
      {required this.activity, required this.cfg});

  @override
  Widget build(BuildContext context) {
    final pct = activity.requiredParticipants > 0
        ? (activity.currentParticipants / activity.requiredParticipants)
        .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.group_outlined, size: 15, color: cfg.color),
          const SizedBox(width: 6),
          Text("Who's Joining",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cfg.color)),
          const Spacer(),
          Text(
            '${activity.currentParticipants} of ${activity.requiredParticipants}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: cfg.color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(cfg.color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          activity.isFull
              ? 'Activity is full'
              : '${activity.requiredParticipants - activity.currentParticipants} spots remaining',
          style: TextStyle(fontSize: 11, color: Colors.black38),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: color.withOpacity(0.12))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP TILE PLACEHOLDER (until real map integration)
// ─────────────────────────────────────────────────────────────────────────────
class _MapTile extends StatelessWidget {
  final ActivityLocation location;
  final Color color;
  const _MapTile({required this.location, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Icon(Icons.place, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(location.area,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen)),
                ]),
                const SizedBox(height: 4),
                Text(location.city,
                    style: TextStyle(
                        fontSize: 12, color: Colors.black45)),
                if (location.venue.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(location.venue,
                      style: TextStyle(
                          fontSize: 11,
                          color: color.withOpacity(0.8),
                          fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.my_location, size: 10, color: Colors.black26),
                  const SizedBox(width: 4),
                  Text(
                    '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.black38),
                  ),
                ]),
              ],
            ),
          ),
        ),
        Container(
          width: 100,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(13)),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.map_outlined, size: 32, color: color.withOpacity(0.5)),
            const SizedBox(height: 6),
            Text('View Map',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM ACTION
// ─────────────────────────────────────────────────────────────────────────────
class _BottomAction extends StatelessWidget {
  final F_User? user;
  final Activity activity;
  final String activityId;
  final bool joined;
  final ActivityTypeConfig cfg;

  const _BottomAction({
    required this.user,
    required this.activity,
    required this.activityId,
    required this.joined,
    required this.cfg,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return _GradientButton(
        label: 'Sign In to Join',
        icon: Icons.login,
        gradient: LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary]),
        onPressed: () =>
            Navigator.pushReplacementNamed(context, '/welcome'),
      );
    }

    if (joined) {
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await ActivityService().leaveActivity(
                  activityId: activityId, userId: user!.uid);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.exit_to_app, size: 16),
            label: const Text('Leave'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade300),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _GradientButton(
            label: 'Check In',
            icon: Icons.qr_code_scanner,
            gradient: LinearGradient(
                colors: [cfg.color, cfg.gradient.last]),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Check-in coming soon')),
            ),
          ),
        ),
      ]);
    }

    // Closed / full
    if (!activity.isOpen || activity.isFull) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            activity.isOpen ? 'Activity is Full' : 'Registration Closed',
            style: TextStyle(
                color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return _GradientButton(
      label: 'Join Activity',
      icon: cfg.icon,
      gradient: LinearGradient(
          colors: [AppTheme.darkGreen, cfg.color],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight),
      onPressed: () async {
        await ActivityService()
            .joinActivity(activityId: activityId, userId: user!.uid);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE CONFIG — exposed so list screen / placeholders can reuse
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