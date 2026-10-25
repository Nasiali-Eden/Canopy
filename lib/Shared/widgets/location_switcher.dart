// lib/Shared/widgets/location_switcher.dart
//
// The location switch at the top of every localised surface — feed,
// marketplace, activities (v2).
//
//   • LocationSwitcher — the compact bar: active scope, opens the picker.
//     Defaults to the member's county.
//   • LocationPickerSheet — tiered picker: Everywhere / Country / Region /
//     County / Area, drilling down, searchable at country, county and area.
//
// Widening to "Everywhere" and returning home are each always one tap.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Geo/geo_registry.dart';
import '../../theme/canopy_components.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SWITCHER BAR
// ─────────────────────────────────────────────────────────────────────────────

class LocationSwitcher extends StatelessWidget {
  /// Light-on-dark, for use over an image or coloured header.
  final bool onDark;

  /// Compact form — no sub-label.
  final bool dense;

  /// App-bar form: label and chevron only.
  final bool bare;

  final EdgeInsetsGeometry padding;

  const LocationSwitcher({
    super.key,
    this.onDark = false,
    this.dense = false,
    this.bare = false,
    this.padding = const EdgeInsets.symmetric(horizontal: CanopySpace.gutter, vertical: CanopySpace.s8),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final provider = context.watch<LocationProvider>();
    final filter = provider.filter;
    final fg = onDark ? Colors.white : p.ink;
    final subFg = onDark ? Colors.white.withAlpha(190) : p.inkMuted;
    final label = provider.isResolving ? 'Finding your area…' : filter.label;

    if (bare) {
      return Padding(
        padding: padding,
        child: Semantics(
          button: true,
          label: 'Location: $label. Change',
          child: InkWell(
            borderRadius: BorderRadius.circular(CanopyRadius.xs),
            onTap: () => showLocationPicker(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
              child: Row(children: [
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.label.copyWith(color: fg)),
                ),
                Icon(Icons.expand_more, size: 18, color: subFg),
              ]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Location: $label. Change',
            child: InkWell(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              onTap: () => showLocationPicker(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
                padding: EdgeInsets.symmetric(horizontal: CanopySpace.s12, vertical: dense ? CanopySpace.s4 : CanopySpace.s8),
                decoration: BoxDecoration(
                  color: onDark ? Colors.white.withAlpha(36) : p.surface,
                  borderRadius: BorderRadius.circular(CanopyRadius.sm),
                  border: Border.all(color: onDark ? Colors.white.withAlpha(60) : p.outlineStrong),
                ),
                child: Row(children: [
                  Icon(filter.isEverywhere ? Icons.public : Icons.place_outlined, size: 18, color: onDark ? Colors.white : p.primaryInk),
                  const SizedBox(width: CanopySpace.s8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Flexible(
                          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.label.copyWith(color: fg)),
                        ),
                        if (provider.isAtHome) ...[
                          const SizedBox(width: CanopySpace.s8),
                          StatusLabel('Yours', color: onDark ? Colors.white : p.primaryInk),
                        ],
                      ]),
                      if (!dense && filter.contextLabel != null)
                        Text('${filter.scope.label} · ${filter.contextLabel}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: subFg)),
                    ]),
                  ),
                  Icon(Icons.expand_more, size: 20, color: subFg),
                ]),
              ),
            ),
          ),
        ),
        if (!filter.isEverywhere) ...[
          const SizedBox(width: CanopySpace.s8),
          CanopyButton(
            label: 'All',
            variant: CanopyButtonVariant.secondary,
            size: CanopyButtonSize.compact,
            onPressed: provider.showEverywhere,
          ),
        ] else if (provider.homeLocation?.countyId != null) ...[
          const SizedBox(width: CanopySpace.s8),
          CanopyButton(
            label: 'My county',
            variant: CanopyButtonVariant.secondary,
            size: CanopyButtonSize.compact,
            onPressed: provider.resetToHome,
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showLocationPicker(BuildContext context) {
  final provider = context.read<LocationProvider>();
  return showCanopySheet<void>(
    context,
    tall: true,
    builder: (_) => ChangeNotifierProvider.value(value: provider, child: const LocationPickerSheet()),
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
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(children: [
        _header(provider),
        if (_level == _PickerLevel.counties || _level == _PickerLevel.areas || _level == _PickerLevel.countries) _searchField(),
        Divider(height: 1, color: context.canopy.outline),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
            children: _body(provider, geo),
          ),
        ),
      ]),
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

    final p = context.canopy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CanopySpace.s8, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s12),
      child: Row(children: [
        if (_level != _PickerLevel.root)
          CanopyIconButton(icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => _go(_PickerLevel.root))
        else
          const SizedBox(width: CanopySpace.s8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: CanopyType.title.copyWith(color: p.ink)),
            Text('Showing: ${provider.filter.label}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
          ]),
        ),
      ]),
    );
  }

  Widget _searchField() {
    final hint = switch (_level) {
      _PickerLevel.areas => 'Search areas',
      _PickerLevel.countries => 'Search countries',
      _ => 'Search all 47 counties',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s12),
      child: CanopyTextField(controller: _searchCtrl, hint: hint, prefixIcon: Icons.search),
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
              trailing: CanopyIconButton(icon: Icons.chevron_right, tooltip: 'Counties in ${r.name}', onPressed: () => _go(_PickerLevel.counties, regionId: r.id)),
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
                  : CanopyIconButton(icon: Icons.chevron_right, tooltip: 'Areas in ${c.name}', onPressed: () => _go(_PickerLevel.areas, countyId: c.id)),
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
        trailing: Icon(Icons.chevron_right, size: 20, color: context.canopy.inkMuted),
      ),
      _Row(
        title: 'By region',
        subtitle: 'Coast, Rift Valley, Nyanza, Western…',
        leading: Icons.layers_outlined,
        onTap: () => _go(_PickerLevel.regions),
        trailing: Icon(Icons.chevron_right, size: 20, color: context.canopy.inkMuted),
      ),
      _Row(
        title: 'By country',
        subtitle: '${geo.countries.length} countries',
        leading: Icons.flag_outlined,
        onTap: () => _go(_PickerLevel.countries),
        trailing: Icon(Icons.chevron_right, size: 20, color: context.canopy.inkMuted),
      ),
    ];
  }

  Widget _sectionLabel(String text) => CanopySectionHeader(title: text, padding: const EdgeInsets.only(top: CanopySpace.s8));

  Widget _empty(String message) => CanopyEmptyState(icon: Icons.search_off, title: message);
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
    final p = context.canopy;
    return Padding(
      padding: const EdgeInsets.only(bottom: CanopySpace.s8),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(CanopyRadius.sm),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: CanopySpace.minTouch + 8),
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s12, vertical: CanopySpace.s8),
            decoration: BoxDecoration(
              color: selected ? p.surfaceBrand : p.surface,
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              border: Border.all(color: selected ? p.ink : p.outline, width: selected ? 1.5 : 1),
            ),
            child: Row(children: [
              if (leading != null) ...[
                Icon(leading, size: 20, color: selected ? p.primaryInk : p.inkMuted),
                const SizedBox(width: CanopySpace.s12),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.label.copyWith(color: p.ink))),
                    if (isHome) ...[const SizedBox(width: CanopySpace.s8), StatusLabel('Yours', color: p.primaryInk)],
                  ]),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ]),
              ),
              if (trailing != null) trailing!,
              if (trailing == null && selected) Icon(Icons.check_circle, size: 20, color: p.primaryInk),
            ]),
          ),
        ),
      ),
    );
  }
}
