// lib/Culture/Heritage/Create/country_completeness_card.dart
//
// CompletenessCard (ARCHIVE_HANDOFF §2 / §3.4): "[Country] page is N of 8
// ready", ink progress, checklist rows with Add. Every row is computed from
// real data — images on the hierarchy nodes and the country's public
// entries — so nothing reads as done unless it is.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Services/heritage_data_service.dart';
import 'create_entry_screen.dart';

class CountryCompletenessCard extends StatefulWidget {
  final String orgId;

  /// Opens the backgrounds editor (null when already on it).
  final VoidCallback? onOpenBackgrounds;
  const CountryCompletenessCard({super.key, required this.orgId, this.onOpenBackgrounds});

  @override
  State<CountryCompletenessCard> createState() => _CountryCompletenessCardState();
}

class _State {
  final HeritageCountry country;
  final List<(String, bool, VoidCallback?)> items;
  const _State(this.country, this.items);
}

class _CountryCompletenessCardState extends State<CountryCompletenessCard> {
  final _service = HeritageDataService();
  Future<_State?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_State?> _load() async {
    final country = await _service.resolveOrgCountry(widget.orgId);
    if (country == null) return null;
    final db = FirebaseFirestore.instance;
    final node = (await db.collection(HeritageDataService.hierarchyCollection).doc(country.id).get()).data() ?? {};
    final items = await _service.streamItems(countryId: country.id).first;
    final usedTypes = items.map((i) => i.contentType).toSet();
    final communities = items.map((i) => i.communityId).whereType<String>().where((c) => c.isNotEmpty).toSet();
    Future<Set<String>> withBg(List<String> ids) async {
      final out = <String>{};
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final s = await db.collection(HeritageDataService.hierarchyCollection).where(FieldPath.documentId, whereIn: chunk).get();
        for (final d in s.docs) {
          if ((d.data()['bg_image_url'] as String?)?.isNotEmpty ?? false) out.add(d.id);
        }
      }
      return out;
    }

    final catIds = [for (final t in usedTypes) HeritageDataService.categoryNodeId(country.id, t)];
    final comIds = [for (final c in communities) HeritageDataService.communityNodeId(c)];
    final catBg = catIds.isEmpty ? <String>{} : await withBg(catIds);
    final comBg = comIds.isEmpty ? <String>{} : await withBg(comIds);
    void add() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateEntryScreen(orgId: widget.orgId)));
    final bg = widget.onOpenBackgrounds;
    return _State(country, [
      ('Banner image for the country page', (node['bg_image_url'] as String?)?.isNotEmpty ?? false, bg),
      ('Card image for the Heritage tab', (node['card_image_url'] as String?)?.isNotEmpty ?? false, bg),
      ('A public entry', items.isNotEmpty, add),
      ('Entries in three or more categories', usedTypes.length >= 3, add),
      ('A background for every category you use', usedTypes.isNotEmpty && catBg.length == catIds.length, bg),
      ('A community background', comBg.isNotEmpty, bg),
      ('A cover photo on every entry', items.isNotEmpty && items.every((i) => (i.coverImageUrl ?? '').isNotEmpty), null),
      ('A knowledge holder recorded', usedTypes.contains('person'), add),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_State?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const CanopyCardSkeleton();
        if (snap.hasError) {
          return CanopyErrorState(inline: true, title: "Couldn't check the country page.", onRetry: () => setState(() => _future = _load()));
        }
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        return CompletenessCard(country: s.country.name, items: s.items);
      },
    );
  }
}
