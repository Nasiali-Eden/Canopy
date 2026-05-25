import 'package:cloud_firestore/cloud_firestore.dart';

/// CulturalComment — feedback/comment on an archive entry
class CulturalComment {
  final String id;
  final String entryId;
  final String commenterId;
  final String commenterName;
  final String voiceTier; // 'community_voice', 'contributor', 'open'
  final String commentBody;
  final String
      commentAction; // ask_question, add_variation, propose_relation, dispute, general
  final bool hasReply;
  final String? replyText;
  final DateTime createdAt;
  final bool isResolved;

  CulturalComment({
    required this.id,
    required this.entryId,
    required this.commenterId,
    required this.commenterName,
    required this.voiceTier,
    required this.commentBody,
    required this.commentAction,
    this.hasReply = false,
    this.replyText,
    required this.createdAt,
    this.isResolved = false,
  });

  factory CulturalComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CulturalComment(
      id: doc.id,
      entryId: data['entry_id'] as String? ?? '',
      commenterId: data['commenter_id'] as String? ?? '',
      commenterName: data['commenter_name'] as String? ?? '',
      voiceTier: data['voice_tier'] as String? ?? 'open',
      commentBody: data['comment_body'] as String? ?? '',
      commentAction: data['comment_action'] as String? ?? 'general',
      hasReply: data['has_reply'] as bool? ?? false,
      replyText: data['reply_text'] as String?,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isResolved: data['is_resolved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'entry_id': entryId,
      'commenter_id': commenterId,
      'commenter_name': commenterName,
      'voice_tier': voiceTier,
      'comment_body': commentBody,
      'comment_action': commentAction,
      'has_reply': hasReply,
      'reply_text': replyText,
      'created_at': Timestamp.fromDate(createdAt),
      'is_resolved': isResolved,
    };
  }

  CulturalComment copyWith({
    String? id,
    String? entryId,
    String? commenterId,
    String? commenterName,
    String? voiceTier,
    String? commentBody,
    String? commentAction,
    bool? hasReply,
    String? replyText,
    DateTime? createdAt,
    bool? isResolved,
  }) {
    return CulturalComment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      commenterId: commenterId ?? this.commenterId,
      commenterName: commenterName ?? this.commenterName,
      voiceTier: voiceTier ?? this.voiceTier,
      commentBody: commentBody ?? this.commentBody,
      commentAction: commentAction ?? this.commentAction,
      hasReply: hasReply ?? this.hasReply,
      replyText: replyText ?? this.replyText,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}
