// lib/MarketPlace/Shop/seller_shop.dart
//
// Seller › Shop (MARKETPLACE_SELLER_DESIGN_BRIEF §4, F). The seller's real
// inventory from /listings (Live · Paused · Sold out), each with its buyer
// requests, pause/resume, sold out, edit and close — and a sticky
// "New listing" into the listing wizard, which publishes for real.
//
// Wizard: Category → Materials → Details → Studio → Photos → Review →
// "Publish listing". Provenance (source, kg) is optional and shown to
// buyers only when entered — nothing is invented.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:image_picker/image_picker.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Models/marketplace/canopy_listing.dart';
import '../../Services/Geo/geo_registry.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../theme/canopy_components.dart';
import '../market_ui.dart';

class SellerShopPage extends StatelessWidget {
  const SellerShopPage({super.key});

  Future<void> _set(BuildContext context, CanopyListing l, ListingStatus s, String done) async {
    try {
      await ListingService.instance.setStatus(l.id, s);
      if (context.mounted) showCanopySnack(context, done);
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    }
  }

  Future<void> _actions(BuildContext context, CanopyListing l) async {
    final action = await showCanopySheet<String>(context, builder: (ctx) {
      return CanopySheetBody(title: l.title, children: [
        CanopyListGroup(children: [
          CanopyListRow(
            icon: Icons.forum_outlined,
            title: 'Buyer requests',
            subtitle: l.responseCount == 0 ? 'None yet' : '${l.responseCount}',
            onTap: () => Navigator.pop(ctx, 'requests'),
          ),
          CanopyListRow(icon: Icons.edit_outlined, title: 'Edit listing', onTap: () => Navigator.pop(ctx, 'edit')),
          if (l.status == ListingStatus.active)
            CanopyListRow(icon: Icons.pause_circle_outline, title: 'Pause — hide from buyers', onTap: () => Navigator.pop(ctx, 'pause')),
          if (l.status == ListingStatus.paused || l.status == ListingStatus.fulfilled)
            CanopyListRow(icon: Icons.play_circle_outline, title: 'Put back on sale', onTap: () => Navigator.pop(ctx, 'live')),
          if (l.status == ListingStatus.active)
            CanopyListRow(icon: Icons.inventory_outlined, title: 'Mark sold out', onTap: () => Navigator.pop(ctx, 'sold')),
          CanopyListRow(icon: Icons.close, title: 'Close listing', titleColor: ctx.canopy.danger, onTap: () => Navigator.pop(ctx, 'close')),
        ]),
      ]);
    });
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'requests':
        showListingResponses(context, l);
      case 'edit':
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => ListingWizardScreen(existing: l)));
      case 'pause':
        _set(context, l, ListingStatus.paused, 'Paused — buyers can\'t see it.');
      case 'live':
        _set(context, l, ListingStatus.active, 'Back on sale.');
      case 'sold':
        _set(context, l, ListingStatus.fulfilled, 'Marked sold out.');
      case 'close':
        final ok = await showCanopyConfirm(context,
            title: 'Close this listing?', message: 'It leaves your shop for good. Requests stay in your history.', confirmLabel: 'Close listing', danger: true);
        if (ok && context.mounted) _set(context, l, ListingStatus.closed, 'Listing closed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const CanopySignedOutState();
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Your shop', showBack: false),
      body: StreamBuilder<List<CanopyListing>>(
        stream: ListingService.instance.watchByMember(uid),
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(title: "Couldn't load your listings");
          if (!snap.hasData) {
            return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 4, leadingSize: 56)]);
          }
          final all = snap.data!.where((l) => l.isCreative && l.status != ListingStatus.closed).toList();
          if (all.isEmpty) {
            return CanopyEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Your shop is empty',
              line: 'List something you made from recovered material. Buyers send you requests; you arrange payment with them.',
              actionLabel: 'New listing',
              primaryAction: true,
              onAction: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const ListingWizardScreen())),
            );
          }
          List<CanopyListing> of(ListingStatus s) => all.where((l) => l.status == s).toList();
          Widget group(String title, List<CanopyListing> list) => list.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: CanopySpace.section),
                  child: CanopyCard(
                    padding: EdgeInsets.zero,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(CanopySpace.s16, CanopySpace.s12, CanopySpace.s16, 0),
                        child: Text('${title.toUpperCase()} · ${list.length}', style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                      ),
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: p.outline),
                        InventoryRow(
                          listing: list[i],
                          onTap: () => _actions(context, list[i]),
                          trailing: CanopyIconButton(icon: Icons.more_horiz, tooltip: 'Manage ${list[i].title}', onPressed: () => _actions(context, list[i])),
                        ),
                      ],
                    ]),
                  ),
                );
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
            children: [
              group('Live', of(ListingStatus.active)),
              group('Paused', of(ListingStatus.paused)),
              group('Sold out', of(ListingStatus.fulfilled)),
            ],
          );
        },
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'New listing',
          expand: true,
          onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const ListingWizardScreen())),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING WIZARD
// ─────────────────────────────────────────────────────────────────────────────

class ListingWizardScreen extends StatefulWidget {
  final CanopyListing? existing;
  const ListingWizardScreen({super.key, this.existing});

  @override
  State<ListingWizardScreen> createState() => _ListingWizardScreenState();
}

class _ListingWizardScreenState extends State<ListingWizardScreen> {
  static const _steps = ['Category', 'Materials', 'Details', 'Studio', 'Photos', 'Review'];

  int _step = 0;
  ListingCategory? _category;
  final Set<MaterialType> _materials = {};
  final _source = TextEditingController();
  final _kg = TextEditingController();
  final _title = TextEditingController();
  final _story = TextEditingController();
  final _price = TextEditingController();
  bool _negotiable = false;
  bool _madeToOrder = false;
  int _stock = 1;
  CanopyLocation _place = CanopyLocation.empty;
  bool _delivers = false, _collect = true;
  final List<String> _existingImages = [];
  final List<File> _newImages = [];
  bool _saving = false, _showErrors = false;
  Map<String, dynamic> _seller = const {};

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _category = e.category;
      _materials.addAll(e.materials);
      _title.text = e.title;
      _story.text = e.story;
      if (e.pricing.amountKes > 0) _price.text = e.pricing.amountKes.round().toString();
      _negotiable = e.pricing.negotiable;
      _madeToOrder = e.quantity.isMadeToOrder;
      _stock = e.quantity.stockCount < 1 ? 1 : e.quantity.stockCount;
      _place = e.location;
      _delivers = e.fulfilment.acceptsDelivery;
      _collect = e.fulfilment.willCollect;
      _existingImages.addAll(e.images);
      if (e.materialDna.isNotEmpty) _source.text = e.materialDna.first.collectionSite ?? '';
      if (e.impact.kgDiverted > 0) _kg.text = e.impact.kgDiverted.toString();
    }
    _loadSeller();
  }

  @override
  void dispose() {
    for (final c in [_source, _kg, _title, _story, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSeller() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final d = (await FirebaseFirestore.instance.collection('marketplace_sellers').doc(uid).get()).data() ?? {};
      await GeoRegistry.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _seller = d;
        if (!_editing && _place == CanopyLocation.empty) _place = GeoRegistry.instance.resolveFromDocument(d);
      });
    } catch (_) {}
  }

  int get _photoCount => _existingImages.length + _newImages.length;

  String? _errorFor(int s) => switch (s) {
        0 => _category == null ? 'Choose a category.' : null,
        1 => _materials.isEmpty ? 'Choose at least one material it is made from.' : null,
        2 => _title.text.trim().isEmpty
            ? 'Give it a name.'
            : _story.text.trim().length < 40
                ? 'Tell buyers its story — at least a couple of sentences.'
                : (!_negotiable && (int.tryParse(_price.text.trim()) ?? 0) <= 0)
                    ? 'Set a price, or mark it negotiable.'
                    : null,
        3 => _place.label.isEmpty || _place == CanopyLocation.empty ? 'Choose where your studio is.' : (!_delivers && !_collect ? 'Choose how buyers get it.' : null),
        4 => _photoCount == 0 ? 'Add at least one photo.' : null,
        _ => null,
      };

  void _next() {
    if (_errorFor(_step) != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _showErrors = false;
        _step--;
      });
    }
  }

  Future<void> _pickPlace() async {
    await GeoRegistry.instance.ensureLoaded();
    if (!mounted) return;
    final picked = await showCanopySheet<CanopyLocation>(context, tall: true, builder: (_) => const _StudioPlaceSheet());
    if (picked != null) setState(() => _place = picked);
  }

  Future<void> _addPhotos() async {
    final xs = await ImagePicker().pickMultiImage(imageQuality: 85);
    setState(() {
      for (final x in xs) {
        if (_photoCount < 6) _newImages.add(File(x.path));
      }
    });
  }

  Future<void> _publish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final urls = [..._existingImages];
      for (var i = 0; i < _newImages.length; i++) {
        final ref = FirebaseStorage.instance.ref('listings/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putFile(_newImages[i]);
        urls.add(await ref.getDownloadURL());
      }
      final kg = double.tryParse(_kg.text.trim()) ?? 0;
      final source = _source.text.trim();
      final listing = CanopyListing(
        id: widget.existing?.id ?? '',
        side: ListingSide.creative,
        intent: ListingIntent.offering,
        status: widget.existing?.status ?? ListingStatus.active,
        title: _title.text.trim(),
        story: _story.text.trim(),
        tagline: makerCategoryLabel(_category!),
        category: _category!,
        materials: _materials.toList(),
        images: urls,
        seller: SellerSnapshot(
          sellerId: uid,
          shopName: (_seller['shop_name'] ?? _seller['name'] ?? '') as String,
          shopLogoUrl: _seller['shop_logo_url'] as String?,
          city: _place.countyName ?? (_seller['city'] as String? ?? ''),
          country: _place.countryName ?? 'Kenya',
        ),
        postedByUid: uid,
        pricing: ListingPricing(
          amountKes: (int.tryParse(_price.text.trim()) ?? 0).toDouble(),
          unit: PriceUnit.perItem,
          negotiable: _negotiable,
        ),
        quantity: ListingQuantity(stockCount: _madeToOrder ? 0 : _stock),
        fulfilment: ListingFulfilment(acceptsDelivery: _delivers, willCollect: _collect),
        materialDna: source.isEmpty && kg <= 0
            ? const []
            : [MaterialDnaLink(collectionSite: source.isEmpty ? null : source, weightKg: kg > 0 ? kg : null, material: _materials.first)],
        impact: ListingImpact(kgDiverted: kg > 0 ? kg : 0),
        location: _place,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      if (_editing) {
        final data = listing.toFirestore()
          ..remove('createdAt')
          ..remove('viewCount')
          ..remove('wishlistCount')
          ..remove('responseCount')
          ..remove('averageRating')
          ..remove('reviewCount');
        await ListingService.instance.update(listing.id, data);
      } else {
        await ListingService.instance.create(listing);
      }
      if (!mounted) return;
      showCanopySnack(context, _editing ? 'Listing updated.' : 'Listed — buyers can find it now.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't publish. Your listing is still here — try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final last = _step == _steps.length - 1;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CanopyScaffold(
        appBar: canopyAppBar(
          context,
          title: _editing ? 'Edit listing' : 'New listing',
          leading: IconButton(icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back), tooltip: _step == 0 ? 'Close' : 'Back', onPressed: _back),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
          children: [
            CanopyStepper(step: _step + 1, total: _steps.length, label: _steps[_step], stepLabels: _steps),
            const SizedBox(height: CanopySpace.section),
            ..._body(p),
            if (_showErrors && _errorFor(_step) != null)
              Padding(
                padding: const EdgeInsets.only(top: CanopySpace.s16),
                child: Text(_errorFor(_step)!, style: CanopyType.body.copyWith(color: p.danger)),
              ),
          ],
        ),
        sticky: StickyActionBar(children: [
          CanopyButton(
            label: last ? (_editing ? 'Save changes' : 'Publish listing') : 'Continue',
            expand: true,
            loading: _saving,
            onPressed: last ? _publish : _next,
          ),
        ]),
      ),
    );
  }

  List<Widget> _body(CanopyPalette p) {
    const gap = SizedBox(height: CanopySpace.s16);
    switch (_step) {
      case 0:
        return [
          Text('What kind of thing is it?', style: CanopyType.title.copyWith(color: p.ink)),
          gap,
          for (final c in kMakerCategories) ...[
            CanopyOptionCard(
              selected: _category == c,
              icon: makerCategoryIcon(c),
              title: makerCategoryLabel(c),
              onTap: () => setState(() => _category = c),
            ),
            const SizedBox(height: CanopySpace.s8),
          ],
        ];
      case 1:
        return [
          Text('What is it made from?', style: CanopyType.title.copyWith(color: p.ink)),
          gap,
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final m in MaterialType.values)
              CanopyFilterChip(
                label: m.label,
                selected: _materials.contains(m),
                onTap: () => setState(() => _materials.contains(m) ? _materials.remove(m) : _materials.add(m)),
              ),
          ]),
          const SizedBox(height: CanopySpace.section),
          Text('Where the material came from (optional)', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s4),
          Text('Only shown to buyers if you fill it in.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s8),
          CanopyTextField(label: 'Source', hint: 'e.g. Bottles collected along the Nairobi River', controller: _source),
          gap,
          CanopyTextField(
            label: 'Material used (kg)',
            hint: 'e.g. 1.5',
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ];
      case 2:
        return [
          CanopyTextField(label: 'Name', hint: 'e.g. Copper wire bangle', controller: _title, maxLength: 80, onChanged: (_) => setState(() {})),
          gap,
          CanopyTextField(
            label: 'Its story',
            hint: 'How you made it, what it was before, who it\'s for',
            controller: _story,
            minLines: 4,
            maxLines: 10,
            maxLength: 1500,
            onChanged: (_) => setState(() {}),
          ),
          gap,
          CanopyTextField.money(label: 'Price', controller: _price, enabled: !_negotiable),
          CanopySwitchRow(title: 'Price is negotiable', value: _negotiable, onChanged: (v) => setState(() => _negotiable = v)),
          CanopySwitchRow(title: 'Made to order', caption: 'You make each one when asked', value: _madeToOrder, onChanged: (v) => setState(() => _madeToOrder = v)),
          if (!_madeToOrder)
            Row(children: [
              Expanded(child: Text('In stock', style: CanopyType.bodyStrong.copyWith(color: p.ink))),
              CanopyIconButton(icon: Icons.remove, tooltip: 'Fewer', onPressed: _stock > 1 ? () => setState(() => _stock--) : null),
              SizedBox(width: 40, child: Text('$_stock', textAlign: TextAlign.center, style: CanopyType.title.copyWith(color: p.ink))),
              CanopyIconButton(icon: Icons.add, tooltip: 'More', onPressed: () => setState(() => _stock++)),
            ]),
        ];
      case 3:
        return [
          Text('Where is your studio?', style: CanopyType.title.copyWith(color: p.ink)),
          gap,
          CanopyPickerField(
            label: 'Studio location',
            value: _place == CanopyLocation.empty || _place.label.isEmpty ? null : _place.label,
            placeholder: 'County or area',
            icon: Icons.place_outlined,
            onTap: _pickPlace,
          ),
          const SizedBox(height: CanopySpace.section),
          Text('HOW BUYERS GET IT', style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s8),
          CanopyCheckRow(label: 'Collect from the studio', value: _collect, onChanged: (v) => setState(() => _collect = v)),
          CanopyCheckRow(label: 'I can deliver', value: _delivers, onChanged: (v) => setState(() => _delivers = v)),
        ];
      case 4:
        return [
          Text('$_photoCount of 6 photos', style: CanopyType.title.copyWith(color: p.ink)),
          Text('The first is the cover. Daylight, plain background, and one close-up of the material.',
              style: CanopyType.body.copyWith(color: p.inkMuted)),
          gap,
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: CanopySpace.s8,
            crossAxisSpacing: CanopySpace.s8,
            children: [
              for (var i = 0; i < _existingImages.length; i++)
                _thumb(CanopyImage(url: _existingImages[i]), () => setState(() => _existingImages.removeAt(i))),
              for (var i = 0; i < _newImages.length; i++)
                _thumb(Image.file(_newImages[i], fit: BoxFit.cover), () => setState(() => _newImages.removeAt(i))),
              if (_photoCount < 6)
                Material(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(CanopyRadius.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(CanopyRadius.sm),
                    onTap: _addPhotos,
                    child: Center(child: Icon(Icons.add_photo_alternate_outlined, color: p.inkMuted)),
                  ),
                ),
            ],
          ),
        ];
      default:
        final kg = double.tryParse(_kg.text.trim()) ?? 0;
        return [
          CanopyListGroup(children: [
            CanopyFactRow(label: 'Category', value: makerCategoryLabel(_category!)),
            CanopyFactRow(label: 'Name', value: _title.text.trim()),
            CanopyFactRow(
              label: 'Price',
              value: _negotiable ? 'Negotiable' : 'KSh ${_price.text.trim().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
            ),
            CanopyFactRow(label: 'Stock', value: _madeToOrder ? 'Made to order' : '$_stock'),
            CanopyFactRow(label: 'Made from', value: _materials.map((m) => m.label).join(', ')),
            if (_source.text.trim().isNotEmpty) CanopyFactRow(label: 'Source', value: _source.text.trim()),
            if (kg > 0) CanopyFactRow(label: 'Material used', value: '$kg kg'),
            CanopyFactRow(label: 'Studio', value: _place.label),
            CanopyFactRow(label: 'Photos', value: '$_photoCount'),
          ]),
          const SizedBox(height: CanopySpace.s16),
          const CanopyCallout(
            text: 'Buyers send you a request from the listing. You agree payment and handover with them — Canopy doesn\'t take payment for made goods yet.',
          ),
        ];
    }
  }

  Widget _thumb(Widget image, VoidCallback onRemove) => Stack(fit: StackFit.expand, children: [
        ClipRRect(borderRadius: BorderRadius.circular(CanopyRadius.sm), child: image),
        Positioned(top: 2, right: 2, child: CanopyIconButton(icon: Icons.close, tooltip: 'Remove photo', onImage: true, onPressed: onRemove)),
      ]);
}

/// County → area → CanopyLocation.
class _StudioPlaceSheet extends StatefulWidget {
  const _StudioPlaceSheet();

  @override
  State<_StudioPlaceSheet> createState() => _StudioPlaceSheetState();
}

class _StudioPlaceSheetState extends State<_StudioPlaceSheet> {
  String _q = '';
  GeoCounty? _county;

  @override
  Widget build(BuildContext context) {
    final geo = GeoRegistry.instance;
    final county = _county;
    return CanopySheetBody(title: county?.name ?? 'Choose a county', children: [
      CanopyTextField.search(
        key: ValueKey(county?.id ?? 'counties'),
        hint: county == null ? 'Search counties' : 'Search areas',
        onChanged: (v) => setState(() => _q = v),
      ),
      const SizedBox(height: CanopySpace.s12),
      CanopyListGroup(children: [
        if (county == null)
          for (final c in geo.searchCounties(_q).take(60))
            CanopyListRow(
              title: c.name,
              subtitle: c.regionName,
              onTap: () => setState(() {
                _county = c;
                _q = '';
              }),
            )
        else ...[
          CanopyListRow(
            icon: Icons.select_all,
            title: 'Anywhere in ${county.name}',
            chevron: false,
            onTap: () => Navigator.pop(context, geo.locationForCounty(county.id)),
          ),
          for (final a in geo.searchAreas(_q, countyId: county.id).take(80))
            CanopyListRow(title: a.name, chevron: false, onTap: () => Navigator.pop(context, geo.locationForArea(a.id))),
        ],
      ]),
    ]);
  }
}
