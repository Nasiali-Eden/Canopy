// lib/Organization/Explorer/programme_view_screen.dart
//
// Public, visual view of a single Programme — immersive cover + glass cards.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Models/programme.dart';
import 'view_commons.dart';

class ProgrammeViewScreen extends StatelessWidget {
  final Programme programme;
  final String orgName;
  final Color accent;

  const ProgrammeViewScreen({
    super.key,
    required this.programme,
    required this.orgName,
    this.accent = const Color(0xFF2D7A4F),
  });

  String _scheduleText() {
    final s = programme.schedule;
    if (s.isOnline) return 'Online · ${s.recurrence.label}';
    final loc = s.location;
    final place = loc == null
        ? ''
        : [loc.venue, loc.area, loc.city].where((e) => e.isNotEmpty).join(', ');
    if (place.isEmpty) return s.recurrence.label;
    return '$place · ${s.recurrence.label}';
  }

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0D),
      body: Stack(
        children: [
          ImmersiveBackground(imageUrl: p.coverImageUrl, tint: accent),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(context)),
                SliverToBoxAdapter(child: _metaCard()),
                if (p.description.isNotEmpty)
                  SliverToBoxAdapter(child: _aboutCard()),
                if (p.supportingImageUrls.isNotEmpty)
                  SliverToBoxAdapter(child: _gallery()),
                SliverToBoxAdapter(child: SizedBox(height: bottomPad + 110)),
              ],
            ),
          ),
          // Back
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: CircleGlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          // Bottom CTA
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomPad + 18,
            child: _ctaBar(context),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(p.type.label, accent),
              const SizedBox(width: 8),
              _pill(p.status.label, Colors.white.withOpacity(0.18)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            p.title,
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
            'by $orgName',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (p.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              p.summary,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Programme get p => programme;

  Widget _metaCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GlassCard(
        child: Row(
          children: [
            _metaItem(Icons.payments_outlined, 'Price', p.displayPrice),
            _divider(),
            _metaItem(Icons.schedule_outlined, 'Cadence',
                p.schedule.recurrence.label),
            _divider(),
            _metaItem(
              Icons.workspace_premium_outlined,
              'Certificate',
              p.details.certificateOffered ? 'Yes' : 'No',
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About this programme',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
            if (p.details.eligibility.isNotEmpty) ...[
              const SizedBox(height: 14),
              _infoRow(Icons.verified_user_outlined, 'Eligibility',
                  p.details.eligibility),
            ],
            if (p.details.duration.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.timelapse_outlined, 'Duration', p.details.duration),
            ],
            const SizedBox(height: 10),
            _infoRow(Icons.place_outlined, 'Where', _scheduleText()),
          ],
        ),
      ),
    );
  }

  Widget _gallery() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Gallery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: p.supportingImageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: p.supportingImageUrls[i],
                  width: 180,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 180,
                    color: Colors.white.withOpacity(0.06),
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaBar(BuildContext context) {
    final canEnquire = p.canEnquire;
    final hasLink = (p.contact.externalLink ?? '').isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(canEnquire
                      ? 'Enquiry flow coming soon'
                      : hasLink
                          ? 'Opening external link…'
                          : 'Details coming soon'),
                ),
              );
            },
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
              child: Center(
                child: Text(
                  canEnquire ? 'Enquire Now' : (hasLink ? 'Visit Link' : 'Learn More'),
                  style: const TextStyle(
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
        CircleGlassButton(icon: Icons.share_outlined, onTap: () {}, size: 54),
      ],
    );
  }

  // ── small helpers ──────────────────────────────────────────────────────────

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(color == Colors.white ? 1 : 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: Colors.white.withOpacity(0.12));

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 8),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
