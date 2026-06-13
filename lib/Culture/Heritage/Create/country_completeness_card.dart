// lib/Culture/Heritage/Create/country_completeness_card.dart
//
// Phase 5.3 — per-country "missing features" checklist for the cultural org.
// Shows, for the org's country, what still needs uploading so the public
// Country screen fills in: the country background image and any of the 12
// content categories that have zero public entries. Parity-safe — everything
// is derived from live Firestore data; if the org has no country set, it
// renders nothing.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../Shared/theme/app_theme.dart';
import '../Services/heritage_content_types.dart';
import '../Services/heritage_data_service.dart';
import 'create_entry_screen.dart';

class CountryCompletenessCard extends StatefulWidget {
  final String orgId;
  const CountryCompletenessCard({super.key, required this.orgId});

  @override
  State<CountryCompletenessCard> createState() =>
      _CountryCompletenessCardState();
}

class _CountryCompletenessCardState extends State<CountryCompletenessCard> {
  final _service = HeritageDataService();
  bool _loading = true;
  String? _countryId;
  String? _countryName;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .get();
      final name = (doc.data()?['country'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        final countries = await _service.loadCountries();
        for (final c in countries) {
          if (c.name.toLowerCase() == name.toLowerCase()) {
            _countryId = c.id;
            _countryName = c.name;
            break;
          }
        }
        // Org has a country that isn't in the registry yet — still nudge by name.
        _countryName ??= name;
      }
    } catch (_) {
      // leave unresolved → renders nothing
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _countryId == null) return const SizedBox.shrink();

    return StreamBuilder<String?>(
      stream: _service.streamNodeBg(_countryId!),
      builder: (context, bgSnap) {
        final missingBg = (bgSnap.data ?? '').isEmpty;
        return StreamBuilder<List<CategoryCount>>(
          stream: _service.streamCategoriesForCountry(_countryId!),
          builder: (context, catSnap) {
            final present =
                (catSnap.data ?? const <CategoryCount>[]).map((c) => c.type.key).toSet();
            final missingCats = HeritageContentTypes.ordered
                .where((t) => !present.contains(t.key))
                .toList();

            final total = (missingBg ? 1 : 0) + missingCats.length;
            // 1 (bg) + 12 categories = 13 checkpoints.
            final done = 13 - total;
            return _card(context, missingBg, missingCats, done);
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, bool missingBg,
      List<HeritageContentType> missingCats, int done) {
    final complete = missingBg == false && missingCats.isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.tertiary.withOpacity(0.10),
            AppTheme.primary.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.tertiary.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(complete ? Icons.verified_outlined : Icons.checklist_rounded,
                  size: 18, color: AppTheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  complete
                      ? '${_countryName ?? 'Your country'} archive is complete'
                      : 'Complete ${_countryName ?? 'your country'}\'s archive',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen),
                ),
              ),
              Text('$done/13',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen.withOpacity(0.55))),
            ],
          ),
          if (!complete) ...[
            const SizedBox(height: 12),
            if (missingBg)
              _row(Icons.image_outlined, 'Add a country background image',
                  'Shown behind the country\'s Heritage page'),
            ...missingCats.take(missingBg ? 4 : 5).map(
                  (t) => _row(t.icon, 'Add ${t.label}',
                      'No ${t.plural} entries yet'),
                ),
            if (missingCats.length > (missingBg ? 4 : 5))
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '+ ${missingCats.length - (missingBg ? 4 : 5)} more categories to fill',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEntryScreen(orgId: widget.orgId),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add an entry',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: Colors.amber.shade800),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkGreen.withOpacity(0.5))),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: AppTheme.darkGreen.withOpacity(0.3)),
        ],
      ),
    );
  }
}
