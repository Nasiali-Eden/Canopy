import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum OrgCapability {
  events,
  volunteers,
  programmes,
  partners,
  environmentalOps;

  String get label {
    switch (this) {
      case OrgCapability.events:          return 'Events';
      case OrgCapability.volunteers:      return 'Volunteers';
      case OrgCapability.programmes:      return 'Programmes';
      case OrgCapability.partners:        return 'Partners';
      case OrgCapability.environmentalOps: return 'Environmental Ops';
    }
  }

  static OrgCapability fromString(String value) {
    switch (value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'events':           return OrgCapability.events;
      case 'volunteers':       return OrgCapability.volunteers;
      case 'programmes':       return OrgCapability.programmes;
      case 'partners':         return OrgCapability.partners;
      case 'environmentalops': return OrgCapability.environmentalOps;
      default:                 return OrgCapability.events;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAPABILITY SEED
//
// Derives initial capabilities from the org designation stored at registration.
// Every org receives the four base capabilities. environmentalOps is not
// derivable from a legal designation acronym alone — it is added by the
// Special Ops approval flow in org_profile.dart after explicit enrolment.
// When registration eventually stores the org type alongside the legal
// designation, this function can be extended to detect env/cleanup types.
// ─────────────────────────────────────────────────────────────────────────────

List<OrgCapability> capabilitiesForDesignation(String? designation) {
  const base = [
    OrgCapability.events,
    OrgCapability.volunteers,
    OrgCapability.programmes,
    OrgCapability.partners,
  ];
  // Environmental/cleanup type identifiers — for future use when registration
  // stores an org-type identifier alongside the legal designation acronym.
  final d = (designation ?? '').toLowerCase();
  const envKeywords = [
    'cleanup', 'environmental', 'recycl', 'conservation', 'waterway', 'greening'
  ];
  if (envKeywords.any((kw) => d.contains(kw))) {
    return [...base, OrgCapability.environmentalOps];
  }
  return base;
}

// ─────────────────────────────────────────────────────────────────────────────
// ORGANIZATION MODEL
// ─────────────────────────────────────────────────────────────────────────────

// capabilities is captured from org TYPE at registration and is the explicit
// source of truth. Org type is set once at registration and is never
// re-asked in any creation flow.

// The Dashboard renders UNIVERSAL metrics only. Env-ops figures (kg diverted,
// trees, territory) must never appear here — they belong to the Env Ops
// screens behind OrgCapability.environmentalOps.

// Verified / impact counts surfaced on the Dashboard are READ-ONLY aggregates
// of operational data.

class Organization {
  final String id;
  final String name;               // 'org_name'
  final String? designation;       // 'orgDesignation'
  final String city;               // 'city', default 'Kenya'
  final bool verified;             // 'verified'
  final String? logoUrl;           // 'logoUrl'
  final String? coverImageUrl;     // 'coverImageUrl' (NEW)
  final String? about;             // 'about' (NEW — stored now, surfaced on public page later)
  final DateTime? foundedAt;       // 'foundedAt' (NEW — powers "Active since")
  final List<OrgCapability> capabilities; // 'capabilities' (NEW — explicit, typed)
  final List<String> galleryImageUrls;    // 'galleryImageUrls' (NEW — stored now, public page later)
  final int? memberCount;          // 'memberCount'

  const Organization({
    required this.id,
    required this.name,
    this.designation,
    this.city = 'Kenya',
    this.verified = false,
    this.logoUrl,
    this.coverImageUrl,
    this.about,
    this.foundedAt,
    this.capabilities = const [],
    this.galleryImageUrls = const [],
    this.memberCount,
  });

  // ── Convenience getters ──────────────────────────────────────────────────

  bool hasCapability(OrgCapability cap) => capabilities.contains(cap);
  bool get hasLogo  => logoUrl != null && logoUrl!.isNotEmpty;
  bool get hasCover => coverImageUrl != null && coverImageUrl!.isNotEmpty;

  /// Year string derived from foundedAt, e.g. '2023'. Returns '—' when null.
  String get activeSinceLabel {
    if (foundedAt == null) return '—';
    return '${foundedAt!.year}';
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final capRaw = (data['capabilities'] as List<dynamic>?)?.cast<String>() ?? [];
    return Organization(
      id:           doc.id,
      name:         data['org_name']        as String? ?? '',
      designation:  data['orgDesignation']  as String?,
      city:         data['city']            as String? ?? 'Kenya',
      verified:     data['verified']        as bool?   ?? false,
      // Fall back to 'profilePhoto' written by older registration flow.
      logoUrl:      (data['logoUrl'] ?? data['profilePhoto']) as String?,
      coverImageUrl: data['coverImageUrl']  as String?,
      about:         data['about']          as String?,
      foundedAt:    (data['foundedAt']  as Timestamp?)?.toDate(),
      capabilities: capRaw.map(OrgCapability.fromString).toList(),
      galleryImageUrls:
          (data['galleryImageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      memberCount:  (data['memberCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'org_name':         name,
    'orgDesignation':   designation,
    'city':             city,
    'verified':         verified,
    'logoUrl':          logoUrl,
    'coverImageUrl':    coverImageUrl,
    'about':            about,
    'foundedAt':        foundedAt != null ? Timestamp.fromDate(foundedAt!) : null,
    'capabilities':     capabilities.map((c) => c.name).toList(),
    'galleryImageUrls': galleryImageUrls,
    'memberCount':      memberCount,
  };

  Organization copyWith({
    String? id,
    String? name,
    String? designation,
    String? city,
    bool? verified,
    String? logoUrl,
    String? coverImageUrl,
    String? about,
    DateTime? foundedAt,
    List<OrgCapability>? capabilities,
    List<String>? galleryImageUrls,
    int? memberCount,
  }) {
    return Organization(
      id:               id              ?? this.id,
      name:             name            ?? this.name,
      designation:      designation     ?? this.designation,
      city:             city            ?? this.city,
      verified:         verified        ?? this.verified,
      logoUrl:          logoUrl         ?? this.logoUrl,
      coverImageUrl:    coverImageUrl   ?? this.coverImageUrl,
      about:            about           ?? this.about,
      foundedAt:        foundedAt       ?? this.foundedAt,
      capabilities:     capabilities    ?? this.capabilities,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      memberCount:      memberCount     ?? this.memberCount,
    );
  }
}
