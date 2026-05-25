import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

class EnvVerifiedScreen extends StatelessWidget {
  const EnvVerifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTierBadge(),
            const SizedBox(height: 12),
            _buildNextTierTeaser(),
            const SizedBox(height: 16),
            _buildCreditPipelineSection(),
            const SizedBox(height: 16),
            _buildExportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTierBadge() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VERIFICATION TIER',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Impact Partner',
                  style: TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Active since Jan 2026',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    _UnlockChip('✓ 3 buy orders'),
                    _UnlockChip('✓ Zone mapped'),
                    _UnlockChip('✓ 30-day site'),
                    _UnlockChip('✓ 6 months active'),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified,
            size: 52,
            color: AppTheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildNextTierTeaser() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.tertiary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.tertiary),
              const SizedBox(width: 8),
              const Text(
                'Credit Issuer',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
              const Spacer(),
              Text(
                '50 trees needed',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.86,
              backgroundColor: Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(AppTheme.tertiary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditPipelineSection() {
    return Column(
      children: [
        _buildExpansionTile(
          icon: Icons.recycling,
          iconColor: AppTheme.primary,
          title: 'Plastic Recovery Credits',
          issuedCount: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Credits Issued: 3',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '0x4a2f...c91b',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppTheme.darkGreen.withOpacity(0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      // Copy hash
                    },
                    color: AppTheme.darkGreen.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.56,
                  backgroundColor: Color(0xFFF0F0F0),
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '280 kg of 500 kg threshold',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // View evidence chain
                },
                child: const Text('View evidence chain →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpansionTile(
          icon: Icons.delete_sweep_outlined,
          iconColor: AppTheme.accent,
          title: 'Dumpsite Transformation Credits',
          issuedCount: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2 sites at 30-day confirmation',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '1 site at 90-day — credit eligible',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  const Text(
                    '1 site did not hold — recorded',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // View evidence chain
                },
                child: const Text('View evidence chain →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpansionTile(
          icon: Icons.park_outlined,
          iconColor: AppTheme.secondary,
          title: 'Urban Greening Credits',
          issuedCount: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.86,
                  backgroundColor: Color(0xFFF0F0F0),
                  valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '43 of 50 trees confirmed',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '7 more 90-day confirmations needed',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Switch to Trees tab
                },
                child: const Text('View in Trees tab →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpansionTile(
          icon: Icons.water_outlined,
          iconColor: const Color(0xFF5C6BC0),
          title: 'Waterway Clearance Credits',
          issuedCount: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2 sections cleared',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  const Text(
                    'Section A — 30-day follow-up due in 8 days',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'Section B — Holding  ✓',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int issuedCount,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppTheme.darkGreen,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (issuedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$issuedCount',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        children: [child],
      ),
    );
  }

  Widget _buildExportButton() {
    return GestureDetector(
      onTap: () {
        // Export verification summary
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.tertiary.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.download_outlined, color: AppTheme.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Verification Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PDF & JSON  ·  Ready for sponsors, grants, credit buyers',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppTheme.darkGreen),
          ],
        ),
      ),
    );
  }
}

class _UnlockChip extends StatelessWidget {
  final String text;

  const _UnlockChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
