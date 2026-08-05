import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../Models/marketplace/canopy_listing.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/widgets/location_switcher.dart';
import 'marketplace_item_view.dart';
import 'marketplace_shop_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SAMPLE DATA — shown ONLY when a location genuinely has no listings yet.
//
// These used to be the entire screen: eco_shop had zero Firestore calls and
// rendered these fixtures as though they were the marketplace. They are now
// what they claim to be — an empty state — and every surface that shows them
// is labelled "Sample" so a demo can never be mistaken for live inventory.
//
// Note what the fixtures cannot express: no story, no material DNA, no named
// collector, no provenance chain. That is the distinction the real model
// carries and the placeholders never did.
// ─────────────────────────────────────────────────────────────────────────────

final _featuredPlaceholders = [
  _PlaceholderItem(
    imageUrl:
        'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=900&auto=format&fit=crop',
    title: 'Nairobi River Copper Bangles',
    tagline: 'Each ring holds 18 months of Mathare River stories',
    price: 'KSh 1,200',
    maker: 'Amina Wanjiku',
    makerCity: 'Kibera, Nairobi',
    kgDiverted: 0.84,
    badge: 'Circular Craft',
    category: 'Jewellery',
  ),
  _PlaceholderItem(
    imageUrl:
        'https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a?w=900&auto=format&fit=crop',
    title: 'Aksum Reclaimed Lamp',
    tagline: 'Industrial copper wire, transformed in Addis Ababa',
    price: 'KSh 4,800',
    maker: 'Dawit Bekele Workshop',
    makerCity: 'Addis Ababa, Ethiopia',
    kgDiverted: 2.3,
    badge: 'Circular Craft',
    category: 'Homeware',
  ),
  _PlaceholderItem(
    imageUrl:
        'https://images.unsplash.com/photo-1464349153735-7db50ed83c84?w=900&auto=format&fit=crop',
    title: 'Lagos Tyre-Sole Sandals',
    tagline: 'Every step on what used to be a flood hazard',
    price: 'KSh 950',
    maker: 'Chibuzor Crafts',
    makerCity: 'Lagos, Nigeria',
    kgDiverted: 1.1,
    badge: 'Circular Craft',
    category: 'Fashion',
  ),
];

final _storyPlaceholders = [
  _StoryItem(
    imageUrl:
        'https://images.unsplash.com/photo-1590492181492-9efd75b27ae9?w=700&auto=format&fit=crop',
    title: 'Pallet Table with Nairobi Skyline Inlay',
    price: 'KSh 18,500',
    maker: 'Kibera Makers Collective',
    city: 'Kibera',
    kgDiverted: 12.4,
    category: 'Furniture',
  ),
  _StoryItem(
    imageUrl:
        'https://images.unsplash.com/photo-1578922746465-3a80a228f223?w=700&auto=format&fit=crop',
    title: 'Fused Glass Panel — Akosombo Dam Series',
    price: 'KSh 7,200',
    maker: 'Accra Glass Studio',
    city: 'Accra',
    kgDiverted: 3.8,
    category: 'Ceramics',
  ),
  _StoryItem(
    imageUrl:
        'https://images.unsplash.com/photo-1530026405186-ed1f139313f8?w=700&auto=format&fit=crop',
    title: 'Mathare Copper Wire Sculpture — "Rising"',
    price: 'KSh 22,000',
    maker: 'James Odhiambo',
    city: 'Mathare',
    kgDiverted: 5.6,
    category: 'Sculpture',
  ),
  _StoryItem(
    imageUrl:
        'https://images.unsplash.com/photo-1445116572660-236099ec97a0?w=700&auto=format&fit=crop',
    title: 'Upcycled Denim Patchwork Jacket',
    price: 'KSh 3,400',
    maker: 'Zola & Thread',
    city: 'Cape Town',
    kgDiverted: 0.9,
    category: 'Fashion',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EcoShopScreen extends StatefulWidget {
  const EcoShopScreen({super.key});

  @override
  State<EcoShopScreen> createState() => _EcoShopScreenState();
}

class _EcoShopScreenState extends State<EcoShopScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late AnimationController _heroAnim;
  late Animation<double> _heroFade;

  String _selectedCategory = 'All';
  String _selectedContinent = 'All';
  bool _showSearch = false;
  bool _onlyCircularBadge = false;

  // ── Live data ──────────────────────────────────────────────────────────────
  StreamSubscription<List<CanopyListing>>? _sub;
  List<CanopyListing> _offering = const [];
  List<CanopyListing> _wanted = const [];
  MarketplaceTotals? _totals;
  bool _loading = true;
  LocationFilter? _boundFilter;

  bool get _isEmpty => _offering.isEmpty && _wanted.isEmpty;

  static const _categories = [
    'All',
    'Jewellery',
    'Furniture',
    'Fashion',
    'Sculpture',
    'Homeware',
    'Ceramics',
    'Prints',
  ];

  static const _continents = [
    'All',
    'Africa',
    'Europe',
    'Americas',
    'Asia',
  ];

  // The hardcoded city chip list that used to live here (Nairobi, Lagos,
  // Accra, Cape Town…) filtered nothing — it was decoration over placeholder
  // data. Location is now the canonical LocationSwitcher, backed by the
  // 47-county registry, and it drives the actual Firestore query.

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _heroFade = CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut);
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-subscribe whenever the location switch moves. Guarded on equality so
    // an unrelated provider rebuild does not tear down a healthy stream.
    final filter = context.watch<LocationProvider>().filter;
    if (_boundFilter != filter) {
      _boundFilter = filter;
      _subscribe(filter);
    }
  }

  void _subscribe(LocationFilter filter) {
    _sub?.cancel();
    // Assigned directly rather than via setState: this runs from
    // didChangeDependencies, which is already inside the build phase.
    _loading = true;

    final service = ListingService.instance;
    _sub = service
        .watch(ListingQuery(
          // Geography is the only predicate pushed to Firestore. Category,
          // badge and search are applied by _visible() over the result, so
          // toggling them never needs a new subscription.
          location: filter,
        ))
        .listen((all) {
      if (!mounted) return;
      setState(() {
        _offering = all.where((l) => l.isOffering).toList();
        _wanted = all.where((l) => l.isSeeking).toList();
        _loading = false;
      });
    }, onError: (Object _) {
      if (mounted) setState(() => _loading = false);
    });

    service.totals(filter).then((t) {
      if (mounted) setState(() => _totals = t);
    });
  }

  /// Client-side narrowing on top of the geo-scoped stream: category chips,
  /// the Circular Craft toggle, and the search field.
  List<CanopyListing> _visible(List<CanopyListing> source) {
    final q = _searchController.text.trim().toLowerCase();
    return source.where((l) {
      if (_selectedCategory != 'All' &&
          l.category.label.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_onlyCircularBadge &&
          l.circularBadge != CircularBadgeTier.verified) return false;
      if (_selectedContinent != 'All' &&
          (l.location.countryName ?? '').isNotEmpty &&
          _selectedContinent != 'Africa') {
        // Continent is only meaningful once non-African sellers exist; until
        // then treat anything other than Africa as a no-match rather than
        // silently ignoring the filter.
        return false;
      }
      if (q.isNotEmpty) {
        final hay = '${l.title} ${l.tagline} ${l.story} '
                '${l.seller.shopName} ${l.location.label}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _heroAnim.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0), // warm off-white — editorial
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildCategoryRail()),
            const SliverToBoxAdapter(child: LocationSwitcher()),
            if (_loading)
              const SliverToBoxAdapter(child: _LoadingStrip())
            else if (_isEmpty)
              SliverToBoxAdapter(child: _buildEmptyNotice()),
            SliverToBoxAdapter(child: _buildHeroCarousel()),

            // ── WANTED ────────────────────────────────────────────────────
            // Materials an environmental participant needs bought. This is
            // the half of the marketplace that previously had no public
            // surface anywhere in the app.
            if (_visible(_wanted).isNotEmpty) ...[
              SliverToBoxAdapter(
                  child: _buildSectionHeader(
                label: 'Wanted Near You',
                sub: 'Collectors and processors looking to buy — fill an order',
                icon: Icons.campaign_outlined,
              )),
              SliverToBoxAdapter(child: _buildWantedRail()),
            ],

            SliverToBoxAdapter(
                child: _buildSectionHeader(
              label: 'Stories from the Ground',
              sub: 'Objects with origin — made by hands you can name',
              icon: Icons.auto_stories_outlined,
            )),
            SliverToBoxAdapter(child: _buildStoryGrid()),
            SliverToBoxAdapter(child: _buildCircularBadgeBanner()),
            SliverToBoxAdapter(
                child: _buildSectionHeader(
              label: 'Featured Makers',
              sub:
                  'Workshops doing extraordinary things with recovered materials',
              icon: Icons.storefront_outlined,
            )),
            SliverToBoxAdapter(child: _buildFeaturedShopsRail()),
            SliverToBoxAdapter(child: _buildImpactTicker()),
            SliverToBoxAdapter(
                child: _buildSectionHeader(
              label: 'Newly Listed',
              sub: 'Fresh from the workshop',
              icon: Icons.new_releases_outlined,
            )),
            SliverToBoxAdapter(child: _buildNewListingsGrid()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF7F5F0),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: AppTheme.darkGreen),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'CANOPY MARKET',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 3,
            ),
          ),
          Text(
            'Objects made, not manufactured',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.accent.withOpacity(0.8),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: () => setState(() => _showSearch = !_showSearch),
          icon: Icon(
            _showSearch ? Icons.close : Icons.search,
            color: AppTheme.darkGreen,
            size: 22,
          ),
        ),
        IconButton(
          onPressed: _showFilterSheet,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.tune_rounded,
                  color: AppTheme.darkGreen, size: 22),
              if (_onlyCircularBadge)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppTheme.lightGreen.withOpacity(0.2),
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    if (!_showSearch) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(
            color: AppTheme.darkGreen,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search objects, makers, materials…',
            hintStyle: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.35),
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search,
                color: AppTheme.primary.withOpacity(0.6), size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Category rail ──────────────────────────────────────────────────────────

  Widget _buildCategoryRail() {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.darkGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppTheme.darkGreen
                      : AppTheme.lightGreen.withOpacity(0.35),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppTheme.darkGreen.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : AppTheme.darkGreen.withOpacity(0.65),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Location rail ──────────────────────────────────────────────────────────

  // ── Empty / sample notice ─────────────────────────────────────────────────

  Widget _buildEmptyNotice() {
    final location = context.read<LocationProvider>();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.tertiary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.tertiary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppTheme.darkGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No listings in ${location.filter.label} yet',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen),
                ),
                const SizedBox(height: 2),
                Text(
                  'Everything below is sample content, shown so the layout '
                  'makes sense. Widen your location to find real listings.',
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppTheme.darkGreen.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: location.showEverywhere,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Everywhere',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Wanted rail ───────────────────────────────────────────────────────────

  Widget _buildWantedRail() {
    final wanted = _visible(_wanted);
    return SizedBox(
      height: 158,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: wanted.length,
        itemBuilder: (context, i) => _WantedCard(listing: wanted[i]),
      ),
    );
  }

  // ── Hero carousel ──────────────────────────────────────────────────────────

  Widget _buildHeroCarousel() {
    final live = _visible(_offering.where((l) => l.isCreative).toList());
    final items = live.isNotEmpty
        ? live.take(6).map(_PlaceholderItem.fromListing).toList()
        : _featuredPlaceholders;
    final ids = live.isNotEmpty ? live.take(6).map((l) => l.id).toList() : null;

    return FadeTransition(
      opacity: _heroFade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: PageView.builder(
              padEnds: false,
              controller: PageController(viewportFraction: 0.88),
              itemCount: items.length,
              itemBuilder: (context, i) => _HeroCard(
                item: items[i],
                index: i,
                listingId: ids?[i],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Story grid ─────────────────────────────────────────────────────────────

  Widget _buildStoryGrid() {
    // Only listings that actually carry a story earn this treatment — the
    // section is called "Stories from the Ground" and should not be padded
    // out with specification-only supply listings.
    final live = _visible(_offering)
        .where((l) => l.story.trim().length >= 40)
        .take(6)
        .toList();
    final items = live.isNotEmpty
        ? live.map(_StoryItem.fromListing).toList()
        : _storyPlaceholders;
    final ids = live.isNotEmpty ? live.map((l) => l.id).toList() : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: List.generate(items.length, (i) {
          return _StoryCard(
            item: items[i],
            isReversed: i.isOdd,
            listingId: ids?[i],
          );
        }),
      ),
    );
  }

  // ── Circular Badge banner ──────────────────────────────────────────────────

  Widget _buildCircularBadgeBanner() {
    return GestureDetector(
      onTap: () => setState(() => _onlyCircularBadge = !_onlyCircularBadge),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGreen.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_outlined,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Circular Craft Badge',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Materials sourced directly from verified collectors on Canopy — the loop is closed.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.tertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _onlyCircularBadge ? 'ON' : 'Filter',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Featured shops rail ────────────────────────────────────────────────────

  Widget _buildFeaturedShopsRail() {
    final shops = [
      _ShopPreview(
        name: 'Kibera Makers Collective',
        city: 'Kibera, Nairobi',
        logoUrl:
            'https://images.unsplash.com/photo-1590086782957-93c06ef21604?w=200&auto=format&fit=crop',
        badge: 'Circular Craft',
        listings: 24,
        kgDiverted: 48.6,
      ),
      _ShopPreview(
        name: 'Dawit Bekele Workshop',
        city: 'Addis Ababa',
        logoUrl:
            'https://images.unsplash.com/photo-1593104547489-5cfb3839a3b5?w=200&auto=format&fit=crop',
        badge: 'Maker',
        listings: 11,
        kgDiverted: 22.1,
      ),
      _ShopPreview(
        name: 'Accra Glass Studio',
        city: 'Accra, Ghana',
        logoUrl:
            'https://images.unsplash.com/photo-1601699165292-b3b1acd6472c?w=200&auto=format&fit=crop',
        badge: 'Circular Craft',
        listings: 8,
        kgDiverted: 14.3,
      ),
      _ShopPreview(
        name: 'Zola & Thread',
        city: 'Cape Town',
        logoUrl:
            'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=200&auto=format&fit=crop',
        badge: 'Maker',
        listings: 19,
        kgDiverted: 8.7,
      ),
    ];

    return SizedBox(
      height: 168,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: shops.length,
        itemBuilder: (context, i) => _ShopPreviewCard(shop: shops[i]),
      ),
    );
  }

  // ── Impact ticker ──────────────────────────────────────────────────────────

  Widget _buildImpactTicker() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Read-only aggregates derived from listing records — never typed
          // in by hand. Same rule the Dashboard follows: impact figures are
          // computed from operational data or they are not shown.
          _ImpactStat(
              value: _totals == null
                  ? '—'
                  : _formatKg(_totals!.kgDiverted),
              label: 'Diverted'),
          _divider(),
          _ImpactStat(
              value: _totals == null ? '—' : '${_totals!.creative}',
              label: 'Made items'),
          _divider(),
          _ImpactStat(
              value: _totals == null
                  ? '—'
                  : '${_totals!.collectorsCredited}',
              label: 'Collectors named'),
          _divider(),
          _ImpactStat(
              value: _totals == null ? '—' : '${_totals!.seeking}',
              label: 'Open requests'),
        ],
      ),
    );
  }

  static String _formatKg(double kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}t';
    return '${kg.round()}kg';
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: AppTheme.lightGreen.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );

  // ── New listings grid ──────────────────────────────────────────────────────

  /// (card model, listing id) pairs — id is null for sample content, which is
  /// how the cards know not to navigate into a listing that does not exist.
  List<(_StoryItem, String?)> get _newestItems {
    final live = _visible(_offering).take(8).toList();
    if (live.isEmpty) {
      return _storyPlaceholders.map((p) => (p, null as String?)).toList();
    }
    return live.map((l) => (_StoryItem.fromListing(l), l.id)).toList();
  }

  Widget _buildNewListingsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _newestItems.length,
        itemBuilder: (context, i) {
          final entry = _newestItems[i];
          return _GridCard(item: entry.$1, listingId: entry.$2);
        },
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
      {required String label, required String sub, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.darkGreen.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter sheet ───────────────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        selectedContinent: _selectedContinent,
        onlyCircularBadge: _onlyCircularBadge,
        onApply: ({required continent, required circularOnly}) {
          setState(() {
            _selectedContinent = continent;
            _onlyCircularBadge = circularOnly;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final _PlaceholderItem item;
  final int index;

  /// Real /listings document id. Null means this card is sample content and
  /// must not navigate — the old code always pushed 'placeholder_$index' into
  /// the item view, which then had nothing to load.
  final String? listingId;

  const _HeroCard({
    required this.item,
    required this.index,
    this.listingId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: listingId == null
          ? () => _sampleTapNotice(context)
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MarketplaceItemViewScreen(listingId: listingId!),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(right: 14, left: 4, bottom: 8, top: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGreen.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  child: const Icon(Icons.image_outlined,
                      color: AppTheme.primary, size: 48),
                ),
              ),

              // Deep gradient scrim
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.3, 0.55, 1.0],
                  ),
                ),
              ),

              // Circular Craft badge — top left
              Positioned(
                top: 14,
                left: 14,
                child: _BadgePill(label: item.badge, gold: true),
              ),

              // Category — top right
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.2,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.tagline,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Maker chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.person_outline,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(item.maker,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          const SizedBox(width: 6),
                          // Impact chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.tertiary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${item.kgDiverted}kg rescued',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Spacer(),
                          // Price
                          Text(
                            item.price,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// STORY CARD — editorial, alternating layout
// ─────────────────────────────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final _StoryItem item;
  final bool isReversed;
  final String? listingId;

  const _StoryCard({
    required this.item,
    required this.isReversed,
    this.listingId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: listingId == null
          ? () => _sampleTapNotice(context)
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MarketplaceItemViewScreen(listingId: listingId!),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: isReversed
              ? [_buildContent(context), _buildImage()]
              : [_buildImage(), _buildContent(context)],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(
        width: 130,
        height: 145,
        child: Stack(fit: StackFit.expand, children: [
          Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.lightGreen.withOpacity(0.15),
              child: const Icon(Icons.image_outlined, color: AppTheme.primary),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.darkGreen.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.place_outlined,
                  size: 11, color: AppTheme.accent),
              const SizedBox(width: 3),
              Flexible(
                child: Text(item.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${item.kgDiverted}kg material given new life',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SizedBox.shrink(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    item.price,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward,
                      size: 12, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID CARD
// ─────────────────────────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final _StoryItem item;
  final String? listingId;

  const _GridCard({required this.item, this.listingId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: listingId == null
          ? () => _sampleTapNotice(context)
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MarketplaceItemViewScreen(listingId: listingId!),
                ),
              ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.lightGreen.withOpacity(0.12),
                    ),
                  ),
                  // Wishlist button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.favorite_border,
                          size: 13, color: AppTheme.darkGreen),
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.place_outlined,
                        size: 10, color: AppTheme.accent),
                    const SizedBox(width: 2),
                    Text(item.city,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.darkGreen.withOpacity(0.5),
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(
                      item.price,
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.kgDiverted}kg',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOP PREVIEW CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ShopPreviewCard extends StatelessWidget {
  final _ShopPreview shop;

  const _ShopPreviewCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MarketplaceShopViewScreen(sellerId: shop.name),
        ),
      ),
      child: Container(
        width: 145,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Image.network(
                    shop.logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.lightGreen.withOpacity(0.2),
                      child: const Icon(Icons.storefront,
                          size: 20, color: AppTheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BadgePill(
                    label: shop.badge, gold: shop.badge == 'Circular Craft'),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              shop.name,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.2,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.place_outlined,
                  size: 10, color: AppTheme.accent),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  shop.city,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.darkGreen.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const Spacer(),
            Row(children: [
              Text(
                '${shop.listings} items',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.darkGreen.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${shop.kgDiverted}kg',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String selectedContinent;
  final bool onlyCircularBadge;
  final void Function({
    required String continent,
    required bool circularOnly,
  }) onApply;

  const _FilterSheet({
    required this.selectedContinent,
    required this.onlyCircularBadge,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _continent;
  late bool _circularOnly;

  static const _continents = ['All', 'Africa', 'Europe', 'Americas', 'Asia'];

  @override
  void initState() {
    super.initState();
    _continent = widget.selectedContinent;
    _circularOnly = widget.onlyCircularBadge;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Filter',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Region',
              style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _continents.map((c) {
              final sel = _continent == c;
              return GestureDetector(
                onTap: () => setState(() => _continent = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.darkGreen : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? AppTheme.darkGreen
                          : AppTheme.lightGreen.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : AppTheme.darkGreen.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Circular Craft Badge only',
                      style: TextStyle(
                          color: AppTheme.darkGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('On-platform sourced materials',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.45))),
                ],
              ),
            ),
            Switch(
              value: _circularOnly,
              onChanged: (v) => setState(() => _circularOnly = v),
              activeColor: AppTheme.primary,
            ),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => widget.onApply(
                  continent: _continent, circularOnly: _circularOnly),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.darkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Apply Filters',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED BADGE PILL
// ─────────────────────────────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  final String label;
  final bool gold;

  const _BadgePill({required this.label, this.gold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gold
            ? AppTheme.tertiary.withOpacity(0.15)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gold
              ? AppTheme.tertiary.withOpacity(0.5)
              : Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified,
            size: 9,
            color: gold ? AppTheme.tertiary : Colors.white.withOpacity(0.8)),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: gold ? AppTheme.tertiary : Colors.white.withOpacity(0.9),
            letterSpacing: 0.3,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPACT STAT
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactStat extends StatelessWidget {
  final String value;
  final String label;

  const _ImpactStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.darkGreen.withOpacity(0.5),
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES FOR PLACEHOLDERS
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderItem {
  final String imageUrl;
  final String title;
  final String tagline;
  final String price;
  final String maker;
  final String makerCity;
  final double kgDiverted;
  final String badge;
  final String category;

  const _PlaceholderItem({
    required this.imageUrl,
    required this.title,
    required this.tagline,
    required this.price,
    required this.maker,
    required this.makerCity,
    required this.kgDiverted,
    required this.badge,
    required this.category,
  });

  /// Adapter so the existing editorial cards can render real records without
  /// being rewritten. The listing's own fields carry more than this view model
  /// can express — story, material DNA, credited collectors — which the item
  /// view surfaces in full.
  factory _PlaceholderItem.fromListing(CanopyListing l) => _PlaceholderItem(
        imageUrl: l.coverImage ?? _fallbackImage(l),
        title: l.title,
        tagline: l.tagline.isNotEmpty
            ? l.tagline
            : (l.story.length > 90 ? '${l.story.substring(0, 87)}…' : l.story),
        price: l.pricing.display,
        maker: l.seller.shopName.isNotEmpty
            ? l.seller.shopName
            : (l.orgName ?? 'Canopy maker'),
        makerCity: l.location.label,
        kgDiverted: l.impact.kgDiverted,
        badge: l.circularBadge.label,
        category: l.category.label,
      );
}

String _fallbackImage(CanopyListing l) =>
    'https://picsum.photos/seed/${l.id}/900/700';

class _StoryItem {
  final String imageUrl;
  final String title;
  final String price;
  final String maker;
  final String city;
  final double kgDiverted;
  final String category;

  const _StoryItem({
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.maker,
    required this.city,
    required this.kgDiverted,
    required this.category,
  });

  factory _StoryItem.fromListing(CanopyListing l) => _StoryItem(
        imageUrl: l.coverImage ?? _fallbackImage(l),
        title: l.title,
        price: l.pricing.display,
        maker: l.seller.shopName.isNotEmpty
            ? l.seller.shopName
            : (l.orgName ?? 'Canopy maker'),
        city: l.location.shortLabel,
        kgDiverted: l.impact.kgDiverted,
        category: l.category.label,
      );
}

class _ShopPreview {
  final String name;
  final String city;
  final String logoUrl;
  final String badge;
  final int listings;
  final double kgDiverted;

  const _ShopPreview({
    required this.name,
    required this.city,
    required this.logoUrl,
    required this.badge,
    required this.listings,
    required this.kgDiverted,
  });
}


// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

void _sampleTapNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Sample item — no listing behind this yet'),
      backgroundColor: AppTheme.darkGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(AppTheme.primary.withOpacity(0.6)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WANTED CARD
//
// A buy request from someone on the environmental side — a processor needing
// PET, a maker needing copper wire for a commission. Distinct visual language
// from a for-sale card because the action is inverted: you respond to it, you
// do not purchase it.
// ─────────────────────────────────────────────────────────────────────────────

class _WantedCard extends StatelessWidget {
  final CanopyListing listing;

  const _WantedCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final needed = listing.quantity.remainingKg.round();
    final unit = listing.pricing.unit == PriceUnit.perKg ? 'kg' : 'units';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MarketplaceItemViewScreen(listingId: listing.id),
        ),
      ),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.tertiary.withOpacity(0.55), width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('WANTED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7)),
                ),
                if (listing.fulfilment.isRecurring) ...[
                  const SizedBox(width: 6),
                  Text('Standing order',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent.withOpacity(0.85))),
                ],
                const Spacer(),
                Icon(Icons.place_outlined,
                    size: 11, color: AppTheme.darkGreen.withOpacity(0.4)),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    listing.location.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              listing.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 3),
            Text(
              listing.orgName ?? listing.seller.shopName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.55),
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  listing.pricing.display,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.tertiary,
                      height: 1),
                ),
                const SizedBox(width: 5),
                Text('offered',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.darkGreen.withOpacity(0.5))),
              ],
            ),
            const SizedBox(height: 8),
            if (needed > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: listing.quantity.fillProgress,
                  minHeight: 4,
                  backgroundColor: AppTheme.lightGreen.withOpacity(0.22),
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.tertiary),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$needed $unit still needed',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.55)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
