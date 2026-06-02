import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─── Heritage dark-theme colour tokens ───────────────────────────────────────
const _deep = Color(0xFF0D1F14);
const _surface = Color(0xFF141F16);
const _surface2 = Color(0xFF1A2B1E);
const _textColor = Color(0xFFE8F0E9);
const _textDim = Color(0x80E8F0E9);
const _textFaint = Color(0x47E8F0E9);
const _gold = Color(0xFFC4A961);
const _goldDim = Color(0x2DC4A961);
const _lgGreen = Color(0xFF86BC9E);
const _green = Color(0xFF2D7A4F);
const _border = Color(0x1F86BC9E);
const _borderGold = Color(0x33C4A961);

// ─── Navigation enum ──────────────────────────────────────────────────────────
enum _HView { home, kenya, luhya, comingSoon }

// ─────────────────────────────────────────────────────────────────────────────
// CommunityHeritageTab — root widget, owns navigation stack
// ─────────────────────────────────────────────────────────────────────────────
class CommunityHeritageTab extends StatefulWidget {
  const CommunityHeritageTab({super.key});

  @override
  State<CommunityHeritageTab> createState() => _CommunityHeritageTabState();
}

class _CommunityHeritageTabState extends State<CommunityHeritageTab> {
  final List<_HView> _stack = [_HView.home];
  String _csName = '';
  String _csSubtitle = '';

  _HView get _current => _stack.last;
  bool get _canPop => _stack.length > 1;

  void _push(_HView view, {String name = '', String subtitle = ''}) =>
      setState(() {
        _stack.add(view);
        _csName = name;
        _csSubtitle = subtitle;
      });

  void _pop() {
    if (_canPop) setState(() => _stack.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_canPop) {
          _pop();
          return false;
        }
        return false;
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey('${_current.index}_${_stack.length}'),
          child: _buildCurrent(),
        ),
      ),
    );
  }

  Widget _buildCurrent() {
    switch (_current) {
      case _HView.home:
        return _HeritageHome(
          onKenyaTap: () => _push(_HView.kenya),
          onCountryComingSoon: (n, s) =>
              _push(_HView.comingSoon, name: n, subtitle: s),
        );
      case _HView.kenya:
        return _KenyaScreen(
          onBack: _pop,
          onLuhyaTap: () => _push(_HView.luhya),
          onTribeComingSoon: (n) => _push(
            _HView.comingSoon,
            name: n,
            subtitle:
                'Cultural content for the $n is being documented by community '
                'knowledge holders. Stories, traditions, food, and history will '
                'appear here.',
          ),
        );
      case _HView.luhya:
        return _LuhyaScreen(onBack: _pop);
      case _HView.comingSoon:
        return _ComingSoonScreen(name: _csName, subtitle: _csSubtitle, onBack: _pop);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1 — Heritage Home (redesigned with BG.png)
// ─────────────────────────────────────────────────────────────────────────────
class _HeritageHome extends StatelessWidget {
  final VoidCallback onKenyaTap;
  final void Function(String name, String subtitle) onCountryComingSoon;

  const _HeritageHome(
      {required this.onKenyaTap, required this.onCountryComingSoon});

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => _showSearch(context),
              icon: const Icon(Icons.search, size: 20, color: _textColor),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Full-screen background image ──
          Positioned.fill(
            child: Image.asset(
              'images/BG.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
            ),
          ),
          // ── Gradient overlay — keeps content legible ──
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
          // ── Scrollable content on top ──
          CustomScrollView(
            slivers: [
              // Space under transparent app bar
              SliverToBoxAdapter(child: SizedBox(height: topInset + 60 + 4)),

              // Quote
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 2,
                        color: _gold,
                        margin: const EdgeInsets.only(bottom: 8),
                      ),
                      const Text(
                        '"Every culture has its own logic,\nits own reason for being."',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: _textDim,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section label
              const SliverToBoxAdapter(child: _SectionLabel('Choose a country')),

              // Country grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _CountryCard(
                        name: 'Kenya',
                        flag: '🇰🇪',
                        emblem: '🌿',
                        subtitle: '45 ethnic groups · 47 counties',
                        gradientStart: const Color(0xFF0D2A1A),
                        gradientEnd: const Color(0xFF2D7A4F),
                        isLive: true,
                        fullWidth: true,
                        onTap: onKenyaTap,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CountryCard(
                              name: 'Uganda',
                              flag: '🇺🇬',
                              emblem: '🦅',
                              subtitle: '56 ethnic groups',
                              gradientStart: const Color(0xFF2A1A0A),
                              gradientEnd: const Color(0xFF5C3810),
                              isLive: false,
                              onTap: () => onCountryComingSoon(
                                'Uganda',
                                '56 ethnic groups · Cultural content is being '
                                    'documented by community knowledge holders and '
                                    'partner organisations.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CountryCard(
                              name: 'Nigeria',
                              flag: '🇳🇬',
                              emblem: '🔥',
                              subtitle: '250+ ethnic groups',
                              gradientStart: const Color(0xFF0A1A2A),
                              gradientEnd: const Color(0xFF0E3D2E),
                              isLive: false,
                              onTap: () => onCountryComingSoon(
                                'Nigeria',
                                '250+ ethnic groups · Cultural content is being '
                                    'documented.',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CountryCard(
                              name: 'Ghana',
                              flag: '🇬🇭',
                              emblem: '🪘',
                              subtitle: '100+ ethnic groups',
                              gradientStart: const Color(0xFF1A0A00),
                              gradientEnd: const Color(0xFF4A2800),
                              isLive: false,
                              onTap: () => onCountryComingSoon(
                                'Ghana',
                                '100+ ethnic groups · Cultural content is being '
                                    'documented.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CountryCard(
                              name: 'Tanzania',
                              flag: '🇹🇿',
                              emblem: '🦁',
                              subtitle: '120+ ethnic groups',
                              gradientStart: const Color(0xFF0D1A0D),
                              gradientEnd: const Color(0xFF1A3D2E),
                              isLive: false,
                              onTap: () => onCountryComingSoon(
                                'Tanzania',
                                '120+ ethnic groups · Cultural content is being '
                                    'documented.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Featured stories
              const SliverToBoxAdapter(child: _SectionLabel('Featured stories')),
              SliverToBoxAdapter(child: _FeaturedStoriesRow()),

              // Bottom padding for transparent nav bar
              SliverToBoxAdapter(child: SizedBox(height: 80 + bottomInset)),
            ],
          ),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(context: context, delegate: _HeritageSearchDelegate());
  }
}

// ─── Search delegate ──────────────────────────────────────────────────────────
class _HeritageSearchDelegate extends SearchDelegate<String> {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: _deep,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface2,
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
  Widget buildResults(BuildContext context) => _buildSearchBody();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchBody();

  Widget _buildSearchBody() {
    if (query.isEmpty) {
      return Container(
        color: _deep,
        child: Center(
          child: Text('Search stories, traditions, foods...',
              style: TextStyle(color: _textFaint, fontSize: 14)),
        ),
      );
    }
    return Container(
      color: _deep,
      child: Center(
        child: Text('No results for "$query" yet.',
            style: const TextStyle(color: _textDim, fontSize: 14)),
      ),
    );
  }
}


// ─── Country card ─────────────────────────────────────────────────────────────
class _CountryCard extends StatelessWidget {
  final String name, flag, emblem, subtitle;
  final Color gradientStart, gradientEnd;
  final bool isLive;
  final bool fullWidth;
  final VoidCallback onTap;

  const _CountryCard({
    required this.name,
    required this.flag,
    required this.emblem,
    required this.subtitle,
    required this.gradientStart,
    required this.gradientEnd,
    required this.isLive,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = fullWidth ? 200.0 : 180.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientStart, gradientEnd],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  emblem,
                  style: TextStyle(fontSize: fullWidth ? 100 : 72),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLive ? _gold : Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isLive ? 'Live' : 'Soon',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isLive ? const Color(0xFF1A0E00) : Colors.white60,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: fullWidth ? 26 : 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.55)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Featured stories row ─────────────────────────────────────────────────────
class _FeaturedStoriesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('heritage_entries')
          .where('visibility', isEqualTo: 'public')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final items = docs.isEmpty ? _staticFeatured : docs
            .map((d) => _FeaturedItem.fromFirestore(d))
            .toList();

        return SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _FeaturedCard(item: items[i]),
          ),
        );
      },
    );
  }

  static final List<_FeaturedItem> _staticFeatured = [
    _FeaturedItem(
      tag: 'Oral tradition · Luhya',
      title: 'Mwambu and Sela — the first Luhya man and woman',
      attribution: 'Luhya Cultural Council · Western Kenya',
      emblem: '🌿',
      gradientStart: const Color(0xFF1A2E0D),
      gradientEnd: const Color(0xFF3D7022),
    ),
    _FeaturedItem(
      tag: 'Myth · Buganda',
      title: 'Kintu — the first man to walk the earth',
      attribution: 'Coming soon · Uganda',
      emblem: '🏔️',
      gradientStart: const Color(0xFF2A1A0A),
      gradientEnd: const Color(0xFF5C3810),
    ),
    _FeaturedItem(
      tag: 'Myth · Yoruba',
      title: 'Olokun — deity of the deep ocean',
      attribution: 'Coming soon · Nigeria',
      emblem: '🌊',
      gradientStart: const Color(0xFF0A1A2A),
      gradientEnd: const Color(0xFF0E3D2E),
    ),
  ];
}

class _FeaturedItem {
  final String tag, title, attribution, emblem;
  final Color gradientStart, gradientEnd;
  final String? imageUrl;

  _FeaturedItem({
    required this.tag,
    required this.title,
    required this.attribution,
    required this.emblem,
    required this.gradientStart,
    required this.gradientEnd,
    this.imageUrl,
  });

  factory _FeaturedItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _FeaturedItem(
      tag: '${d['content_type'] ?? ''} · ${d['locality'] ?? ''}',
      title: d['title'] as String? ?? '',
      attribution: d['locality'] as String? ?? '',
      emblem: '📜',
      gradientStart: const Color(0xFF1A2E0D),
      gradientEnd: const Color(0xFF2D7A4F),
      imageUrl: d['image_url'] as String?,
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final _FeaturedItem item;

  const _FeaturedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGold),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 84,
            width: double.infinity,
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _CardGradientTop(item: item),
                  )
                : _CardGradientTop(item: item),
          ),
          Expanded(
            child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tag.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _gold,
                    letterSpacing: 0.08,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  item.attribution,
                  style: const TextStyle(fontSize: 11, color: _textFaint),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _CardGradientTop extends StatelessWidget {
  final _FeaturedItem item;

  const _CardGradientTop({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [item.gradientStart, item.gradientEnd],
            ),
          ),
        ),
        Center(
          child: Text(item.emblem, style: const TextStyle(fontSize: 44)),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2 — Kenya
// ─────────────────────────────────────────────────────────────────────────────
class _KenyaScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLuhyaTap;
  final void Function(String tribeName) onTribeComingSoon;

  const _KenyaScreen({
    required this.onBack,
    required this.onLuhyaTap,
    required this.onTribeComingSoon,
  });

  @override
  State<_KenyaScreen> createState() => _KenyaScreenState();
}

class _KenyaScreenState extends State<_KenyaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      body: Stack(
        children: [
          // ── Full-screen kenya.png ──
          Positioned.fill(
            child: Image.asset(
              'images/kenya.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D2A1A), Color(0xFF1F5539)],
                  ),
                ),
              ),
            ),
          ),
          // ── Scrim: darkens only the very top so white text is legible ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.25),
                  ],
                  stops: const [0.0, 0.20, 0.38],
                ),
              ),
            ),
          ),
          // ── Column layout — no NestedScrollView ──
          Column(
            children: [
              // Kenya header (below status bar + transparent app bar)
              Padding(
                padding: EdgeInsets.fromLTRB(20, topInset + 56, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🇰🇪', style: TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    const Text(
                      'Kenya',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'East Africa · 1963 independence',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.65)),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        _KenyaStat(label: 'Ethnic groups', value: '45'),
                        SizedBox(width: 20),
                        _KenyaStat(label: 'Counties', value: '47'),
                        SizedBox(width: 20),
                        _KenyaStat(label: 'Languages', value: '68+'),
                        SizedBox(width: 20),
                        _KenyaStat(label: 'Population', value: '55M'),
                      ],
                    ),
                  ],
                ),
              ),
              // Tab bar with translucent dark strip
              Container(
                color: Colors.black.withOpacity(0.28),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Cultures'),
                    Tab(text: 'Food'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
              // Tab content — fills remaining space, transparent so bg shows
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CulturesTab(
                      onLuhyaTap: widget.onLuhyaTap,
                      onTribeComingSoon: widget.onTribeComingSoon,
                    ),
                    const _FoodTab(),
                    const _HistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KenyaStat extends StatelessWidget {
  final String label, value;

  const _KenyaStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45))),
      ],
    );
  }
}

// ─── Cultures tab ─────────────────────────────────────────────────────────────
class _CulturesTab extends StatelessWidget {
  final VoidCallback onLuhyaTap;
  final void Function(String) onTribeComingSoon;

  const _CulturesTab(
      {required this.onLuhyaTap, required this.onTribeComingSoon});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _RegionHeader('Western Kenya'),
        _TribeItem(
          num: '01', emoji: '🌿', name: 'Luhya',
          location: 'Kakamega, Bungoma, Vihiga, Trans Nzoia',
          hasContent: true, onTap: onLuhyaTap,
        ),
        _TribeItem(
          num: '02', emoji: '🎣', name: 'Luo',
          location: 'Kisumu, Siaya, Homa Bay, Migori',
          onTap: () => onTribeComingSoon('Luo'),
        ),
        _TribeItem(
          num: '03', emoji: '🏃', name: 'Kipsigis',
          location: 'Kericho, Bomet',
          onTap: () => onTribeComingSoon('Kipsigis'),
        ),
        _RegionHeader('Central Kenya'),
        _TribeItem(
          num: '04', emoji: '🏔️', name: 'Kikuyu',
          location: 'Kiambu, Muranga, Nyeri, Kirinyaga',
          onTap: () => onTribeComingSoon('Kikuyu'),
        ),
        _TribeItem(
          num: '05', emoji: '🌲', name: 'Meru',
          location: 'Meru, Tharaka-Nithi',
          onTap: () => onTribeComingSoon('Meru'),
        ),
        _TribeItem(
          num: '06', emoji: '🌿', name: 'Embu',
          location: 'Embu County',
          onTap: () => onTribeComingSoon('Embu'),
        ),
        _RegionHeader('Eastern & Coast'),
        _TribeItem(
          num: '07', emoji: '🪵', name: 'Kamba',
          location: 'Machakos, Kitui, Makueni',
          onTap: () => onTribeComingSoon('Kamba'),
        ),
        _TribeItem(
          num: '08', emoji: '🌊', name: 'Mijikenda',
          location: 'Mombasa, Kilifi, Kwale, Lamu',
          onTap: () => onTribeComingSoon('Mijikenda'),
        ),
        _TribeItem(
          num: '09', emoji: '⛵', name: 'Swahili',
          location: 'Mombasa Old Town, Lamu',
          onTap: () => onTribeComingSoon('Swahili'),
        ),
        _RegionHeader('Rift Valley'),
        _TribeItem(
          num: '10', emoji: '🛡️', name: 'Maasai',
          location: 'Kajiado, Narok',
          onTap: () => onTribeComingSoon('Maasai'),
        ),
        _TribeItem(
          num: '11', emoji: '🏃', name: 'Kalenjin',
          location: 'Uasin Gishu, Elgeyo, Nandi, Baringo',
          onTap: () => onTribeComingSoon('Kalenjin'),
        ),
        _TribeItem(
          num: '12', emoji: '🏜️', name: 'Turkana',
          location: 'Turkana County (largest county)',
          onTap: () => onTribeComingSoon('Turkana'),
        ),
        _RegionHeader('North-Eastern'),
        _TribeItem(
          num: '13', emoji: '🪘', name: 'Somali',
          location: 'Garissa, Wajir, Mandera',
          onTap: () => onTribeComingSoon('Somali'),
        ),
        _TribeItem(
          num: '14', emoji: '🌵', name: 'Borana',
          location: 'Marsabit, Isiolo',
          onTap: () => onTribeComingSoon('Borana'),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white.withOpacity(0.88),
          child: const Text(
            '+ 31 more ethnic groups · content being documented',
            style: TextStyle(fontSize: 12, color: Color(0x884A7060)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _RegionHeader extends StatelessWidget {
  final String text;

  const _RegionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      color: Colors.white.withOpacity(0.82),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Color(0xFF6B4F1A),
        ),
      ),
    );
  }
}

class _TribeItem extends StatelessWidget {
  final String num, emoji, name, location;
  final bool hasContent;
  final VoidCallback onTap;

  const _TribeItem({
    required this.num,
    required this.emoji,
    required this.name,
    required this.location,
    required this.onTap,
    this.hasContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          border: const Border(
            bottom: BorderSide(color: Color(0x18000000)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(num,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0x88000000))),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasContent
                          ? const Color(0xFF1A5C35)
                          : const Color(0xFF0D2A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(location,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF4A7060))),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: hasContent
                  ? const Color(0xFFC4A961)
                  : const Color(0x44000000),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Food tab ─────────────────────────────────────────────────────────────────
class _FoodTab extends StatelessWidget {
  const _FoodTab();

  static const _foods = [
    ('🫘', 'Ugali', 'National staple · all regions'),
    ('🍖', 'Nyama choma', 'Grilled meat tradition'),
    ('🥗', 'Mukimo', 'Kikuyu · Central highlands'),
    ('🍚', 'Pilau', 'Swahili · Coastal tradition'),
    ('🌿', 'Isombe', 'Luhya · Western Kenya'),
    ('🫘', 'Githeri', 'Kikuyu · maize + beans'),
    ('🌽', 'Ugali wa wimbi', 'Finger millet ugali'),
    ('🍲', 'Nyoyo', 'Maize + beans mix'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: Colors.white.withOpacity(0.88),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: const Text(
            'Kenyan food traditions vary by region — coast, highlands, '
            'and pastoral communities each have distinct food cultures '
            'shaped by land and history.',
            style: TextStyle(
                fontSize: 13, color: Color(0xFF2D4A38), height: 1.6),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: _foods.length,
            itemBuilder: (_, i) {
              final (emoji, name, tribe) = _foods[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 5),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D2A1A))),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(tribe,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF4A7060))),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.70),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Detailed recipes being documented · contributors welcome',
              style: TextStyle(fontSize: 11, color: Color(0xFF4A7060)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── History tab ──────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  static const _events = [
    ('~3000 BC', 'Cushitic peoples arrive',
     'Early Cushitic communities settle in the northern and eastern regions, '
     'bringing pastoralism and trade routes through the Horn of Africa.'),
    ('~1000 AD', 'Swahili coast trade networks',
     'Arab, Persian, and Indian traders establish coastal settlements. The '
     'Swahili culture emerges — a blend of Bantu and Islamic traditions that '
     'still defines Mombasa and Lamu.'),
    ('1400s', 'Bantu migration south',
     'Bantu-speaking communities including the Kikuyu, Luhya, Luo, and Kamba '
     'settle across the highlands and lake basin, establishing clan systems '
     'still intact today.'),
    ('1895', 'British East Africa Protectorate',
     'Colonial boundaries drawn with no regard for ethnic territories — '
     'communities divided, languages suppressed, land alienated in the '
     'highlands.'),
    ('1952', 'Mau Mau uprising',
     'Predominantly Kikuyu-led resistance against colonial land theft. Declared '
     'a state of emergency. A defining moment in Kenya\'s path to independence.'),
    ('1963', 'Independence — Uhuru',
     'Kenya gains independence on December 12th. Jomo Kenyatta becomes the '
     'first Prime Minister. 45 ethnic communities now share one nation-state.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _events.length,
      itemBuilder: (_, i) {
        final (year, title, body) = _events[i];
        final isLast = i == _events.length - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year column with timeline line
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC4A961).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(year,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B4F1A))),
                    ),
                    if (!isLast)
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: const Color(0x33C4A961),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D2A1A))),
                      const SizedBox(height: 5),
                      Text(body,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2D4A38),
                              height: 1.60)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 3 — Luhya Tribe Detail (redesigned with K_FOREST.png)
// ─────────────────────────────────────────────────────────────────────────────
class _LuhyaScreen extends StatelessWidget {
  final VoidCallback onBack;

  const _LuhyaScreen({required this.onBack});

  static const _subGroups = [
    ('Bukusu', 'Bungoma County'), ('Maragoli', 'Vihiga County'),
    ('Banyore', 'Vihiga County'), ('Batsotso', 'Kakamega'),
    ('Idakho', 'Kakamega'), ('Isukha', 'Kakamega'),
    ('Kabras', 'Kakamega'), ('Tiriki', 'Vihiga'),
    ('Wanga', 'Mumias, Kakamega'), ('Marachi', 'Busia County'),
    ('Samia', 'Busia County'), ('Kisa', 'Kakamega'),
    ('Marama', 'Kakamega'), ('Tachoni', 'Bungoma'),
    ('Nyala', 'Kakamega'), ('Banyala', 'Kakamega'),
    ('Khayo', 'Busia'), ('Nyore', 'Vihiga'),
  ];

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: onBack,
        ),
      ),
      body: Stack(
        children: [
          // ── Full-screen K_FOREST.png ──
          Positioned.fill(
            child: Image.asset(
              'images/K_FOREST.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
            ),
          ),
          // ── Gradient overlay — darkens progressively downward ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.18),
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.72),
                    Colors.black.withOpacity(0.92),
                  ],
                  stops: const [0.0, 0.25, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // ── Scrollable content ──
          CustomScrollView(
            slivers: [
              // Hero title section — floats over the image
              SliverToBoxAdapter(
                child: SizedBox(
                  height: topInset + 56 + 180,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Luhya',
                              style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Western Kenya · Bantu · ~7 million people',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5))),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              'Bantu origin',
                              '18 sub-groups',
                              'Oluhya language',
                              'Kakamega heartland',
                            ]
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(t,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverList(
            delegate: SliverChildListDelegate([
              _ContentBlock(
                title: 'Who are the Luhya?',
                body:
                    'The Luhya — also written Luyia or Abaluyia — are the second-largest '
                    'ethnic group in Kenya, numbering approximately 7 million people. They '
                    'occupy the fertile lands of western Kenya, primarily in the counties of '
                    'Kakamega, Bungoma, Vihiga, Trans Nzoia, and parts of Busia.\n\n'
                    'The name Abaluyia means "those of the same hearth" — a reference to '
                    'the shared fireplace that once symbolised community belonging. The '
                    'Luhya are not a single tribe but a confederation of 18 sub-groups, '
                    'each with distinct dialects and traditions, united by a shared Bantu '
                    'origin.',
              ),
              _ContentBlock(
                title: 'The 18 sub-groups',
                body: '',
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: _subGroups.length,
                  itemBuilder: (_, i) {
                    final (name, county) = _subGroups[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name, style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500, color: _textColor)),
                          Text(county, style: const TextStyle(
                              fontSize: 11, color: _textDim)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('ORIGIN STORIES', style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    letterSpacing: 1.0, color: _gold)),
              ),
              _StoryCard(
                tag: 'Oral tradition · creation myth',
                title: 'Mwambu and Sela — the first Luhya man and woman',
                body:
                    'In the beginning, Were — the supreme creator — made Mwambu, '
                    'the first man, and placed him on earth. He gave him Sela for '
                    'a wife. Mwambu and Sela were the ancestors of the Abaluyia. '
                    'Were told them: "The land is yours, tend it well. The cattle '
                    'are yours, care for them. Your children shall fill the earth."\n\n'
                    'Mwambu and Sela had many children, and as the family grew they '
                    'spread across the western highlands. Each child became the '
                    'founder of a sub-group — Bukusu, Maragoli, Wanga — each '
                    'carrying a part of the original instruction from Were. The '
                    'Luhya say: Omwana ka omukana — a child is the child of '
                    'everyone.',
                meta: 'Oral tradition · documented in Oluhya and English · Western Kenya',
              ),
              _StoryCard(
                tag: 'Historical story · The Bukusu',
                title: 'Maina wa Mutsembi and the Bukusu circumcision rite',
                body:
                    'The Bukusu circumcision — Imbalu — is performed every '
                    'even-numbered year and is among the most significant cultural '
                    'events in western Kenya. Young men are circumcised publicly '
                    'without anaesthetic as a test of courage and entry into '
                    'adulthood.\n\n'
                    'The ceremony begins with the candidate smearing white clay on '
                    'their body and dancing through the village before dawn. Elders, '
                    'family, and community gather to witness. A man who flinches is '
                    'considered to have shamed his lineage. The scar is permanent — '
                    'it is the mark of having stood.',
                meta: 'Documented by Luhya Cultural Council · Bungoma County',
              ),
              _ContentBlock(
                title: 'Language',
                body:
                    'Oluhya is not a single language but a dialect continuum — a '
                    'family of related Bantu dialects that are mutually intelligible '
                    'to varying degrees. Lubukusu (spoken by the Bukusu) and '
                    'Luragoli (spoken by the Maragoli) are the most divergent.\n\n'
                    'Key phrases in Oluhya:\n'
                    '· Oli otyani? — How are you?\n'
                    '· Ndi mwega — I am fine\n'
                    '· Amina — Amen / so be it\n'
                    '· Mwana wange — my child',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('MUSIC & CEREMONY', style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    letterSpacing: 1.0, color: _gold)),
              ),
              ...[
                ('Imbalu circumcision chant', 'Pre-dawn ceremony song · Bukusu sub-group', 'Lubukusu'),
                ('Isukuti drum ensemble', 'Traditional celebration drumming · weddings and harvest', 'Oluhya'),
                ('Omwana alilira', 'Lullaby · sung by mothers during harvest season', 'Luragoli'),
              ].map((e) => _MusicItem(title: e.$1, subtitle: e.$2, lang: e.$3)),
              _ContentBlock(
                title: 'Food traditions',
                body:
                    'Luhya cuisine is rooted in the fertile agricultural land of '
                    'western Kenya. Staple foods include ugali made from maize or '
                    'sorghum flour, served with isombe (cassava leaves), kunde '
                    '(cowpeas), mrenda (a mucilaginous vegetable), and ekeberi '
                    '(cow innards).\n\n'
                    'The Luhya are also known for their love of chicken — '
                    'particularly ingokho (local chicken) — central to celebrations '
                    'and hospitality. The bull holds ceremonial importance; a '
                    'household that slaughters one for a guest demonstrates wealth '
                    'and honour.',
              ),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                      child: const Center(
                        child: Text('LC', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Documented by Luhya Cultural Council · Kakamega\n'
                        'Content verified by community elders · Open for additions',
                        style: TextStyle(fontSize: 11, color: _textFaint, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 32 + bottomInset)),
        ],
      ),
    ],
  ),
    );
  }
}

// ─── Content block ────────────────────────────────────────────────────────────
class _ContentBlock extends StatelessWidget {
  final String title, body;
  final Widget? child;

  const _ContentBlock({required this.title, required this.body, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: _textColor)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(fontSize: 14, color: _textDim, height: 1.75)),
          ],
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

// ─── Story card ───────────────────────────────────────────────────────────────
class _StoryCard extends StatelessWidget {
  final String tag, title, body, meta;

  const _StoryCard({required this.tag, required this.title,
      required this.body, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: const BorderSide(color: _gold, width: 3),
          top: BorderSide(color: _borderGold),
          right: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tag.toUpperCase(), style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600,
              color: _gold, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: _textColor, height: 1.3)),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(
              fontSize: 13, color: _textDim, height: 1.65)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Text(meta,
                style: const TextStyle(fontSize: 11, color: _textFaint)),
          ),
        ],
      ),
    );
  }
}

// ─── Music item ───────────────────────────────────────────────────────────────
class _MusicItem extends StatelessWidget {
  final String title, subtitle, lang;

  const _MusicItem({required this.title, required this.subtitle, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _goldDim, shape: BoxShape.circle,
              border: Border.all(color: _borderGold),
            ),
            child: const Icon(Icons.play_arrow, color: _gold, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: _textColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _textDim)),
              ],
            ),
          ),
          Text(lang, style: const TextStyle(fontSize: 10, color: _textFaint)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 4 — Coming Soon
// ─────────────────────────────────────────────────────────────────────────────
class _ComingSoonScreen extends StatelessWidget {
  final String name, subtitle;
  final VoidCallback onBack;

  const _ComingSoonScreen(
      {required this.name, required this.subtitle, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deep,
      appBar: AppBar(
        backgroundColor: _deep,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.length <= 2 ? name : '🗺️',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w600, color: _lgGreen)),
              const SizedBox(height: 16),
              const Text('📖', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Coming soon', style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w600, color: _textColor)),
              const SizedBox(height: 12),
              Text(subtitle, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _textDim, height: 1.7)),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: _goldDim,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: _borderGold),
                  ),
                  child: const Text('Notify me when ready',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: _gold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
