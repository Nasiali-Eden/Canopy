import 'package:cloud_firestore/cloud_firestore.dart';
import '../Shared/Activities/activity.dart' show ActivityLocation;

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum ProgrammeType {
  course,
  onlineCourse,
  workshop,
  service,
  mentorship,
  membership;

  String get label {
    switch (this) {
      case ProgrammeType.course:       return 'Course';
      case ProgrammeType.onlineCourse: return 'Online Course';
      case ProgrammeType.workshop:     return 'Workshop';
      case ProgrammeType.service:      return 'Service';
      case ProgrammeType.mentorship:   return 'Mentorship';
      case ProgrammeType.membership:   return 'Membership';
    }
  }

  static ProgrammeType fromString(String value) {
    switch (value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'course':       return ProgrammeType.course;
      case 'onlinecourse': return ProgrammeType.onlineCourse;
      case 'workshop':     return ProgrammeType.workshop;
      case 'service':      return ProgrammeType.service;
      case 'mentorship':   return ProgrammeType.mentorship;
      case 'membership':   return ProgrammeType.membership;
      default:             return ProgrammeType.workshop;
    }
  }
}

enum ProgrammeStatus {
  draft,
  upcoming,
  active,
  completed,
  archived;

  String get label => name[0].toUpperCase() + name.substring(1);

  static ProgrammeStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'draft':     return ProgrammeStatus.draft;
      case 'upcoming':  return ProgrammeStatus.upcoming;
      case 'active':    return ProgrammeStatus.active;
      case 'completed': return ProgrammeStatus.completed;
      case 'archived':  return ProgrammeStatus.archived;
      default:          return ProgrammeStatus.draft;
    }
  }
}

enum EngagementModel {
  free,
  paid,
  volunteer;

  String get label => name[0].toUpperCase() + name.substring(1);

  static EngagementModel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'paid':      return EngagementModel.paid;
      case 'volunteer': return EngagementModel.volunteer;
      default:          return EngagementModel.free;
    }
  }
}

enum RecurrencePattern {
  oneTime,
  weekly,
  monthly,
  ongoing;

  String get label {
    switch (this) {
      case RecurrencePattern.oneTime:  return 'One-time';
      case RecurrencePattern.weekly:   return 'Weekly';
      case RecurrencePattern.monthly:  return 'Monthly';
      case RecurrencePattern.ongoing:  return 'Ongoing';
    }
  }

  static RecurrencePattern fromString(String value) {
    switch (value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'onetime':  return RecurrencePattern.oneTime;
      case 'weekly':   return RecurrencePattern.weekly;
      case 'monthly':  return RecurrencePattern.monthly;
      case 'ongoing':  return RecurrencePattern.ongoing;
      default:         return RecurrencePattern.oneTime;
    }
  }
}

enum ProgrammeContactMode {
  enquiry,
  externalLink,
  both;

  String get label {
    switch (this) {
      case ProgrammeContactMode.enquiry:      return 'Enquiry';
      case ProgrammeContactMode.externalLink: return 'External link';
      case ProgrammeContactMode.both:         return 'Both';
    }
  }

  static ProgrammeContactMode fromString(String value) {
    switch (value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'externallink': return ProgrammeContactMode.externalLink;
      case 'both':         return ProgrammeContactMode.both;
      default:             return ProgrammeContactMode.enquiry;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NESTED CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class ProgrammeSchedule {
  final DateTime? startDate;
  final DateTime? endDate;
  final RecurrencePattern recurrence;

  /// True when the programme is delivered fully online; location is null when isOnline.
  final bool isOnline;

  /// Null when isOnline is true. Reuses ActivityLocation — not duplicated.
  final ActivityLocation? location;

  const ProgrammeSchedule({
    this.startDate,
    this.endDate,
    this.recurrence = RecurrencePattern.oneTime,
    this.isOnline = false,
    this.location,
  });

  factory ProgrammeSchedule.fromMap(Map<String, dynamic> map) {
    final locMap = map['location'] as Map<String, dynamic>?;
    return ProgrammeSchedule(
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate:   (map['endDate']   as Timestamp?)?.toDate(),
      recurrence: RecurrencePattern.fromString(
          map['recurrence'] as String? ?? 'oneTime'),
      isOnline: map['isOnline'] as bool? ?? false,
      location: locMap != null ? ActivityLocation.fromMap(locMap) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'startDate':  startDate  != null ? Timestamp.fromDate(startDate!)  : null,
    'endDate':    endDate    != null ? Timestamp.fromDate(endDate!)    : null,
    'recurrence': recurrence.name,
    'isOnline':   isOnline,
    'location':   location?.toMap(),
  };
}

class ProgrammeDetails {
  // price MUST be non-null when engagementModel == EngagementModel.paid, and
  // MUST be null otherwise. Volunteer programmes carry no price and link to
  // People > Volunteers on enrol.
  final EngagementModel engagementModel;
  final double? price;

  /// Defaults to 'KES'.
  final String currency;
  final int? capacity;
  final String duration;
  final bool certificateOffered;
  final String eligibility;

  const ProgrammeDetails({
    this.engagementModel = EngagementModel.free,
    this.price,
    this.currency = 'KES',
    this.capacity,
    this.duration = '',
    this.certificateOffered = false,
    this.eligibility = '',
  });

  factory ProgrammeDetails.fromMap(Map<String, dynamic> map) {
    return ProgrammeDetails(
      engagementModel: EngagementModel.fromString(
          map['engagementModel'] as String? ?? 'free'),
      price:              (map['price']    as num?)?.toDouble(),
      currency:           map['currency']  as String? ?? 'KES',
      capacity:           (map['capacity'] as num?)?.toInt(),
      duration:           map['duration']  as String? ?? '',
      certificateOffered: map['certificateOffered'] as bool? ?? false,
      eligibility:        map['eligibility'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'engagementModel':    engagementModel.name,
    'price':              price,
    'currency':           currency,
    'capacity':           capacity,
    'duration':           duration,
    'certificateOffered': certificateOffered,
    'eligibility':        eligibility,
  };
}

class ProgrammeContact {
  final ProgrammeContactMode mode;

  // contact.externalLink is REQUIRED when type == onlineCourse OR
  // contact.mode involves externalLink.
  final String? externalLink;
  final bool enquiryEnabled;

  const ProgrammeContact({
    this.mode = ProgrammeContactMode.enquiry,
    this.externalLink,
    this.enquiryEnabled = true,
  });

  factory ProgrammeContact.fromMap(Map<String, dynamic> map) {
    return ProgrammeContact(
      mode:           ProgrammeContactMode.fromString(
          map['mode'] as String? ?? 'enquiry'),
      externalLink:   map['externalLink']   as String?,
      enquiryEnabled: map['enquiryEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'mode':           mode.name,
    'externalLink':   externalLink,
    'enquiryEnabled': enquiryEnabled,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRAMME MODEL
// ─────────────────────────────────────────────────────────────────────────────

class Programme {
  final String id;
  final String orgId;
  final ProgrammeType type;
  final ProgrammeStatus status;
  final String title;

  /// Short summary used on cards.
  final String summary;

  /// Full description shown on the detail view.
  final String description;

  final String? coverImageUrl;

  // supportingImageUrls: HARD CAP of 5. Cover image is separate (coverImageUrl).
  // Enforce in the editor before write and assert on construction.
  final List<String> supportingImageUrls;

  final ProgrammeSchedule schedule;
  final ProgrammeDetails details;
  final ProgrammeContact contact;

  // impactRefs is READ-ONLY. Programme never writes impact figures. The Track
  // Record renders verified impact aggregated from the operational record
  // (impactRecord); a programme only references it. Writing impact numbers
  // here breaks the verification moat.
  final List<String> impactRefs;

  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  Programme({
    required this.id,
    required this.orgId,
    required this.type,
    required this.status,
    required this.title,
    this.summary = '',
    this.description = '',
    this.coverImageUrl,
    this.supportingImageUrls = const [],
    required this.schedule,
    required this.details,
    required this.contact,
    this.impactRefs = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  }) : assert(supportingImageUrls.length <= 5,
            'supportingImageUrls hard cap is 5');

  // ── Convenience getters ──────────────────────────────────────────────────

  bool get isPaid      => details.engagementModel == EngagementModel.paid;
  bool get isVolunteer => details.engagementModel == EngagementModel.volunteer;
  bool get isFree      => details.engagementModel == EngagementModel.free;
  bool get isCompleted => status == ProgrammeStatus.completed;
  bool get canEnquire  => contact.enquiryEnabled;

  /// Formatted price string — e.g. "KES 1,200", "Free", or "Volunteer".
  String get displayPrice {
    if (isPaid && details.price != null) {
      final amt = details.price!.toInt();
      final formatted = amt
          .toString()
          .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
      return '${details.currency} $formatted';
    }
    if (isVolunteer) return 'Volunteer';
    return 'Free';
  }

  /// Cover slot + up to 5 supporting slots; null entries render as placeholders.
  /// Mirror of Activity.gallerySlots — total possible slots: 6.
  List<String?> get gallerySlots {
    final slots = <String?>[coverImageUrl, ...supportingImageUrls];
    while (slots.length < 6) slots.add(null);
    return slots.take(6).toList();
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory Programme.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final supporting =
        (data['supportingImageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    return Programme(
      id:          doc.id,
      orgId:       data['orgId']   as String? ?? '',
      type:        ProgrammeType.fromString(  data['type']   as String? ?? 'workshop'),
      status:      ProgrammeStatus.fromString(data['status'] as String? ?? 'draft'),
      title:       data['title']       as String? ?? '',
      summary:     data['summary']     as String? ?? '',
      description: data['description'] as String? ?? '',
      coverImageUrl:       data['coverImageUrl'] as String?,
      supportingImageUrls: supporting.take(5).toList(),
      schedule: ProgrammeSchedule.fromMap(
          data['schedule'] as Map<String, dynamic>? ?? {}),
      details: ProgrammeDetails.fromMap(
          data['details'] as Map<String, dynamic>? ?? {}),
      contact: ProgrammeContact.fromMap(
          data['contact'] as Map<String, dynamic>? ?? {}),
      impactRefs: (data['impactRefs'] as List<dynamic>?)?.cast<String>() ?? [],
      createdBy:   data['createdBy'] as String?,
      createdAt:   (data['createdAt']   as Timestamp?)?.toDate(),
      updatedAt:   (data['updatedAt']   as Timestamp?)?.toDate(),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'orgId':               orgId,
    'type':                type.name,
    'status':              status.name,
    'title':               title,
    'summary':             summary,
    'description':         description,
    'coverImageUrl':       coverImageUrl,
    'supportingImageUrls': supportingImageUrls,
    'schedule':            schedule.toMap(),
    'details':             details.toMap(),
    'contact':             contact.toMap(),
    'impactRefs':          impactRefs,
    'createdBy':           createdBy,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt':   FieldValue.serverTimestamp(),
    'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
  };

  Programme copyWith({
    String? id,
    String? orgId,
    ProgrammeType? type,
    ProgrammeStatus? status,
    String? title,
    String? summary,
    String? description,
    String? coverImageUrl,
    List<String>? supportingImageUrls,
    ProgrammeSchedule? schedule,
    ProgrammeDetails? details,
    ProgrammeContact? contact,
    List<String>? impactRefs,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
  }) {
    return Programme(
      id:                  id                  ?? this.id,
      orgId:               orgId               ?? this.orgId,
      type:                type                ?? this.type,
      status:              status              ?? this.status,
      title:               title               ?? this.title,
      summary:             summary             ?? this.summary,
      description:         description         ?? this.description,
      coverImageUrl:       coverImageUrl       ?? this.coverImageUrl,
      supportingImageUrls: supportingImageUrls ?? this.supportingImageUrls,
      schedule:            schedule            ?? this.schedule,
      details:             details             ?? this.details,
      contact:             contact             ?? this.contact,
      impactRefs:          impactRefs          ?? this.impactRefs,
      createdBy:           createdBy           ?? this.createdBy,
      createdAt:           createdAt           ?? this.createdAt,
      updatedAt:           updatedAt           ?? this.updatedAt,
      publishedAt:         publishedAt         ?? this.publishedAt,
    );
  }
}
