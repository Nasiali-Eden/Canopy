import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum ActivityType {
  cleanup,
  event,
  task;

  String get label {
    switch (this) {
      case ActivityType.cleanup:
        return 'Cleanup';
      case ActivityType.event:
        return 'Event';
      case ActivityType.task:
        return 'Task';
    }
  }

  static ActivityType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'cleanups':
      case 'cleanup':
        return ActivityType.cleanup;
      case 'tasks':
      case 'task':
        return ActivityType.task;
      default:
        return ActivityType.event;
    }
  }
}

enum RegistrationState {
  open,
  closed;

  String get label => name[0].toUpperCase() + name.substring(1);

  static RegistrationState fromString(String value) {
    return value.toLowerCase() == 'closed'
        ? RegistrationState.closed
        : RegistrationState.open;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION DATA — tied to KenyaCities.json structure
// ─────────────────────────────────────────────────────────────────────────────

class ActivityLocation {
  /// Human-readable area name, e.g. "Westlands"
  final String area;

  /// Parent city / county, e.g. "Nairobi"
  final String city;

  /// Free-text venue description, e.g. "Karura Forest Gate 2"
  final String venue;

  /// Geographic coordinates
  final double lat;
  final double lng;

  const ActivityLocation({
    required this.area,
    required this.city,
    required this.venue,
    required this.lat,
    required this.lng,
  });

  factory ActivityLocation.fromMap(Map<String, dynamic> map) {
    final coords = map['coordinates'] as Map<String, dynamic>? ?? {};
    return ActivityLocation(
      area: map['area'] as String? ?? '',
      city: map['city'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      lat: (coords['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (coords['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'area': area,
    'city': city,
    'venue': venue,
    'coordinates': {'lat': lat, 'lng': lng},
  };

  /// Short label used in chips and cards
  String get shortLabel => area.isNotEmpty ? '$area, $city' : city;
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY MODEL
// ─────────────────────────────────────────────────────────────────────────────

class Activity {
  final String id;
  final String title;
  final String description;
  final ActivityType type;

  /// Structured location with coordinates + KenyaCities area data
  final ActivityLocation location;

  /// Ordered image URLs — first one is the cover, rest form the gallery.
  /// Minimum 4 slots; null entries render placeholder tiles.
  final List<String?> images;

  /// Registration gate — defaults to [RegistrationState.open].
  /// Only an Organizer can flip it to [RegistrationState.closed].
  final RegistrationState registrationState;

  final List<String> participantIds;
  final int requiredParticipants;

  final DateTime? dateTime;
  final String? createdBy;

  /// Legacy plain-text status ("upcoming", "ongoing", "completed").
  final String status;

  const Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
    this.images = const [],
    this.registrationState = RegistrationState.open,
    this.participantIds = const [],
    this.requiredParticipants = 10,
    this.dateTime,
    this.createdBy,
    this.status = 'upcoming',
  });

  // ── Convenience getters ──────────────────────────────────────────────────

  int get currentParticipants => participantIds.length;

  bool get isOpen => registrationState == RegistrationState.open;

  bool get isFull => currentParticipants >= requiredParticipants;

  bool canRegister(String userId) =>
      isOpen && !isFull && !participantIds.contains(userId);

  /// Always returns exactly 4 slots (null = placeholder).
  List<String?> get gallerySlots {
    final slots = List<String?>.from(images);
    while (slots.length < 4) {
      slots.add(null);
    }
    return slots.take(4).toList();
  }

  /// First non-null image or null.
  String? get coverImage =>
      images.isNotEmpty ? images.firstWhere((i) => i != null, orElse: () => null) : null;

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory Activity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Activity(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: ActivityType.fromString(data['type'] as String? ?? 'event'),
      location: ActivityLocation.fromMap(
          data['location'] as Map<String, dynamic>? ?? {}),
      images: (data['images'] as List<dynamic>?)
          ?.map((e) => e as String?)
          .toList() ??
          [],
      registrationState: RegistrationState.fromString(
          data['registrationState'] as String? ?? 'open'),
      participantIds: (data['participantIds'] as List<dynamic>?)
          ?.cast<String>() ??
          [],
      requiredParticipants:
      (data['requiredParticipants'] as num?)?.toInt() ?? 10,
      dateTime: (data['dateTime'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      status: data['status'] as String? ?? 'upcoming',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'type': type.label,
    'location': location.toMap(),
    'images': images,
    'registrationState': registrationState.name,
    'participantIds': participantIds,
    'requiredParticipants': requiredParticipants,
    'dateTime':
    dateTime != null ? Timestamp.fromDate(dateTime!) : null,
    'createdBy': createdBy,
    'status': status,
  };

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    ActivityType? type,
    ActivityLocation? location,
    List<String?>? images,
    RegistrationState? registrationState,
    List<String>? participantIds,
    int? requiredParticipants,
    DateTime? dateTime,
    String? createdBy,
    String? status,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      location: location ?? this.location,
      images: images ?? this.images,
      registrationState: registrationState ?? this.registrationState,
      participantIds: participantIds ?? this.participantIds,
      requiredParticipants: requiredParticipants ?? this.requiredParticipants,
      dateTime: dateTime ?? this.dateTime,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
    );
  }
}