import 'package:flutter/material.dart';
import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/role_context_switcher.dart';
import 'Market/env_market.dart';
import 'Territory/env_territory.dart';
import 'Trees/env_trees.dart';
import 'Fleet/env_fleet.dart';

class EnvOpsShell extends StatefulWidget {
  /// Context-switch builders injected by the caller to avoid circular imports.
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? marketplaceContextBuilder;
  final WidgetBuilder? culturalContextBuilder;
  final bool hasMarketplace;
  final bool hasCultural;

  const EnvOpsShell({
    super.key,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.marketplaceContextBuilder,
    this.culturalContextBuilder,
    this.hasMarketplace = false,
    this.hasCultural = false,
  });

  @override
  State<EnvOpsShell> createState() => _EnvOpsShellState();
}

class _EnvOpsShellState extends State<EnvOpsShell> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        const EnvMarketScreen(),
        const EnvTerritoryScreen(),
        const EnvTreesScreen(),
        const EnvFleetScreen(),
        _EnvOpsProfileTab(
          orgContextBuilder: widget.orgContextBuilder,
          memberContextBuilder: widget.memberContextBuilder,
          marketplaceContextBuilder: widget.marketplaceContextBuilder,
          culturalContextBuilder: widget.culturalContextBuilder,
          hasMarketplace: widget.hasMarketplace,
          hasCultural: widget.hasCultural,
        ),
      ];

  static const _tabs = [
    _TabInfo('Market', Icons.storefront_outlined),
    _TabInfo('Territory', Icons.map_outlined),
    _TabInfo('Trees', Icons.park_outlined),
    _TabInfo('Fleet', Icons.local_shipping_outlined),
    _TabInfo('Profile', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F5F0),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ENVIRONMENTAL OPS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  fontSize: 14,
                  color: AppTheme.darkGreen,
                ),
              ),
              Text(
                'Market · Territory · Trees · Fleet',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.45),
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFFF7F5F0),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          height: 70,
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isActive = _selectedIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primary
                                : AppTheme.primary.withOpacity(0.10),
                            shape: BoxShape.circle,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color:
                                          AppTheme.primary.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            tab.icon,
                            size: 20,
                            color: isActive
                                ? Colors.white
                                : AppTheme.darkGreen.withOpacity(0.65),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppTheme.primary
                                : AppTheme.darkGreen.withOpacity(0.65),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Env Ops Profile tab ──────────────────────────────────────────────────────
class _EnvOpsProfileTab extends StatelessWidget {
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? marketplaceContextBuilder;
  final WidgetBuilder? culturalContextBuilder;
  final bool hasMarketplace;
  final bool hasCultural;

  const _EnvOpsProfileTab({
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.marketplaceContextBuilder,
    this.culturalContextBuilder,
    this.hasMarketplace = false,
    this.hasCultural = false,
  });

  void _switchTo(BuildContext context, WidgetBuilder? builder) {
    if (builder == null) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: builder),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.eco_outlined,
                      size: 36, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Environmental Ops',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Active context',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkGreen.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Switch context ────────────────────────────────────────────────
          if (orgContextBuilder != null || memberContextBuilder != null) ...[
            _sectionLabel('SWITCH CONTEXT'),
            const SizedBox(height: 10),
            RoleContextSwitcher(
              activeContext: 'envOps',
              hasMarketplace: hasMarketplace,
              hasEnvOps: true,
              hasCultural: hasCultural,
              onOrgTap: () => _switchTo(context, orgContextBuilder),
              onMemberTap: () => _switchTo(context, memberContextBuilder),
              onMarketplaceTap: marketplaceContextBuilder != null
                  ? () => _switchTo(context, marketplaceContextBuilder)
                  : null,
              onEnvOpsTap: () {},
              onCulturalTap: culturalContextBuilder != null
                  ? () => _switchTo(context, culturalContextBuilder)
                  : null,
            ),
            const SizedBox(height: 28),
          ],

          // ── Ops activity summary ──────────────────────────────────────────
          _sectionLabel('THIS MONTH'),
          const SizedBox(height: 10),
          _buildStatGrid(),
          const SizedBox(height: 28),

          // ── Return to org dashboard ───────────────────────────────────────
          if (orgContextBuilder != null) ...[
            _sectionLabel('ORGANISATION'),
            const SizedBox(height: 10),
            _buildReturnToOrgCard(context),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppTheme.darkGreen.withOpacity(0.45),
      ),
    );
  }

  Widget _buildReturnToOrgCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _switchTo(context, orgContextBuilder),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              child: Icon(Icons.business_outlined,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organisation Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'People, operations, programmes & settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppTheme.primary.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: const [
        _StatCard(
            label: 'Collection Zones',
            value: '—',
            icon: Icons.map_outlined),
        _StatCard(
            label: 'Trees Planted',
            value: '—',
            icon: Icons.park_outlined),
        _StatCard(
            label: 'Fleet Active',
            value: '—',
            icon: Icons.local_shipping_outlined),
        _StatCard(
            label: 'Credits Earned',
            value: '—',
            icon: Icons.verified_outlined),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkGreen)),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.darkGreen.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;

  const _TabInfo(this.label, this.icon);
}
