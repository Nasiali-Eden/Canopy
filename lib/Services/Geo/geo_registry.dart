// lib/Services/Geo/geo_registry.dart
//
// The canonical geography service. One load, cached for the process lifetime.
//
// Sources:
//   assets/geo/kenya.json      — 47 counties, 8 regions, 321 areas (generated
//                                from the legacy KenyaCities.json, corrected:
//                                towns folded into their parent county,
//                                Makueni added, region grouping applied)
//   assets/WorldCountries.json — 195 countries with region / subregion, used
//                                for the country tier of the location switch
//
// resolve() is the migration bridge: it takes whatever free text a legacy
// document holds ("Eldoret", "Nairobi", "Kibera", "Thika") and returns a fully
// populated CanopyLocation with canonical ids. Every write path should call it
// so new documents are queryable from day one; a backfill can call it over the
// existing corpus.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../Models/geo/canopy_location.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRY TYPES
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class GeoArea {
  final String id;
  final String name;
  final String countyId;
  final double? lat;
  final double? lng;

  /// The legacy KenyaCities.json key this area used to sit under, when that
  /// differed from its true county — e.g. "Eldoret" for areas now in
  /// Uasin Gishu. Kept so stored free-text values still resolve.
  final String? legacyCity;

  const GeoArea({
    required this.id,
    required this.name,
    required this.countyId,
    this.lat,
    this.lng,
    this.legacyCity,
  });
}

@immutable
class GeoCounty {
  final String id;
  final String name;
  final int code;
  final String regionId;
  final String regionName;
  final String countryId;
  final double? lat;
  final double? lng;
  final List<GeoArea> areas;

  const GeoCounty({
    required this.id,
    required this.name,
    required this.code,
    required this.regionId,
    required this.regionName,
    required this.countryId,
    this.lat,
    this.lng,
    this.areas = const [],
  });
}

@immutable
class GeoRegion {
  final String id;
  final String name;
  final String countryId;
  final List<String> countyIds;

  const GeoRegion({
    required this.id,
    required this.name,
    required this.countryId,
    required this.countyIds,
  });
}

@immutable
class GeoCountry {
  final String id;        // 'country_kenya' for live countries, else ISO 'NG'
  final String name;
  final String isoCode;
  final String continent; // 'Africa'
  final String? subregion;
  final String flag;

  /// True when Canopy holds a full county/area registry for this country.
  /// Only Kenya is live today; the switch shows the rest as country-tier only.
  final bool hasRegistry;

  const GeoCountry({
    required this.id,
    required this.name,
    required this.isoCode,
    required this.continent,
    this.subregion,
    this.flag = '',
    this.hasRegistry = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRY
// ─────────────────────────────────────────────────────────────────────────────

class GeoRegistry {
  GeoRegistry._();
  static final GeoRegistry instance = GeoRegistry._();

  bool _loaded = false;
  Future<void>? _loading;

  final List<GeoCountry> _countries = [];
  final List<GeoRegion> _regions = [];
  final List<GeoCounty> _counties = [];

  final Map<String, GeoCounty> _countyById = {};
  final Map<String, GeoRegion> _regionById = {};
  final Map<String, GeoCountry> _countryById = {};
  final Map<String, GeoArea> _areaById = {};

  /// Lowercased name → county. Includes the legacy town keys, so "eldoret"
  /// resolves to Uasin Gishu and "thika" to Kiambu.
  final Map<String, GeoCounty> _countyByName = {};

  /// Lowercased area name → area. First writer wins on collisions; area names
  /// repeat across counties ("Township" appears in several).
  final Map<String, GeoArea> _areaByName = {};

  final Map<String, GeoCountry> _countryByName = {};

  static const kenyaId = 'country_kenya';

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final kenyaRaw = await rootBundle.loadString('assets/geo/kenya.json');
      final kenya = jsonDecode(kenyaRaw) as Map<String, dynamic>;

      final countryJson = kenya['country'] as Map<String, dynamic>;
      final kenyaCountry = GeoCountry(
        id: countryJson['id'] as String,
        name: countryJson['name'] as String,
        isoCode: countryJson['iso_code'] as String? ?? 'KE',
        continent: countryJson['continent'] as String? ?? 'Africa',
        flag: '🇰🇪',
        hasRegistry: true,
      );
      _countries.add(kenyaCountry);
      _countryById[kenyaCountry.id] = kenyaCountry;
      _countryByName[kenyaCountry.name.toLowerCase()] = kenyaCountry;

      for (final r in (kenya['regions'] as List).cast<Map<String, dynamic>>()) {
        final region = GeoRegion(
          id: r['id'] as String,
          name: r['name'] as String,
          countryId: r['country_id'] as String? ?? kenyaId,
          countyIds: (r['county_ids'] as List?)?.cast<String>() ?? const [],
        );
        _regions.add(region);
        _regionById[region.id] = region;
      }

      for (final c in (kenya['counties'] as List).cast<Map<String, dynamic>>()) {
        final countyId = c['id'] as String;
        final areas = ((c['areas'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((a) => GeoArea(
                  id: a['id'] as String,
                  name: a['name'] as String,
                  countyId: countyId,
                  lat: (a['lat'] as num?)?.toDouble(),
                  lng: (a['lng'] as num?)?.toDouble(),
                  legacyCity: a['legacy_city'] as String?,
                ))
            .toList();

        final county = GeoCounty(
          id: countyId,
          name: c['name'] as String,
          code: (c['code'] as num?)?.toInt() ?? 0,
          regionId: c['region_id'] as String,
          regionName: c['region_name'] as String,
          countryId: c['country_id'] as String? ?? kenyaId,
          lat: (c['lat'] as num?)?.toDouble(),
          lng: (c['lng'] as num?)?.toDouble(),
          areas: areas,
        );

        _counties.add(county);
        _countyById[county.id] = county;
        _countyByName[county.name.toLowerCase()] = county;
        // Counties with punctuation get a plain alias too: "Murang'a" → "muranga".
        final plain = county.name.toLowerCase().replaceAll(RegExp(r"[^a-z ]"), '');
        _countyByName.putIfAbsent(plain, () => county);

        for (final a in areas) {
          _areaById[a.id] = a;
          _areaByName.putIfAbsent(a.name.toLowerCase(), () => a);
          if (a.legacyCity != null) {
            _countyByName.putIfAbsent(a.legacyCity!.toLowerCase(), () => county);
          }
        }
      }

      // Country tier — the rest of the world, no county registry.
      try {
        final worldRaw =
            await rootBundle.loadString('assets/WorldCountries.json');
        final world = jsonDecode(worldRaw) as Map<String, dynamic>;
        for (final c in (world['countries'] as List).cast<Map<String, dynamic>>()) {
          final name = c['name'] as String? ?? '';
          if (name.toLowerCase() == 'kenya') continue;
          final country = GeoCountry(
            id: c['id'] as String? ?? '',
            name: name,
            isoCode: c['id'] as String? ?? '',
            continent: c['region'] as String? ?? '',
            subregion: c['subregion'] as String?,
            flag: c['flag'] as String? ?? '',
          );
          _countries.add(country);
          _countryById[country.id] = country;
          _countryByName[country.name.toLowerCase()] = country;
        }
      } catch (e) {
        debugPrint('[GeoRegistry] WorldCountries.json unavailable: $e');
      }

      _loaded = true;
      debugPrint('[GeoRegistry] loaded '
          '${_counties.length} counties · ${_regions.length} regions · '
          '${_areaById.length} areas · ${_countries.length} countries');
    } catch (e, st) {
      debugPrint('[GeoRegistry] load failed: $e\n$st');
      _loaded = true; // don't wedge the app; lookups degrade to null
    }
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  bool get isLoaded => _loaded;

  List<GeoCounty> get counties => List.unmodifiable(_counties);
  List<GeoRegion> get regions => List.unmodifiable(_regions);
  List<GeoCountry> get countries => List.unmodifiable(_countries);

  /// Countries Canopy has a full registry for — currently Kenya only.
  List<GeoCountry> get liveCountries =>
      _countries.where((c) => c.hasRegistry).toList();

  GeoCounty? county(String? id) => id == null ? null : _countyById[id];
  GeoRegion? region(String? id) => id == null ? null : _regionById[id];
  GeoCountry? country(String? id) => id == null ? null : _countryById[id];
  GeoArea? area(String? id) => id == null ? null : _areaById[id];

  List<GeoCounty> countiesInRegion(String regionId) =>
      _counties.where((c) => c.regionId == regionId).toList();

  List<GeoArea> areasInCounty(String countyId) =>
      _countyById[countyId]?.areas ?? const [];

  /// Counties whose name starts with / contains [query]. Ordered so prefix
  /// matches come first — what a picker search field wants.
  List<GeoCounty> searchCounties(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return counties;
    final starts = <GeoCounty>[];
    final contains = <GeoCounty>[];
    for (final c in _counties) {
      final n = c.name.toLowerCase();
      if (n.startsWith(q)) {
        starts.add(c);
      } else if (n.contains(q)) {
        contains.add(c);
      }
    }
    return [...starts, ...contains];
  }

  List<GeoArea> searchAreas(String query, {String? countyId}) {
    final q = query.trim().toLowerCase();
    final pool = countyId != null ? areasInCounty(countyId) : _areaById.values;
    if (q.isEmpty) return pool.toList();
    return pool.where((a) => a.name.toLowerCase().contains(q)).toList();
  }

  // ── Building CanopyLocations ──────────────────────────────────────────────

  /// Fully populated location for a county id.
  CanopyLocation? locationForCounty(String countyId) {
    final c = _countyById[countyId];
    if (c == null) return null;
    return CanopyLocation(
      countryId: c.countryId,
      countryName: _countryById[c.countryId]?.name ?? 'Kenya',
      regionId: c.regionId,
      regionName: c.regionName,
      countyId: c.id,
      countyName: c.name,
      lat: c.lat,
      lng: c.lng,
    );
  }

  /// Fully populated location for an area id, including its county and region.
  CanopyLocation? locationForArea(String areaId) {
    final a = _areaById[areaId];
    if (a == null) return null;
    final base = locationForCounty(a.countyId);
    if (base == null) return null;
    return base.copyWith(
      areaId: a.id,
      areaName: a.name,
      lat: a.lat ?? base.lat,
      lng: a.lng ?? base.lng,
    );
  }

  CanopyLocation? locationForRegion(String regionId) {
    final r = _regionById[regionId];
    if (r == null) return null;
    return CanopyLocation(
      countryId: r.countryId,
      countryName: _countryById[r.countryId]?.name ?? 'Kenya',
      regionId: r.id,
      regionName: r.name,
    );
  }

  CanopyLocation? locationForCountry(String countryId) {
    final c = _countryById[countryId];
    if (c == null) return null;
    return CanopyLocation(countryId: c.id, countryName: c.name);
  }

  // ── Resolution — the legacy bridge ────────────────────────────────────────

  /// Turns whatever free text a legacy document holds into a canonical
  /// location. Tries, in order: exact area name, exact county name (including
  /// legacy town keys like "Eldoret"), country name, then a comma-split
  /// "Area, County" pass.
  ///
  /// Returns [CanopyLocation.empty] when nothing matches — callers should keep
  /// the original string in `venue` so no information is lost.
  CanopyLocation resolve({
    String? area,
    String? county,
    String? country,
    String? freeText,
    double? lat,
    double? lng,
  }) {
    CanopyLocation? result;

    // 1. Area name — the most specific signal available.
    final areaHit = _lookupArea(area) ?? _lookupArea(freeText);
    if (areaHit != null) {
      result = locationForArea(areaHit.id);
    }

    // 2. County (or legacy town) name.
    if (result == null) {
      final countyHit = _lookupCounty(county) ??
          _lookupCounty(area) ??
          _lookupCounty(freeText);
      if (countyHit != null) result = locationForCounty(countyHit.id);
    }

    // 3. "Kibera, Nairobi" / "Westlands, Nairobi" — split and retry.
    if (result == null) {
      for (final raw in [freeText, area, county]) {
        if (raw == null || !raw.contains(',')) continue;
        final parts = raw.split(',').map((s) => s.trim()).toList();
        final countyHit = _lookupCounty(parts.last);
        final areaInCounty = countyHit == null
            ? null
            : countyHit.areas.firstWhere(
                (a) => a.name.toLowerCase() == parts.first.toLowerCase(),
                orElse: () => GeoArea(
                    id: '', name: '', countyId: countyHit.id),
              );
        if (countyHit != null) {
          result = locationForCounty(countyHit.id);
          if (areaInCounty != null && areaInCounty.id.isNotEmpty) {
            result = locationForArea(areaInCounty.id);
          }
          break;
        }
        final areaHit2 = _lookupArea(parts.first);
        if (areaHit2 != null) {
          result = locationForArea(areaHit2.id);
          break;
        }
      }
    }

    // 4. Country only — a non-Kenya listing, or "Kenya" sitting in a city field
    //    (Organization.city defaults to 'Kenya', which is why this matters).
    if (result == null) {
      final countryHit =
          _lookupCountry(country) ?? _lookupCountry(county) ?? _lookupCountry(freeText);
      if (countryHit != null) result = locationForCountry(countryHit.id);
    }

    if (result == null) return CanopyLocation(lat: lat, lng: lng);
    if (lat != null && lng != null) {
      result = result.copyWith(lat: lat, lng: lng);
    }
    return result;
  }

  /// Convenience: resolve straight from a raw Firestore document map, reading
  /// whichever legacy keys it happens to carry.
  CanopyLocation resolveFromDocument(Map<String, dynamic> d) {
    final existing = CanopyLocation.fromFirestore(d);
    if (existing.countyId != null || existing.countryId != null) return existing;
    final coords = d['coordinates'] as Map<String, dynamic>?;
    return resolve(
      area: (d['area'] ?? existing.areaName) as String?,
      county: (d['city'] ?? d['county'] ?? existing.countyName) as String?,
      country: (d['country'] ?? existing.countryName) as String?,
      freeText: (d['location'] is String ? d['location'] : null) as String? ??
          (d['location_text'] ?? d['locationText']) as String?,
      lat: (coords?['lat'] as num?)?.toDouble() ?? existing.lat,
      lng: (coords?['lng'] as num?)?.toDouble() ?? existing.lng,
    );
  }

  GeoArea? _lookupArea(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    return _areaByName[name.trim().toLowerCase()];
  }

  GeoCounty? _lookupCounty(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final k = name.trim().toLowerCase();
    return _countyByName[k] ??
        _countyByName[k.replaceAll(RegExp(r'\s*county\s*$'), '')];
  }

  GeoCountry? _lookupCountry(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    return _countryByName[name.trim().toLowerCase()];
  }
}
