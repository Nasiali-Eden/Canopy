import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../Shared/theme/app_theme.dart';
import 'create_listing_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class EnvMarketScreen extends StatefulWidget {
  const EnvMarketScreen({super.key});

  @override
  State<EnvMarketScreen> createState() => _EnvMarketScreenState();
}

class _EnvMarketScreenState extends State<EnvMarketScreen> {
  bool _showBuying = true;

  // org state
  String? _orgId;
  Map<String, dynamic>? _orgData;

  // material taxonomy sample images: subTypeId → imageUrl
  Map<String, String> _sampleImages = {};

  @override
  void initState() {
    super.initState();
    _loadOrg();
    _loadTaxonomy();
  }

  Future<void> _loadOrg() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final orgId = userDoc.data()?['orgId'] as String?;
      if (orgId == null) return;
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      if (mounted) {
        setState(() {
          _orgId = orgId;
          _orgData = orgDoc.data();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTaxonomy() async {
    try {
      final raw = await rootBundle
          .loadString('assets/environmental/material_types.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cats = (json['categories'] as List).cast<Map<String, dynamic>>();
      final map = <String, String>{};
      for (final cat in cats) {
        for (final sub
            in (cat['sub_types'] as List).cast<Map<String, dynamic>>()) {
          final id = sub['id'] as String;
          final url = sub['sample_image_url'] as String?;
          if (url != null) map[id] = url;
        }
      }
      if (mounted) setState(() => _sampleImages = map);
    } catch (_) {}
  }

  String _imageForListing(Map<String, dynamic> data) {
    final uploaded = data['image_url'] as String?;
    if (uploaded != null && uploaded.isNotEmpty) return uploaded;
    final subId = data['material_sub_type_id'] as String? ?? '';
    return _sampleImages[subId] ??
        'https://picsum.photos/seed/${subId.isEmpty ? 'material' : subId}/400/250';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildStatStrip(),
            const SizedBox(height: 12),
            _buildTabSwitcher(),
            const SizedBox(height: 4),
            Expanded(child: _buildListings()),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (_orgId == null || _orgData == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Loading organisation data…'),
                    behavior: SnackBarBehavior.floating),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateListingScreen(
                  orgId: _orgId!,
                  orgData: _orgData!,
                ),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'Post Listing',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  Widget _buildStatStrip() {
    if (_orgId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: _StatCard(label: 'Active Orders', value: '—')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Kg This Month', value: '—')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Avg KSh/kg', value: '—')),
          ],
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('market_listings')
          .where('org_id', isEqualTo: _orgId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final activeCount = docs.length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Active Orders',
                      value: '$activeCount')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Kg This Month', value: '—')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Avg KSh/kg', value: '—')),
            ],
          ),
        );
      },
    );
  }

  // ── Tab switcher ─────────────────────────────────────────────────────────

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Tab(
              label: 'Buying',
              active: _showBuying,
              onTap: () => setState(() => _showBuying = true)),
          const SizedBox(width: 8),
          _Tab(
              label: 'Offered',
              active: !_showBuying,
              onTap: () => setState(() => _showBuying = false)),
        ],
      ),
    );
  }

  // ── Live listings ─────────────────────────────────────────────────────────

  Widget _buildListings() {
    if (_orgId == null) {
      return const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.primary)),
      );
    }

    final targetType = _showBuying
        ? ['buy_order', 'recurring_buy']
        : ['sell_listing'];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('market_listings')
          .where('org_id', isEqualTo: _orgId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primary)),
          );
        }

        final allDocs = snap.data?.docs ?? [];
        final filtered = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final type = data['listing_type'] as String? ?? '';
          return targetType.contains(type);
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final data =
                filtered[i].data() as Map<String, dynamic>;
            return _ListingCard(
              data: data,
              imageUrl: _imageForListing(data),
              isBuy: _showBuying,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.storefront_outlined,
                size: 34, color: AppTheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            _showBuying ? 'No buy orders yet' : 'No sell listings yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Post Listing to get started',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.40),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String imageUrl;
  final bool isBuy;

  const _ListingCard({
    required this.data,
    required this.imageUrl,
    required this.isBuy,
  });

  @override
  Widget build(BuildContext context) {
    final material =
        data['material_sub_type_label'] as String? ?? 'Material';
    final grade = data['grade'] as String? ?? '';
    final price = (data['price_per_unit'] as num?)?.toInt() ?? 0;
    final unit = data['unit'] as String? ?? 'kg';
    final quantity = (data['quantity_kg'] as num?)?.toInt() ?? 0;
    final location = data['location'] as String? ?? '';
    final status = data['status'] as String? ?? 'active';
    final isRecurring = data['is_recurring'] as bool? ?? false;
    final catLabel =
        data['material_category_label'] as String? ?? '';
    final weCollect = data['we_collect'] as bool? ?? false;
    final notes = data['notes'] as String? ?? '';

    final statusColor = status == 'active'
        ? const Color(0xFF2D7A4F)
        : status == 'paused'
            ? Colors.amber
            : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ──────────────────────────────────────────────────────
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.primary.withOpacity(0.08),
                    child: Center(
                      child: Icon(Icons.image_outlined,
                          size: 36,
                          color: AppTheme.primary.withOpacity(0.25)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.primary.withOpacity(0.08),
                    child: Center(
                      child: Text(
                        _emojiForCategory(catLabel),
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                ),
                // gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // material name over image
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Text(
                    material,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black45)
                      ],
                    ),
                  ),
                ),
                // badges top-right
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      if (isRecurring)
                        _Badge(label: 'Recurring', color: const Color(0xFF6A1B9A)),
                      if (isRecurring) const SizedBox(width: 5),
                      _Badge(
                        label: status.toUpperCase(),
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // grade + category row
                Row(
                  children: [
                    if (grade.isNotEmpty) ...[
                      _GradeChip(label: grade),
                      const SizedBox(width: 6),
                    ],
                    if (catLabel.isNotEmpty)
                      Text(
                        catLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.50),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // price + unit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'KSh $price',
                      style: const TextStyle(
                        color: AppTheme.tertiary,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'per $unit${isBuy ? ' needed' : ' asking'}',
                      style: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.50),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // quantity + logistics row
                Row(
                  children: [
                    Icon(Icons.scale_outlined,
                        size: 13,
                        color: AppTheme.darkGreen.withOpacity(0.45)),
                    const SizedBox(width: 4),
                    Text(
                      '$quantity $unit',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (weCollect) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.local_shipping_outlined,
                          size: 13,
                          color: AppTheme.accent.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'We collect',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const Spacer(),
                      Icon(Icons.place_outlined,
                          size: 13,
                          color: AppTheme.darkGreen.withOpacity(0.40)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.50),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.50),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // actions
                Row(
                  children: [
                    _ActionBtn(
                      label: isBuy ? 'View Responses' : 'View Interest',
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coming soon'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      label: 'Edit',
                      outlined: true,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit coming soon'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _emojiForCategory(String catLabel) {
    final lower = catLabel.toLowerCase();
    if (lower.contains('plastic')) return '♻️';
    if (lower.contains('metal')) return '🔩';
    if (lower.contains('electron')) return '📱';
    if (lower.contains('paper') || lower.contains('card')) return '📦';
    if (lower.contains('glass')) return '🍾';
    if (lower.contains('rubber')) return '⚙️';
    if (lower.contains('wood')) return '🪵';
    if (lower.contains('text')) return '👕';
    return '♻️';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent
                : AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? Colors.white
                  : AppTheme.darkGreen.withOpacity(0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  final String label;
  const _GradeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, this.outlined = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.primary.withOpacity(0.6)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.primary)),
      );
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
    );
  }
}
