import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum EnquiryStatus {
  unread,
  read,
  responded,
  closed;

  String get label => name[0].toUpperCase() + name.substring(1);

  static EnquiryStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'read':      return EnquiryStatus.read;
      case 'responded': return EnquiryStatus.responded;
      case 'closed':    return EnquiryStatus.closed;
      default:          return EnquiryStatus.unread;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRAMME ENQUIRY MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ProgrammeEnquiry {
  final String id;
  final String programmeId;

  /// Denormalised for org inbox display — avoids a join on every render.
  final String programmeTitle;

  final String orgId;
  final String fromUserId;

  /// Denormalised for the same reason as programmeTitle.
  final String fromUserName;

  final String message;
  final String? contactPhone;
  final String? contactEmail;
  final EnquiryStatus status;
  final DateTime? createdAt;

  const ProgrammeEnquiry({
    required this.id,
    required this.programmeId,
    required this.programmeTitle,
    required this.orgId,
    required this.fromUserId,
    required this.fromUserName,
    required this.message,
    this.contactPhone,
    this.contactEmail,
    this.status = EnquiryStatus.unread,
    this.createdAt,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory ProgrammeEnquiry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProgrammeEnquiry(
      id:             doc.id,
      programmeId:    data['programmeId']    as String? ?? '',
      programmeTitle: data['programmeTitle'] as String? ?? '',
      orgId:          data['orgId']          as String? ?? '',
      fromUserId:     data['fromUserId']     as String? ?? '',
      fromUserName:   data['fromUserName']   as String? ?? '',
      message:        data['message']        as String? ?? '',
      contactPhone:   data['contactPhone']   as String?,
      contactEmail:   data['contactEmail']   as String?,
      status:    EnquiryStatus.fromString(data['status'] as String? ?? 'unread'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'programmeId':    programmeId,
    'programmeTitle': programmeTitle,
    'orgId':          orgId,
    'fromUserId':     fromUserId,
    'fromUserName':   fromUserName,
    'message':        message,
    'contactPhone':   contactPhone,
    'contactEmail':   contactEmail,
    'status':         status.name,
    // Enquiry creation is a DUAL-WRITE handoff: write the enquiry doc AND
    // signal the org's inbox (unread counter / Broadcast entry in Operations).
    // Both writes must succeed or neither applies — use a batch or transaction.
    'createdAt': FieldValue.serverTimestamp(),
  };

  ProgrammeEnquiry copyWith({
    String? id,
    String? programmeId,
    String? programmeTitle,
    String? orgId,
    String? fromUserId,
    String? fromUserName,
    String? message,
    String? contactPhone,
    String? contactEmail,
    EnquiryStatus? status,
    DateTime? createdAt,
  }) {
    return ProgrammeEnquiry(
      id:             id             ?? this.id,
      programmeId:    programmeId    ?? this.programmeId,
      programmeTitle: programmeTitle ?? this.programmeTitle,
      orgId:          orgId          ?? this.orgId,
      fromUserId:     fromUserId     ?? this.fromUserId,
      fromUserName:   fromUserName   ?? this.fromUserName,
      message:        message        ?? this.message,
      contactPhone:   contactPhone   ?? this.contactPhone,
      contactEmail:   contactEmail   ?? this.contactEmail,
      status:         status         ?? this.status,
      createdAt:      createdAt      ?? this.createdAt,
    );
  }
}
