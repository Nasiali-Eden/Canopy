// lib/MarketPlace/Profile/seller_profile.dart
//
// Seller › Profile (MARKETPLACE_SELLER_DESIGN_BRIEF §4, F). Shop header,
// stats (only real ones), buyer requests by listing, specialisations, the
// honest state for payouts, edit shop details (real), workspace switcher,
// account and sign out. No sales history is invented: payments through
// Canopy aren't built, so requests are how buyers reach the seller.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:image_picker/image_picker.dart';

import '../../Community/Home/community_home.dart';
import '../../Community/Profile/security_screen.dart';
import '../../Community/Profile/support_sheet.dart';
import '../../Models/marketplace/canopy_listing.dart';
import '../../Models/marketplace/marketplace_seller_profile.dart';
import '../../Services/Authentication/auth.dart';
import '../../Services/Geo/geo_registry.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../Shared/Pages/login.dart';
import '../../Shared/widgets/role_context_switcher.dart';
import '../../theme/canopy_components.dart';
import '../The Market/marketplace_shop_view.dart';
import '../market_ui.dart';

class SellerProfilePage extends StatelessWidget {
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? envOpsContextBuilder;
  final WidgetBuilder? culturalContextBuilder;
  final bool hasEnvOps;
  final bool hasCultural;

  const SellerProfilePage({
    super.key,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.envOpsContextBuilder,
    this.culturalContextBuilder,
    this.hasEnvOps = false,
    this.hasCultural = false,
  });

  void _go(BuildContext context, WidgetBuilder b) =>
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: b), (_) => false);

  Future<void> _signOut(BuildContext context) async {
    final ok = await showCanopyConfirm(context, title: 'Sign out?', message: "You'll need to sign in again to manage your shop.", confirmLabel: 'Sign out');
    if (!ok) return;
    await AuthService().signOut();
    if (context.mounted) _go(context, (_) => LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const CanopyScaffold(body: CanopySignedOutState());
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Profile', showBack: false, actions: [
        CanopyIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit shop details',
          onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const EditShopScreen())),
        ),
        const SizedBox(width: CanopySpace.s8),
      ]),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('marketplace_sellers').doc(uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(title: "Couldn't load your shop");
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() ?? const <String, dynamic>{};
          final shop = MarketplaceSellerProfile.fromMap(uid, data);
          final points = (data['impact_points'] as num?)?.toInt() ?? 0;
          return StreamBuilder<List<CanopyListing>>(
            stream: ListingService.instance.watchByMember(uid),
            builder: (context, ls) {
              final listings = (ls.data ?? const <CanopyListing>[]).where((l) => l.isCreative && l.status != ListingStatus.closed).toList();
              final live = listings.where((l) => l.isActive).length;
              final withRequests = listings.where((l) => l.responseCount > 0).toList();
              final requests = withRequests.fold(0, (s, l) => s + l.responseCount);
              return ListView(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
                children: [
                  ShopHeader(
                    shop: shop,
                    action: CanopyButton.secondary(
                      label: 'Public shop',
                      size: CanopyButtonSize.compact,
                      onPressed: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(builder: (_) => MarketplaceShopViewScreen(sellerId: uid))),
                    ),
                  ),
                  const SizedBox(height: CanopySpace.section),
                  SellerStatStrip(liveListings: live, requests: requests, kgDiverted: shop.kgDiverted, impactPoints: points),
                  const CanopySectionHeader(title: 'Buyer requests', padding: EdgeInsets.only(top: CanopySpace.section)),
                  if (withRequests.isEmpty)
                    Text('Requests from buyers appear here, by listing.', style: CanopyType.body.copyWith(color: p.inkMuted))
                  else
                    CanopyCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < withRequests.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.outline),
                          InventoryRow(listing: withRequests[i], onTap: () => showListingResponses(context, withRequests[i])),
                        ],
                      ]),
                    ),
                  const SizedBox(height: CanopySpace.s8),
                  Text('Payments through Canopy aren\'t built yet, so there is no sales history here — you arrange payment with each buyer.',
                      style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  if (points > 0) ...[
                    const SizedBox(height: CanopySpace.section),
                    const CanopyComingSoon(
                      boxed: true,
                      icon: Icons.payments_outlined,
                      label: 'Not built yet',
                      title: 'Cash out impact points to M-Pesa',
                      line: 'Your points are recorded. Redeeming them for money isn\'t available yet.',
                    ),
                  ],
                  const CanopySectionHeader(title: 'Workspace', padding: EdgeInsets.only(top: CanopySpace.section)),
                  RoleContextSwitcher(
                    activeContext: 'marketplace',
                    hasMarketplace: true,
                    hasEnvOps: hasEnvOps,
                    hasCultural: hasCultural,
                    onOrgTap: () {
                      if (orgContextBuilder != null) _go(context, orgContextBuilder!);
                    },
                    onMemberTap: () => _go(context, memberContextBuilder ?? (_) => const CommunityHomeScreen()),
                    onMarketplaceTap: () {},
                    onEnvOpsTap: envOpsContextBuilder == null ? null : () => _go(context, envOpsContextBuilder!),
                    onCulturalTap: culturalContextBuilder == null ? null : () => _go(context, culturalContextBuilder!),
                  ),
                  const CanopySectionHeader(title: 'Account', padding: EdgeInsets.only(top: CanopySpace.section)),
                  CanopyListGroup(children: [
                    CanopyListRow(
                      icon: Icons.storefront_outlined,
                      title: 'Shop details',
                      subtitle: 'Name, logo, banner, bio, specialisations',
                      onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const EditShopScreen())),
                    ),
                    CanopyListRow(
                      icon: Icons.lock_outline,
                      title: 'Password & security',
                      onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const SecurityScreen())),
                    ),
                    CanopyListRow(icon: Icons.help_outline, title: 'Get help', onTap: () => showSupportSheet(context)),
                  ]),
                  const SizedBox(height: CanopySpace.section),
                  Center(child: CanopyButton.quietDanger(label: 'Sign out', onPressed: () => _signOut(context))),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT SHOP
// ─────────────────────────────────────────────────────────────────────────────

class EditShopScreen extends StatefulWidget {
  const EditShopScreen({super.key});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final Set<String> _specialisations = {};
  String? _logoUrl, _bannerUrl;
  File? _newLogo, _newBanner;
  bool _loading = true, _saving = false, _showErrors = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _bio, _city, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = (await FirebaseFirestore.instance.collection('marketplace_sellers').doc(_uid).get()).data() ?? {};
      final s = MarketplaceSellerProfile.fromMap(_uid!, d);
      _name.text = s.name == 'Canopy seller' ? '' : s.name;
      _bio.text = s.bio;
      _city.text = s.city;
      _area.text = s.area;
      _logoUrl = s.logoUrl;
      _bannerUrl = s.bannerUrl;
      _specialisations.addAll(s.specialisations);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick(bool logo) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (f != null) setState(() => logo ? _newLogo = File(f.path) : _newBanner = File(f.path));
  }

  Future<String> _upload(File f, String name) async {
    final ref = FirebaseStorage.instance.ref('marketplace_sellers/$_uid/${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(f);
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final logo = _newLogo != null ? await _upload(_newLogo!, 'shop_logo') : _logoUrl;
      final banner = _newBanner != null ? await _upload(_newBanner!, 'banner') : _bannerUrl;
      await GeoRegistry.instance.ensureLoaded();
      final geo = GeoRegistry.instance.resolve(area: _area.text.trim(), county: _city.text.trim(), country: 'Kenya');
      await FirebaseFirestore.instance.collection('marketplace_sellers').doc(_uid).set({
        ...geo.toFirestore(),
        'shop_name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'city': _city.text.trim(),
        'area': _area.text.trim(),
        'shop_logo_url': logo,
        'banner_url': banner,
        'specialisations': _specialisations.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      showCanopySnack(context, 'Shop details saved.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (_loading) return CanopyScaffold(appBar: canopyAppBar(context, title: 'Shop details'), body: const Center(child: CircularProgressIndicator()));
    const gap = SizedBox(height: CanopySpace.s16);
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Shop details'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          SizedBox(
            height: 186,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CanopyRadius.md),
                  child: Material(
                    color: p.surfaceMuted,
                    child: InkWell(
                      onTap: () => _pick(false),
                      child: Stack(fit: StackFit.expand, children: [
                        if (_newBanner != null)
                          Image.file(_newBanner!, fit: BoxFit.cover)
                        else if (_bannerUrl != null)
                          CanopyImage(url: _bannerUrl)
                        else
                          Center(child: Text('Add a banner photo', style: CanopyType.label.copyWith(color: p.inkMuted))),
                        Positioned(right: CanopySpace.s8, bottom: CanopySpace.s8, child: Icon(Icons.edit_outlined, color: p.ink)),
                      ]),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: CanopySpace.s16,
                top: 114,
                child: GestureDetector(
                  onTap: () => _pick(true),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: p.canvas, borderRadius: BorderRadius.circular(24)),
                    child: _newLogo != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.file(_newLogo!, width: 72, height: 72, fit: BoxFit.cover))
                        : CanopyAvatar(url: _logoUrl, name: _name.text, size: 72, org: true),
                  ),
                ),
              ),
            ]),
          ),
          Text('Tap the banner or logo to change them.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
          gap,
          CanopyTextField(
            label: 'Shop name',
            controller: _name,
            error: _showErrors && _name.text.trim().isEmpty ? 'Your shop needs a name.' : null,
            onChanged: (_) => setState(() {}),
          ),
          gap,
          CanopyTextField(label: 'About your shop', hint: 'What you make and how', controller: _bio, minLines: 3, maxLines: 8, maxLength: 800),
          gap,
          Row(children: [
            Expanded(child: CanopyTextField(label: 'County or city', controller: _city)),
            const SizedBox(width: CanopySpace.s12),
            Expanded(child: CanopyTextField(label: 'Area', controller: _area)),
          ]),
          const SizedBox(height: CanopySpace.section),
          Text('Materials you work with', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final m in MaterialType.values.where((m) => m != MaterialType.mixed))
              CanopyFilterChip(
                label: m.label,
                selected: _specialisations.contains(m.label),
                onTap: () => setState(() => _specialisations.contains(m.label) ? _specialisations.remove(m.label) : _specialisations.add(m.label)),
              ),
          ]),
        ],
      ),
      sticky: StickyActionBar(children: [CanopyButton(label: 'Save shop details', expand: true, loading: _saving, onPressed: _save)]),
    );
  }
}
