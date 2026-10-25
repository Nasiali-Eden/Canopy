import 'package:cloud_firestore/cloud_firestore.dart';

import '../Shared/utils/rich_body.dart';

/// An organisation broadcast (top-level `announcements`, written by the
/// org BroadcastComposer).
class Announcement {
  final String id;
  final String title;
  final String body; // plain text (rich bodies are flattened)
  final bool pinned; // urgent broadcasts pin to the top
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String orgId;
  final String orgName;
  final String? orgLogoUrl;
  final String type;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.createdAt,
    this.expiresAt,
    this.orgId = '',
    this.orgName = '',
    this.orgLogoUrl,
    this.type = 'general',
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  static Announcement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    DateTime? date(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    return Announcement(
      id: doc.id,
      title: (d['title'] as String?)?.trim() ?? '',
      body: richBodyToPlainText(d['body']),
      pinned: (d['isUrgent'] ?? d['pinned'] ?? false) as bool,
      createdAt: date(d['createdAt'] ?? d['sentAt']),
      expiresAt: date(d['expiresAt']),
      orgId: d['orgId'] as String? ?? '',
      orgName: d['orgName'] as String? ?? '',
      orgLogoUrl: d['orgLogoUrl'] as String?,
      type: d['type'] as String? ?? 'general',
    );
  }
}
