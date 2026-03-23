import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../Services/Authentication/auth.dart';
import '../../../Shared/Pages/login.dart';
import '../../../Shared/theme/app_theme.dart';

class OrgProfile extends StatefulWidget {
  const OrgProfile({super.key});

  @override
  State<OrgProfile> createState() => _OrgProfileState();
}

class _OrgProfileState extends State<OrgProfile> {
  final AuthService _authService = AuthService();
  late Future<Map<String, dynamic>?> _orgDataFuture;

  @override
  void initState() {
    super.initState();
    _orgDataFuture = _fetchOrgData();
  }

  Future<Map<String, dynamic>?> _fetchOrgData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final firestore = FirebaseFirestore.instance;

      // Get user's organization data from Users collection
      final userDoc =
          await firestore.collection('Users').doc(currentUser.uid).get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final orgId = userData['orgId'] as String?;

      if (orgId == null) return null;

      // Get organization details from organizations collection
      final orgDoc =
          await firestore.collection('organizations').doc(orgId).get();

      if (!orgDoc.exists) return null;

      return orgDoc.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      return null;
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final trimmed = name.trim();
    final words = trimmed.split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return (words[0][0] + words[words.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 68,
        centerTitle: true,
        title: Text(
          'Canopy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _orgDataFuture,
        builder: (context, snapshot) {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context, snapshot.data),
                const SizedBox(height: 24),
                _buildOrganizationInfo(context),
                const SizedBox(height: 24),
                _buildAccountSection(context),
                const SizedBox(height: 16),
                _buildNotificationsSection(context),
                const SizedBox(height: 16),
                _buildSupportSection(context),
                const SizedBox(height: 24),
                _buildSignOutButton(context),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic>? orgData) {
    final orgName = orgData?['org_name'] as String? ?? 'Organization';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, AppTheme.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.business,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            orgName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Active Organization',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Organization Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                IconButton(
                  onPressed: () {
                    // TODO: Navigate to edit organization details
                  },
                  icon: Icon(Icons.edit, color: AppTheme.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.category,
              label: 'Type',
              value: 'Environmental NGO',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on,
              label: 'Operating Area',
              value: 'Nairobi, Kenya',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Established',
              value: 'January 2020',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.people,
              label: 'Team Size',
              value: '24 Members',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Account Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.account_circle,
                title: 'Account Details',
                onTap: () {
                  // TODO: Navigate to account details
                },
              ),
              _SettingsItem(
                icon: Icons.lock,
                title: 'Password and Security',
                onTap: () {
                  // TODO: Navigate to security settings
                },
              ),
              _SettingsItem(
                icon: Icons.location_city,
                title: 'Organization Address',
                onTap: () {
                  // TODO: Navigate to address settings
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.email,
                title: 'Email Notifications',
                onTap: () {
                  // TODO: Navigate to email notification settings
                },
              ),
              _SettingsItem(
                icon: Icons.notifications,
                title: 'Push Notifications',
                onTap: () {
                  // TODO: Navigate to push notification settings
                },
              ),
              _SettingsItem(
                icon: Icons.notifications_off,
                title: 'Manage Preferences',
                onTap: () {
                  // TODO: Navigate to notification preferences
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Support & Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {
                  // TODO: Navigate to help center
                },
              ),
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'About Canopy',
                onTap: () {
                  // TODO: Navigate to about page
                },
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  // TODO: Navigate to privacy policy
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to sign out?',
                    style: TextStyle(color: AppTheme.darkGreen),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.darkGreen),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (shouldSignOut == true) {
                await _authService.signOut();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.logout, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: isLast ? const Radius.circular(16) : Radius.zero,
                  ),
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon,
                              color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.darkGreen,
                                ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 62),
                  child: Divider(
                    height: 1,
                    color: AppTheme.lightGreen.withOpacity(0.2),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
