import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../Models/programme.dart';
import '../../../Shared/theme/app_theme.dart';
import 'programme_enquiry_sheet.dart';

const _kBg = Color(0xFFF7F5F0);

// ─────────────────────────────────────────────────────────────────────────────
// Programme Detail — reader-facing view
// ─────────────────────────────────────────────────────────────────────────────

class ProgrammeDetail extends StatefulWidget {
  final Programme programme;

  /// Organisation display name — shown in the org identity line at the bottom.
  final String orgName;

  const ProgrammeDetail({
    super.key,
    required this.programme,
    required this.orgName,
  });

  @override
  State<ProgrammeDetail> createState() => _ProgrammeDetailState();
}

class _ProgrammeDetailState extends State<ProgrammeDetail> {
  int _galleryIndex = 0;

  Programme get p => widget.programme;

  List<String?> get _images => p.gallerySlots;

  void _openEnquiry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProgrammeEnquirySheet(programme: p),
    );
  }

  void _openLink() {
    final link = p.contact.externalLink;
    if (link == null || link.isEmpty) return;
    // Copy link to clipboard and show a confirmation — add url_launcher to
    // pubspec.yaml to enable direct browser launch.
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied: $link'),
        backgroundColor: AppTheme.darkGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // ── Cover image SliverAppBar ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppTheme.darkGreen,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _images[_galleryIndex] != null
                  ? Image.network(
                      _images[_galleryIndex]!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(),
                    )
                  : _coverPlaceholder(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gallery strip (supporting images)
                  if (_images.where((u) => u != null).length > 1) ...[
                    _galleryStrip(),
                    const SizedBox(height: 20),
                  ],

                  // Type chip + price
                  Row(
                    children: [
                      _Chip(
                        label: p.type.label,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: p.displayPrice,
                        color: p.isPaid
                            ? AppTheme.tertiary
                            : p.isVolunteer
                                ? AppTheme.accent
                                : AppTheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (p.description.isNotEmpty) ...[
                    Text(
                      p.description,
                      style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.darkGreen.withOpacity(0.75),
                          height: 1.6),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Schedule / details block
                  _detailsBlock(),
                  const SizedBox(height: 24),

                  // Org identity line
                  _orgLine(),
                  const SizedBox(height: 28),

                  // CTAs
                  _ctaBlock(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gallery strip ──────────────────────────────────────────────────────────

  Widget _galleryStrip() {
    final visible =
        _images.where((u) => u != null).toList();
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        itemBuilder: (ctx, i) {
          final selected = _galleryIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _galleryIndex = i),
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppTheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  visible[i]!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppTheme.lightGreen.withOpacity(0.15)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Details block ──────────────────────────────────────────────────────────

  Widget _detailsBlock() {
    final s = p.schedule;
    final d = p.details;
    final rows = <_DetailRow>[];

    if (s.startDate != null) {
      rows.add(_DetailRow(
        icon: Icons.calendar_today_outlined,
        label: 'Date',
        value: s.endDate != null
            ? '${DateFormat('d MMM yyyy').format(s.startDate!)} – '
                '${DateFormat('d MMM yyyy').format(s.endDate!)}'
            : DateFormat('d MMM yyyy').format(s.startDate!),
      ));
    }
    if (s.recurrence != RecurrencePattern.oneTime) {
      rows.add(_DetailRow(
          icon: Icons.repeat_outlined,
          label: 'Recurrence',
          value: s.recurrence.label));
    }
    if (d.duration.isNotEmpty) {
      rows.add(_DetailRow(
          icon: Icons.schedule_outlined,
          label: 'Duration',
          value: d.duration));
    }
    if (s.isOnline) {
      rows.add(const _DetailRow(
          icon: Icons.laptop_outlined,
          label: 'Format',
          value: 'Online / remote'));
    } else if (s.location != null) {
      rows.add(_DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: [
            if (s.location!.venue.isNotEmpty) s.location!.venue,
            s.location!.shortLabel,
          ].join(' · ')));
    }
    if (d.capacity != null) {
      rows.add(_DetailRow(
          icon: Icons.people_outline,
          label: 'Capacity',
          value: '${d.capacity} participants'));
    }
    if (d.certificateOffered) {
      rows.add(const _DetailRow(
          icon: Icons.workspace_premium_outlined,
          label: 'Certificate',
          value: 'Offered on completion'));
    }
    if (d.eligibility.isNotEmpty) {
      rows.add(_DetailRow(
          icon: Icons.checklist_outlined,
          label: 'Who can join',
          value: d.eligibility));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.icon, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: Text(r.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkGreen.withOpacity(0.5),
                                fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: Text(r.value,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkGreen,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Org identity line ──────────────────────────────────────────────────────

  Widget _orgLine() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.orgName.isNotEmpty
                ? widget.orgName[0].toUpperCase()
                : 'O',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.orgName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.darkGreen)),
              Text('Offering this programme',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.45))),
            ],
          ),
        ),
      ],
    );
  }

  // ── CTAs ───────────────────────────────────────────────────────────────────

  Widget _ctaBlock() {
    final mode = p.contact.mode;
    final hasLink = p.contact.externalLink?.isNotEmpty ?? false;
    final showEnquire = p.canEnquire &&
        (mode == ProgrammeContactMode.enquiry ||
            mode == ProgrammeContactMode.both);
    final showLink = hasLink &&
        (mode == ProgrammeContactMode.externalLink ||
            mode == ProgrammeContactMode.both ||
            p.type == ProgrammeType.onlineCourse);

    if (!showEnquire && !showLink) return const SizedBox.shrink();

    return Column(
      children: [
        if (showEnquire)
          FilledButton.icon(
            onPressed: _openEnquiry,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Send an enquiry',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        if (showEnquire && showLink) const SizedBox(height: 10),
        if (showLink)
          OutlinedButton.icon(
            onPressed: () => _openLink(),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              p.type == ProgrammeType.onlineCourse
                  ? 'Open course'
                  : 'Visit link',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
      ],
    );
  }

  Widget _coverPlaceholder() => Container(
        color: AppTheme.lightGreen.withOpacity(0.15),
        child: Center(
          child: Icon(Icons.image_outlined,
              size: 48, color: AppTheme.lightGreen.withOpacity(0.4)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
