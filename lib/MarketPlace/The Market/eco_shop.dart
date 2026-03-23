import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Shared/theme/app_theme.dart';
import 'marketplace_item_view.dart';
import 'marketplace_shop_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER DATA — rich editorial content for empty states
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

  // African countries — location filter chips
  static const _africaLocations = [
    'All',
    'Nairobi',
    'Lagos',
    'Accra',
    'Cape Town',
    'Addis Ababa',
    'Kampala',
    'Dar es Salaam',
    'Mombasa',
  ];

  String _selectedLocation = 'All';

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _heroFade = CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
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
            SliverToBoxAdapter(child: _buildLocationRail()),
            SliverToBoxAdapter(child: _buildHeroCarousel()),
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

  Widget _buildLocationRail() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        itemCount: _africaLocations.length,
        itemBuilder: (context, i) {
          final loc = _africaLocations[i];
          final selected = _selectedLocation == loc;
          return GestureDetector(
            onTap: () => setState(() => _selectedLocation = loc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.accent.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppTheme.accent
                      : AppTheme.lightGreen.withOpacity(0.3),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child:
                          Icon(Icons.place, size: 10, color: AppTheme.accent),
                    ),
                  Text(
                    loc,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTheme.accent
                          : AppTheme.darkGreen.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Hero carousel ──────────────────────────────────────────────────────────

  Widget _buildHeroCarousel() {
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
              itemCount: _featuredPlaceholders.length,
              itemBuilder: (context, i) {
                final item = _featuredPlaceholders[i];
                return _HeroCard(item: item, index: i);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Story grid ─────────────────────────────────────────────────────────────

  Widget _buildStoryGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: List.generate(_storyPlaceholders.length, (i) {
          final item = _storyPlaceholders[i];
          return _StoryCard(item: item, isReversed: i.isOdd);
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
          _ImpactStat(value: '2.4t', label: 'Diverted'),
          _divider(),
          _ImpactStat(value: '187', label: 'Makers'),
          _divider(),
          _ImpactStat(value: '43', label: 'Collectors paid'),
          _divider(),
          _ImpactStat(value: 'KSh 84k', label: 'Royalties'),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: AppTheme.lightGreen.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );

  // ── New listings grid ──────────────────────────────────────────────────────

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
        itemCount: _storyPlaceholders.length,
        itemBuilder: (context, i) {
          final item = _storyPlaceholders[i % _storyPlaceholders.length];
          return _GridCard(item: item);
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

  const _HeroCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MarketplaceItemViewScreen(listingId: 'placeholder_$index'),
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

  const _StoryCard({required this.item, required this.isReversed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MarketplaceItemViewScreen(listingId: 'story_${item.title}'),
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

  const _GridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MarketplaceItemViewScreen(listingId: 'grid_${item.title}'),
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
}

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
