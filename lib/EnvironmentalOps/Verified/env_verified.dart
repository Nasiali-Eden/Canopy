import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Models/environmental/enums/verification_tier.dart';
import '../../Models/environmental/models/environmental_credit.dart';
import '../../Models/environmental/models/transformation_record_summary.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../Shared/theme/app_theme.dart';

class EnvVerifiedScreen extends StatefulWidget {
  const EnvVerifiedScreen({super.key});

  @override
  State<EnvVerifiedScreen> createState() => _EnvVerifiedScreenState();
}

class _EnvVerifiedScreenState extends State<EnvVerifiedScreen> {
  final _service = EnvironmentOpsService.instance;

  EnvironmentOpsContext? _context;
  VerificationSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final context = await _service.resolveContext();
      if (context == null) {
        if (!mounted) return;
        setState(() {
          _context = null;
          _snapshot = null;
          _loading = false;
        });
        return;
      }
      final snapshot = await _service.fetchVerificationSnapshot(
        orgId: context.orgId,
        uid: context.uid,
      );
      if (!mounted) return;
      setState(() {
        _context = context;
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openTransformationLogger() async {
    final contextData = _context;
    if (contextData == null) return;
    final result = await showModalBottomSheet<_TransformationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogTransformationSheet(
        initialArea: contextData.area,
      ),
    );
    if (result == null) return;
    try {
      await _service.createTransformationRecord(
        orgId: contextData.orgId,
        siteLabel: result.siteLabel,
        area: result.area,
        interventionDate: result.interventionDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transformation site logged'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not log site: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EE),
      floatingActionButton: _context == null
          ? null
          : FloatingActionButton.extended(
                onPressed: _openTransformationLogger,
                backgroundColor: AppTheme.primary,
                icon: const Icon(Icons.add_location_alt_outlined,
                    color: Colors.white),
                label: const Text(
                  'Log Site',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _load,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                )
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : _context == null || snapshot == null
                      ? const _NoOrgState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                          children: [
                            _TierHero(
                              orgName: _context!.orgName,
                              snapshot: snapshot,
                            ),
                            const SizedBox(height: 18),
                            _MetricGrid(snapshot: snapshot),
                            const SizedBox(height: 22),
                            _SectionLabel(
                              label: 'CREDIT PIPELINES',
                              note: 'Track how daily work turns into verified impact.',
                            ),
                            const SizedBox(height: 12),
                            _PipelineCard(
                              title: 'Plastic Recovery',
                              icon: Icons.recycling_outlined,
                              color: AppTheme.primary,
                              progressValue:
                                  (snapshot.plasticKgVerified / 500).clamp(0.0, 1.0),
                              progressLabel:
                                  '${snapshot.plasticKgVerified.toStringAsFixed(snapshot.plasticKgVerified >= 100 ? 0 : 1)} kg of 500 kg',
                              helperText: snapshot.plasticKgVerified >= 500
                                  ? 'Threshold met for credit-issuer eligibility.'
                                  : 'Keep logging verified handoffs to build your first plastic credit.',
                            ),
                            const SizedBox(height: 10),
                            _PipelineCard(
                              title: 'Urban Greening',
                              icon: Icons.park_outlined,
                              color: const Color(0xFF3E7F4E),
                              progressValue:
                                  (snapshot.treesConfirmed90Day / 50).clamp(0.0, 1.0),
                              progressLabel:
                                  '${snapshot.treesConfirmed90Day} of 50 trees confirmed at 90 days',
                              helperText: snapshot.totalTrees == 0
                                  ? 'Log new planting records to start the survival trail.'
                                  : 'Survival, not planting count, is the unlock metric.',
                            ),
                            const SizedBox(height: 10),
                            _PipelineCard(
                              title: 'Dumpsite Transformation',
                              icon: Icons.delete_sweep_outlined,
                              color: AppTheme.tertiary,
                              progressValue: snapshot.transformationsLogged == 0
                                  ? 0
                                  : (snapshot.transformationsHolding /
                                          snapshot.transformationsLogged)
                                      .clamp(0.0, 1.0),
                              progressLabel:
                                  '${snapshot.transformationsHolding} of ${snapshot.transformationsLogged} logged sites holding',
                              helperText: snapshot.transformationsLogged == 0
                                  ? 'Log intervention sites, then confirm they hold after follow-up.'
                                  : 'A site only counts when it still holds after follow-up.',
                            ),
                            const SizedBox(height: 22),
                            _SectionLabel(
                              label: 'TRANSFORMATION SITES',
                              note: 'Recent dumpsite and cleanup interventions.',
                            ),
                            const SizedBox(height: 12),
                            if (snapshot.transformations.isEmpty)
                              const _EmptyPanel(
                                icon: Icons.delete_sweep_outlined,
                                title: 'No transformation sites yet',
                                subtitle:
                                    'Use Log Site to start building a verified dumpsite transformation record.',
                              )
                            else
                              ...snapshot.transformations
                                  .take(6)
                                  .map((record) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _TransformationCard(record: record),
                                      )),
                            const SizedBox(height: 22),
                            _SectionLabel(
                              label: 'ISSUED CREDITS',
                              note: 'Proof-ready assets backed by your evidence chain.',
                            ),
                            const SizedBox(height: 12),
                            if (snapshot.credits.isEmpty)
                              const _EmptyPanel(
                                icon: Icons.verified_outlined,
                                title: 'No credits issued yet',
                                subtitle:
                                    'Once thresholds are met and verified, issued credits will appear here.',
                              )
                            else
                              ...snapshot.credits
                                  .take(6)
                                  .map((credit) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _CreditCard(credit: credit),
                                      )),
                            const SizedBox(height: 22),
                            _ExportPanel(
                              enabled: snapshot.credits.isNotEmpty ||
                                  snapshot.transformations.isNotEmpty,
                            ),
                          ],
                        ),
        ),
      ),
    );
  }
}

class _TierHero extends StatelessWidget {
  final String orgName;
  final VerificationSnapshot snapshot;

  const _TierHero({
    required this.orgName,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _tierColor(snapshot.tier);
    final nextTier = _nextTier(snapshot.tier);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGreen,
            accent,
            const Color(0xFF8EB69B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orgName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Verification and evidence pipeline',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              snapshot.tier.displayLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _tierSummary(snapshot),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextTier == null
                        ? 'You are already in the highest verification tier available on this track.'
                        : 'Next target: ${nextTier.displayLabel}. ${_remainingNote(snapshot)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static VerificationTier? _nextTier(VerificationTier tier) {
    switch (tier) {
      case VerificationTier.registered:
        return VerificationTier.verified;
      case VerificationTier.verified:
        return VerificationTier.impactPartner;
      case VerificationTier.impactPartner:
        return VerificationTier.creditIssuer;
      case VerificationTier.creditIssuer:
        return null;
    }
  }

  static Color _tierColor(VerificationTier tier) {
    switch (tier) {
      case VerificationTier.registered:
        return const Color(0xFF4B7A65);
      case VerificationTier.verified:
        return const Color(0xFF2D7A4F);
      case VerificationTier.impactPartner:
        return const Color(0xFF3B8A7A);
      case VerificationTier.creditIssuer:
        return const Color(0xFFC4A961);
    }
  }

  static String _tierSummary(VerificationSnapshot snapshot) {
    switch (snapshot.tier) {
      case VerificationTier.registered:
        return 'Your evidence trail has started. Map territory, log collections, and document the first transformation site to move into verified status.';
      case VerificationTier.verified:
        return 'You are now showing consistent field activity. The next step is proving sustained operational follow-through across zones, trees, and site interventions.';
      case VerificationTier.impactPartner:
        return 'Your operations are strong enough to support partner-grade reporting. One more threshold unlocks credit issuance readiness.';
      case VerificationTier.creditIssuer:
        return 'Your environmental work is now structured for formal credit issuance, sponsor reporting, and buyer-facing proof exports.';
    }
  }

  static String _remainingNote(VerificationSnapshot snapshot) {
    if (snapshot.tier == VerificationTier.registered) {
      return 'Aim for at least 1 zone, 3 active orders, and a transformation site on follow-up.';
    }
    if (snapshot.tier == VerificationTier.verified) {
      return 'Sustain activity and push either 500 kg plastic, 50 confirmed trees, or a holding transformation pipeline.';
    }
    if (snapshot.tier == VerificationTier.impactPartner) {
      return 'You are close once one of the credit thresholds is clearly met.';
    }
    return '';
  }
}

class _MetricGrid extends StatelessWidget {
  final VerificationSnapshot snapshot;

  const _MetricGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final items = <_MetricData>[
      _MetricData(
        label: 'Zones',
        value: '${snapshot.zoneCount}',
        icon: Icons.map_outlined,
        color: AppTheme.primary,
      ),
      _MetricData(
        label: 'Active Orders',
        value: '${snapshot.activeOrders}',
        icon: Icons.storefront_outlined,
        color: AppTheme.accent,
      ),
      _MetricData(
        label: 'Plastic Verified',
        value: snapshot.plasticKgVerified >= 1000
            ? '${(snapshot.plasticKgVerified / 1000).toStringAsFixed(1)} t'
            : '${snapshot.plasticKgVerified.toStringAsFixed(0)} kg',
        icon: Icons.recycling_outlined,
        color: const Color(0xFF31714C),
      ),
      _MetricData(
        label: 'Credits Issued',
        value: '${snapshot.issuedCredits}',
        icon: Icons.workspace_premium_outlined,
        color: AppTheme.tertiary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final crossAxisCount = wide ? 4 : 2;
        final width = (constraints.maxWidth - (12 * (crossAxisCount - 1))) /
            crossAxisCount;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _MetricCard(data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkGreen,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final double progressValue;
  final String progressLabel;
  final String helperText;

  const _PipelineCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.progressValue,
    required this.progressLabel,
    required this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progressLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.58),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransformationCard extends StatelessWidget {
  final TransformationRecordSummary record;

  const _TransformationCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final stageColor = _statusColor(record);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: stageColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.siteLabel ?? 'Unnamed transformation site',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: stageColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(record),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: stageColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${record.locationArea} · ${record.interventionDate != null ? DateFormat('d MMM yyyy').format(record.interventionDate!) : 'Date pending'}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStatusPill(
                label: record.stage1.confirmed ? 'Intervention logged' : 'Intervention pending',
                color: record.stage1.confirmed ? AppTheme.primary : Colors.grey,
              ),
              _MiniStatusPill(
                label: record.stage2.confirmed ? '30-day follow-up done' : '30-day follow-up pending',
                color: record.stage2.confirmed ? AppTheme.accent : Colors.orange,
              ),
              _MiniStatusPill(
                label: record.stage3.confirmed
                    ? ((record.stage3.siteHeld ?? false) ? 'Site held' : 'Site failed')
                    : _dueLabel(record.stage3.followUpDueAt),
                color: record.stage3.confirmed
                    ? ((record.stage3.siteHeld ?? false)
                        ? AppTheme.primary
                        : Colors.red.shade400)
                    : Colors.blueGrey,
              ),
            ],
          ),
          if ((record.stage3.siteFailureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              record.stage3.siteFailureReason!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade400,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusText(TransformationRecordSummary record) {
    if (record.creditIssued) return 'CREDITED';
    if (record.stage3.confirmed && (record.stage3.siteHeld ?? false)) {
      return 'HOLDING';
    }
    if (record.stage3.confirmed && !(record.stage3.siteHeld ?? true)) {
      return 'FAILED';
    }
    if (record.stage2.confirmed) return 'FOLLOW-UP';
    return 'IN PROGRESS';
  }

  static Color _statusColor(TransformationRecordSummary record) {
    if (record.creditIssued) return AppTheme.tertiary;
    if (record.stage3.confirmed && (record.stage3.siteHeld ?? false)) {
      return AppTheme.primary;
    }
    if (record.stage3.confirmed && !(record.stage3.siteHeld ?? true)) {
      return Colors.red.shade400;
    }
    if (record.stage2.confirmed) return AppTheme.accent;
    return Colors.orange;
  }

  static String _dueLabel(DateTime? dueAt) {
    if (dueAt == null) return 'Follow-up pending';
    final diff = DateTime(
      dueAt.year,
      dueAt.month,
      dueAt.day,
    ).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    if (diff.inDays < 0) return 'Follow-up overdue';
    if (diff.inDays == 0) return 'Follow-up due today';
    return 'Follow-up in ${diff.inDays}d';
  }
}

class _CreditCard extends StatelessWidget {
  final EnvironmentalCredit credit;

  const _CreditCard({required this.credit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.tertiary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 20,
                  color: AppTheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit.certificate.serialNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    Text(
                      credit.creditType.displayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkGreen.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  credit.tradingStatus.displayLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            credit.quantity.displayLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            credit.issuedAt != null
                ? 'Issued ${DateFormat('d MMM yyyy').format(credit.issuedAt!)}'
                : 'Issue date pending',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.55),
            ),
          ),
          if (credit.evidenceChain.onChainAnchor.txHash.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'On-chain: ${_shortHash(credit.evidenceChain.onChainAnchor.txHash)}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.darkGreen.withOpacity(0.48),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _shortHash(String hash) {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }
}

class _ExportPanel extends StatelessWidget {
  final bool enabled;

  const _ExportPanel({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.file_download_outlined, color: AppTheme.accent),
              SizedBox(width: 10),
              Text(
                'Verification Summary Export',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'Your evidence trail is now rich enough for a sponsor-ready export surface. Export wiring can be added next on top of these records.'
                : 'Once you have logged verified sites or issued credits, this panel becomes your report handoff point.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.58),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Export workflow is the next backend step.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Prepare Export'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniStatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? note;

  const _SectionLabel({
    required this.label,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.darkGreen.withOpacity(0.45),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.58),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppTheme.primary.withOpacity(0.38)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.52),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoOrgState extends StatelessWidget {
  const _NoOrgState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.forest_outlined,
                  size: 36,
                  color: AppTheme.primary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connect an organisation to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verification, credits, transformation records, and environmental reporting all sit on top of an organisation context.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.darkGreen.withOpacity(0.58),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Could not load verification data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransformationDraft {
  final String siteLabel;
  final String area;
  final DateTime interventionDate;

  const _TransformationDraft({
    required this.siteLabel,
    required this.area,
    required this.interventionDate,
  });
}

class _LogTransformationSheet extends StatefulWidget {
  final String initialArea;

  const _LogTransformationSheet({
    required this.initialArea,
  });

  @override
  State<_LogTransformationSheet> createState() => _LogTransformationSheetState();
}

class _LogTransformationSheetState extends State<_LogTransformationSheet> {
  late final TextEditingController _siteCtrl;
  late final TextEditingController _areaCtrl;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _siteCtrl = TextEditingController();
    _areaCtrl = TextEditingController(text: widget.initialArea);
  }

  @override
  void dispose() {
    _siteCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _siteCtrl.text.trim().isNotEmpty && _areaCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6F4EE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Log Transformation Site',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Record the intervention point so the follow-up trail can start.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Site Label'),
              _SheetField(
                controller: _siteCtrl,
                hint: 'e.g. Laini Saba Dumpsite',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Area'),
              _SheetField(
                controller: _areaCtrl,
                hint: 'e.g. Kibera',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Intervention Date'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.lightGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppTheme.accent),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('d MMM yyyy').format(_date),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _valid
                      ? () => Navigator.pop(
                            context,
                            _TransformationDraft(
                              siteLabel: _siteCtrl.text.trim(),
                              area: _areaCtrl.text.trim(),
                              interventionDate: _date,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Site'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.darkGreen,
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _SheetField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.45)),
        ),
      ),
    );
  }
}
