// lib/HomeServices/create_service_listing_screen.dart
//
// 3-step listing wizard for providers, mirroring
// EnvironmentalOps/Market/create_listing_screen.dart's PageController shape
// (not env_trees.dart's IndexedStack wizard — that pattern suits a form with
// steps that stay mounted for a long-running record; a listing is filled in
// once and submitted, same as a market listing). Step numbering, the
// _StepProgressBar, _SectionLabel and _FieldBox visual language are the same
// as that screen so a provider who has listed on the Marketplace already
// knows this form.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Models/geo/canopy_location.dart';
import '../Models/marketplace/canopy_listing.dart' show SellerSnapshot;
import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../Shared/theme/app_theme.dart';

class CreateServiceListingScreen extends StatefulWidget {
  final ServiceCategory category;

  const CreateServiceListingScreen({required this.category, super.key});

  @override
  State<CreateServiceListingScreen> createState() =>
      _CreateServiceListingScreenState();
}

class _CreateServiceListingScreenState
    extends State<CreateServiceListingScreen> {
  late ServiceCategory _category = widget.category;
  final Set<String> _offerings = {};

  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _fromPriceCtrl = TextEditingController();
  final _toPriceCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  ServiceRateType _rateType = ServiceRateType.monthly;

  File? _imageFile;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  final _pageCtrl = PageController();
  int _step = 0; // 0=category+offerings, 1=details, 2=review

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _fromPriceCtrl.dispose();
    _toPriceCtrl.dispose();
    _radiusCtrl.dispose();
    _venueCtrl.dispose();
    _countyCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && _offerings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one thing you offer'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    }
  }

  Future<void> _pickImage() async {
    final xFile =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (xFile != null) setState(() => _imageFile = File(xFile.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'anon';

      String providerName = user?.displayName ?? '';
      if (providerName.isEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        providerName = (userDoc.data()?['name'] as String?) ?? 'Canopy provider';
      }

      String? imageUrl;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref(
            'service_listings/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      final fromKes = double.tryParse(_fromPriceCtrl.text.trim());
      final toKes = double.tryParse(_toPriceCtrl.text.trim());
      final radius = double.tryParse(_radiusCtrl.text.trim()) ?? 0;

      final listing = ServiceListing(
        id: '',
        category: _category,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        offerings: _offerings.toList(),
        images: [if (imageUrl != null) imageUrl],
        provider: SellerSnapshot(
          sellerId: uid,
          shopName: providerName,
          city: _countyCtrl.text.trim(),
        ),
        postedByUid: uid,
        pricing: fromKes == null
            ? const ServicePricing()
            : ServicePricing(rateType: _rateType, fromKes: fromKes, toKes: toKes),
        serviceRadiusKm: radius,
        location: CanopyLocation(
          countyName: _countyCtrl.text.trim().isEmpty ? null : _countyCtrl.text.trim(),
          venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
        ),
        createdAt: DateTime.now(),
      );

      await ServiceMarketplaceService.instance.createListing(listing);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service listed — requesters can now find you'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(_step > 0 ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
              size: 18),
          color: AppTheme.darkGreen,
          onPressed: _step > 0 ? _prevStep : () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('List Your Service',
                style: TextStyle(
                    color: AppTheme.darkGreen, fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Step ${_step + 1} of 3',
                style: TextStyle(
                    fontSize: 10, color: color.withOpacity(0.75), fontWeight: FontWeight.w600)),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: color.withOpacity(0.10),
            valueColor: const AlwaysStoppedAnimation(color),
            minHeight: 3,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StepCategoryOfferings(
              category: _category,
              offerings: _offerings,
              onCategoryChanged: (c) => setState(() {
                _category = c;
                _offerings.clear();
              }),
              onOfferingToggled: (key) => setState(() {
                if (_offerings.contains(key)) {
                  _offerings.remove(key);
                } else {
                  _offerings.add(key);
                }
              }),
            ),
            _StepDetails(
              rateType: _rateType,
              onRateTypeChanged: (t) => setState(() => _rateType = t),
              titleCtrl: _titleCtrl,
              descriptionCtrl: _descriptionCtrl,
              fromPriceCtrl: _fromPriceCtrl,
              toPriceCtrl: _toPriceCtrl,
              radiusCtrl: _radiusCtrl,
              venueCtrl: _venueCtrl,
              countyCtrl: _countyCtrl,
              imageFile: _imageFile,
              onPickImage: _pickImage,
            ),
            _StepReview(
              category: _category,
              offerings: _offerings,
              title: _titleCtrl.text,
              description: _descriptionCtrl.text,
              rateType: _rateType,
              fromPrice: _fromPriceCtrl.text,
              toPrice: _toPriceCtrl.text,
              venue: _venueCtrl.text,
              county: _countyCtrl.text,
              imageFile: _imageFile,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: SizedBox(
          height: 52,
          child: _step < 2
              ? ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_step == 0 ? 'Continue to Details' : 'Review Listing',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                )
              : ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.publish_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Post Listing',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — CATEGORY + OFFERINGS
// ─────────────────────────────────────────────────────────────────────────────

class _StepCategoryOfferings extends StatelessWidget {
  final ServiceCategory category;
  final Set<String> offerings;
  final ValueChanged<ServiceCategory> onCategoryChanged;
  final ValueChanged<String> onOfferingToggled;

  const _StepCategoryOfferings({
    required this.category,
    required this.offerings,
    required this.onCategoryChanged,
    required this.onOfferingToggled,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        const _SectionLabel(label: 'Category'),
        const SizedBox(height: 10),
        Row(
          children: ServiceCategory.values.map((c) {
            final selected = c == category;
            return Expanded(
              child: GestureDetector(
                onTap: () => onCategoryChanged(c),
                child: Container(
                  margin: EdgeInsets.only(
                      right: c == ServiceCategory.values.first ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.primary.withOpacity(0.20)),
                  ),
                  child: Column(
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        c.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppTheme.darkGreen.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _SectionLabel(label: 'What do you offer?', note: 'Pick all that apply'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: category.offeringOptions.map((key) {
            final selected = offerings.contains(key);
            return GestureDetector(
              onTap: () => onOfferingToggled(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.primary.withOpacity(0.20)),
                ),
                child: Text(
                  ServiceCategory.offeringLabel(key),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.darkGreen.withOpacity(0.75),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — DETAILS
// ─────────────────────────────────────────────────────────────────────────────

class _StepDetails extends StatelessWidget {
  final ServiceRateType rateType;
  final ValueChanged<ServiceRateType> onRateTypeChanged;
  final TextEditingController titleCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController fromPriceCtrl;
  final TextEditingController toPriceCtrl;
  final TextEditingController radiusCtrl;
  final TextEditingController venueCtrl;
  final TextEditingController countyCtrl;
  final File? imageFile;
  final VoidCallback onPickImage;

  const _StepDetails({
    required this.rateType,
    required this.onRateTypeChanged,
    required this.titleCtrl,
    required this.descriptionCtrl,
    required this.fromPriceCtrl,
    required this.toPriceCtrl,
    required this.radiusCtrl,
    required this.venueCtrl,
    required this.countyCtrl,
    required this.imageFile,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        const _SectionLabel(label: 'Listing title'),
        const SizedBox(height: 8),
        _FieldBox(
          child: TextFormField(
            controller: titleCtrl,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
            decoration: InputDecoration(
              hintText: 'e.g. Weekly compound pickup, Kiambu Rd',
              hintStyle: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.30)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionLabel(label: 'Description'),
        const SizedBox(height: 8),
        _FieldBox(
          child: TextFormField(
            controller: descriptionCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
            decoration: InputDecoration(
              hintText: 'What makes your service reliable — experience, equipment, coverage.',
              hintStyle: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.30)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(
          label: 'Your rate',
          note: 'What you charge — negotiated per job, this is just a starting figure',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ServiceRateType.values.map((t) {
            final selected = t == rateType;
            return GestureDetector(
              onTap: () => onRateTypeChanged(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.primary.withOpacity(0.20)),
                ),
                child: Text(
                  switch (t) {
                    ServiceRateType.monthly => 'Monthly',
                    ServiceRateType.perVisit => 'Per visit',
                    ServiceRateType.quoteOnly => 'Quote only',
                  },
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.darkGreen.withOpacity(0.75),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (rateType != ServiceRateType.quoteOnly) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FieldBox(
                  child: TextFormField(
                    controller: fromPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
                    decoration: InputDecoration(
                      hintText: 'From (KSh)',
                      hintStyle:
                          TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.30)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FieldBox(
                  child: TextFormField(
                    controller: toPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
                    decoration: InputDecoration(
                      hintText: 'To (optional)',
                      hintStyle:
                          TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.30)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const _SectionLabel(label: "Where you're based"),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FieldBox(
                child: TextFormField(
                  controller: countyCtrl,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
                  decoration: InputDecoration(
                    hintText: 'County / town',
                    hintStyle:
                        TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.30)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: _FieldBox(
                child: TextFormField(
                  controller: radiusCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
                  decoration: InputDecoration(
                    hintText: 'Radius km',
                    hintStyle:
                        TextStyle(fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.30)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FieldBox(
          child: TextFormField(
            controller: venueCtrl,
            style: const TextStyle(fontSize: 13.5, color: AppTheme.darkGreen),
            decoration: InputDecoration(
              hintText: 'Landmark / area detail (optional)',
              hintStyle: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.30)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Photo (optional)'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(14),
              image: imageFile != null
                  ? DecorationImage(image: FileImage(imageFile!), fit: BoxFit.cover)
                  : null,
            ),
            child: imageFile == null
                ? Center(
                    child: Icon(Icons.add_a_photo_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.35), size: 28),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — REVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _StepReview extends StatelessWidget {
  final ServiceCategory category;
  final Set<String> offerings;
  final String title;
  final String description;
  final ServiceRateType rateType;
  final String fromPrice;
  final String toPrice;
  final String venue;
  final String county;
  final File? imageFile;

  const _StepReview({
    required this.category,
    required this.offerings,
    required this.title,
    required this.description,
    required this.rateType,
    required this.fromPrice,
    required this.toPrice,
    required this.venue,
    required this.county,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    final from = double.tryParse(fromPrice.trim());
    final to = double.tryParse(toPrice.trim());
    final pricing = from == null
        ? const ServicePricing()
        : ServicePricing(rateType: rateType, fromKes: from, toKes: to);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        const _SectionLabel(label: 'Review before posting'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(category.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(category.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title.isEmpty ? '(untitled listing)' : title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description,
                    style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.7))),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    offerings.map((o) => _Chip(label: ServiceCategory.offeringLabel(o))).toList(),
              ),
              const Divider(height: 28),
              _ReviewRow(label: 'Rate', value: pricing.display),
              _ReviewRow(
                  label: 'Location',
                  value: [
                    if (county.trim().isNotEmpty) county.trim(),
                    if (venue.trim().isNotEmpty) venue.trim(),
                  ].join(', ').isEmpty
                      ? 'Not set'
                      : [
                          if (county.trim().isNotEmpty) county.trim(),
                          if (venue.trim().isNotEmpty) venue.trim(),
                        ].join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Requesters will message you for a quote — you set the final '
                  'price per job. Canopy takes a small commission from your '
                  'payout, and the requester pays a flat booking fee.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.75), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.55))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED FIELD WIDGETS — same visual language as create_listing_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? note;
  const _SectionLabel({required this.label, this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note!,
              style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
        ],
      ],
    );
  }
}

class _FieldBox extends StatelessWidget {
  final Widget child;
  const _FieldBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.darkGreen)),
    );
  }
}
