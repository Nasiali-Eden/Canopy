// lib/Community/Heritage/community_heritage_tab.dart
//
// Phase 4 — Heritage home, fully data-driven. Replaces the old 1.8k-line
// hardcoded screen (country grid, tribe lists, foods, history, Luhya page) with
// a registry-driven country grid + Firestore-driven featured rail. Navigation
// goes Home → CountryScreen → Category/Community → Item (all in sibling files).
//
// Backend ⇄ frontend parity: countries come from the bundled registry; liveness
// + featured come from `cultural_entries`. No hardcoded cultural content, no
// orphan `heritage_entries` read. The ONLY static image is `images/BG.png`.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Culture/Heritage/Services/heritage_data_service.dart';
import 'country_screen.dart';
import 'heritage_item_screen.dart';
import 'heritage_widgets.dart';

// ─── Heritage dark-theme tokens ───────────────────────────────────────────────
const _textColor = Color(0xFFE8F0E9);
const _textDim = Color(0x80E8F0E9);
const _textFaint = Color(0x47E8F0E9);
const _gold = Color(0xFFC4A961);
const _border = Color(0x1F86BC9E);

class CommunityHeritageTab extends StatelessWidget {
  const CommunityHeritageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = HeritageDataService();
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top;
    final bottomInset = mq.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Heritage',
          style: TextStyle(
            color: _textColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: _border),
            ),
            child: IconButton(
              padding: const EdgeInsets.all(8),
              onPressed: () => showSearch(
                  context: context, delegate: _HeritageSearchDelegate(service)),
              icon: const Icon(Icons.search, size: 20, color: _textColor),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // The one static image that stays.
          Positioned.fill(
            child: Image.asset(
              'images/BG.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.22),
                    Colors.black.withOpacity(0.40),
                    Colors.black.withOpacity(0.65),
                    Colors.black.withOpacity(0.82),
                  ],
                  stops: const [0.0, 0.28, 0.60, 1.0],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topInset + 52)),

              // Quote — enlarged, the hero line of the Heritage home.
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 36,
                          child: Divider(color: _gold, thickness: 3)),
                      SizedBox(height: 14),
                      Text(
                        'Every culture has its own logic,\nits own reason for being.',
                        style: TextStyle(
                          fontSize: 24,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                          height: 1.4,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Country grid (registry-driven).
              SliverToBoxAdapter(
                child: FutureBuilder<List<HeritageCountry>>(
                  future: service.loadCountries(),
                  builder: (context, snap) {
                    final countries = snap.data ?? const <HeritageCountry>[];
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: _gold, strokeWidth: 2),
                        ),
                      );
                    }
                    if (countries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Text(
                          'Countries will appear here soon.',
                          style: TextStyle(color: _textFaint, fontSize: 13),
                        ),
                      );
                    }
                    final shown = countries.take(4).toList();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.92,
                            ),
                            itemCount: shown.length,
                            itemBuilder: (_, i) => _CountryCard(
                              country: shown[i],
                              service: service,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CountryScreen(country: shown[i]),
                                ),
                              ),
                            ),
                          ),
                          if (countries.length > 4) ...[
                            const SizedBox(height: 12),
                            _ShowAllButton(
                              label: 'Show all ${countries.length} countries',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AllCountriesScreen(countries: countries),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Featured items below the countries — real entries when present,
              // glassy placeholder cards otherwise (represents the design).
              SliverToBoxAdapter(
                child: StreamBuilder<List<HeritageItem>>(
                  stream: service.streamFeatured(limit: 8),
                  builder: (context, snap) {
                    final items = snap.data ?? const <HeritageItem>[];
                    final has = items.isNotEmpty;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Featured'),
                        SizedBox(
                          height: 190,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: has ? items.length : 4,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) => SizedBox(
                              width: 240,
                              child: has
                                  ? HeritageItemCard(
                                      item: items[i],
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HeritageItemScreen(
                                              item: items[i]),
                                        ),
                                      ),
                                    )
                                  : HeritagePlaceholderCard(
                                      icon: i.isEven
                                          ? Icons.auto_stories_outlined
                                          : Icons.restaurant_outlined,
                                      accent: i.isEven
                                          ? const Color(0xFFB87333)
                                          : const Color(0xFFD4873A),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 80 + bottomInset)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Show-all button ──────────────────────────────────────────────────────────
class _ShowAllButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ShowAllButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withOpacity(0.33)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: _gold, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── All countries (show-all) screen ──────────────────────────────────────────
class AllCountriesScreen extends StatelessWidget {
  final List<HeritageCountry> countries;
  const AllCountriesScreen({super.key, required this.countries});

  @override
  Widget build(BuildContext context) {
    final service = HeritageDataService();
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
        title: const Text('All Countries',
            style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('images/BG.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Colors.black)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.82),
                  ],
                ),
              ),
            ),
          ),
          GridView.builder(
            padding: EdgeInsets.fromLTRB(
                20, topInset + 64, 20, bottomInset + 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: countries.length,
            itemBuilder: (_, i) => _CountryCard(
              country: countries[i],
              service: service,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CountryScreen(country: countries[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Country card ─────────────────────────────────────────────────────────────
class _CountryCard extends StatelessWidget {
  final HeritageCountry country;
  final HeritageDataService service;
  final VoidCallback onTap;

  const _CountryCard({
    required this.country,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop: org-uploaded country image, else one glassy translucent
              // style (frosted over the Heritage background) — never a coloured
              // per-country gradient.
              Positioned.fill(
                child: StreamBuilder<String?>(
                  stream: service.streamNodeBg(country.id),
                  builder: (_, snap) {
                    final url = snap.data;
                    if (url != null && url.isNotEmpty) {
                      return CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _glass(),
                        placeholder: (_, __) => _glass(),
                      );
                    }
                    return _glass();
                  },
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),
              ),
              // Live / Soon badge — from real entry presence.
              Positioned(
                top: 10,
                right: 10,
                child: StreamBuilder<bool>(
                  stream: service.streamCountryHasEntries(country.id),
                  builder: (_, snap) {
                    final live = snap.data ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: live ? _gold : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        live ? 'Live' : 'Soon',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color:
                              live ? const Color(0xFF1A0E00) : Colors.white60,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (country.flagEmoji.isNotEmpty)
                        Text(country.flagEmoji,
                            style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        country.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                      if (country.continent.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          country.continent,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.55)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One consistent glassy translucent fill (frosts the Heritage background)
  /// used for every country without an uploaded image.
  Widget _glass() {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(color: Colors.white.withOpacity(0.07)),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
          color: _textFaint,
        ),
      ),
    );
  }
}

// ─── Search — real entries (recent public set, filtered client-side) ──────────
class _HeritageSearchDelegate extends SearchDelegate<String> {
  final HeritageDataService service;
  _HeritageSearchDelegate(this.service);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: const Color(0xFF0D1F14),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2B1E),
        iconTheme: IconThemeData(color: _textColor),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: _textFaint),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: _textColor, fontSize: 16),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear, color: _textFaint),
          onPressed: () => query = '',
        )
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: _textColor),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return Container(
        color: const Color(0xFF0D1F14),
        child: const Center(
          child: Text('Search stories, food, music, places…',
              style: TextStyle(color: _textFaint, fontSize: 14)),
        ),
      );
    }
    return Container(
      color: const Color(0xFF0D1F14),
      child: StreamBuilder<List<HeritageItem>>(
        stream: service.streamFeatured(limit: 50),
        builder: (context, snap) {
          final all = snap.data ?? const <HeritageItem>[];
          final results = all.where((it) {
            return it.title.toLowerCase().contains(q) ||
                it.description.toLowerCase().contains(q) ||
                it.tags.any((t) => t.toLowerCase().contains(q)) ||
                (it.communityName ?? '').toLowerCase().contains(q);
          }).toList();
          if (results.isEmpty) {
            return Center(
              child: Text('No results for "$query" yet.',
                  style: const TextStyle(color: _textDim, fontSize: 14)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => HeritageItemCard(
              item: results[i],
              compact: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HeritageItemScreen(item: results[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
