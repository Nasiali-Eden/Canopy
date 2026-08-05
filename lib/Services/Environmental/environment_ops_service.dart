import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:impact_trail/Models/environmental/enums/fleet_collector_status.dart';
import 'package:impact_trail/Models/environmental/enums/material_category.dart';
import 'package:impact_trail/Models/environmental/enums/material_order_status.dart';
import 'package:impact_trail/Models/environmental/enums/payment_method.dart';
import 'package:impact_trail/Models/environmental/enums/tree_species.dart';
import 'package:impact_trail/Models/environmental/enums/tree_status.dart';
import 'package:impact_trail/Models/environmental/enums/verification_tier.dart';
import 'package:impact_trail/Models/environmental/models/collection_handoff.dart';
import 'package:impact_trail/Models/environmental/models/collection_zone.dart';
import 'package:impact_trail/Models/environmental/models/environmental_credit.dart';
import 'package:impact_trail/Models/environmental/models/fleet_collector.dart';
import 'package:impact_trail/Models/environmental/models/market_order.dart';
import 'package:impact_trail/Models/environmental/models/transformation_record_summary.dart';
import 'package:impact_trail/Models/environmental/models/tree_record.dart';
import 'package:impact_trail/Models/environmental/shared/gps_coordinate.dart';
import 'package:impact_trail/Models/geo/canopy_location.dart';
import 'package:impact_trail/Models/marketplace/canopy_listing.dart';
import 'package:impact_trail/Services/Geo/geo_registry.dart';
import 'package:impact_trail/Services/Marketplace/listing_service.dart';

class EnvironmentOpsContext {
  final String uid;
  final String orgId;
  final Map<String, dynamic> orgData;

  const EnvironmentOpsContext({
    required this.uid,
    required this.orgId,
    required this.orgData,
  });

  String get orgName =>
      (orgData['org_name'] ?? orgData['name'] ?? 'Organisation') as String;

  String get area =>
      (orgData['area'] ?? orgData['city'] ?? 'Unspecified area') as String;
}

class VerificationSnapshot {
  final VerificationTier tier;
  final int zoneCount;
  final int activeOrders;
  final double plasticKgVerified;
  final int totalTrees;
  final int treesConfirmed90Day;
  final int transformationsLogged;
  final int transformationsHolding;
  final int issuedCredits;
  final List<TransformationRecordSummary> transformations;
  final List<EnvironmentalCredit> credits;

  const VerificationSnapshot({
    required this.tier,
    required this.zoneCount,
    required this.activeOrders,
    required this.plasticKgVerified,
    required this.totalTrees,
    required this.treesConfirmed90Day,
    required this.transformationsLogged,
    required this.transformationsHolding,
    required this.issuedCredits,
    required this.transformations,
    required this.credits,
  });
}

class EnvironmentOpsService {
  EnvironmentOpsService._();

  static final EnvironmentOpsService instance = EnvironmentOpsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _orgs =>
      _db.collection('organizations');

  Future<EnvironmentOpsContext?> resolveContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    var userDoc = await _db.collection('Users').doc(uid).get();
    if (!userDoc.exists) {
      userDoc = await _db.collection('users').doc(uid).get();
    }
    final orgId = userDoc.data()?['orgId'] as String?;
    if (orgId == null || orgId.isEmpty) return null;

    final orgDoc = await _orgs.doc(orgId).get();
    return EnvironmentOpsContext(
      uid: uid,
      orgId: orgId,
      orgData: orgDoc.data() ?? const <String, dynamic>{},
    );
  }

  Future<void> createZone({
    required String orgId,
    required String uid,
    required String name,
    required List<LatLng> vertices,
    required double areaKm2,
  }) async {
    final zoneRef = _orgs.doc(orgId).collection('collectionZones').doc();
    final legacyRef = _db.collection('collection_zones').doc(zoneRef.id);
    final now = DateTime.now();
    final polygon = _buildPolygon(vertices, areaKm2);

    final zone = CollectionZone(
      zoneId: zoneRef.id,
      orgId: orgId,
      label: name,
      polygon: polygon,
      schedule: const ZoneSchedule(
        days: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
        startTime: '06:00',
        endTime: '18:00',
        timezone: 'Africa/Nairobi',
      ),
      materialTypes: const <String>[],
      linkedOrderIds: const <String>[],
      isActive: true,
      color: '#2D7A4F',
      stats: const ZoneStats(
        totalCollectionsLogged: 0,
        totalKgVerified: 0,
        activeMonths: 0,
      ),
      creditEligibility: const ZoneCreditEligibility(
        monthsActive: 0,
        thresholdMet: false,
        plasticCreditEligibleKg: 0,
      ),
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
    );

    final batch = _db.batch();
    batch.set(zoneRef, zone.toFirestore());
    batch.set(legacyRef, {
      'name': name,
      'vertices': vertices
          .map((point) => {
                'lat': point.latitude,
                'lng': point.longitude,
              })
          .toList(),
      'created_at': Timestamp.fromDate(now),
      'created_by': uid,
      'org_id': orgId,
      'status': 'active',
      'area_km2': areaKm2,
    });
    await batch.commit();
  }

  Future<void> createMarketOrder({
    required String orgId,
    required String uid,
    required String orgName,
    required MarketOrderType orderType,
    required MaterialCategory category,
    required String categoryLabel,
    required String materialType,
    required String materialSubTypeId,
    String? grade,
    required double quantityKg,
    required String unit,
    required double pricePerUnit,
    String? notes,
    required String locationText,
    required bool canCollect,
    required bool canDeliver,
    String? imageUrl,
    bool isRecurring = false,
  }) async {
    final orderRef = _orgs.doc(orgId).collection('marketOrders').doc();
    final legacyRef = _db.collection('market_listings').doc(orderRef.id);
    final now = DateTime.now();

    final order = MarketOrder(
      orderId: orderRef.id,
      orgId: orgId,
      orderType: orderType,
      material: MarketOrderMaterial(
        category: category,
        type: materialType,
        grade: grade,
        conditionNotes: notes,
      ),
      pricing: MarketOrderPricing(
        pricePerKg: pricePerUnit,
        currency: 'KES',
        negotiable: false,
      ),
      quantity: MarketOrderQuantity(
        minimumKg: quantityKg,
        maximumKg: quantityKg,
        filledKg: 0,
      ),
      zone: MarketOrderZone(
        zoneIds: const <String>[],
        zoneLabels: <String>[locationText].where((e) => e.isNotEmpty).toList(),
        acceptsDelivery: canDeliver,
        willCollect: canCollect,
      ),
      responses: const MarketOrderResponses(count: 0, respondentUids: <String>[]),
      status: MaterialOrderStatus.active,
      notes: notes,
      expiresAt: now.add(const Duration(days: 30)),
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
    );

    // Resolve the free-text location onto the canonical registry so this
    // order is reachable from the county / region / country tiers of the
    // location switch. Falls back to the org's own registered location, then
    // to keeping the raw string as a display-only venue.
    await GeoRegistry.instance.ensureLoaded();
    var location = GeoRegistry.instance.resolve(freeText: locationText);
    if (location.countyId == null) {
      try {
        final orgSnap = await _orgs.doc(orgId).get();
        final orgData = orgSnap.data();
        if (orgData != null) {
          location = GeoRegistry.instance.resolveFromDocument(orgData);
        }
      } catch (_) {/* keep the unresolved location */}
    }
    if (location.venue == null && locationText.isNotEmpty) {
      location = location.copyWith(venue: locationText);
    }

    // The public, browsable record. This is what every member sees in the
    // marketplace — including buy orders, which were previously visible only
    // to the posting organisation because env_market filtered on org_id.
    final publicRef = _db.collection(ListingService.collectionPath).doc(orderRef.id);
    final listing = CanopyListing(
      id: orderRef.id,
      side: ListingSide.supply,
      intent: orderType == MarketOrderType.buy
          ? ListingIntent.seeking
          : ListingIntent.offering,
      status: ListingStatus.active,
      title: materialType.isNotEmpty ? materialType : categoryLabel,
      story: notes ?? '',
      tagline: categoryLabel,
      category: ListingCategory.materials,
      materialSubTypeId: materialSubTypeId,
      materialGrade: grade,
      images: [if (imageUrl != null && imageUrl.isNotEmpty) imageUrl],
      seller: SellerSnapshot(
        sellerId: uid,
        shopName: orgName,
        city: location.countyName ?? '',
        country: location.countryName ?? 'Kenya',
      ),
      orgId: orgId,
      orgName: orgName,
      postedByUid: uid,
      pricing: ListingPricing(
        amountKes: pricePerUnit,
        unit: unit.toLowerCase() == 'kg' ? PriceUnit.perKg : PriceUnit.perItem,
      ),
      quantity: ListingQuantity(
        quantityKg: quantityKg,
        minimumKg: quantityKg,
        filledKg: 0,
        stockCount: 1,
      ),
      fulfilment: ListingFulfilment(
        willCollect: canCollect,
        acceptsDelivery: canDeliver,
        isRecurring: isRecurring,
      ),
      location: location,
      createdAt: now,
      updatedAt: now,
      // Recurring buy orders are standing requests and never go stale.
      expiresAt: isRecurring ? null : now.add(const Duration(days: 30)),
    );

    final batch = _db.batch();
    batch.set(orderRef, order.toFirestore());
    batch.set(publicRef, listing.toFirestore());
    batch.set(legacyRef, {
      'listing_type': switch (orderType) {
        MarketOrderType.buy => isRecurring ? 'recurring_buy' : 'buy_order',
        MarketOrderType.sell => 'sell_listing',
      },
      // Written so the retired collection stays readable during migration.
      // Nothing reads market_listings after the backfill — delete this block
      // and legacyRef together once the corpus is converted.
      ...location.toFirestore(),
      'is_recurring': isRecurring,
      'category_id': category.firestoreKey,
      'category_label': categoryLabel,
      'sub_type_id': materialSubTypeId,
      'sub_type_label': materialType,
      'grade': grade,
      'quantity_kg': quantityKg,
      'unit': unit,
      'price_per_unit': pricePerUnit,
      'currency': 'KSh',
      'notes': notes,
      'location_text': locationText,
      'can_collect': canCollect,
      'can_deliver': canDeliver,
      'image_url': imageUrl,
      'org_id': orgId,
      'org_name': orgName,
      'posted_by_uid': uid,
      'status': 'active',
      'created_at': Timestamp.fromDate(now),
      'responses_count': 0,
    });
    await batch.commit();
  }

  Future<void> addCollector({
    required String orgId,
    required String uid,
    required String name,
    String? zone,
    String? phone,
    required FleetCollectorStatus status,
  }) async {
    final collectorRef = _orgs.doc(orgId).collection('fleetCollectors').doc();
    final legacyRef = _db.collection('collectors').doc(collectorRef.id);
    final now = DateTime.now();

    final zoneLabels = <String>[if (zone != null && zone.trim().isNotEmpty) zone.trim()];

    final collector = FleetCollector(
      fleetMemberId: collectorRef.id,
      orgId: orgId,
      collectorUid: 'manual:${phone?.trim().isNotEmpty == true ? phone!.trim() : collectorRef.id}',
      profile: FleetCollectorProfile(
        displayName: name,
        phoneNumber: phone?.trim().isEmpty == true ? null : phone?.trim(),
      ),
      assignment: FleetAssignment(
        assignedZoneIds: const <String>[],
        assignedZoneLabels: zoneLabels,
      ),
      status: status,
      statusUpdatedAt: now,
      statusUpdatedBy: uid,
      routeSharing: const FleetRouteSharing(enabled: false),
      stats: const FleetStats(
        thisMonthKg: 0,
        thisMonthTransactions: 0,
        thisMonthEarningsKes: 0,
        totalKgAllTime: 0,
        totalTransactionsAllTime: 0,
        totalEarningsKesAllTime: 0,
        royaltiesReceivedKesAllTime: 0,
      ),
      joinedFleetAt: now,
      invitedBy: uid,
    );

    final batch = _db.batch();
    batch.set(collectorRef, collector.toFirestore());
    batch.set(legacyRef, {
      'org_id': orgId,
      'name': name,
      'zone': zone?.trim(),
      'phone': phone?.trim(),
      'status': _legacyCollectorStatus(status),
      'created_by': uid,
      'created_at': Timestamp.fromDate(now),
    });
    await batch.commit();
  }

  Future<void> logCollectionHandoff({
    required String orgId,
    required String uid,
    required String collectorId,
    required String collectorName,
    required double weightKg,
    required String materialType,
    MaterialCategory? category,
    String? grade,
    double pricePerKg = 0,
    PaymentMethod paymentMethod = PaymentMethod.mpesa,
    String? locationLabel,
    double? lat,
    double? lng,
    DateTime? deliveredAt,
  }) async {
    final handoffRef = _orgs.doc(orgId).collection('collectionHandoffs').doc();
    final legacyRef = _db.collection('collection_handoffs').doc(handoffRef.id);
    final transactionRef = _db.collection('marketplace_transactions').doc(handoffRef.id);
    final when = deliveredAt ?? DateTime.now();
    final resolvedCategory = category ?? _guessMaterialCategory(materialType);
    final totalPaidKes = pricePerKg * weightKg;
    final impactPoints = _impactPointsFor(resolvedCategory, materialType, weightKg);

    final handoff = CollectionHandoff(
      handoffId: handoffRef.id,
      orgId: orgId,
      collectorUid: collectorId,
      material: HandoffMaterial(
        category: resolvedCategory,
        type: materialType,
        grade: grade,
        weightKg: weightKg,
        impactScore: math.min(100, impactPoints / 2).toDouble(),
      ),
      financials: HandoffFinancials(
        pricePerKg: pricePerKg,
        totalPaidKes: totalPaidKes,
        impactPointsAwarded: impactPoints,
        softPlasticBonus: _isSoftPlastic(materialType),
        paymentMethod: paymentMethod,
        paidAt: when,
      ),
      location: HandoffLocation(
        lat: lat ?? 0,
        lng: lng ?? 0,
        label: locationLabel?.trim().isEmpty == true
            ? 'Collection hub'
            : (locationLabel?.trim() ?? 'Collection hub'),
      ),
      linkedTransactionId: transactionRef.id,
      loggedAt: when,
      loggedBy: uid,
    );

    final batch = _db.batch();
    batch.set(handoffRef, handoff.toFirestore());
    batch.set(legacyRef, {
      'org_id': orgId,
      'collector_id': collectorId,
      'collector_name': collectorName,
      'kg': weightKg,
      'material': materialType,
      'delivered_at': Timestamp.fromDate(when),
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
    });
    batch.set(transactionRef, {
      'orgId': orgId,
      'collectorUid': collectorId,
      'collectorName': collectorName,
      'weightKg': weightKg,
      'materialType': materialType,
      'materialCategory': resolvedCategory.firestoreKey,
      'totalPaidKes': totalPaidKes,
      'loggedAt': Timestamp.fromDate(when),
      'handoffId': handoffRef.id,
      'createdBy': uid,
    });
    await batch.commit();
  }

  Future<void> createTreePlanting({
    required String orgId,
    required String uid,
    required String speciesName,
    required int quantity,
    required DateTime plantedDate,
    required double lat,
    required double lng,
    required List<String> photoUrls,
    required String area,
    String? zoneId,
    List<LatLng>? zoneVertices,
  }) async {
    final species = _resolveTreeSpecies(speciesName);
    final now = DateTime.now();
    final legacyRef = _db.collection('planting_posts').doc();

    WriteBatch batch = _db.batch();
    var opCount = 0;
    Future<void> flushBatch() async {
      if (opCount == 0) return;
      await batch.commit();
      batch = _db.batch();
      opCount = 0;
    }

    for (var i = 0; i < quantity; i++) {
      if (opCount >= 395) {
        await flushBatch();
      }
      final treeRef = _orgs.doc(orgId).collection('trees').doc();
      final tree = TreeRecord(
        treeId: treeRef.id,
        treeRef: _treeRefFor(now, i),
        orgId: orgId,
        species: species,
        commonName: species.displayLabel,
        planting: TreePlanting(
          plantedAt: plantedDate,
          plantedBy: uid,
          location: TreePlantingLocation(
            lat: lat,
            lng: lng,
            area: area,
            zoneId: zoneId,
          ),
        ),
        survival: const TreeSurvival(
          survivalConfirmed90Day: false,
          creditEligible: false,
        ),
        status: TreeStatus.unconfirmed,
        statusUpdatedAt: now,
        statusUpdatedBy: uid,
        updateSchedule: TreeUpdateSchedule(
          nextUpdateDueAt: plantedDate.add(const Duration(days: 30)),
          updateIntervalDays: 30,
          overdueThresholdDays: 30,
          criticalThresholdDays: 60,
        ),
        monthlyUpdates: const [],
        updateCount: 0,
        notes: quantity > 1 ? 'Planted in batch of $quantity trees' : null,
        createdAt: now,
      );
      batch.set(treeRef, tree.toFirestore());
      opCount++;
    }

    batch.set(legacyRef, {
      'species': speciesName.trim(),
      'quantity': quantity,
      'planted_date': Timestamp.fromDate(plantedDate),
      'lat': lat,
      'lng': lng,
      'photo_urls': photoUrls,
      'stage': 'pending',
      'created_by': uid,
      'created_at': Timestamp.fromDate(now),
      'follow_up_30': Timestamp.fromDate(now.add(const Duration(days: 30))),
      'follow_up_90': Timestamp.fromDate(now.add(const Duration(days: 90))),
      if (zoneVertices != null && zoneVertices.isNotEmpty)
        'zone_vertices': zoneVertices
            .map((point) => {'lat': point.latitude, 'lng': point.longitude})
            .toList(),
    });
    opCount++;
    await flushBatch();
  }

  Future<void> createTransformationRecord({
    required String orgId,
    required String siteLabel,
    required String area,
    required DateTime interventionDate,
    String category = 'dumpsite_transformation',
  }) async {
    final ref = _db.collection('transformation_records').doc();
    final record = TransformationRecordSummary(
      transformationId: ref.id,
      category: category,
      locationArea: area,
      siteLabel: siteLabel,
      interventionDate: interventionDate,
      stage1: TransformationStage(
        confirmed: true,
        confirmedAt: interventionDate,
      ),
      stage2: const TransformationStage(confirmed: false),
      stage3: TransformationStage3(
        confirmed: false,
        followUpDueAt: interventionDate.add(const Duration(days: 30)),
      ),
      creditIssued: false,
    );

    await ref.set({
      ...record.toFirestore(),
      'orgId': orgId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<VerificationSnapshot> fetchVerificationSnapshot({
    required String orgId,
    required String uid,
  }) async {
    final creditsQuery = _db
        .collection('environmental_credits')
        .where('issuedTo', isEqualTo: orgId)
        .get();
    final transformationsQuery = _db
        .collection('transformation_records')
        .where('orgId', isEqualTo: orgId)
        .get();
    final zoneCountQuery = _orgs.doc(orgId).collection('collectionZones').count().get();
    final orderCountQuery = _orgs.doc(orgId).collection('marketOrders').count().get();
    final handoffsQuery =
        _orgs.doc(orgId).collection('collectionHandoffs').get();
    final treesQuery = _orgs.doc(orgId).collection('trees').get();
    final legacyZonesQuery = _db
        .collection('collection_zones')
        .where('org_id', isEqualTo: orgId)
        .count()
        .get();
    final legacyOrdersQuery = _db
        .collection('market_listings')
        .where('org_id', isEqualTo: orgId)
        .get();
    final legacyHandoffsQuery = _db
        .collection('collection_handoffs')
        .where('org_id', isEqualTo: orgId)
        .get();
    final legacyTreesQuery = _db
        .collection('planting_posts')
        .where('created_by', isEqualTo: uid)
        .get();

    final results = await Future.wait<dynamic>([
      creditsQuery,
      transformationsQuery,
      zoneCountQuery,
      orderCountQuery,
      handoffsQuery,
      treesQuery,
      legacyZonesQuery,
      legacyOrdersQuery,
      legacyHandoffsQuery,
      legacyTreesQuery,
    ]);

    final creditSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final transformationSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final zoneCountSnap = results[2] as AggregateQuerySnapshot;
    final orderCountSnap = results[3] as AggregateQuerySnapshot;
    final handoffSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final treeSnap = results[5] as QuerySnapshot<Map<String, dynamic>>;
    final legacyZoneCountSnap = results[6] as AggregateQuerySnapshot;
    final legacyOrderSnap = results[7] as QuerySnapshot<Map<String, dynamic>>;
    final legacyHandoffSnap = results[8] as QuerySnapshot<Map<String, dynamic>>;
    final legacyTreeSnap = results[9] as QuerySnapshot<Map<String, dynamic>>;

    final credits = creditSnap.docs.map(EnvironmentalCredit.fromFirestore).toList()
      ..sort((a, b) => (b.issuedAt ?? DateTime(1970))
          .compareTo(a.issuedAt ?? DateTime(1970)));
    final transformations = transformationSnap.docs
        .map(TransformationRecordSummary.fromFirestore)
        .toList()
      ..sort((a, b) => (b.interventionDate ?? DateTime(1970))
          .compareTo(a.interventionDate ?? DateTime(1970)));

    final newZoneCount = zoneCountSnap.count ?? 0;
    final legacyZoneCount = legacyZoneCountSnap.count ?? 0;
    final zoneCount = newZoneCount > 0 ? newZoneCount : legacyZoneCount;

    final newOrderCount = orderCountSnap.count ?? 0;
    final legacyOrderCount = legacyOrderSnap.docs.where((doc) {
      final data = doc.data();
      return (data['status'] as String? ?? 'active') == 'active';
    }).length;
    final activeOrders = newOrderCount > 0 ? newOrderCount : legacyOrderCount;

    final newPlasticKg = handoffSnap.docs.fold<double>(0, (sum, doc) {
      final data = doc.data();
      final material = (data['material'] as Map<String, dynamic>?) ?? const {};
      return sum + ((material['weightKg'] as num?)?.toDouble() ?? 0);
    });
    final legacyPlasticKg = legacyHandoffSnap.docs.fold<double>(0, (sum, doc) {
      final data = doc.data();
      return sum + ((data['kg'] as num?)?.toDouble() ?? 0);
    });
    final plasticKgVerified = newPlasticKg > 0 ? newPlasticKg : legacyPlasticKg;

    var totalTrees = treeSnap.size;
    var treesConfirmed90Day = treeSnap.docs.where((doc) {
      final data = doc.data();
      final survival = (data['survival'] as Map<String, dynamic>?) ?? const {};
      return (survival['survivalConfirmed90Day'] as bool?) ?? false;
    }).length;

    if (totalTrees == 0 && legacyTreeSnap.docs.isNotEmpty) {
      totalTrees = legacyTreeSnap.docs.fold<int>(0, (sum, doc) {
        return sum + ((doc.data()['quantity'] as num?)?.toInt() ?? 0);
      });
      treesConfirmed90Day = legacyTreeSnap.docs.fold<int>(0, (sum, doc) {
        final data = doc.data();
        final isFull = (data['stage'] as String? ?? '') == 'full';
        final qty = (data['quantity'] as num?)?.toInt() ?? 0;
        return sum + (isFull ? qty : 0);
      });
    }

    final transformationsHolding = transformations.where((record) {
      return record.stage3.confirmed &&
          (record.stage3.siteHeld ?? false) &&
          !record.creditIssued;
    }).length;

    final tier = _estimateTier(
      zoneCount: zoneCount,
      activeOrders: activeOrders,
      plasticKgVerified: plasticKgVerified,
      treesConfirmed90Day: treesConfirmed90Day,
      transformations: transformations,
      credits: credits,
    );

    return VerificationSnapshot(
      tier: tier,
      zoneCount: zoneCount,
      activeOrders: activeOrders,
      plasticKgVerified: plasticKgVerified,
      totalTrees: totalTrees,
      treesConfirmed90Day: treesConfirmed90Day,
      transformationsLogged: transformations.length,
      transformationsHolding: transformationsHolding,
      issuedCredits: credits.length,
      transformations: transformations,
      credits: credits,
    );
  }

  ZonePolygon _buildPolygon(List<LatLng> vertices, double areaKm2) {
    final points = vertices
        .map((point) => GeoPoint(point.latitude, point.longitude))
        .toList();
    final centroid = _centroid(vertices);
    return ZonePolygon(
      coordinates: points,
      centroid: GeoPoint(centroid.latitude, centroid.longitude),
      areaEstimateSqm: areaKm2 * 1000000,
    );
  }

  LatLng _centroid(List<LatLng> vertices) {
    if (vertices.isEmpty) {
      return const LatLng(-1.2921, 36.8219);
    }
    var lat = 0.0;
    var lng = 0.0;
    for (final point in vertices) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / vertices.length, lng / vertices.length);
  }

  String _treeRefFor(DateTime now, int index) {
    final seed = now.millisecondsSinceEpoch.remainder(1000000);
    return 'T-${seed.toString().padLeft(6, '0')}-${(index + 1).toString().padLeft(3, '0')}';
  }

  TreeSpecies _resolveTreeSpecies(String label) {
    final normalized = label.trim().toLowerCase();
    for (final species in TreeSpecies.values) {
      if (species.displayLabel.toLowerCase() == normalized ||
          species.firestoreKey == normalized.replaceAll(' ', '_')) {
        return species;
      }
    }
    if (normalized.contains('neem')) return TreeSpecies.azadirachtaIndica;
    if (normalized.contains('grevillea')) return TreeSpecies.grevilleaRobusta;
    if (normalized.contains('mango')) return TreeSpecies.mangiferaIndica;
    if (normalized.contains('avocado')) return TreeSpecies.perseaAmericana;
    if (normalized.contains('eucalyptus')) return TreeSpecies.eucalyptusGrandis;
    return TreeSpecies.other;
  }

  MaterialCategory _guessMaterialCategory(String value) {
    final text = value.toLowerCase();
    if (text.contains('pet') ||
        text.contains('plastic') ||
        text.contains('film') ||
        text.contains('bag') ||
        text.contains('pp ') ||
        text.contains('pvc') ||
        text.contains('styrofoam')) {
      return MaterialCategory.plastics;
    }
    if (text.contains('copper') ||
        text.contains('aluminium') ||
        text.contains('metal') ||
        text.contains('steel') ||
        text.contains('iron')) {
      return MaterialCategory.metals;
    }
    if (text.contains('glass')) return MaterialCategory.glass;
    if (text.contains('paper') || text.contains('cardboard')) {
      return MaterialCategory.paperCardboard;
    }
    if (text.contains('tyre') || text.contains('rubber')) {
      return MaterialCategory.rubberComposites;
    }
    if (text.contains('wood') || text.contains('pallet')) {
      return MaterialCategory.reclaimedWood;
    }
    if (text.contains('fabric') || text.contains('textile') || text.contains('cotton')) {
      return MaterialCategory.textiles;
    }
    if (text.contains('phone') ||
        text.contains('pcb') ||
        text.contains('computer') ||
        text.contains('cable')) {
      return MaterialCategory.electronics;
    }
    return MaterialCategory.plastics;
  }

  bool _isSoftPlastic(String materialType) {
    final text = materialType.toLowerCase();
    return text.contains('film') || text.contains('bag');
  }

  int _impactPointsFor(
    MaterialCategory category,
    String materialType,
    double weightKg,
  ) {
    final baseMultiplier = switch (category) {
      MaterialCategory.plastics => 2,
      MaterialCategory.metals => 2,
      MaterialCategory.glass => 1,
      MaterialCategory.paperCardboard => 1,
      MaterialCategory.rubberComposites => 2,
      MaterialCategory.reclaimedWood => 1,
      MaterialCategory.textiles => 1,
      MaterialCategory.electronics => 3,
    };
    final bonus = _isSoftPlastic(materialType) ? 1 : 0;
    return (weightKg * (baseMultiplier + bonus)).round();
  }

  String _legacyCollectorStatus(FleetCollectorStatus status) {
    switch (status) {
      case FleetCollectorStatus.active:
        return 'active';
      case FleetCollectorStatus.offShift:
        return 'off_shift';
      case FleetCollectorStatus.uncontactable:
        return 'uncontactable';
      case FleetCollectorStatus.inactive:
        return 'inactive';
      case FleetCollectorStatus.suspended:
        return 'suspended';
    }
  }

  VerificationTier _estimateTier({
    required int zoneCount,
    required int activeOrders,
    required double plasticKgVerified,
    required int treesConfirmed90Day,
    required List<TransformationRecordSummary> transformations,
    required List<EnvironmentalCredit> credits,
  }) {
    final has30DayTransformation = transformations.any((record) {
      return record.stage2.confirmed || record.stage3.followUpDueAt != null;
    });
    final hasImpactPartnerBase =
        zoneCount >= 1 && activeOrders >= 3 && has30DayTransformation;
    final hasCreditThreshold =
        plasticKgVerified >= 500 || treesConfirmed90Day >= 50 || credits.isNotEmpty;

    if (hasImpactPartnerBase && hasCreditThreshold) {
      return VerificationTier.creditIssuer;
    }
    if (hasImpactPartnerBase) {
      return VerificationTier.impactPartner;
    }
    if (zoneCount >= 1 || activeOrders >= 1 || transformations.isNotEmpty) {
      return VerificationTier.verified;
    }
    return VerificationTier.registered;
  }
}
