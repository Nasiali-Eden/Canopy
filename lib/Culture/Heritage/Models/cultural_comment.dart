import 'package:cloud_firestore/cloud_firestore.dart';

/// CulturalComment — a member's question, addition or dispute on an entry,
/// and the archive's reply.
class CulturalComment {
  final String id;
  final String entryId;
  final String? orgId;
  final String commenterId;
  final String commenterName;
  final String voiceTier; // 'community_voice', 'contributor', 'open'
  final String commentBody;
  final String commentAction; // ask_question, add_variation, propose_relation, dispute, general
  final bool hasReply;
  final String? replyText;
  final DateTime createdAt;
  final bool isResolved;

  /// pending · under_review · resolved
  final String status;
  final String? ownerUid;
  final String? ownerName;
  final DateTime? repliedAt;
  final String? resolutionNote;

  CulturalComment({
    required this.id,
    required this.entryId,
    this.orgId,
    required this.commenterId,
    required this.commenterName,
    required this.voiceTier,
    required this.commentBody,
    required this.commentAction,
    this.hasReply = false,
    this.replyText,
    required this.createdAt,
    this.isResolved = false,
    this.status = 'pending',
    this.ownerUid,
    this.ownerName,
    this.repliedAt,
    this.resolutionNote,
  });

  bool get isDispute => commentAction == 'dispute';

  factory CulturalComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final resolved = data['is_resolved'] as bool? ?? false;
    final hasReply = data['has_reply'] as bool? ?? false;
    return CulturalComment(
      id: doc.id,
      entryId: data['entry_id'] as String? ?? '',
      orgId: data['org_id'] as String?,
      commenterId: data['commenter_id'] as String? ?? '',
      commenterName: data['commenter_name'] as String? ?? '',
      voiceTier: data['voice_tier'] as String? ?? 'open',
      commentBody: data['comment_body'] as String? ?? '',
      commentAction: data['comment_action'] as String? ?? 'general',
      hasReply: hasReply,
      replyText: data['reply_text'] as String?,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isResolved: resolved,
      status: data['status'] as String? ?? (resolved ? 'resolved' : (hasReply ? 'under_review' : 'pending')),
      ownerUid: data['owner_uid'] as String?,
      ownerName: data['owner_name'] as String?,
      repliedAt: (data['replied_at'] as Timestamp?)?.toDate(),
      resolutionNote: data['resolution_note'] as String?,
    );
  }
}
