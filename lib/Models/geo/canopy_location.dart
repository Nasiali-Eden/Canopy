// lib/Models/geo/canopy_location.dart
//
// The single canonical location shape for the whole platform.
//
// Before this model the app carried five incompatible representations of
// "where": CommunityUser.location (free String), Organization.city (String,
// defaulting to the *country* 'Kenya'), ActivityLocation {area, city, venue},
// MarketplaceListing {city, country, continent}, and cultural_entries.locality
// {country_id, region_id, county_id, ...}. Only the last was queryable.
//
// CanopyLocation is a superset of all five and is stored FLAT on every
// document (no subcollections) so Firestore can filter on any tier with a
// single-field index:
//
//   geo_country_id : 'country_kenya'
//   geo_region_id  : 'region_nairobi'
//   geo_county_id  : 'county_nairobi'      ← the default feed / market scope
//   geo_area_id    : 'area_nairobi_kibera'
//   geo_label      : 'Kibera, Nairobi'     ← display only, never queried
//   geo_point      : GeoPoint(lat, lng)    ← map rendering + distance
//
// Writers use `toFirestore()` and spread it into the document map. Readers use
// `CanopyLocation.fromFirestore(data)`, which also understands the legacy
// shapes so nothing breaks while documents are being backfilled.

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCOPE — the tier a screen is currently filtered to
// ─────────────────────────────────────────────────────────────────────────────

enum LocationScope {
  /// Everything, everywhere. No geo predicate applied.
  all,

  /// One country, e.g. Kenya.
  country,

  /// One region within a country, e.g. Rift Valley.
  region,

  /// One county, e.g. Kiambu. This is the default a member lands on.
  county,

  /// One area / ward within a county, e.g. Kibera.
  area;

  String get label {
    switch (this) {
      case LocationScope.all:     return 'Everywhere';
      case LocationScope.country: return 'Country';
      case LocationScope.region:  return 'Region';
      case LocationScope.county:  return 'County';
      case LocationScope.area:    return 'Area';
    }
  }

  /// Firestore field this scope filters on. Null for [all] — no predicate.
  String? get fieldName {
    switch (this) {
      case LocationScope.all:     return null;
      case LocationScope.country: return 'geo_country_id';
      case LocationScope.region:  return 'geo_region_id';
      case LocationScope.county:  return 'geo_county_id';
      case LocationScope.area:    return 'geo_area_id';
    }
  }

  static LocationScope fromString(String? v) {
    return LocationScope.values.firstWhere(
      (e) => e.name == v,
      orElse: () => LocationScope.county,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CANOPY LOCATION
// ─────────────────────────────────────────────────────────────────────────────

class CanopyLocation {
  final String? countryId;
  final String? countryName;
  final String? regionId;
  final String? regionName;
  final String? countyId;
  final String? countyName;
  final String? areaId;
  final String? areaName;

  /// Free-text detail that no taxonomy covers — "Karura Forest Gate 2",
  /// "behind the Mathare bridge". Display only.
  final String? venue;

  final double? lat;
  final double? lng;

  const CanopyLocation({
    this.countryId,
    this.countryName,
    this.regionId,
    this.regionName,
    this.countyId,
    this.countyName,
    this.areaId,
    this.areaName,
    this.venue,
    this.lat,
    this.lng,
  });

  static const empty = CanopyLocation();

  bool get isEmpty => countyId == null && countryId == null && areaId == null;
  bool get isNotEmpty => !isEmpty;
  bool get hasCoordinates => lat != null && lng != null;

  /// Most specific tier this location actually resolves to.
  LocationScope get resolvedScope {
    if (areaId != null) return LocationScope.area;
    if (countyId != null) return LocationScope.county;
    if (regionId != null) return LocationScope.region;
    if (countryId != null) return LocationScope.country;
    return LocationScope.all;
  }

  /// "Kibera, Nairobi" — the label shown on cards and in the location switch.
  String get label {
    final parts = <String>[
      if (areaName != null && areaName!.isNotEmpty) areaName!,
      if (countyName != null && countyName!.isNotEmpty) countyName!,
    ];
    if (parts.isEmpty) {
      return regionName ?? countryName ?? 'Unknown location';
    }
    return parts.join(', ');
  }

  /// Short label for chips — the most specific single name available.
  String get shortLabel {
    if (areaName != null && areaName!.isNotEmpty) return areaName!;
    if (countyName != null && countyName!.isNotEmpty) return countyName!;
    if (regionName != null && regionName!.isNotEmpty) return regionName!;
    return countryName ?? 'Everywhere';
  }

  /// The id this location would be filtered by at [scope].
  String? idForScope(LocationScope scope) {
    switch (scope) {
      case LocationScope.all:     return null;
      case LocationScope.country: return countryId;
      case LocationScope.region:  return regionId;
      case LocationScope.county:  return countyId;
      case LocationScope.area:    return areaId;
    }
  }

  CanopyLocation copyWith({
    String? countryId,
    String? countryName,
    String? regionId,
    String? regionName,
    String? countyId,
    String? countyName,
    String? areaId,
    String? areaName,
    String? venue,
    double? lat,
    double? lng,
  }) {
    return CanopyLocation(
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      regionId: regionId ?? this.regionId,
      regionName: regionName ?? this.regionName,
      countyId: countyId ?? this.countyId,
      countyName: countyName ?? this.countyName,
      areaId: areaId ?? this.areaId,
      areaName: areaName ?? this.areaName,
      venue: venue ?? this.venue,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  /// Drops the area tier — used when a member widens the switch from area to
  /// county without re-picking their county.
  CanopyLocation get withoutArea => CanopyLocation(
        countryId: countryId,
        countryName: countryName,
        regionId: regionId,
        regionName: regionName,
        countyId: countyId,
        countyName: countyName,
        venue: venue,
        lat: lat,
        lng: lng,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Flat map to be spread into any Firestore document:
  ///   `{...listing.toMap(), ...location.toFirestore()}`
  Map<String, dynamic> toFirestore() => {
        'geo_country_id': countryId,
        'geo_country_name': countryName,
        'geo_region_id': regionId,
        'geo_region_name': regionName,
        'geo_county_id': countyId,
        'geo_county_name': countyName,
        'geo_area_id': areaId,
        'geo_area_name': areaName,
        'geo_venue': venue,
        'geo_label': label,
        if (lat != null && lng != null) 'geo_point': GeoPoint(lat!, lng!),
      };

  /// Reads the canonical fields. Falls back to the legacy shapes so documents
  /// written before the geo migration still render — they simply cannot be
  /// filtered until backfilled.
  factory CanopyLocation.fromFirestore(Map<String, dynamic> d) {
    if (d['geo_county_id'] != null || d['geo_country_id'] != null) {
      final pt = d['geo_point'];
      return CanopyLocation(
        countryId: d['geo_country_id'] as String?,
        countryName: d['geo_country_name'] as String?,
        regionId: d['geo_region_id'] as String?,
        regionName: d['geo_region_name'] as String?,
        countyId: d['geo_county_id'] as String?,
        countyName: d['geo_county_name'] as String?,
        areaId: d['geo_area_id'] as String?,
        areaName: d['geo_area_name'] as String?,
        venue: d['geo_venue'] as String?,
        lat: pt is GeoPoint ? pt.latitude : (d['geo_lat'] as num?)?.toDouble(),
        lng: pt is GeoPoint ? pt.longitude : (d['geo_lng'] as num?)?.toDouble(),
      );
    }
    return CanopyLocation.fromLegacy(d);
  }

  /// Best-effort read of the five pre-migration shapes. Produces names only —
  /// ids are resolved separately by GeoRegistry.resolve(), which needs the
  /// asset registry loaded.
  factory CanopyLocation.fromLegacy(Map<String, dynamic> d) {
    // ActivityLocation: {area, city, venue, coordinates:{lat,lng}}
    final coords = d['coordinates'] as Map<String, dynamic>?;
    // Organization / member: 'city'. Marketplace: 'city' + 'country'.
    // CommunityUser: 'location' (single free string).
    final legacyPoint = d['location'];
    return CanopyLocation(
      countryName: d['country'] as String?,
      countyName: (d['city'] ?? d['county']) as String?,
      areaName: (d['area'] ??
              (d['location'] is String ? d['location'] : null))
          as String?,
      venue: (d['venue'] ?? d['location_text'] ?? d['locationText']) as String?,
      lat: (coords?['lat'] as num?)?.toDouble() ??
          (legacyPoint is GeoPoint ? legacyPoint.latitude : null),
      lng: (coords?['lng'] as num?)?.toDouble() ??
          (legacyPoint is GeoPoint ? legacyPoint.longitude : null),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CanopyLocation &&
      other.countryId == countryId &&
      other.regionId == regionId &&
      other.countyId == countyId &&
      other.areaId == areaId;

  @override
  int get hashCode => Object.hash(countryId, regionId, countyId, areaId);

  @override
  String toString() => 'CanopyLocation($label)';
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE SCOPE — what the location switch is currently set to
//
// Distinct from CanopyLocation: a location is *where something is*, a scope is
// *what the member is currently looking at*. The switch mutates the scope; the
// documents carry the location.
// ─────────────────────────────────────────────────────────────────────────────

class LocationFilter {
  final LocationScope scope;

  /// The place the scope is anchored to. Ignored when scope is [all].
  final CanopyLocation anchor;

  const LocationFilter({
    this.scope = LocationScope.county,
    this.anchor = CanopyLocation.empty,
  });

  static const everywhere =
      LocationFilter(scope: LocationScope.all, anchor: CanopyLocation.empty);

  bool get isEverywhere => scope == LocationScope.all;

  /// The Firestore field this filter queries, or null for no predicate.
  String? get field => scope.fieldName;

  /// The value this filter matches, or null for no predicate.
  String? get value => anchor.idForScope(scope);

  /// True when this filter can actually be pushed into a Firestore query.
  /// A county scope with no county resolved falls back to no predicate rather
  /// than silently returning zero results.
  bool get isQueryable => field != null && value != null;

  /// Label for the switch chip: "Kiambu", "Rift Valley", "Kenya", "Everywhere".
  String get label {
    if (isEverywhere) return 'Everywhere';
    switch (scope) {
      case LocationScope.country:
        return anchor.countryName ?? 'Country';
      case LocationScope.region:
        return anchor.regionName ?? 'Region';
      case LocationScope.county:
        return anchor.countyName ?? 'Select county';
      case LocationScope.area:
        return anchor.areaName ?? 'Select area';
      case LocationScope.all:
        return 'Everywhere';
    }
  }

  /// Sub-label giving the parent context: "Kiambu · Central".
  String? get contextLabel {
    switch (scope) {
      case LocationScope.area:   return anchor.countyName;
      case LocationScope.county: return anchor.regionName;
      case LocationScope.region: return anchor.countryName;
      default: return null;
    }
  }

  LocationFilter copyWith({LocationScope? scope, CanopyLocation? anchor}) =>
      LocationFilter(
        scope: scope ?? this.scope,
        anchor: anchor ?? this.anchor,
      );

  Map<String, dynamic> toJson() => {
        'scope': scope.name,
        'country_id': anchor.countryId,
        'country_name': anchor.countryName,
        'region_id': anchor.regionId,
        'region_name': anchor.regionName,
        'county_id': anchor.countyId,
        'county_name': anchor.countyName,
        'area_id': anchor.areaId,
        'area_name': anchor.areaName,
      };

  factory LocationFilter.fromJson(Map<String, dynamic> j) => LocationFilter(
        scope: LocationScope.fromString(j['scope'] as String?),
        anchor: CanopyLocation(
          countryId: j['country_id'] as String?,
          countryName: j['country_name'] as String?,
          regionId: j['region_id'] as String?,
          regionName: j['region_name'] as String?,
          countyId: j['county_id'] as String?,
          countyName: j['county_name'] as String?,
          areaId: j['area_id'] as String?,
          areaName: j['area_name'] as String?,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is LocationFilter && other.scope == scope && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(scope, anchor);
}
