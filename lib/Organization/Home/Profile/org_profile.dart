import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../Culture/culture_home.dart';
import '../../../EnvironmentalOps/env_ops_shell.dart';
import '../../../MarketPlace/market_home.dart';
import '../../../Community/Home/community_home.dart';
import '../../../Services/Authentication/auth.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../../Shared/Pages/login.dart';
import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/widgets/role_context_switcher.dart';

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

      final userDoc =
          await firestore.collection('Users').doc(currentUser.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final orgId = userData['orgId'] as String?;
      if (orgId == null) return null;

      final orgDoc =
          await firestore.collection('organizations').doc(orgId).get();
      if (!orgDoc.exists) return null;

      final data =
          Map<String, dynamic>.from(orgDoc.data() as Map<String, dynamic>);
      data['orgId'] = orgId;
      return data;
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      return null;
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading organization data',
                  style: TextStyle(color: AppTheme.darkGreen)),
            );
          }

          final orgData = snapshot.data;
          final currentUser = FirebaseAuth.instance.currentUser;
          final isOrgRep = currentUser != null &&
              orgData != null &&
              orgData['org_rep_uid'] == currentUser.uid;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context, orgData),
                const SizedBox(height: 24),
                if (isOrgRep) ...[
                  _buildRoleContextSwitcher(context, orgData),
                  const SizedBox(height: 20),
                  _buildSpecialOpsButton(context, orgData),
                  const SizedBox(height: 24),
                ],
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

  // ── Header ──────────────────────────────────────────────────────────────────

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
            child: const Icon(Icons.business, size: 50, color: Colors.white),
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

  // ── Role context switcher ────────────────────────────────────────────────────

  Widget _buildRoleContextSwitcher(
      BuildContext context, Map<String, dynamic>? orgData) {
    final hasMarketplace = orgData?['marketplaceStatus'] == 'approved';
    final hasEnvOps = orgData?['envOpsStatus'] == 'approved';
    final hasCultural = orgData?['culturalStatus'] == 'approved';
    final orgId = orgData?['orgId'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RoleContextSwitcher(
        activeContext: 'org',
        hasMarketplace: hasMarketplace,
        hasEnvOps: hasEnvOps,
        hasCultural: hasCultural,
        onOrgTap: () {},
        onMemberTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const CommunityHomeScreen()),
            (route) => false,
          );
        },
        onMarketplaceTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SellerHomeScreen()),
            (route) => false,
          );
        },
        onEnvOpsTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const EnvOpsShell()),
            (route) => false,
          );
        },
        onCulturalTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => CultureHomeScreen(orgId: orgId)),
            (route) => false,
          );
        },
      ),
    );
  }

  // ── Special Operations button ────────────────────────────────────────────────

  Widget _buildSpecialOpsButton(
      BuildContext context, Map<String, dynamic>? orgData) {
    final marketStatus = orgData?['marketplaceStatus'] as String? ?? 'none';
    final envStatus = orgData?['envOpsStatus'] as String? ?? 'none';
    final culturalStatus = orgData?['culturalStatus'] as String? ?? 'none';
    final statuses = [marketStatus, envStatus, culturalStatus];
    final activeCount = statuses.where((s) => s == 'approved').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _openSpecialOps(context, orgData),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.extension_outlined,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special Operations',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeCount == 0
                          ? 'Marketplace · Env Ops · Cultural Archive'
                          : '$activeCount of 3 enabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _StatusDot(status: marketStatus),
                  const SizedBox(width: 4),
                  _StatusDot(status: envStatus),
                  const SizedBox(width: 4),
                  _StatusDot(status: culturalStatus),
                ],
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right,
                  color: AppTheme.primary.withOpacity(0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openSpecialOps(BuildContext context, Map<String, dynamic>? orgData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpecialOpsSheet(
        orgData: orgData,
        onChanged: () => setState(() {
          _orgDataFuture = _fetchOrgData();
        }),
      ),
    );
  }

  // ── Organization info ────────────────────────────────────────────────────────

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
                  onPressed: () {},
                  icon: Icon(Icons.edit, color: AppTheme.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.category, label: 'Type', value: 'Environmental NGO'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.location_on, label: 'Operating Area', value: 'Nairobi, Kenya'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.calendar_today, label: 'Established', value: 'January 2020'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.people, label: 'Team Size', value: '24 Members'),
          ],
        ),
      ),
    );
  }

  // ── Account section ──────────────────────────────────────────────────────────

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
              _SettingsItem(icon: Icons.account_circle, title: 'Account Details', onTap: () {}),
              _SettingsItem(icon: Icons.lock, title: 'Password and Security', onTap: () {}),
              _SettingsItem(icon: Icons.location_city, title: 'Organization Address', onTap: () {}),
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
              _SettingsItem(icon: Icons.email, title: 'Email Notifications', onTap: () {}),
              _SettingsItem(icon: Icons.notifications, title: 'Push Notifications', onTap: () {}),
              _SettingsItem(icon: Icons.notifications_off, title: 'Manage Preferences', onTap: () {}),
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
              _SettingsItem(icon: Icons.help_outline, title: 'Help Center', onTap: () {}),
              _SettingsItem(icon: Icons.info_outline, title: 'About Canopy', onTap: () {}),
              _SettingsItem(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', onTap: () {}),
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
                  title: Text('Sign Out',
                      style: TextStyle(
                          color: AppTheme.darkGreen,
                          fontWeight: FontWeight.w700)),
                  content: Text('Are you sure you want to sign out?',
                      style: TextStyle(color: AppTheme.darkGreen)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel',
                          style: TextStyle(color: AppTheme.darkGreen)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red),
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

// ─── Status dot ──────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final String status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => Colors.green,
      'pending' => Colors.amber,
      _ => Colors.grey[300]!,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─── Special Operations bottom sheet ─────────────────────────────────────────

class _SpecialOpsSheet extends StatefulWidget {
  final Map<String, dynamic>? orgData;
  final VoidCallback onChanged;

  const _SpecialOpsSheet({required this.orgData, required this.onChanged});

  @override
  State<_SpecialOpsSheet> createState() => _SpecialOpsSheetState();
}

class _SpecialOpsSheetState extends State<_SpecialOpsSheet> {
  final _communityAuth = CommunityAuthService();

  // Local status mirrors — updated optimistically after successful registration
  late String _marketplaceStatus;
  late String _envOpsStatus;
  late String _culturalStatus;

  // Marketplace
  String? _sellerRole;
  bool _applyingMarketplace = false;

  // Env Ops
  final Set<String> _envActivities = {};
  bool _applyingEnvOps = false;

  // Cultural Archive
  String? _culturalRole;
  bool _applyingCultural = false;

  static const _envActivityOptions = [
    ('market', 'Material Market', Icons.storefront_outlined),
    ('territory', 'Territory', Icons.map_outlined),
    ('trees', 'Tree Monitoring', Icons.park_outlined),
    ('fleet', 'Collector Fleet', Icons.directions_bike_outlined),
    ('credits', 'Impact Credits', Icons.verified_outlined),
  ];

  static const _culturalRoleOptions = [
    ('documentation', 'Heritage Documentation', 'Documenting and archiving community cultural knowledge'),
    ('council', 'Community Voice', 'Representing a community\'s cultural heritage interests'),
    ('research', 'Research & Education', 'Academic, archival, or educational cultural work'),
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.orgData;
    _marketplaceStatus = d?['marketplaceStatus'] as String? ?? 'none';
    _envOpsStatus = d?['envOpsStatus'] as String? ?? 'none';
    _culturalStatus = d?['culturalStatus'] as String? ?? 'none';
  }

  String? get _orgId => widget.orgData?['orgId'] as String?;

  // ── Apply methods ────────────────────────────────────────────────────────────

  Future<void> _applyForMarketplace() async {
    if (_sellerRole == null || _orgId == null) return;
    setState(() => _applyingMarketplace = true);
    try {
      await _communityAuth.applyForMarketplaceSeller(
        orgId: _orgId!,
        sellerRole: _sellerRole!,
      );
      setState(() {
        _marketplaceStatus = 'pending';
        _sellerRole = null;
      });
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snack(
          'Marketplace application submitted — you\'ll be notified when approved.',
          Colors.amber.shade700,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_errSnack());
    } finally {
      if (mounted) setState(() => _applyingMarketplace = false);
    }
  }

  Future<void> _applyForEnvOps() async {
    if (_envActivities.isEmpty || _orgId == null) return;
    setState(() => _applyingEnvOps = true);
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_orgId)
          .update({
        'envOpsStatus': 'approved',
        'envOpsActivities': _envActivities.toList(),
        'envOpsRegisteredAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _envOpsStatus = 'approved';
        _envActivities.clear();
      });
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snack(
          'Environmental Operations enabled. Use the Env Ops tab to switch.',
          const Color(0xFF2E7D5E),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_errSnack());
    } finally {
      if (mounted) setState(() => _applyingEnvOps = false);
    }
  }

  Future<void> _applyForCultural() async {
    if (_culturalRole == null || _orgId == null) return;
    setState(() => _applyingCultural = true);
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_orgId)
          .update({
        'culturalStatus': 'approved',
        'culturalRole': _culturalRole,
        'culturalRegisteredAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _culturalStatus = 'approved';
        _culturalRole = null;
      });
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snack(
          'Cultural Archive enabled. Use the Culture tab to switch.',
          const Color(0xFF7A5230),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_errSnack());
    } finally {
      if (mounted) setState(() => _applyingCultural = false);
    }
  }

  SnackBar _snack(String msg, Color bg) => SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      );

  SnackBar _errSnack() => _snack('Something went wrong. Please try again.', Colors.red.shade700);

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Text(
                      'Special Operations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.darkGreen,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Extend your organisation\'s capabilities on Canopy.',
                  style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6)),
                ),
              ),
              const Divider(height: 1),
              // Op cards
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _buildMarketplaceCard(context),
                    const SizedBox(height: 12),
                    _buildEnvOpsCard(context),
                    const SizedBox(height: 12),
                    _buildCulturalCard(context),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Marketplace card ─────────────────────────────────────────────────────────

  Widget _buildMarketplaceCard(BuildContext context) {
    return _OpCard(
      icon: Icons.storefront_outlined,
      color: AppTheme.tertiary,
      title: 'Marketplace',
      description: 'List materials, processed goods, or artisan products. Your verified org identity backs every listing.',
      status: _marketplaceStatus,
      onOpenTap: _marketplaceStatus == 'approved'
          ? () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SellerHomeScreen()),
                (r) => false,
              )
          : null,
      form: _marketplaceStatus == 'none' || _marketplaceStatus == 'rejected'
          ? _buildMarketplaceForm()
          : null,
    );
  }

  Widget _buildMarketplaceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your seller role',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen.withOpacity(0.7))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _roleChip('collector', 'Collector', AppTheme.primary,
                _sellerRole, (v) => setState(() => _sellerRole = v)),
            _roleChip('processor', 'Processor', AppTheme.accent,
                _sellerRole, (v) => setState(() => _sellerRole = v)),
            _roleChip('maker', 'Maker / Artisan', AppTheme.tertiary,
                _sellerRole, (v) => setState(() => _sellerRole = v)),
          ],
        ),
        const SizedBox(height: 14),
        _applyButton(
          label: 'Apply to Sell',
          color: AppTheme.tertiary,
          enabled: _sellerRole != null,
          loading: _applyingMarketplace,
          onTap: _applyForMarketplace,
        ),
      ],
    );
  }

  // ── Env Ops card ─────────────────────────────────────────────────────────────

  Widget _buildEnvOpsCard(BuildContext context) {
    return _OpCard(
      icon: Icons.eco_outlined,
      color: const Color(0xFF2E7D5E),
      title: 'Environmental Operations',
      description: 'Track material collection, territory, tree planting, collector fleet, and impact credits.',
      status: _envOpsStatus,
      onOpenTap: _envOpsStatus == 'approved'
          ? () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const EnvOpsShell()),
                (r) => false,
              )
          : null,
      form: _envOpsStatus == 'none' || _envOpsStatus == 'rejected'
          ? _buildEnvOpsForm()
          : null,
    );
  }

  Widget _buildEnvOpsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select the areas your org will use',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen.withOpacity(0.7))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _envActivityOptions.map((opt) {
            final (key, label, icon) = opt;
            final selected = _envActivities.contains(key);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) _envActivities.remove(key);
                else _envActivities.add(key);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2E7D5E).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2E7D5E)
                        : const Color(0xFF2E7D5E).withOpacity(0.3),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: const Color(0xFF2E7D5E)),
                    const SizedBox(width: 5),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D5E))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _applyButton(
          label: 'Enable Environmental Ops',
          color: const Color(0xFF2E7D5E),
          enabled: _envActivities.isNotEmpty,
          loading: _applyingEnvOps,
          onTap: _applyForEnvOps,
        ),
      ],
    );
  }

  // ── Cultural Archive card ────────────────────────────────────────────────────

  Widget _buildCulturalCard(BuildContext context) {
    final orgId = _orgId ?? '';
    return _OpCard(
      icon: Icons.auto_stories_outlined,
      color: const Color(0xFF7A5230),
      title: 'Cultural Archive',
      description: 'Document and preserve community heritage — oral traditions, music, craft, language, food, and more.',
      status: _culturalStatus,
      onOpenTap: _culturalStatus == 'approved'
          ? () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => CultureHomeScreen(orgId: orgId)),
                (r) => false,
              )
          : null,
      form: _culturalStatus == 'none' || _culturalStatus == 'rejected'
          ? _buildCulturalForm()
          : null,
    );
  }

  Widget _buildCulturalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your organisation\'s role',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen.withOpacity(0.7))),
        const SizedBox(height: 10),
        ..._culturalRoleOptions.map((opt) {
          final (key, label, desc) = opt;
          final selected = _culturalRole == key;
          return GestureDetector(
            onTap: () => setState(() => _culturalRole = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF7A5230).withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF7A5230)
                      : Colors.grey[300]!,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? const Color(0xFF7A5230)
                                    : AppTheme.darkGreen)),
                        const SizedBox(height: 2),
                        Text(desc,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.darkGreen.withOpacity(0.55))),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle,
                        size: 18, color: const Color(0xFF7A5230)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        _applyButton(
          label: 'Enable Cultural Archive',
          color: const Color(0xFF7A5230),
          enabled: _culturalRole != null,
          loading: _applyingCultural,
          onTap: _applyForCultural,
        ),
      ],
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Widget _roleChip(
    String key,
    String label,
    Color color,
    String? selected,
    void Function(String) onTap,
  ) {
    final active = selected == key;
    return GestureDetector(
      onTap: () => onTap(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withOpacity(0.3),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _applyButton({
    required String label,
    required Color color,
    required bool enabled,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled && !loading ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          disabledBackgroundColor: color.withOpacity(0.35),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Op card ──────────────────────────────────────────────────────────────────

class _OpCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String status;
  final VoidCallback? onOpenTap;
  final Widget? form;

  const _OpCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.status,
    this.onOpenTap,
    this.form,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'approved'
              ? color.withOpacity(0.4)
              : Colors.grey[200]!,
          width: status == 'approved' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen)),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Text(description,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.6))),

          // Approved state: open button
          if (status == 'approved' && onOpenTap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenTap,
                icon: Icon(Icons.open_in_new, size: 15, color: color),
                label: Text('Open', style: TextStyle(color: color)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],

          // Pending state
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Text('Application under review',
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade700)),
                ],
              ),
            ),
          ],

          // Registration form (not enrolled)
          if (form != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            form!,
          ],
        ],
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'approved' => ('Active', Colors.green.withOpacity(0.12), Colors.green.shade700),
      'pending' => ('Pending', Colors.amber.withOpacity(0.12), Colors.amber.shade700),
      'rejected' => ('Reapply', Colors.red.withOpacity(0.1), Colors.red.shade700),
      _ => ('Apply', AppTheme.primary.withOpacity(0.08), AppTheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

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
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.6))),
              const SizedBox(height: 2),
              Text(value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen,
                      )),
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
                      color: AppTheme.lightGreen.withOpacity(0.2)),
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

  _SettingsItem({required this.icon, required this.title, required this.onTap});
}
