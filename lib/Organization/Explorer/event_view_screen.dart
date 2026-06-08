// lib/Organization/Explorer/event_view_screen.dart
//
// Public, visual view of a single event (activities/{id}) — immersive style.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'view_commons.dart';

class EventViewScreen extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final String orgName;
  final Color accent;

  const EventViewScreen({
    super.key,
    required this.eventId,
    required this.data,
    required this.orgName,
    this.accent = const Color(0xFF2D7A4F),
  });

  // ── field extraction (tolerant of String|Map shapes) ────────────────────────

  String? get _cover {
    final imgs = data['images'];
    if (imgs is List) {
      for (final x in imgs) {
        if (x is String && x.isNotEmpty) return x;
      }
    }
    return data['coverImageUrl'] as String? ?? data['imageUrl'] as String?;
  }

  String get _title => data['name'] as String? ?? data['title'] as String? ?? 'Event';

  String get _locationText {
    final loc = data['location'];
    if (loc is String) return loc;
    if (loc is Map) {
      final m = loc.cast<String, dynamic>();
      return [m['venue'], m['area'], m['city']]
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    return '';
  }

  String _dateText() {
    final raw = data['date'] ?? data['dateTime'];
    if (raw is! Timestamp) return 'Date to be announced';
    final dt = raw.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final participants = (data['participants'] as num?)?.toInt() ??
        (data['participantIds'] as List?)?.length ??
        0;
    final maxP = (data['maxParticipants'] as num?)?.toInt() ??
        (data['requiredParticipants'] as num?)?.toInt() ??
        0;
    final pct = maxP > 0 ? (participants / maxP).clamp(0.0, 1.0) : 0.0;
    final bounty = (data['bountyAmount'] as num?)?.toDouble();
    final desc = data['description'] as String? ?? '';
    final status = (data['status'] as String? ?? 'upcoming');

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0D),
      body: Stack(
        children: [
          ImmersiveBackground(imageUrl: _cover, tint: accent),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status[0].toUpperCase() + status.substring(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hosted by $orgName',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Meta card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: GlassCard(
                      child: Column(
                        children: [
                          _row(Icons.calendar_today_outlined, _dateText()),
                          if (_locationText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _row(Icons.place_outlined, _locationText),
                          ],
                          const SizedBox(height: 14),
                          // Participation
                          Row(
                            children: [
                              Icon(Icons.groups_outlined,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.7)),
                              const SizedBox(width: 8),
                              Text(
                                '$participants${maxP > 0 ? ' / $maxP' : ''} joined',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              if (bounty != null && bounty > 0)
                                Text(
                                  'KES ${bounty.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: accent == Colors.white
                                        ? Colors.white
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                          if (maxP > 0) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 5,
                                backgroundColor: Colors.white.withOpacity(0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (desc.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'About this event',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              desc,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 13.5,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: bottomPad + 110)),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: CircleGlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomPad + 18,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Registration coming soon')),
                    ),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Join Event',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleGlassButton(
                    icon: Icons.share_outlined, onTap: () {}, size: 54),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
