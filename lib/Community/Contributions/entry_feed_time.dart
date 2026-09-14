// lib/Community/Contributions/entry_feed_time.dart
//
// Small standalone `timeAgo` used by EntryFeedCard's caption overlay.
// Deliberately not importing `../Home/community_home.dart` (which already
// exports an identical helper from home_feed.dart) to avoid a
// home_feed → entry_feed_card → community_home → home_feed import cycle.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

String feedCardTimeAgo(Timestamp timestamp) {
  final diff = DateTime.now().difference(timestamp.toDate());
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return DateFormat('d MMM yyyy').format(timestamp.toDate());
}
