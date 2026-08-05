// lib/Providers/location_provider.dart
//
// Holds the location scope every localized surface reads from — the feed, the
// marketplace, activities, and the map.
//
// Behaviour the product asks for:
//   • A member lands on THEIR county. Not "everywhere", not "Nairobi".
//   • They can widen to region, country, or everywhere, or narrow to an area.
//   • The choice sticks across app launches.
//
// Home county is derived once, in this order:
//   1. A previously saved scope (they chose it — respect it).
//   2. Their profile: Users/{uid}.geo_county_id, else the legacy free-text
//      'city' / 'location' fields run through GeoRegistry.resolve().
//   3. Their organisation's location, for org-context accounts.
//   4. Nothing — scope falls back to Everywhere rather than guessing a county
//      and quietly showing them the wrong place.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/geo/canopy_location.dart';
import '../Services/Geo/geo_registry.dart';

class LocationProvider extends ChangeNotifier {
  static const _prefsKey = 'canopy_location_filter_v1';

  LocationFilter _filter = LocationFilter.everywhere;

  /// The member's own county, resolved from their profile. Distinct from the
  /// active filter — "Reset to my county" needs to know where home is even
  /// after they've browsed elsewhere.
  CanopyLocation? _homeLocation;

  bool _ready = false;
  bool _resolving = false;

  LocationFilter get filter => _filter;
  CanopyLocation? get homeLocation => _homeLocation;
  bool get isReady => _ready;
  bool get isResolving => _resolving;

  /// True when the active filter is the member's own county — used to show the
  /// "Your county" marker on the switch.
  bool get isAtHome =>
      _homeLocation != null &&
      _filter.scope == LocationScope.county &&
      _filter.anchor.countyId == _homeLocation!.countyId;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once after auth resolves. Safe to call again on account switch.
  Future<void> initialise({String? uid, String? orgId}) async {
    _resolving = true;
    notifyListeners();

    await GeoRegistry.instance.ensureLoaded();

    // 1. Saved scope wins — it was an explicit choice.
    final saved = await _readSaved();

    // 2 & 3. Resolve home county regardless, so "reset to my county" works.
    _homeLocation = await _resolveHome(uid: uid, orgId: orgId);

    if (saved != null && (saved.isEverywhere || saved.isQueryable)) {
      _filter = saved;
    } else if (_homeLocation?.countyId != null) {
      _filter = LocationFilter(
        scope: LocationScope.county,
        anchor: _homeLocation!,
      );
    } else {
      _filter = LocationFilter.everywhere;
    }

    _ready = true;
    _resolving = false;
    notifyListeners();
  }

  Future<CanopyLocation?> _resolveHome({String? uid, String? orgId}) async {
    final geo = GeoRegistry.instance;
    final db = FirebaseFirestore.instance;

    Future<CanopyLocation?> fromDoc(DocumentReference ref) async {
      try {
        final snap = await ref.get();
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null) return null;
        final loc = geo.resolveFromDocument(data);
        return loc.isNotEmpty ? loc : null;
      } catch (_) {
        return null;
      }
    }

    if (uid != null && uid.isNotEmpty) {
      // 'Users' is the auth/profile document. 'members' and the lowercase
      // 'users' doc are checked as fallbacks — the codebase writes profile
      // fragments to all three.
      for (final path in ['Users', 'members', 'users']) {
        final loc = await fromDoc(db.collection(path).doc(uid));
        if (loc != null && loc.countyId != null) return loc;
      }
    }

    if (orgId != null && orgId.isNotEmpty) {
      final loc = await fromDoc(db.collection('organizations').doc(orgId));
      if (loc != null && loc.countyId != null) return loc;
    }

    return null;
  }

  // ── Mutation ──────────────────────────────────────────────────────────────

  void setFilter(LocationFilter next) {
    if (next == _filter) return;
    _filter = next;
    notifyListeners();
    _persist();
  }

  void showEverywhere() => setFilter(LocationFilter.everywhere);

  void selectCounty(String countyId) {
    final loc = GeoRegistry.instance.locationForCounty(countyId);
    if (loc == null) return;
    setFilter(LocationFilter(scope: LocationScope.county, anchor: loc));
  }

  void selectArea(String areaId) {
    final loc = GeoRegistry.instance.locationForArea(areaId);
    if (loc == null) return;
    setFilter(LocationFilter(scope: LocationScope.area, anchor: loc));
  }

  void selectRegion(String regionId) {
    final loc = GeoRegistry.instance.locationForRegion(regionId);
    if (loc == null) return;
    setFilter(LocationFilter(scope: LocationScope.region, anchor: loc));
  }

  void selectCountry(String countryId) {
    final loc = GeoRegistry.instance.locationForCountry(countryId);
    if (loc == null) return;
    setFilter(LocationFilter(scope: LocationScope.country, anchor: loc));
  }

  /// Widen one tier: area → county → region → country → everywhere.
  void widen() {
    switch (_filter.scope) {
      case LocationScope.area:
        setFilter(_filter.copyWith(
            scope: LocationScope.county, anchor: _filter.anchor.withoutArea));
      case LocationScope.county:
        setFilter(_filter.copyWith(scope: LocationScope.region));
      case LocationScope.region:
        setFilter(_filter.copyWith(scope: LocationScope.country));
      case LocationScope.country:
      case LocationScope.all:
        showEverywhere();
    }
  }

  /// Back to the member's own county. No-op when home is unknown.
  void resetToHome() {
    final home = _homeLocation;
    if (home?.countyId == null) return;
    setFilter(LocationFilter(scope: LocationScope.county, anchor: home!));
  }

  /// Record a member's county on their profile so the next device resolves it
  /// without a picker. Called from registration and profile editing.
  static Future<void> writeHomeLocation({
    required String uid,
    required CanopyLocation location,
    String? collection,
  }) async {
    final db = FirebaseFirestore.instance;
    final payload = {
      ...location.toFirestore(),
      'geo_updated_at': FieldValue.serverTimestamp(),
    };
    final targets = collection != null ? [collection] : ['Users', 'members'];
    for (final c in targets) {
      try {
        await db.collection(c).doc(uid).set(payload, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[LocationProvider] home write failed for $c/$uid: $e');
      }
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_filter.toJson()));
    } catch (e) {
      debugPrint('[LocationProvider] persist failed: $e');
    }
  }

  Future<LocationFilter?> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      return LocationFilter.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[LocationProvider] read failed: $e');
      return null;
    }
  }
}
