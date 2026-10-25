// lib/Organization/org_ui.dart
//
// Organisation workspace components (handoff/ORG_HANDOFF.md §1–§2). Same
// theme, denser rhythm: rows 52, card padding 14, section gap 20. Hierarchy
// comes from Bricolage numbers and ink rules, not boxes.
//
//   OrgMasthead · AttentionStrip · MetricTile · WorkspaceQuickAction ·
//   DenseRow · MembershipLabel · ContentStateLabel · SectionCard ·
//   EventQr · CapabilityCard · WorkspaceSection.

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/canopy_components.dart';
import '../theme/tokens/org_tokens.dart';

export '../theme/tokens/org_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MASTHEAD
// ─────────────────────────────────────────────────────────────────────────────

/// Cover 150 with top scrim; workspace switcher chip left + notifications
/// glass button right; 72 squircle logo overlapping by 34 with a 4px canvas
/// ring + "Public page"; name (display); verified line; ruled stat row; a
/// one-line "today" sentence. No cover → "Add a cover photo" band +
/// profile-progress bar instead of stats.
class OrgMastheadView extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final String? coverUrl;
  final bool verified;
  final String? designation;
  final String? area;
  final List<(String value, String label, VoidCallback? onTap)> stats;
  final String? today;
  final double profileProgress;
  final VoidCallback? onSwitchWorkspace;
  final VoidCallback onNotifications;
  final VoidCallback onPublicPage;
  final VoidCallback onAddCover;
  final VoidCallback? onEditLogo;
  final bool notificationsDot;

  const OrgMastheadView({
    super.key,
    required this.name,
    this.logoUrl,
    this.coverUrl,
    this.verified = false,
    this.designation,
    this.area,
    this.stats = const [],
    this.today,
    this.profileProgress = 0,
    this.onSwitchWorkspace,
    required this.onNotifications,
    required this.onPublicPage,
    required this.onAddCover,
    this.onEditLogo,
    this.notificationsDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;
    final coverH = OrgMasthead.coverHeight + top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: coverH + OrgMasthead.logoSize - 34,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: coverH,
                child: hasCover
                    ? Stack(fit: StackFit.expand, children: [
                        CanopyImage(url: coverUrl),
                        const Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: 90,
                            width: double.infinity,
                            child: DecoratedBox(
                                decoration: BoxDecoration(gradient: OrgMasthead.coverScrim)),
                          ),
                        ),
                      ])
                    : Material(
                        color: p.surfaceMuted,
                        child: InkWell(
                          onTap: onAddCover,
                          child: Container(
                            decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: p.outlineStrong))),
                            alignment: Alignment.bottomRight,
                            padding: const EdgeInsets.all(CanopySpace.s12),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: CanopyIconSize.s18, color: p.inkMuted),
                              const SizedBox(width: CanopySpace.s4 + 2),
                              Text('Add a cover photo',
                                  style: CanopyType.label.copyWith(color: p.inkMuted)),
                            ]),
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: top + CanopySpace.s8,
                left: CanopySpace.s12,
                right: CanopySpace.s8,
                child: Row(children: [
                  if (onSwitchWorkspace != null)
                    Material(
                      color: hasCover ? p.scrim : p.surface,
                      borderRadius: BorderRadius.circular(CanopyRadius.pill),
                      child: InkWell(
                        onTap: onSwitchWorkspace,
                        borderRadius: BorderRadius.circular(CanopyRadius.pill),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s12),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.swap_horiz,
                                size: CanopyIconSize.s18,
                                color: hasCover ? CanopyPalette.onHero : p.ink),
                            const SizedBox(width: CanopySpace.s4 + 2),
                            Text('Organisation workspace',
                                style: CanopyType.label.copyWith(
                                    color: hasCover ? CanopyPalette.onHero : p.ink)),
                            Icon(Icons.expand_more,
                                size: CanopyIconSize.s18,
                                color: hasCover ? CanopyPalette.onHero : p.ink),
                          ]),
                        ),
                      ),
                    ),
                  const Spacer(),
                  CanopyIconButton(
                    icon: Icons.notifications_none_outlined,
                    tooltip: 'Notifications',
                    onImage: hasCover,
                    filled: !hasCover,
                    dot: notificationsDot,
                    onPressed: onNotifications,
                  ),
                ]),
              ),
              Positioned(
                left: CanopySpace.gutter,
                top: coverH - 34,
                child: GestureDetector(
                  onTap: onEditLogo,
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.canvas,
                      borderRadius: BorderRadius.circular((OrgMasthead.logoSize + 8) * 0.3),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: CanopyAvatar(
                        url: logoUrl, name: name, size: OrgMasthead.logoSize, org: true),
                  ),
                ),
              ),
              Positioned(
                right: CanopySpace.gutter,
                top: coverH + CanopySpace.s8,
                child: CanopyButton.secondary(
                    label: 'Public page', size: CanopyButtonSize.compact, onPressed: onPublicPage),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: CanopyType.display.copyWith(color: p.ink)),
              const SizedBox(height: CanopySpace.s2),
              Row(children: [
                if (verified) ...[
                  Icon(Icons.verified, size: CanopyIconSize.s16, color: p.success),
                  const SizedBox(width: CanopySpace.s4),
                ],
                Flexible(
                  child: Text(
                    [
                      if (verified) 'Verified ${designation ?? 'organisation'}' else if (designation != null) designation!,
                      if (area != null && area!.isNotEmpty) area!,
                    ].join(' · '),
                    style: CanopyType.body.copyWith(color: p.inkMuted),
                  ),
                ),
              ]),
              const SizedBox(height: CanopySpace.s16),
              if (hasCover && stats.isNotEmpty)
                IntrinsicHeight(
                  child: Row(children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) VerticalDivider(width: CanopySpace.s24, color: p.outline),
                      Expanded(
                        child: InkWell(
                          onTap: stats[i].$3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stats[i].$1, style: OrgMasthead.statValue.copyWith(color: p.ink)),
                              Text(stats[i].$2, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text('Profile ${(profileProgress * 100).round()}% complete',
                            style: CanopyType.label.copyWith(color: p.ink)),
                      ),
                    ]),
                    const SizedBox(height: CanopySpace.s4 + 2),
                    CanopyProgressBar(value: profileProgress, ink: true),
                  ],
                ),
              if (today != null) ...[
                const SizedBox(height: CanopySpace.s12),
                Text(today!, style: CanopyType.body.copyWith(color: p.ink)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENTION STRIP
// ─────────────────────────────────────────────────────────────────────────────

class AttentionItem {
  final int count;
  final String label;
  final VoidCallback onTap;
  const AttentionItem(this.count, this.label, this.onTap);
}

/// 1.5px ink border, radius 14, rows 56: count (Bricolage 26) + label +
/// chevron. Nothing → single "All caught up" line.
class AttentionStrip extends StatelessWidget {
  final List<AttentionItem> items;
  final bool loading;
  const AttentionStrip({super.key, required this.items, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (loading) return const CanopySkeleton(height: 56, radius: 14);
    final live = items.where((i) => i.count > 0).toList();
    if (live.isEmpty) {
      return Row(children: [
        Icon(Icons.check_circle_outline, size: CanopyIconSize.s18, color: p.success),
        const SizedBox(width: CanopySpace.s8),
        Text('All caught up — nothing needs you right now.',
            style: CanopyType.body.copyWith(color: p.ink)),
      ]);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.ink, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < live.length; i++) ...[
          if (i > 0) Divider(height: 1, color: p.outline),
          InkWell(
            onTap: live[i].onTap,
            child: SizedBox(
              height: CanopyWorkspace.attentionRowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  SizedBox(
                    width: 40,
                    child: Text('${live[i].count}',
                        style: CanopyWorkspace.attentionCount.copyWith(color: p.ink)),
                  ),
                  Expanded(
                      child: Text(live[i].label, style: CanopyType.bodyStrong.copyWith(color: p.ink))),
                  Icon(Icons.chevron_right, size: CanopyIconSize.s18, color: p.inkMuted),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRICS, ACTIONS, ROWS
// ─────────────────────────────────────────────────────────────────────────────

/// 2px ink top rule, value Bricolage 26, caption inkMuted; tappable.
class MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const MetricTile({super.key, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: CanopySpace.s8, bottom: CanopySpace.s4),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.ink, width: CanopyWorkspace.metricRule))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: CanopyWorkspace.metricValue.copyWith(color: p.ink)),
          Text(label, style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ],
      ),
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

/// 1px outline, radius 12, 24 glyph + label. Four only.
class WorkspaceQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const WorkspaceQuickAction(
      {super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        side: BorderSide(color: p.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Icon(icon, size: CanopyIconSize.nav, color: p.ink),
            const SizedBox(height: CanopySpace.s4 + 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CanopyType.label.copyWith(color: p.ink, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

/// Dense row: avatar 40 · name + role/team · status label · trailing action.
class DenseRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? status;
  final Widget? trailing;
  final VoidCallback? onTap;
  const DenseRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.status,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CanopyWorkspace.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: CanopyWorkspace.rowPaddingH, vertical: CanopyWorkspace.rowPaddingV),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: CanopySpace.s12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CanopyType.caption.copyWith(color: p.inkMuted)),
                if (status != null) ...[const SizedBox(height: CanopySpace.s2), status!],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: CanopySpace.s8), trailing!],
        ]),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

class MembershipLabel extends StatelessWidget {
  final MembershipStatus status;
  const MembershipLabel(this.status, {super.key});

  @override
  Widget build(BuildContext context) => StatusLabel(
      switch (status) {
        MembershipStatus.active => 'Active',
        MembershipStatus.inactive => 'Inactive',
        MembershipStatus.pending => 'Pending',
        MembershipStatus.invited => 'Invited',
      },
      color: OrgStatusColors.membership(status, context.canopy));
}

class ContentStateLabel extends StatelessWidget {
  final ContentState state;
  final String? when;
  const ContentStateLabel(this.state, {super.key, this.when});

  @override
  Widget build(BuildContext context) => StatusLabel(
      switch (state) {
        ContentState.draft => 'Draft',
        ContentState.published => 'Published',
        ContentState.scheduled => 'Scheduled${when == null ? '' : ' $when'}',
      },
      color: OrgStatusColors.content(state, context.canopy));
}

/// Workspace section: heading + optional action, 20 gap rhythm.
class WorkspaceSection extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  const WorkspaceSection(
      {super.key, required this.title, this.actionLabel, this.onAction, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopyWorkspace.sectionGap, CanopySpace.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CanopySectionHeader(
                title: title,
                actionLabel: actionLabel ?? 'See all',
                onAction: onAction,
                padding: EdgeInsets.zero),
            child,
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LONG-FORM SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────

enum SectionCardState { done, open, locked }

/// done: ink number + check + summary + Edit · open: 1.5 ink border ·
/// locked: dashed "Complete section N to continue".
class SectionCard extends StatelessWidget {
  final int number;
  final String title;
  final SectionCardState state;
  final String? summary;
  final Widget? child;
  final VoidCallback? onEdit;
  const SectionCard({
    super.key,
    required this.number,
    required this.title,
    required this.state,
    this.summary,
    this.child,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final head = Row(children: [
      Text('$number', style: CanopyWorkspace.metricValue.copyWith(fontSize: 20, color: state == SectionCardState.locked ? p.inkFaint : p.ink)),
      const SizedBox(width: CanopySpace.s12),
      Expanded(
        child: Text(title,
            style: CanopyType.subhead
                .copyWith(color: state == SectionCardState.locked ? p.inkFaint : p.ink)),
      ),
      if (state == SectionCardState.done) ...[
        Icon(Icons.check, size: CanopyIconSize.s18, color: p.success),
        if (onEdit != null)
          CanopyButton.quiet(label: 'Edit', size: CanopyButtonSize.compact, onPressed: onEdit),
      ],
    ]);
    switch (state) {
      case SectionCardState.locked:
        return DashedBorder(
          color: p.outlineStrong,
          radius: 14,
          child: Padding(
            padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              head,
              const SizedBox(height: CanopySpace.s4),
              Text('Complete section ${number - 1} to continue',
                  style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
          ),
        );
      case SectionCardState.done:
        return CanopyCard(
          padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            head,
            if (summary != null)
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ),
          ]),
        );
      case SectionCardState.open:
        return CanopyCard(
          borderColor: p.ink,
          borderWidth: 1.5,
          padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            head,
            if (child != null) ...[const SizedBox(height: CanopySpace.s16), child!],
          ]),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENT QR — never themed
// ─────────────────────────────────────────────────────────────────────────────

class EventQr extends StatelessWidget {
  final String data;
  final double size;
  const EventQr({super.key, required this.data, this.size = CanopyWorkspace.qrSize});

  @override
  Widget build(BuildContext context) {
    final s = size.clamp(240.0, MediaQuery.sizeOf(context).width - 2 * CanopySpace.gutter);
    return Semantics(
      label: 'Event check-in QR code',
      image: true,
      child: Container(
        color: CanopyWorkspace.qrBackground,
        padding: const EdgeInsets.all(CanopyWorkspace.qrQuietZone),
        child: QrImageView(
          data: data,
          size: s - 2 * CanopyWorkspace.qrQuietZone,
          padding: EdgeInsets.zero,
          backgroundColor: CanopyWorkspace.qrBackground,
          eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square, color: CanopyWorkspace.qrForeground),
          dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square, color: CanopyWorkspace.qrForeground),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAPABILITY CARD
// ─────────────────────────────────────────────────────────────────────────────

/// Marketplace / Environmental Ops / Cultural Archive. Not applied (Apply) ·
/// Under review (date) · Enabled (1.5 ink border, "Open workspace" primary).
class CapabilityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final CapabilityState state;
  final String? reviewNote;
  final VoidCallback? onApply;
  final VoidCallback? onOpen;
  final bool primaryOpen;
  const CapabilityCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.state,
    this.reviewNote,
    this.onApply,
    this.onOpen,
    this.primaryOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final enabled = state == CapabilityState.enabled;
    return CanopyCard(
      borderColor: enabled ? p.ink : null,
      borderWidth: enabled ? 1.5 : 1,
      padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: CanopyIconSize.nav, color: p.ink),
            const SizedBox(width: CanopySpace.s12),
            Expanded(child: Text(title, style: CanopyType.subhead.copyWith(color: p.ink))),
            StatusLabel(
              switch (state) {
                CapabilityState.notApplied => 'Not applied',
                CapabilityState.underReview => 'Under review',
                CapabilityState.enabled => 'Enabled',
              },
              color: OrgStatusColors.capability(state, p),
            ),
          ]),
          const SizedBox(height: CanopySpace.s4),
          Text(description, style: CanopyType.body.copyWith(color: p.inkMuted)),
          if (state == CapabilityState.underReview && reviewNote != null) ...[
            const SizedBox(height: CanopySpace.s4),
            Text(reviewNote!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
          ],
          if (state == CapabilityState.notApplied && onApply != null)
            Align(
              alignment: Alignment.centerLeft,
              child: CanopyButton.secondary(
                  label: 'Apply', size: CanopyButtonSize.compact, onPressed: onApply),
            ),
          if (enabled && onOpen != null) ...[
            const SizedBox(height: CanopySpace.s8),
            primaryOpen
                ? CanopyButton(label: 'Open workspace', expand: true, onPressed: onOpen)
                : CanopyButton.secondary(label: 'Open workspace', expand: true, onPressed: onOpen),
          ],
        ],
      ),
    );
  }
}
