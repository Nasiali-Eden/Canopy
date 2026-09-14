import 'package:flutter/material.dart';

import '../../theme/canopy_ui.dart';

class CanopyProfileScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? leading;
  final Future<void> Function()? onRefresh;

  const CanopyProfileScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.leading,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final content = ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        CanopyUi.pageGutter,
        8,
        CanopyUi.pageGutter,
        32,
      ),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: CanopyUi.sectionGap),
      itemBuilder: (_, index) => children[index],
    );

    return Scaffold(
      backgroundColor: CanopyUi.canvas,
      appBar: AppBar(
        title: Text(title),
        leading: leading,
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: onRefresh == null
            ? content
            : RefreshIndicator(onRefresh: onRefresh!, child: content),
      ),
    );
  }
}

class CanopyIdentityLedger extends StatelessWidget {
  final String name;
  final String role;
  final String? location;
  final String? imageUrl;
  final String initials;
  final String? status;
  final Color accent;
  final Widget? action;

  const CanopyIdentityLedger({
    super.key,
    required this.name,
    required this.role,
    required this.initials,
    this.location,
    this.imageUrl,
    this.status,
    this.accent = CanopyUi.primary,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl?.trim().isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CanopyUi.ink,
        borderRadius: BorderRadius.circular(CanopyUi.heroRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: accent,
                foregroundImage: hasImage ? NetworkImage(imageUrl!) : null,
                child: hasImage
                    ? null
                    : Text(
                        initials.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                              ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      role,
                      style: const TextStyle(
                        color: Color(0xFFD6E4DA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (location?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: Color(0xFFB9CBBF)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB9CBBF),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          if (status?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 18),
            CanopyStatusPill(label: status!, color: accent),
          ],
        ],
      ),
    );
  }
}

class CanopyStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const CanopyStatusPill({
    super.key,
    required this.label,
    this.color = CanopyUi.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class CanopyProfileSection extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final Widget? trailing;

  const CanopyProfileSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: CanopyUi.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 5),
            Text(
              description!,
              style: const TextStyle(color: CanopyUi.inkMuted, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      );
}

class CanopyProfileMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const CanopyProfileMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.color = CanopyUi.primary,
  });
}

class CanopyProfileMetricGrid extends StatelessWidget {
  final List<CanopyProfileMetric> metrics;

  const CanopyProfileMetricGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 640 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (_, index) {
              final metric = metrics[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(metric.icon, color: metric.color, size: 21),
                      Text(
                        metric.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: CanopyUi.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        metric.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CanopyUi.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
}

class CanopyProfileEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CanopyProfileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: CanopyUi.sage,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: CanopyUi.primary),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CanopyUi.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CanopyUi.inkMuted, height: 1.4),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}

class CanopyMediaFallback extends StatelessWidget {
  final String label;
  final IconData icon;

  const CanopyMediaFallback({
    super.key,
    this.label = 'Image not added',
    this.icon = Icons.eco_outlined,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: CanopyUi.sage,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CanopyUi.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CanopyUi.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}
