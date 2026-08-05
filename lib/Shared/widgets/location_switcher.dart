// lib/Shared/widgets/location_switcher.dart
//
// The location switch that sits at the top of every localized surface — feed,
// marketplace, activities.
//
// Two pieces:
//   • LocationSwitcher  — the compact bar. Shows the active scope and opens
//     the picker. Defaults to the member's county.
//   • LocationPickerSheet — the tiered picker: Everywhere / Country / Region /
//     County / Area, drilling down, searchable at the county and area tiers.
//
// The switch never silently changes what a member is looking at. Widening to
// "Everywhere" is always one tap, and returning home is always one tap.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Geo/geo_registry.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SWITCHER BAR
// ─────────────────────────────────────────────────────────────────────────────

class LocationSwitcher extends StatelessWidget {
  /// Renders light-on-dark, for use over an image or coloured header.
  final bool onDark;

  /// Compact form for app bars — no sub-label, smaller hit area.
  final bool dense;

  final EdgeInsetsGeometry padding;

  const LocationSwitcher({
    super.key,
    this.onDark = false,
    this.dense = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final filter = provider.filter;

    final fg = onDark ? Colors.white : AppTheme.darkGreen;
    final subFg = onDark
        ? Colors.white.withOpacity(0.75)
        : AppTheme.darkGreen.withOpacity(0.6);
    final bg = onDark
        ? Colors.white.withOpacity(0.14)
        : AppTheme.lightGreen.withOpacity(0.14);
    final borderColor = onDark
        ? Colors.white.withOpacity(0.24)
        : AppTheme.lightGreen.withOpacity(0.32);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => showLocationPicker(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: dense ? 8 : 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filter.isEverywhere
                            ? Icons.public_rounded
                            : Icons.place_rounded,
                        size: dense ? 16 : 18,
                        color: onDark ? Colors.white : AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    provider.isResolving
                                        ? 'Finding your area…'
                                        : filter.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: dense ? 13 : 14.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (provider.isAtHome) ...[
                                  const SizedBox(width: 6),
                                  _HomeDot(onDark: onDark),
                                ],
                              ],
                            ),
                            if (!dense && filter.contextLabel != null)
                              Text(
                                '${filter.scope.label} · ${filter.contextLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subFg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.expand_more_rounded,
                          size: dense ? 18 : 20, color: subFg),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!filter.isEverywhere) ...[
            const SizedBox(width: 8),
            _QuickAction(
              label: 'All',
              icon: Icons.public_rounded,
              onDark: onDark,
              onTap: provider.showEverywhere,
            ),
          ] else if (provider.homeLocation?.countyId != null) ...[
            const SizedBox(width: 8),
            _QuickAction(
              label: 'My county',
              icon: Icons.my_location_rounded,
              onDark: onDark,
              onTap: provider.resetToHome,
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeDot extends StatelessWidget {
  final bool onDark;
  const _HomeDot({required this.onDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.tertiary.withOpacity(onDark ? 0.30 : 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'YOURS',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: onDark ? Colors.white : AppTheme.darkGreen,
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool onDark;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onDark
                  ? Colors.white.withOpacity(0.24)
                  : AppTheme.lightGreen.withOpacity(0.32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showLocationPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<LocationProvider>(),
      child: const LocationPickerSheet(),
    ),
  );
}

enum _PickerLevel { root, countries, regions, counties, areas }

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  _PickerLevel _level = _PickerLevel.root;
  String _query = '';

  /// Set when drilling into a specific region's counties or county's areas.
  String? _drillRegionId;
  String? _drillCountyId;

  @override
  void initState() {
    super.initState();
    GeoRegistry.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _go(_PickerLevel level, {String? regionId, String? countyId}) {
    setState(() {
      _level = level;
      _drillRegionId = regionId ?? _drillRegionId;
      _drillCountyId = countyId ?? _drillCountyId;
      _searchCtrl.clear();
      _query = '';
    });
  }

  void _apply(VoidCallback mutate) {
    mutate();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final geo = GeoRegistry.instance;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _header(provider),
              if (_level == _PickerLevel.counties ||
                  _level == _PickerLevel.areas ||
                  _level == _PickerLevel.countries)
                _searchField(),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: _body(provider, geo),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(LocationProvider provider) {
    final title = switch (_level) {
      _PickerLevel.root => 'Where are you looking?',
      _PickerLevel.countries => 'Choose a country',
      _PickerLevel.regions => 'Choose a region',
      _PickerLevel.counties => _drillRegionId != null
          ? '${GeoRegistry.instance.region(_drillRegionId)?.name ?? ''} counties'
          : 'Choose a county',
      _PickerLevel.areas =>
        '${GeoRegistry.instance.county(_drillCountyId)?.name ?? ''} areas',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          if (_level != _PickerLevel.root)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: AppTheme.darkGreen),
              onPressed: () => _go(_PickerLevel.root),
            ),
          if (_level != _PickerLevel.root) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkGreen,
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(
                  'Showing: ${provider.filter.label}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.6),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    final hint = switch (_level) {
      _PickerLevel.areas => 'Search areas',
      _PickerLevel.countries => 'Search countries',
      _ => 'Search all 47 counties',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.lightGreen.withOpacity(0.4)),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(LocationProvider provider, GeoRegistry geo) {
    switch (_level) {
      case _PickerLevel.root:
        return _rootOptions(provider, geo);

      case _PickerLevel.countries:
        final all = geo.countries
            .where((c) => _query.isEmpty ||
                c.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();
        return [
          for (final c in all)
            _Row(
              title: '${c.flag} ${c.name}'.trim(),
              subtitle: c.hasRegistry
                  ? 'Full county registry'
                  : (c.subregion ?? c.continent),
              selected: provider.filter.scope == LocationScope.country &&
                  provider.filter.anchor.countryId == c.id,
              onTap: () => _apply(() => provider.selectCountry(c.id)),
            ),
        ];

      case _PickerLevel.regions:
        return [
          for (final r in geo.regions)
            _Row(
              title: r.name,
              subtitle: '${r.countyIds.length} counties',
              selected: provider.filter.scope == LocationScope.region &&
                  provider.filter.anchor.regionId == r.id,
              trailing: IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: () =>
                    _go(_PickerLevel.counties, regionId: r.id),
              ),
              onTap: () => _apply(() => provider.selectRegion(r.id)),
            ),
        ];

      case _PickerLevel.counties:
        final pool = _drillRegionId != null
            ? geo.countiesInRegion(_drillRegionId!)
            : geo.searchCounties(_query);
        final list = _drillRegionId != null && _query.isNotEmpty
            ? pool
                .where((c) =>
                    c.name.toLowerCase().contains(_query.toLowerCase()))
                .toList()
            : pool;
        if (list.isEmpty) return [_empty('No county matches "$_query"')];
        return [
          for (final c in list)
            _Row(
              title: c.name,
              subtitle: '${c.regionName} · ${c.areas.length} areas',
              selected: provider.filter.anchor.countyId == c.id,
              isHome: provider.homeLocation?.countyId == c.id,
              trailing: c.areas.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: () =>
                          _go(_PickerLevel.areas, countyId: c.id),
                    ),
              onTap: () => _apply(() => provider.selectCounty(c.id)),
            ),
        ];

      case _PickerLevel.areas:
        final areas = geo.searchAreas(_query, countyId: _drillCountyId);
        if (areas.isEmpty) return [_empty('No areas listed here yet')];
        return [
          _Row(
            title: 'All of ${geo.county(_drillCountyId)?.name ?? 'this county'}',
            subtitle: 'County-wide',
            selected: provider.filter.scope == LocationScope.county &&
                provider.filter.anchor.countyId == _drillCountyId,
            onTap: () => _apply(() => provider.selectCounty(_drillCountyId!)),
          ),
          const SizedBox(height: 4),
          for (final a in areas)
            _Row(
              title: a.name,
              selected: provider.filter.anchor.areaId == a.id,
              onTap: () => _apply(() => provider.selectArea(a.id)),
            ),
        ];
    }
  }

  List<Widget> _rootOptions(LocationProvider provider, GeoRegistry geo) {
    final home = provider.homeLocation;
    return [
      if (home?.countyId != null)
        _Row(
          title: home!.countyName ?? '',
          subtitle: 'Your county — where you are registered',
          leading: Icons.my_location_rounded,
          selected: provider.isAtHome,
          isHome: true,
          onTap: () => _apply(provider.resetToHome),
        ),
      _Row(
        title: 'Everywhere',
        subtitle: 'Every county and country on Canopy',
        leading: Icons.public_rounded,
        selected: provider.filter.isEverywhere,
        onTap: () => _apply(provider.showEverywhere),
      ),
      const SizedBox(height: 14),
      _sectionLabel('Narrow it down'),
      _Row(
        title: 'By county',
        subtitle: 'All 47 Kenyan counties',
        leading: Icons.map_outlined,
        onTap: () => _go(_PickerLevel.counties),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
      _Row(
        title: 'By region',
        subtitle: 'Coast, Rift Valley, Nyanza, Western…',
        leading: Icons.layers_outlined,
        onTap: () => _go(_PickerLevel.regions),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
      _Row(
        title: 'By country',
        subtitle: '${geo.countries.length} countries',
        leading: Icons.flag_outlined,
        onTap: () => _go(_PickerLevel.countries),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
    ];
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 0, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: AppTheme.darkGreen.withOpacity(0.45),
          ),
        ),
      );

  Widget _empty(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final bool selected;
  final bool isHome;
  final VoidCallback onTap;

  const _Row({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.isHome = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? AppTheme.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppTheme.primary.withOpacity(0.35)
                    : AppTheme.lightGreen.withOpacity(0.22),
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(leading,
                      size: 19,
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.darkGreen.withOpacity(0.6)),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight:
                                    selected ? FontWeight.w800 : FontWeight.w600,
                                color: AppTheme.darkGreen,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isHome) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.tertiary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text('YOURS',
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                      color: AppTheme.darkGreen)),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.darkGreen.withOpacity(0.58),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null && selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 19, color: AppTheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
