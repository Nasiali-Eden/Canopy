import 'package:flutter/material.dart';

import '../../Shared/theme/app_theme.dart';
import '../Pages/login.dart';
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberRegisterScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrgRegisterWizard()));
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
        title: Text('Create Account', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(child: _buildRoleSelection()),
    );
  }

  Widget _buildRoleSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        Text('How will you join?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Choose whether you\'re joining as an individual community member, or registering an organization.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.darkGreen.withOpacity(0.65)),
        ),
        const SizedBox(height: 28),
        RoleCard(
          title: 'Community Member',
          subtitle: 'Participate in activities, follow organizations, and engage with your community.',
          icon: Icons.people_outline,
          accent: AppTheme.primary,
          selected: _role == 'Member',
          onTap: () => setState(() => _role = 'Member'),
        ),
        const SizedBox(height: 14),
        RoleCard(
          title: 'Organization Representative',
          subtitle: 'Register an NGO, recycler, waste-art collective, clinic, school, or any community org.',
          icon: Icons.business_outlined,
          accent: const Color(0xFF0097A7),
          selected: _role == 'Org Rep',
          onTap: () => setState(() => _role = 'Org Rep'),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
          child: Row(children: [
            Icon(Icons.volunteer_activism_outlined, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Want to volunteer? You can register as a volunteer directly inside the app after joining as a member.', style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.75))),
            ),
          ]),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _continue,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ]),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Already have an account? ', style: TextStyle(color: AppTheme.darkGreen.withOpacity(0.6))),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
            child: Text('Sign In', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}
