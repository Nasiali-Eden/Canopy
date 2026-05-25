import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../Models/index.dart';

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
    _subscription = FirebaseFirestore.instance
        .collection('cultural_entries')
        .where('org_id', isEqualTo: orgId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _entries =
          snapshot.docs.map((doc) => CulturalEntry.fromFirestore(doc)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
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

/// Provider for fetching cultural comments for a specific entry
class HeritageCommentsProvider extends ChangeNotifier {
  List<CulturalComment> _comments = [];
  bool _isLoading = false;
  String? _entryId;
  StreamSubscription? _subscription;

  List<CulturalComment> get comments => _comments;
  bool get isLoading => _isLoading;

  HeritageCommentsProvider();

  void fetchComments(String entryId) {
    if (_entryId == entryId && _subscription != null) return;

    _entryId = entryId;
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('cultural_comments')
        .where('entry_id', isEqualTo: entryId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _comments = snapshot.docs
          .map((doc) => CulturalComment.fromFirestore(doc))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
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

/// Provider for fetching cultural comments for multiple entries
class HeritageCommentsListProvider extends ChangeNotifier {
  List<CulturalComment> _comments = [];
  bool _isLoading = false;
  List<String> _entryIds = [];
  StreamSubscription? _subscription;

  List<CulturalComment> get comments => _comments;
  bool get isLoading => _isLoading;

  HeritageCommentsListProvider();

  void fetchCommentsList(List<String> entryIds) {
    if (_entryIds == entryIds && _subscription != null) return;

    _entryIds = entryIds;
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();

    if (entryIds.isEmpty) {
      _comments = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _subscription = FirebaseFirestore.instance
        .collection('cultural_comments')
        .where('entry_id', whereIn: entryIds)
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _comments = snapshot.docs
          .map((doc) => CulturalComment.fromFirestore(doc))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
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

/// Provider for fetching cultural relations
class HeritageRelationsProvider extends ChangeNotifier {
  List<CulturalRelation> _relations = [];
  bool _isLoading = false;
  List<String> _entryIds = [];
  StreamSubscription? _subscription;

  List<CulturalRelation> get relations => _relations;
  bool get isLoading => _isLoading;

  HeritageRelationsProvider();

  void fetchRelations(List<String> entryIds) {
    if (_entryIds == entryIds && _subscription != null) return;

    _entryIds = entryIds;
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();

    if (entryIds.isEmpty) {
      _relations = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _subscription = FirebaseFirestore.instance
        .collection('cultural_relations')
        .where('from_entry_id', whereIn: entryIds)
        .snapshots()
        .listen((snapshot) {
      _relations = snapshot.docs
          .map((doc) => CulturalRelation.fromFirestore(doc))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
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

/// Provider for fetching cultural media for an organization
class HeritageMediaProvider extends ChangeNotifier {
  List<CulturalMedia> _media = [];
  bool _isLoading = false;
  String? _orgId;
  StreamSubscription? _subscription;

  List<CulturalMedia> get media => _media;
  bool get isLoading => _isLoading;

  HeritageMediaProvider();

  void fetchMedia(String orgId) {
    if (_orgId == orgId && _subscription != null) return;

    _orgId = orgId;
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('cultural_media')
        .where('org_id', isEqualTo: orgId)
        .snapshots()
        .listen((snapshot) {
      _media =
          snapshot.docs.map((doc) => CulturalMedia.fromFirestore(doc)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
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

/// Provider for org entry IDs (used as a dependency for other providers)
class OrgEntryIdsProvider extends ChangeNotifier {
  List<String> _entryIds = [];
  bool _isLoading = false;
  String? _orgId;

  List<String> get entryIds => _entryIds;
  bool get isLoading => _isLoading;

  OrgEntryIdsProvider();

  Future<void> fetchEntryIds(String orgId) async {
    if (_orgId == orgId && _entryIds.isNotEmpty) return;

    _orgId = orgId;
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cultural_entries')
          .where('org_id', isEqualTo: orgId)
          .get();

      _entryIds = snapshot.docs.map((doc) => doc.id).toList();
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
