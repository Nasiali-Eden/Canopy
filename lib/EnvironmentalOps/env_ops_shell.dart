import 'package:flutter/material.dart';
import '../Shared/theme/app_theme.dart';
import 'Market/env_market.dart';
import 'Territory/env_territory.dart';
import 'Trees/env_trees.dart';
import 'Fleet/env_fleet.dart';
import 'Verified/env_verified.dart';

class EnvOpsShell extends StatefulWidget {
  const EnvOpsShell({super.key});

  @override
  State<EnvOpsShell> createState() => _EnvOpsShellState();
}

class _EnvOpsShellState extends State<EnvOpsShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const EnvMarketScreen(),
    const EnvTerritoryScreen(),
    const EnvTreesScreen(),
    const EnvFleetScreen(),
    const EnvVerifiedScreen(),
  ];

  final List<_TabInfo> _tabs = [
    _TabInfo('Market', Icons.storefront_outlined),
    _TabInfo('Territory', Icons.map_outlined),
    _TabInfo('Trees', Icons.park_outlined),
    _TabInfo('Fleet', Icons.local_shipping_outlined),
    _TabInfo('Verified', Icons.verified_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: AppTheme.darkGreen,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
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
              'Market · Territory · Trees · Fleet · Verified',
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
                                    color: AppTheme.primary.withOpacity(0.25),
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
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;

  _TabInfo(this.label, this.icon);
}
