// lib/HomeServices/create_service_listing_screen.dart
//
// Create listing (SERVICES_HANDOFF §3.8) — 4-step stepper:
//   1 Category  — 3-col grid; regulated categories need a licence photo to
//                 continue (LicencePhotoTile: empty · captured + Retake ·
//                 uploading · failed + retry).
//   2 Details   — title, description, offerings (filter chips), photo.
//   3 Pricing & area — rate type segmented, from/to range, county, base,
//                 radius slider.
//   4 Review    — edit links per section; regulated → "won't appear in
//                 Browse until verified".
// Two confirmations: Live in Browse vs Pending verification (timeline
// Submitted → Licence check → Live).
//
// Edit mode ([existing]): same steps minus the category change; saves a
// patch via ServiceMarketplaceService.updateListing.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Models/geo/canopy_location.dart';
import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import 'my_service_listings_screen.dart';
import 'services_ui.dart';

class CreateServiceListingScreen extends StatefulWidget {
  final ServiceCategory? initialCategory;
  final ServiceListing? existing;

  const CreateServiceListingScreen({this.initialCategory, this.existing, super.key});

  @override
  State<CreateServiceListingScreen> createState() => _CreateServiceListingScreenState();
}

class _CreateServiceListingScreenState extends State<CreateServiceListingScreen> {
  static const _labels = ['Category', 'Details', 'Pricing & area', 'Review'];

  late final bool _editing = widget.existing != null;
  late ServiceCategory? _category = widget.existing?.category ?? widget.initialCategory;
  late final Set<String> _offerings = {...?widget.existing?.offerings};
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _from = TextEditingController(
      text: widget.existing?.pricing.fromKes?.round().toString());
  late final _to = TextEditingController(
      text: widget.existing?.pricing.toKes?.round().toString());
  late final _county = TextEditingController(text: widget.existing?.location.countyName);
  late final _base = TextEditingController(text: widget.existing?.location.venue);
  late ServiceRateType _rate = widget.existing?.pricing.rateType ?? ServiceRateType.perVisit;
  late double _radius = (widget.existing?.serviceRadiusKm ?? 10).clamp(1, 50).toDouble();

  File? _photo;
  File? _licence;
  bool _licenceFailed = false;

  int _step = 0;
  bool _showErrors = false;
  bool _submitting = false;
  bool _failed = false;
  bool? _doneLive; // null = not submitted; true = live; false = pending check

  @override
  void initState() {
    super.initState();
    if (_editing) _step = 1;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _from, _to, _county, _base]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation per step ─────────────────────────────────────────────────

  String? get _titleError =>
      _title.text.trim().length < 5 ? 'Give your listing a clear title.' : null;
  String? get _offeringsError => _offerings.isEmpty ? 'Pick at least one thing you offer.' : null;
  String? get _fromError {
    if (_rate == ServiceRateType.quoteOnly) return null;
    final f = int.tryParse(_from.text.trim());
    return f == null || f <= 0 ? 'Enter your starting price.' : null;
  }

  String? get _toError {
    final t = _to.text.trim();
    if (_rate == ServiceRateType.quoteOnly || t.isEmpty) return null;
    final to = int.tryParse(t), from = int.tryParse(_from.text.trim()) ?? 0;
    return to == null || to <= from ? 'Must be more than the starting price.' : null;
  }

  String? get _countyError => _county.text.trim().isEmpty ? 'Say which county you work in.' : null;

  bool _stepValid(int s) => switch (s) {
        0 => _category != null &&
            (!_category!.requiresLicenseVerification || _licence != null || _editing),
        1 => _titleError == null && _offeringsError == null,
        2 => _fromError == null && _toError == null && _countyError == null,
        _ => true,
      };

  void _next() {
    setState(() => _showErrors = true);
    if (!_stepValid(_step)) return;
    setState(() {
      _showErrors = false;
      _step++;
    });
  }

  void _back() {
    if (_step == 0 || (_editing && _step == 1)) {
      Navigator.maybePop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<File?> _pick({required bool licence}) async {
    final source = await showCanopySheet<ImageSource>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: licence ? 'Photo of your ${_category!.licenceName}' : 'Listing photo',
        caption: licence ? 'Make sure your name and licence number are readable.' : null,
        children: [
          CanopyListGroup(children: [
            CanopyListRow(
                icon: Icons.photo_camera_outlined,
                title: 'Take a photo',
                onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            CanopyListRow(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ]),
        ],
      ),
    );
    if (source == null) return null;
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85);
    return x == null ? null : File(x.path);
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _failed = false;
      _licenceFailed = false;
    });
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      String? photoUrl;
      if (_photo != null) {
        final ref = FirebaseStorage.instance
            .ref('service_listings/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
        await ref.putFile(_photo!);
        photoUrl = await ref.getDownloadURL();
      }
      String? licenceUrl;
      if (_licence != null) {
        try {
          final ref = FirebaseStorage.instance.ref(
              'service_provider_licenses/$uid/${DateTime.now().millisecondsSinceEpoch}_${_category!.name}.jpg');
          await ref.putFile(_licence!);
          licenceUrl = await ref.getDownloadURL();
        } catch (_) {
          setState(() => _licenceFailed = true);
          rethrow;
        }
      }
      final from = int.tryParse(_from.text.trim());
      final to = int.tryParse(_to.text.trim());
      final pricing = _rate == ServiceRateType.quoteOnly || from == null
          ? const ServicePricing()
          : ServicePricing(rateType: _rate, fromKes: from.toDouble(), toKes: to?.toDouble());
      final location = CanopyLocation(
        countyName: _county.text.trim(),
        venue: _base.text.trim().isEmpty ? null : _base.text.trim(),
      );

      if (_editing) {
        final e = widget.existing!;
        await ServiceMarketplaceService.instance.updateListing(e.id, {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'offerings': _offerings.toList(),
          if (photoUrl != null) 'images': [photoUrl, ...e.images.skip(1)],
          'pricing': pricing.toMap(),
          'serviceRadiusKm': _radius,
          ...location.toFirestore(),
        });
        if (mounted) {
          Navigator.pop(context);
          showCanopySnack(context, 'Listing updated.');
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser!;
      var name = user.displayName ?? '';
      if (name.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        name = (doc.data()?['name'] as String?) ?? 'Canopy provider';
      }
      final c = _category!;
      await ServiceMarketplaceService.instance.createListing(ServiceListing(
        id: '',
        category: c,
        title: _title.text.trim(),
        description: _description.text.trim(),
        offerings: _offerings.toList(),
        images: [if (photoUrl != null) photoUrl],
        provider: SellerSnapshot(sellerId: uid, shopName: name, city: _county.text.trim()),
        postedByUid: uid,
        pricing: pricing,
        serviceRadiusKm: _radius,
        location: location,
        licenseDocumentUrl: licenceUrl,
        licenseVerificationStatus: c.requiresLicenseVerification
            ? LicenseVerificationStatus.pending
            : LicenseVerificationStatus.notRequired,
        createdAt: DateTime.now(),
      ));
      if (mounted) setState(() => _doneLive = !c.requiresLicenseVerification);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_doneLive != null) return _confirmation(_doneLive!);
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(
        context,
        title: _editing ? 'Edit listing' : 'List a service',
        leading: CanopyIconButton(
          icon: _step == 0 || (_editing && _step == 1) ? Icons.close : Icons.arrow_back,
          tooltip: 'Back',
          onPressed: _back,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
        children: [
          CanopyStepper(step: _step + 1, total: 4, label: _labels[_step]),
          const SizedBox(height: CanopySpace.section),
          ...switch (_step) {
            0 => _categoryStep(p),
            1 => _detailsStep(p),
            2 => _pricingStep(p),
            _ => _reviewStep(p),
          },
        ],
      ),
      sticky: StickyActionBar(children: [
        if (_step < 3)
          CanopyButton(
            label: 'Next · ${_labels[_step + 1]}',
            expand: true,
            onPressed: _next,
          )
        else
          CanopyButton(
            label: _editing ? 'Save changes' : (_failed ? 'Try again' : 'Post listing'),
            expand: true,
            loading: _submitting,
            onPressed: _submit,
          ),
      ]),
    );
  }

  List<Widget> _categoryStep(CanopyPalette p) {
    final c = _category;
    final reg = c == null ? null : regulatoryCallout(c);
    return [
      Text('What are you offering?', style: CanopyType.title.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s12),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: CanopySpace.s8,
        crossAxisSpacing: CanopySpace.s8,
        childAspectRatio: 0.95,
        children: [
          for (final cat in ServiceCategory.values)
            Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CanopyRadius.sm),
                side: BorderSide(
                    color: cat == c ? p.ink : p.outline, width: cat == c ? 2 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(CanopyRadius.sm),
                onTap: () => setState(() {
                  _category = cat;
                  _offerings.clear();
                  if (!cat.requiresLicenseVerification) _licence = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(CanopySpace.s8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CategoryGlyph(cat, size: 26),
                      const SizedBox(height: CanopySpace.s4),
                      Text(cat.name2,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: CanopyType.label.copyWith(color: p.ink, fontSize: 12)),
                      if (cat.licenceName != null)
                        Text(cat.licenceName!,
                            textAlign: TextAlign.center,
                            style: CanopyType.micro.copyWith(color: p.inkMuted, letterSpacing: 0)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      if (_showErrors && c == null) ...[
        const SizedBox(height: CanopySpace.s8),
        Text('Pick a category.', style: CanopyType.caption.copyWith(color: p.danger)),
      ],
      if (reg != null) ...[const SizedBox(height: CanopySpace.s16), reg],
      if (c != null && c.requiresLicenseVerification) ...[
        const SizedBox(height: CanopySpace.s16),
        Text('Photo of your ${c.licenceName}', style: CanopyType.label.copyWith(color: p.ink)),
        const SizedBox(height: CanopySpace.s4 + 2),
        _LicenceTile(
          file: _licence,
          uploading: _submitting && _licence != null,
          failed: _licenceFailed,
          showRequired: _showErrors && _licence == null,
          onPick: () async {
            final f = await _pick(licence: true);
            if (f != null) setState(() => _licence = f);
          },
        ),
        const SizedBox(height: CanopySpace.s4 + 2),
        Text('Only Canopy sees this. Customers see "Licence verified" once it\'s checked.',
            style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
    ];
  }

  List<Widget> _detailsStep(CanopyPalette p) {
    final c = _category!;
    return [
      CanopyTextField(
        label: 'Title',
        hint: '${c.name2} in ${_county.text.isEmpty ? 'your area' : _county.text}',
        controller: _title,
        maxLength: 70,
        error: _showErrors ? _titleError : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: CanopySpace.s16),
      CanopyTextField(
        label: 'Description',
        hint: 'What you do, how you work, what customers should know',
        controller: _description,
        minLines: 4,
        maxLines: 8,
        maxLength: 800,
      ),
      const SizedBox(height: CanopySpace.s16),
      Text('What do you offer?', style: CanopyType.label.copyWith(color: p.ink)),
      Wrap(
        spacing: CanopySpace.s8,
        children: [
          for (final o in c.offeringOptions)
            CanopyFilterChip(
              label: ServiceCategory.offeringLabel(o),
              selected: _offerings.contains(o),
              onTap: () => setState(
                  () => _offerings.contains(o) ? _offerings.remove(o) : _offerings.add(o)),
            ),
        ],
      ),
      if (_showErrors && _offeringsError != null)
        Text(_offeringsError!, style: CanopyType.caption.copyWith(color: p.danger)),
      const SizedBox(height: CanopySpace.s16),
      Text('Photo (optional)', style: CanopyType.label.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s4 + 2),
      _PhotoTile(
        file: _photo,
        existingUrl: widget.existing?.coverImage,
        onPick: () async {
          final f = await _pick(licence: false);
          if (f != null) setState(() => _photo = f);
        },
        onRemove: () => setState(() => _photo = null),
      ),
    ];
  }

  List<Widget> _pricingStep(CanopyPalette p) {
    return [
      Text('How do you charge?', style: CanopyType.label.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s4 + 2),
      CanopySegmented<ServiceRateType>(
        options: const [
          (ServiceRateType.monthly, 'Per month'),
          (ServiceRateType.perVisit, 'Per visit'),
          (ServiceRateType.quoteOnly, 'Quote only'),
        ],
        value: _rate,
        onChanged: (v) => setState(() => _rate = v),
      ),
      const SizedBox(height: CanopySpace.s16),
      if (_rate == ServiceRateType.quoteOnly)
        const CanopyCallout(
            text: 'Customers see "Quote on request · free to ask" and you quote each job.')
      else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CanopyTextField.money(
                label: 'From',
                controller: _from,
                error: _showErrors ? _fromError : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: CanopyTextField.money(
                label: 'Up to (optional)',
                controller: _to,
                error: _showErrors ? _toError : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      if (_rate != ServiceRateType.quoteOnly) ...[
        const SizedBox(height: CanopySpace.s8),
        Text('The actual price is agreed per job when you send a quote. Canopy keeps 8% of it.',
            style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
      const SizedBox(height: CanopySpace.section),
      CanopyTextField(
        label: 'County',
        hint: 'Nairobi',
        controller: _county,
        error: _showErrors ? _countyError : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: CanopySpace.s16),
      CanopyTextField(
        label: 'Where you\'re based (optional)',
        hint: 'Estate or area',
        controller: _base,
      ),
      const SizedBox(height: CanopySpace.s16),
      Row(
        children: [
          Expanded(
              child: Text('How far will you travel?',
                  style: CanopyType.label.copyWith(color: p.ink))),
          Text('${_radius.round()} km',
              style: CanopyType.money.copyWith(fontSize: 15, color: p.ink)),
        ],
      ),
      Slider(
        value: _radius,
        min: 1,
        max: 50,
        divisions: 49,
        activeColor: p.primary,
        inactiveColor: p.outline,
        label: '${_radius.round()} km',
        onChanged: (v) => setState(() => _radius = v),
      ),
    ];
  }

  List<Widget> _reviewStep(CanopyPalette p) {
    final c = _category!;
    final from = int.tryParse(_from.text.trim());
    final pricing = _rate == ServiceRateType.quoteOnly || from == null
        ? const ServicePricing()
        : ServicePricing(
            rateType: _rate, fromKes: from.toDouble(), toKes: int.tryParse(_to.text.trim())?.toDouble());
    Widget section(String label, int step, List<String> lines) => CanopyListRow(
          title: label,
          below: Text(lines.where((s) => s.isNotEmpty).join('\n'),
              style: CanopyType.body.copyWith(color: p.inkMuted)),
          trailing: Text('Edit', style: CanopyType.label.copyWith(color: p.primaryInk)),
          chevron: false,
          onTap: step == 0 && _editing ? null : () => setState(() => _step = step),
        );
    final reg = regulatoryCallout(c,
        status: _editing ? widget.existing!.licenseVerificationStatus : LicenseVerificationStatus.pending);
    return [
      Text('Check your listing', style: CanopyType.title.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s12),
      CanopyListGroup(children: [
        section('Category', 0, [c.name2, if (_licence != null) '${c.licenceName} photo added']),
        section('Details', 1, [
          _title.text.trim(),
          _offerings.map(ServiceCategory.offeringLabel).join(' · '),
          if (_photo != null || widget.existing?.coverImage != null) 'Photo added',
        ]),
        section('Pricing & area', 2, [
          pricing.isQuoteOnly
              ? 'Quote on request'
              : '${ksh(pricing.fromKes!)}${pricing.toKes != null ? ' – ${ksh(pricing.toKes!)}' : ''} ${pricing.rateType.suffix}',
          [_county.text.trim(), if (_base.text.trim().isNotEmpty) _base.text.trim()].join(' · '),
          'Travels up to ${_radius.round()} km',
        ]),
      ]),
      if (reg != null) ...[const SizedBox(height: CanopySpace.s16), reg],
      if (_failed) ...[
        const SizedBox(height: CanopySpace.s16),
        CanopyCallout(
          kind: CalloutKind.danger,
          text: _licenceFailed
              ? "Your licence photo didn't upload. Check your connection and try again."
              : "Your listing didn't save. Nothing was lost — try again.",
        ),
      ],
    ];
  }

  Widget _confirmation(bool live) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, showBack: false, actions: [
        CanopyIconButton(
            icon: Icons.close, tooltip: 'Close', onPressed: () => Navigator.pop(context)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Icon(live ? Icons.check_circle_outline : Icons.hourglass_top_outlined,
              size: CanopyIconSize.empty, color: live ? p.success : p.warning),
          const SizedBox(height: CanopySpace.s12),
          StatusLabel(live ? 'Live in Browse' : 'Pending verification',
              color: live ? p.success : p.warning),
          const SizedBox(height: CanopySpace.s4),
          Text(live ? 'Your listing is live' : 'We\'re checking your licence',
              style: CanopyType.display.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          Text(
            live
                ? 'Neighbours can find you under ${_category!.name2} now. Requests arrive in My bookings → Incoming jobs.'
                : 'Your listing won\'t appear in Browse until Canopy has checked your ${_category!.licenceName}. We\'ll let you know.',
            style: CanopyType.body.copyWith(color: p.inkMuted),
          ),
          if (!live) ...[
            const SizedBox(height: CanopySpace.section),
            CanopyCard(
              child: CanopyTimeline(steps: [
                const TimelineStep('Submitted', state: TimelineState.done),
                TimelineStep('Licence check',
                    line: 'Canopy reviews your ${_category!.licenceName}',
                    state: TimelineState.now),
                const TimelineStep('Live in Browse'),
              ]),
            ),
          ],
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'See my listings',
          expand: true,
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const MyServiceListingsScreen())),
        ),
      ]),
    );
  }
}

class _LicenceTile extends StatelessWidget {
  final File? file;
  final bool uploading;
  final bool failed;
  final bool showRequired;
  final VoidCallback onPick;
  const _LicenceTile(
      {required this.file,
      required this.uploading,
      required this.failed,
      required this.showRequired,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (file == null) {
      return DashedBorder(
        color: showRequired ? p.danger : p.outlineStrong,
        radius: CanopyRadius.sm,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPick,
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: CanopyIconSize.s32, color: p.ink),
                  const SizedBox(height: CanopySpace.s4),
                  Text('Photograph or upload', style: CanopyType.label.copyWith(color: p.ink)),
                  if (showRequired)
                    Text('Required to continue',
                        style: CanopyType.caption.copyWith(color: p.danger)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(CanopyRadius.sm),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file!, fit: BoxFit.cover),
            if (uploading || failed)
              ColoredBox(
                color: failed ? p.danger.withAlpha(0xB3) : p.scrim,
                child: Center(
                  child: uploading
                      ? const CircularProgressIndicator(color: CanopyPalette.onHero)
                      : Text('Upload failed — tap Try again',
                          style: CanopyType.label.copyWith(color: CanopyPalette.onHero)),
                ),
              ),
            if (!uploading)
              Positioned(
                right: CanopySpace.s8,
                bottom: CanopySpace.s8,
                child: Material(
                  color: p.scrim,
                  borderRadius: BorderRadius.circular(CanopyRadius.xs),
                  child: InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(CanopyRadius.xs),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: CanopySpace.s12, vertical: CanopySpace.s8),
                      child: Text('Retake',
                          style: CanopyType.label.copyWith(color: CanopyPalette.onHero)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final File? file;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _PhotoTile(
      {required this.file, required this.existingUrl, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (file == null && existingUrl == null) {
      return DashedBorder(
        color: p.outlineStrong,
        radius: CanopyRadius.sm,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPick,
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: CanopyIconSize.nav, color: p.ink),
                  const SizedBox(height: CanopySpace.s4),
                  Text('Add a photo of your work',
                      style: CanopyType.label.copyWith(color: p.ink)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(CanopyRadius.sm),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            file != null ? Image.file(file!, fit: BoxFit.cover) : CanopyImage(url: existingUrl),
            Positioned(
              top: 0,
              right: 0,
              child: Row(children: [
                CanopyIconButton(
                    icon: Icons.edit_outlined, tooltip: 'Change photo', onImage: true, onPressed: onPick),
                if (file != null)
                  CanopyIconButton(
                      icon: Icons.close, tooltip: 'Remove photo', onImage: true, onPressed: onRemove),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
