import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Shared/theme/app_theme.dart';
import 'marketplace_item_view.dart';
import 'marketplace_listing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER SHOP DATA
// ─────────────────────────────────────────────────────────────────────────────

const _placeholderShop = _ShopDetail(
  name: 'Kibera Makers Collective',
  tagline: 'We make things that carry the weight of where they came from.',
  bio: '''We are seven makers who share a workshop in Kibera. None of us trained formally — we learned by taking apart what other people threw away.

The Collective started in 2022 when we realised we were all buying copper wire from the same collector, James Odhiambo, who walked the Mathare River every morning. We thought: what if the people who collect and the people who create worked in the same direction?

We now source almost everything through Canopy. We know whose hands held the material before ours. We pay fair prices. When we sell something, the collector gets a royalty — because the object is as much theirs as it is ours.

We make jewellery, sculpture, furniture, and whatever comes to us when we look at what James brings back from the river.''',
  bannerUrl: 'https://images.unsplash.com/photo-1605000797499-95a51c5269ae?w=1200&auto=format&fit=crop',
  logoUrl: 'https://images.unsplash.com/photo-1590492181492-9efd75b27ae9?w=300&auto=format&fit=crop',
  city: 'Kibera, Nairobi',
  country: 'Kenya',
  badge: 'Circular Craft',
  rating: 4.9,
  reviewCount: 87,
  totalSales: 203,
  totalListings: 24,
  memberSince: 'March 2022',
  kgDiverted: 48.6,
  collectorsSupported: 6,
  materialSpecialties: ['Copper', 'Scrap metal', 'Reclaimed wood', 'Soft plastic'],
  categories: ['Jewellery', 'Sculpture', 'Furniture', 'Homeware'],
  whatsappNumber: '+254700000000',
  instagramHandle: '@kiberamakers',
);

const _placeholderListings = [
  _ShopListingPreview(
    title: 'Nairobi River Copper Bangles',
    price: 'KSh 1,200',
    kgDiverted: 0.84,
    imageUrl: 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=600&auto=format&fit=crop',
    category: 'Jewellery',
    badge: 'Circular Craft',
  ),
  _ShopListingPreview(
    title: 'Mathare Wire Sculpture — "Kustawi"',
    price: 'KSh 22,000',
    kgDiverted: 5.6,
    imageUrl: 'https://images.unsplash.com/photo-1530026405186-ed1f139313f8?w=600&auto=format&fit=crop',
    category: 'Sculpture',
    badge: 'Circular Craft',
  ),
  _ShopListingPreview(
    title: 'Pallet Table with Skyline Inlay',
    price: 'KSh 18,500',
    kgDiverted: 12.4,
    imageUrl: 'https://images.unsplash.com/photo-1590492181492-9efd75b27ae9?w=600&auto=format&fit=crop',
    category: 'Furniture',
    badge: 'Circular Craft',
  ),
  _ShopListingPreview(
    title: 'Soft Plastic Bowl — Kibera Series',
    price: 'KSh 680',
    kgDiverted: 0.32,
    imageUrl: 'https://images.unsplash.com/photo-1578922746465-3a80a228f223?w=600&auto=format&fit=crop',
    category: 'Homeware',
    badge: 'Circular Craft',
  ),
];

const _processJournal = [
  _JournalEntry(
    imageUrl: 'https://images.unsplash.com/photo-1605001011156-cbf0b0f67a51?w=600&auto=format&fit=crop',
    caption: 'James brings in copper wire sorted by gauge. We weigh it together.',
    date: 'January 14, 2026',
  ),
  _JournalEntry(
    imageUrl: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600&auto=format&fit=crop',
    caption: 'The hammering takes two days. No two bangles are the same.',
    date: 'January 16, 2026',
  ),
  _JournalEntry(
    imageUrl: 'https://images.unsplash.com/photo-1611923134239-b9be5816e23c?w=600&auto=format&fit=crop',
    caption: 'Finished. The irregularities are not defects — they are evidence.',
    date: 'January 18, 2026',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceShopViewScreen extends StatefulWidget {
  final String sellerId;
  final CanopyShop? shop;

  const MarketplaceShopViewScreen({
    super.key,
    required this.sellerId,
    this.shop,
  });

  @override
  State<MarketplaceShopViewScreen> createState() =>
      _MarketplaceShopViewScreenState();
}

class _MarketplaceShopViewScreenState extends State<MarketplaceShopViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = _placeholderShop;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildHeader(shop),
          _buildTabBar(),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildListingsTab(),
            _buildStoryTab(shop),
            _buildImpactTab(shop),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(_ShopDetail shop) {
    return SliverAppBar(
      expandedHeight: 270,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppTheme.darkGreen),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined,
                size: 18, color: AppTheme.darkGreen),
          ),
        ),
        const SizedBox(width: 6),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner
            CachedNetworkImage(
              imageUrl: shop.bannerUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.darkGreen,
              ),
            ),

            // Scrim
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

            // Shop identity
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: shop.logoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.primary,
                            child: const Icon(Icons.storefront,
                                color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge
                          if (shop.badge == 'Circular Craft')
                            Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.tertiary.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified,
                                        size: 10, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text('Circular Craft Badge',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800)),
                                  ]),
                            ),
                          Text(shop.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                height: 1.2,
                              )),
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.place_outlined,
                                size: 11, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(shop.city,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        ],
                      ),
                    ),
                    // Rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppTheme.tertiary),
                          const SizedBox(width: 3),
                          Text('${shop.rating}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ]),
                        Text('${shop.reviewCount} reviews',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ],
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

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.darkGreen,
          unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.4),
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Shop'),
            Tab(text: 'Our Story'),
            Tab(text: 'Impact'),
          ],
        ),
      ),
    );
  }

  // ── Listings tab ─────────────────────────────────────────────────────────────

  Widget _buildListingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.lightGreen.withOpacity(0.2)),
            ),
            child: Row(children: [
              _MiniStat(
                  value: '${_placeholderShop.totalListings}',
                  label: 'Listings'),
              _vDivider(),
              _MiniStat(
                  value: '${_placeholderShop.totalSales}',
                  label: 'Sold'),
              _vDivider(),
              _MiniStat(
                  value: _placeholderShop.memberSince,
                  label: 'Member since'),
            ]),
          ),

          const SizedBox(height: 16),

          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _placeholderListings.length,
            itemBuilder: (_, i) =>
                _ListingCard(listing: _placeholderListings[i]),
          ),
        ],
      ),
    );
  }

  // ── Story tab ────────────────────────────────────────────────────────────────

  Widget _buildStoryTab(_ShopDetail shop) {
    final preview =
    shop.bio.length > 400 ? shop.bio.substring(0, 400) : shop.bio;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.lightGreen.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShopSectionLabel(
                    icon: Icons.auto_stories_outlined,
                    label: 'Who We Are',
                    color: AppTheme.primary),
                const SizedBox(height: 12),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _bioExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Text('$preview…',
                      style: TextStyle(
                          color: AppTheme.darkGreen.withOpacity(0.75),
                          fontSize: 14,
                          height: 1.75)),
                  secondChild: Text(shop.bio,
                      style: TextStyle(
                          color: AppTheme.darkGreen.withOpacity(0.75),
                          fontSize: 14,
                          height: 1.75)),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _bioExpanded = !_bioExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(children: [
                      Text(
                        _bioExpanded ? 'Read less' : 'Read full story',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      Icon(
                        _bioExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Material specialties
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.lightGreen.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShopSectionLabel(
                    icon: Icons.recycling,
                    label: 'Materials We Work With',
                    color: AppTheme.accent),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: shop.materialSpecialties
                      .map((m) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                      AppTheme.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.accent
                              .withOpacity(0.25)),
                    ),
                    child: Text(m,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600)),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Process journal
          const _ShopSectionLabel(
              icon: Icons.photo_library_outlined,
              label: 'Process Journal',
              color: AppTheme.secondary),
          const SizedBox(height: 12),
          ..._processJournal
              .map((j) => _JournalCard(entry: j))
              .toList(),
        ],
      ),
    );
  }

  // ── Impact tab ───────────────────────────────────────────────────────────────

  Widget _buildImpactTab(_ShopDetail shop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Impact hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.darkGreen, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.darkGreen.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Our Environmental Record',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text('Since ${shop.memberSince}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11)),
                const SizedBox(height: 18),
                Row(children: [
                  _BigImpactStat(
                      value: '${shop.kgDiverted}kg',
                      label: 'Material\ndiverted'),
                  const SizedBox(width: 12),
                  _BigImpactStat(
                      value: '${shop.collectorsSupported}',
                      label: 'Collectors\nsupported'),
                  const SizedBox(width: 12),
                  _BigImpactStat(
                      value: '${shop.totalSales}',
                      label: 'Objects\nsold'),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Collector network
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.lightGreen.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShopSectionLabel(
                    icon: Icons.people_outline,
                    label: 'Collector Network',
                    color: AppTheme.primary),
                const SizedBox(height: 12),
                Text(
                  'We source from ${shop.collectorsSupported} collectors, all verified on Canopy. Every sale generates an automatic M-Pesa royalty back to the collector whose material we used.',
                  style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.6),
                ),
                const SizedBox(height: 14),
                // Collector preview row
                Row(children: [
                  ...[
                    'James Odhiambo · Mathare',
                    'Wambui Njeri · Kibera',
                    'Peter Otieno · Kawangware',
                  ]
                      .map((c) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary
                            .withOpacity(0.05),
                        borderRadius:
                        BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primary
                                .withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.lightGreen
                                  .withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: AppTheme.primary),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            c.split(' · ')[0],
                            style: const TextStyle(
                                color: AppTheme.darkGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 10),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            c.split(' · ')[1],
                            style: TextStyle(
                                color: AppTheme.darkGreen
                                    .withOpacity(0.4),
                                fontSize: 9),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ))
                      .toList(),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 28,
    color: AppTheme.lightGreen.withOpacity(0.3),
    margin: const EdgeInsets.symmetric(horizontal: 10),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING CARD (in shop grid)
// ─────────────────────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final _ShopListingPreview listing;

  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MarketplaceItemViewScreen(listingId: listing.title),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
          Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(13)),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(
                  imageUrl: listing.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.lightGreen.withOpacity(0.12),
                  ),
                ),
                if (listing.badge == 'Circular Craft')
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.verified,
                          size: 10, color: Colors.white),
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
                Text(listing.title,
                    style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Text(listing.price,
                      style: const TextStyle(
                          color: AppTheme.darkGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                  const Spacer(),
                  Text('${listing.kgDiverted}kg',
                      style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOURNAL CARD
// ─────────────────────────────────────────────────────────────────────────────

class _JournalCard extends StatelessWidget {
  final _JournalEntry entry;

  const _JournalCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(13)),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: entry.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.lightGreen.withOpacity(0.12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.caption,
                  style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.8),
                      fontSize: 13,
                      height: 1.5,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 10, color: AppTheme.accent),
                const SizedBox(width: 4),
                Text(entry.date,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.darkGreen.withOpacity(0.4),
                        fontWeight: FontWeight.w500)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.darkGreen.withOpacity(0.4),
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BigImpactStat extends StatelessWidget {
  final String value;
  final String label;

  const _BigImpactStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.3),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _ShopSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ShopSectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 7),
      Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSISTENT HEADER DELEGATE
// ─────────────────────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class _ShopDetail {
  final String name;
  final String tagline;
  final String bio;
  final String bannerUrl;
  final String logoUrl;
  final String city;
  final String country;
  final String badge;
  final double rating;
  final int reviewCount;
  final int totalSales;
  final int totalListings;
  final String memberSince;
  final double kgDiverted;
  final int collectorsSupported;
  final List<String> materialSpecialties;
  final List<String> categories;
  final String? whatsappNumber;
  final String? instagramHandle;

  const _ShopDetail({
    required this.name,
    required this.tagline,
    required this.bio,
    required this.bannerUrl,
    required this.logoUrl,
    required this.city,
    required this.country,
    required this.badge,
    required this.rating,
    required this.reviewCount,
    required this.totalSales,
    required this.totalListings,
    required this.memberSince,
    required this.kgDiverted,
    required this.collectorsSupported,
    required this.materialSpecialties,
    required this.categories,
    this.whatsappNumber,
    this.instagramHandle,
  });
}

class _ShopListingPreview {
  final String title;
  final String price;
  final double kgDiverted;
  final String imageUrl;
  final String category;
  final String badge;

  const _ShopListingPreview({
    required this.title,
    required this.price,
    required this.kgDiverted,
    required this.imageUrl,
    required this.category,
    required this.badge,
  });
}

class _JournalEntry {
  final String imageUrl;
  final String caption;
  final String date;

  const _JournalEntry({
    required this.imageUrl,
    required this.caption,
    required this.date,
  });
}