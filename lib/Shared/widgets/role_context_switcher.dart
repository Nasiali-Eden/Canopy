import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoleContextSwitcher extends StatelessWidget {
  final String activeContext; // 'org' | 'member' | 'marketplace' | 'envOps' | 'cultural'
  final bool hasMarketplace;
  final bool hasEnvOps;
  final bool hasCultural;
  final VoidCallback onOrgTap;
  final VoidCallback onMemberTap;
  final VoidCallback? onMarketplaceTap;
  final VoidCallback? onEnvOpsTap;
  final VoidCallback? onCulturalTap;

  const RoleContextSwitcher({
    super.key,
    required this.activeContext,
    required this.hasMarketplace,
    this.hasEnvOps = false,
    this.hasCultural = false,
    required this.onOrgTap,
    required this.onMemberTap,
    this.onMarketplaceTap,
    this.onEnvOpsTap,
    this.onCulturalTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // ── Org Tab ────────────────────────────────────────────────────
            _buildTab(
              label: 'Org',
              icon: Icons.business_outlined,
              color: AppTheme.primary,
              isActive: activeContext == 'org',
              onTap: onOrgTap,
            ),
            const SizedBox(width: 8),

            // ── My Profile Tab ─────────────────────────────────────────────
            _buildTab(
              label: 'My Profile',
              icon: Icons.person_outline,
              color: AppTheme.accent,
              isActive: activeContext == 'member',
              onTap: onMemberTap,
            ),

            // ── Marketplace Tab (conditional) ──────────────────────────────
            if (hasMarketplace) ...[
              const SizedBox(width: 8),
              _buildTab(
                label: 'Marketplace',
                icon: Icons.storefront_outlined,
                color: AppTheme.tertiary,
                isActive: activeContext == 'marketplace',
                onTap: onMarketplaceTap ?? () {},
              ),
            ],

            // ── Environmental Ops Tab (conditional) ───────────────────────
            if (hasEnvOps) ...[
              const SizedBox(width: 8),
              _buildTab(
                label: 'Env Ops',
                icon: Icons.eco_outlined,
                color: const Color(0xFF2E7D5E),
                isActive: activeContext == 'envOps',
                onTap: onEnvOpsTap ?? () {},
              ),
            ],

            // ── Cultural Archive Tab (conditional) ────────────────────────
            if (hasCultural) ...[
              const SizedBox(width: 8),
              _buildTab(
                label: 'Culture',
                icon: Icons.auto_stories_outlined,
                color: const Color(0xFF7A5230),
                isActive: activeContext == 'cultural',
                onTap: onCulturalTap ?? () {},
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          border: isActive
              ? null
              : Border.all(
                  color: color.withOpacity(0.35),
                  width: 1.5,
                ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
