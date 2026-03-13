import 'package:flutter/material.dart';

import '../../Shared/theme/app_theme.dart';
import '../Pages/login.dart';
import 'Artists/m_registration.dart';
import 'components/role_card.dart';
import 'member/member_register_screen.dart';
import 'organization/org_register_wizard.dart';

class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  String _role = 'Member';

  void _continue() {
    if (_role == 'Member') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MemberRegisterScreen()));
    } else if (_role == 'Org Rep') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const OrgRegisterWizard()));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MarketplaceRegisterScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Create Account',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: AppTheme.darkGreen, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: _buildRoleSelection()),
    );
  }

  Widget _buildRoleSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        Text(
          'How will you join?',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppTheme.darkGreen, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the path that matches how you\'ll participate in Canopy.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.darkGreen.withOpacity(0.65)),
        ),
        const SizedBox(height: 28),

        // ── Community Member ───────────────────────────────────────────────
        RoleCard(
          title: 'Community Member',
          subtitle:
          'Report issues, attend cleanups, follow organisations, and engage with your community.',
          icon: Icons.people_outline,
          accent: AppTheme.primary,
          selected: _role == 'Member',
          onTap: () => setState(() => _role = 'Member'),
        ),
        const SizedBox(height: 14),

        // ── Organisation ───────────────────────────────────────────────────
        RoleCard(
          title: 'Organisation Representative',
          subtitle:
          'Register an NGO, recycler, waste-art collective, clinic, school, or any community org.',
          icon: Icons.business_outlined,
          accent: const Color(0xFF0097A7),
          selected: _role == 'Org Rep',
          onTap: () => setState(() => _role = 'Org Rep'),
        ),
        const SizedBox(height: 14),

        // ── Marketplace ────────────────────────────────────────────────────
        RoleCard(
          title: 'Marketplace Member',
          subtitle:
          'Collect & sell materials, process recyclables, or create and sell artisan goods made from recovered materials.',
          icon: Icons.storefront_outlined,
          accent: AppTheme.tertiary,
          selected: _role == 'Marketplace',
          onTap: () => setState(() => _role = 'Marketplace'),
        ),

        // ── Marketplace role pills (shown only when selected) ──────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _role == 'Marketplace'
              ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.tertiary.withOpacity(0.25)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _rolePill(Icons.recycling_outlined, 'Collector',
                      const Color(0xFF2D7A4F)),
                  _rolePill(Icons.factory_outlined, 'Processor',
                      const Color(0xFF0097A7)),
                  _rolePill(Icons.palette_outlined, 'Maker / Artisan',
                      AppTheme.tertiary),
                ],
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 10),

        // ── Volunteer hint ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.volunteer_activism_outlined,
                color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Want to volunteer? You can register as a volunteer directly inside the app after joining as a member.',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.75)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 32),

        // ── Continue button ────────────────────────────────────────────────
        FilledButton(
          onPressed: _continue,
          style: FilledButton.styleFrom(
            backgroundColor: _role == 'Marketplace'
                ? AppTheme.tertiary
                : AppTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Continue',
                  style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Already have an account? ',
              style:
              TextStyle(color: AppTheme.darkGreen.withOpacity(0.6))),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginPage())),
            child: Text('Sign In',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }

  Widget _rolePill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}