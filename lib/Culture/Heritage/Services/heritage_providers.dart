import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../Models/cultural_entry.dart';

/// Provider for fetching cultural entries for the current organization
class HeritageEntriesProvider extends ChangeNotifier {
  List<CulturalEntry> _entries = [];
  bool _isLoading = false;
  String? _orgId;
  StreamSubscription? _subscription;

  List<CulturalEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  HeritageEntriesProvider();

  void fetchEntries(String orgId) {
    if (_orgId == orgId && _subscription != null) return;

    _orgId = orgId;
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    // No orderBy here: org_id + orderBy(updated_at) needs a composite index
    // that may not exist (the query then errors and the archive looks empty).
    // Sort client-side instead — same pattern used elsewhere in the app.
    _subscription = FirebaseFirestore.instance
        .collection('cultural_entries')
        .where('org_id', isEqualTo: orgId)
        .snapshots()
        .listen((snapshot) {
      final list =
          snapshot.docs.map((doc) => CulturalEntry.fromFirestore(doc)).toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _entries = list;
      _isLoading = false;
      notifyListeners();
    }, onError: (error, stack) {
      debugPrint('[HeritageEntriesProvider] fetchEntries error: $error');
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
