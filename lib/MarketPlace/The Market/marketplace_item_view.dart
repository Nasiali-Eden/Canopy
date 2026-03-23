import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Shared/theme/app_theme.dart';
import 'marketplace_listing.dart';
import 'marketplace_shop_view.dart';
import 'marketplace_checkout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER DATA
// ─────────────────────────────────────────────────────────────────────────────

final _placeholderListing = _PlaceholderDetail(
  title: 'Nairobi River Copper Bangles',
  tagline: 'Each ring holds 18 months of Mathare River stories',
  story: '''James Odhiambo has been walking the Mathare River bank every morning since 2019. Not for exercise — for copper wire. The wire that falls from electricity repairs, that washes down from construction sites, that gets tangled in the reeds and slowly becomes part of the riverbed.

He collected 840 grams of this wire over three weeks in January. He cleaned it, sorted it by gauge, weighed it, and sold it through Canopy to Amina Wanjiku's workshop in Kibera — at a price three times what a middleman would have offered, because James's six months of Canopy history meant Amina knew exactly what she was getting.

Amina spent two days on each bangle. The hammering is deliberate — she keeps the surface imperfect, because the irregularities are part of the story. No two are identical because no two stretches of wire are identical.

What you are buying is not copper. You are buying the morning walk, the sort, the fair price, the two days of hammering. You are buying the proof that this object did not have to exist — it was made out of something that was on its way to being lost.''',
  images: [
    'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=900&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1611923134239-b9be5816e23c?w=900&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1573408301185-9519f94815a2?w=900&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=900&auto=format&fit=crop',
  ],
  price: 'KSh 1,200',
  priceNum: 1200,
  makerName: 'Amina Wanjiku',
  makerCity: 'Kibera, Nairobi',
  makerBio: 'Metalworker and jewellery designer. Working with recovered copper and brass since 2021.',
  shopName: 'AW Studio Kibera',
  collectorName: 'James Odhiambo',
  collectorCity: 'Mathare, Nairobi',
  collectionSite: 'Mathare River, near Mji wa Huruma bridge',
  collectionDate: 'January 14, 2026',
  materialWeightKg: 0.84,
  material: 'Copper wire',
  kgDiverted: 0.84,
  impactScore: 78,
  royaltyKes: 48.0,
  category: 'Jewellery',
  tags: ['copper', 'bangle', 'handmade', 'Nairobi', 'river'],
  rating: 4.8,
  reviewCount: 23,
  isCircularCraft: true,
  isOnChain: true,
  cardanoTxHash: 'a1b2c3d4e5f6...0987',
);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceItemViewScreen extends StatefulWidget {
  final String listingId;
  final MarketplaceListing? listing; // if already loaded

  const MarketplaceItemViewScreen({
    super.key,
    required this.listingId,
    this.listing,
  });

  @override
  State<MarketplaceItemViewScreen> createState() =>
      _MarketplaceItemViewScreenState();
}

class _MarketplaceItemViewScreenState extends State<MarketplaceItemViewScreen>
    with SingleTickerProviderStateMixin {
  int _activeImage = 0;
  final PageController _pageCtrl = PageController();
  bool _wishlistActive = false;
  bool _storyExpanded = false;
  late AnimationController _wishlistAnim;
  late Animation<double> _wishlistScale;

  @override
  void initState() {
    super.initState();
    _wishlistAnim = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _wishlistScale = Tween(begin: 1.0, end: 1.35)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_wishlistAnim);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _wishlistAnim.dispose();
    super.dispose();
  }

  void _toggleWishlist() {
    setState(() => _wishlistActive = !_wishlistActive);
    _wishlistAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Using placeholder — in production swap for Firestore fetch
    final item = _placeholderListing;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildImageHeader(item),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIdentity(item),
                    _buildStory(item),
                    _buildMaterialDnaChain(item),
                    _buildImpactCard(item),
                    _buildMakerSection(item),
                    _buildTags(item),
                    _buildReviewSummary(item),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar(item)),
        ],
      ),
    );
  }

  // ── Image header ────────────────────────────────────────────────────────────

  Widget _buildImageHeader(_PlaceholderDetail item) {
    return SliverAppBar(
      expandedHeight: 340,
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
        ScaleTransition(
          scale: _wishlistScale,
          child: IconButton(
            onPressed: _toggleWishlist,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 8),
                ],
              ),
              child: Icon(
                _wishlistActive ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: _wishlistActive ? Colors.red.shade500 : AppTheme.darkGreen,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: item.images.length,
              onPageChanged: (i) => setState(() => _activeImage = i),
              itemBuilder: (ctx, i) => CachedNetworkImage(
                imageUrl: item.images[i],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.lightGreen.withOpacity(0.15),
                  child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.lightGreen.withOpacity(0.15),
                  child: const Icon(Icons.image_outlined,
                      size: 48, color: AppTheme.primary),
                ),
              ),
            ),
            // Dot indicator
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  item.images.length,
                      (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _activeImage == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _activeImage == i
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            // Circular Craft badge
            if (item.isCircularCraft)
              Positioned(
                top: 80,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.tertiary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified, size: 11, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Circular Craft',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Thumbnail strip ─────────────────────────────────────────────────────────

  // ── Identity block ──────────────────────────────────────────────────────────

  Widget _buildIdentity(_PlaceholderDetail item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category + rating
          Row(children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(item.category,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
            ),
            const Spacer(),
            const Icon(Icons.star_rounded,
                size: 14, color: AppTheme.tertiary),
            const SizedBox(width: 3),
            Text('${item.rating}',
                style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            Text(' (${item.reviewCount})',
                style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.4),
                    fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          // Title
          Text(
            item.title,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          // Tagline — italicised editorial voice
          Text(
            '"${item.tagline}"',
            style: TextStyle(
              color: AppTheme.accent.withOpacity(0.85),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          // Price row
          Row(children: [
            Text(
              item.price,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const Spacer(),
            // Royalty indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.tertiary.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 12, color: AppTheme.tertiary),
                const SizedBox(width: 4),
                Text(
                  'KSh ${item.royaltyKes.toStringAsFixed(0)} to collector',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'When you buy this, James Odhiambo earns a royalty automatically.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: AppTheme.lightGreen.withOpacity(0.3)),
        ],
      ),
    );
  }

  // ── Story ────────────────────────────────────────────────────────────────────

  Widget _buildStory(_PlaceholderDetail item) {
    final preview = item.story.length > 300
        ? item.story.substring(0, 300)
        : item.story;
    final showToggle = item.story.length > 300;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
              icon: Icons.auto_stories_outlined,
              label: 'The Story',
              color: AppTheme.primary),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _storyExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              '$preview…',
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.75),
                fontSize: 14,
                height: 1.75,
              ),
            ),
            secondChild: Text(
              item.story,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.75),
                fontSize: 14,
                height: 1.75,
              ),
            ),
          ),
          if (showToggle)
            GestureDetector(
              onTap: () => setState(() => _storyExpanded = !_storyExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Text(
                    _storyExpanded ? 'Read less' : 'Read full story',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _storyExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 20),
          Divider(color: AppTheme.lightGreen.withOpacity(0.3)),
        ],
      ),
    );
  }

  // ── Material DNA chain ───────────────────────────────────────────────────────

  Widget _buildMaterialDnaChain(_PlaceholderDetail item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
              icon: Icons.link_rounded,
              label: 'Material DNA',
              color: AppTheme.accent),
          const SizedBox(height: 4),
          Text(
            'The verified provenance chain of this object',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),

          // Node 1 — Collector
          _DnaNode(
            icon: Icons.person_pin_circle_outlined,
            color: AppTheme.primary,
            role: 'Collected by',
            name: item.collectorName,
            detail: '${item.material} · ${item.materialWeightKg}kg',
            sub: '${item.collectionSite}\n${item.collectionDate}',
            isFirst: true,
            isLast: false,
            onChain: item.isOnChain,
          ),

          // Node 2 — Maker
          _DnaNode(
            icon: Icons.handyman_outlined,
            color: AppTheme.accent,
            role: 'Crafted by',
            name: item.makerName,
            detail: 'Jewellery maker',
            sub: item.makerCity,
            isFirst: false,
            isLast: false,
            onChain: item.isOnChain,
          ),

          // Node 3 — You
          _DnaNode(
            icon: Icons.shopping_bag_outlined,
            color: AppTheme.tertiary,
            role: 'Owned by',
            name: 'You',
            detail: 'The loop closes here',
            sub: '',
            isFirst: false,
            isLast: true,
            onChain: false,
          ),

          // Cardano hash
          if (item.isOnChain) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.15)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.lock_outlined,
                      size: 13, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Anchored on Cardano',
                          style: TextStyle(
                              color: AppTheme.darkGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        'tx: ${item.cardanoTxHash}',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.darkGreen.withOpacity(0.4),
                            fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: AppTheme.lightGreen.withOpacity(0.3)),
        ],
      ),
    );
  }

  // ── Impact card ──────────────────────────────────────────────────────────────

  Widget _buildImpactCard(_PlaceholderDetail item) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.darkGreen.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.eco_outlined, color: Colors.white, size: 16),
            SizedBox(width: 7),
            Text('Environmental Impact',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _ImpactPill(
                value: '${item.kgDiverted}kg',
                label: 'Diverted',
                icon: Icons.recycling),
            const SizedBox(width: 10),
            _ImpactPill(
                value: '${item.impactScore}',
                label: 'Impact Score',
                icon: Icons.show_chart),
            const SizedBox(width: 10),
            _ImpactPill(
                value: 'KSh ${item.royaltyKes.toStringAsFixed(0)}',
                label: 'Collector Royalty',
                icon: Icons.payments_outlined),
          ]),
        ],
      ),
    );
  }

  // ── Maker section ────────────────────────────────────────────────────────────

  Widget _buildMakerSection(_PlaceholderDetail item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
              icon: Icons.storefront_outlined,
              label: 'The Maker',
              color: AppTheme.secondary),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MarketplaceShopViewScreen(sellerId: item.shopName),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.lightGreen.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primary.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.handyman_outlined,
                      size: 26, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.makerName,
                          style: const TextStyle(
                            color: AppTheme.darkGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          )),
                      const SizedBox(height: 2),
                      Text(item.shopName,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary.withOpacity(0.8),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.place_outlined,
                            size: 10, color: AppTheme.accent),
                        const SizedBox(width: 3),
                        Text(item.makerCity,
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.darkGreen.withOpacity(0.5),
                                fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('View Shop',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: AppTheme.lightGreen.withOpacity(0.3)),
        ],
      ),
    );
  }

  // ── Tags ─────────────────────────────────────────────────────────────────────

  Widget _buildTags(_PlaceholderDetail item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: item.tags
            .map((t) => Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.lightGreen.withOpacity(0.3)),
          ),
          child: Text('#$t',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.6),
                  fontWeight: FontWeight.w600)),
        ))
            .toList(),
      ),
    );
  }

  // ── Review summary ────────────────────────────────────────────────────────────

  Widget _buildReviewSummary(_PlaceholderDetail item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
              icon: Icons.star_outline_rounded,
              label: 'Reviews',
              color: AppTheme.tertiary),
          const SizedBox(height: 12),
          Row(children: [
            Text('${item.rating}',
                style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 32)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(
                    i < item.rating.floor()
                        ? Icons.star_rounded
                        : Icons.star_half_rounded,
                    size: 16,
                    color: AppTheme.tertiary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text('${item.reviewCount} reviews',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.45))),
            ]),
          ]),
        ],
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar(_PlaceholderDetail item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(children: [
        // Collector royalty note
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Collector earns',
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.black38,
                  fontWeight: FontWeight.w500)),
          Text('KSh ${item.royaltyKes.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: AppTheme.tertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ]),
        const SizedBox(width: 16),
        // Buy button
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.darkGreen, AppTheme.primary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarketplaceCheckoutScreen(
                      listingId: widget.listingId,
                      listingTitle: item.title,
                      priceKes: item.priceNum,
                      sellerName: item.makerName,
                      collectorName: item.collectorName,
                      royaltyKes: item.royaltyKes,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Buy — Pay with M-Pesa',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DNA NODE
// ─────────────────────────────────────────────────────────────────────────────

class _DnaNode extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String role;
  final String name;
  final String detail;
  final String sub;
  final bool isFirst;
  final bool isLast;
  final bool onChain;

  const _DnaNode({
    required this.icon,
    required this.color,
    required this.role,
    required this.name,
    required this.detail,
    required this.sub,
    required this.isFirst,
    required this.isLast,
    required this.onChain,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withOpacity(0.4), color.withOpacity(0.1)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : 16, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(role,
                        style: TextStyle(
                            fontSize: 10,
                            color: color.withOpacity(0.7),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    if (onChain && !isLast)
                      Row(children: [
                        const Icon(Icons.link, size: 10, color: AppTheme.primary),
                        const SizedBox(width: 2),
                        Text('On-chain',
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700)),
                      ]),
                  ]),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          color: AppTheme.darkGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(detail,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGreen.withOpacity(0.55),
                            fontWeight: FontWeight.w500)),
                  ],
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.4),
                            height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPACT PILL
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactPill extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _ImpactPill(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(height: 5),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(width: 10),
      Expanded(
          child: Container(
              height: 1, color: color.withOpacity(0.12))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER DETAIL DATA
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderDetail {
  final String title;
  final String tagline;
  final String story;
  final List<String> images;
  final String price;
  final double priceNum;
  final String makerName;
  final String makerCity;
  final String makerBio;
  final String shopName;
  final String collectorName;
  final String collectorCity;
  final String collectionSite;
  final String collectionDate;
  final double materialWeightKg;
  final String material;
  final double kgDiverted;
  final int impactScore;
  final double royaltyKes;
  final String category;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final bool isCircularCraft;
  final bool isOnChain;
  final String cardanoTxHash;

  const _PlaceholderDetail({
    required this.title,
    required this.tagline,
    required this.story,
    required this.images,
    required this.price,
    required this.priceNum,
    required this.makerName,
    required this.makerCity,
    required this.makerBio,
    required this.shopName,
    required this.collectorName,
    required this.collectorCity,
    required this.collectionSite,
    required this.collectionDate,
    required this.materialWeightKg,
    required this.material,
    required this.kgDiverted,
    required this.impactScore,
    required this.royaltyKes,
    required this.category,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    required this.isCircularCraft,
    required this.isOnChain,
    required this.cardanoTxHash,
  });
}