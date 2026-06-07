// lib/EnvironmentalOps/Market/create_listing_screen.dart
//
// Create a market listing or buy order.
// Types: Buy Order (one-time) · Sell Listing · Recurring Buy (standing order)
// Material taxonomy loaded from assets/environmental/material_types.json

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LISTING TYPE
// ─────────────────────────────────────────────────────────────────────────────

enum _ListingType { buyOrder, sellListing, recurringBuy }

extension _ListingTypeX on _ListingType {
  String get label {
    switch (this) {
      case _ListingType.buyOrder:
        return 'Buy Order';
      case _ListingType.sellListing:
        return 'Sell Listing';
      case _ListingType.recurringBuy:
        return 'Recurring Buy';
    }
  }

  String get description {
    switch (this) {
      case _ListingType.buyOrder:
        return 'One-time request to buy a specific quantity';
      case _ListingType.sellListing:
        return 'You have materials to sell — post your offer';
      case _ListingType.recurringBuy:
        return 'Standing order — you always buy this material (like a recycler that collects old phones)';
    }
  }

  IconData get icon {
    switch (this) {
      case _ListingType.buyOrder:
        return Icons.shopping_cart_outlined;
      case _ListingType.sellListing:
        return Icons.sell_outlined;
      case _ListingType.recurringBuy:
        return Icons.autorenew_rounded;
    }
  }

  Color get color {
    switch (this) {
      case _ListingType.buyOrder:
        return const Color(0xFF1565C0);
      case _ListingType.sellListing:
        return const Color(0xFF2E7D32);
      case _ListingType.recurringBuy:
        return const Color(0xFFE65100);
    }
  }

  String get firestoreKey {
    switch (this) {
      case _ListingType.buyOrder:
        return 'buy_order';
      case _ListingType.sellListing:
        return 'sell_listing';
      case _ListingType.recurringBuy:
        return 'recurring_buy';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CreateListingScreen extends StatefulWidget {
  final String? orgId;
  final Map<String, dynamic>? orgData;

  const CreateListingScreen({this.orgId, this.orgData, super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  // ── Material taxonomy ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _selectedSubType;

  // ── Form state ───────────────────────────────────────────────────────────
  _ListingType _listingType = _ListingType.buyOrder;
  String? _selectedGrade;
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _canCollect = true; // org will collect from seller
  bool _canDeliver = false; // seller/org will deliver

  // ── Image ────────────────────────────────────────────────────────────────
  File? _imageFile;

  // ── Submission ───────────────────────────────────────────────────────────
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  // ── Page controller (3 steps) ────────────────────────────────────────────
  final _pageCtrl = PageController();
  int _step = 0; // 0=type+material, 1=details, 2=review

  @override
  void initState() {
    super.initState();
    _loadMaterialTypes();
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    _locationCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaterialTypes() async {
    final raw = await rootBundle
        .loadString('assets/environmental/material_types.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final cats = (json['categories'] as List)
        .cast<Map<String, dynamic>>();
    setState(() => _categories = cats);
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _nextStep() {
    if (_step == 0 && (_selectedCategory == null || _selectedSubType == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a material type first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Image ────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final xFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (xFile != null) setState(() => _imageFile = File(xFile.path));
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final orgId = widget.orgId ??
          (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get())
              .data()?['orgId'] as String? ??
          '';
      final orgName =
          (widget.orgData?['org_name'] ?? widget.orgData?['name'] ?? '') as String;

      String? imageUrl;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref(
            'market_listings/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      final subType = _selectedSubType!;
      final qty = double.tryParse(_quantityCtrl.text.trim());
      final price = double.tryParse(_priceCtrl.text.trim());

      await FirebaseFirestore.instance.collection('market_listings').add({
        'listing_type': _listingType.firestoreKey,
        'is_recurring': _listingType == _ListingType.recurringBuy,
        'category_id': _selectedCategory!['id'],
        'category_label': _selectedCategory!['label'],
        'sub_type_id': subType['id'],
        'sub_type_label': subType['label'],
        'grade': _selectedGrade,
        'quantity_kg': qty,
        'unit': subType['units'] ?? 'kg',
        'price_per_unit': price,
        'currency': 'KSh',
        'notes': _notesCtrl.text.trim(),
        'location_text': _locationCtrl.text.trim(),
        'can_collect': _canCollect,
        'can_deliver': _canDeliver,
        'image_url': imageUrl,
        'org_id': orgId,
        'org_name': orgName,
        'posted_by_uid': uid,
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'responses_count': 0,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _listingType == _ListingType.recurringBuy
                  ? 'Recurring listing posted — collectors can now find you'
                  : 'Listing posted successfully',
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = _listingType.color;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            _step > 0
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded,
            size: 18,
          ),
          color: AppTheme.darkGreen,
          onPressed: _step > 0 ? _prevStep : () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create Listing',
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              'Step ${_step + 1} of 3',
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepProgressBar(step: _step, color: color),
        ),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StepTypeMaterial(
              categories: _categories,
              listingType: _listingType,
              selectedCategory: _selectedCategory,
              selectedSubType: _selectedSubType,
              onListingTypeChanged: (t) => setState(() => _listingType = t),
              onCategorySelected: (c) => setState(() {
                _selectedCategory = c;
                _selectedSubType = null;
                _selectedGrade = null;
              }),
              onSubTypeSelected: (s) => setState(() {
                _selectedSubType = s;
                _selectedGrade = null;
              }),
            ),
            _StepDetails(
              listingType: _listingType,
              subType: _selectedSubType,
              selectedGrade: _selectedGrade,
              onGradeChanged: (g) => setState(() => _selectedGrade = g),
              quantityCtrl: _quantityCtrl,
              priceCtrl: _priceCtrl,
              notesCtrl: _notesCtrl,
              locationCtrl: _locationCtrl,
              canCollect: _canCollect,
              canDeliver: _canDeliver,
              onCollectChanged: (v) => setState(() => _canCollect = v),
              onDeliverChanged: (v) => setState(() => _canDeliver = v),
              imageFile: _imageFile,
              onPickImage: _pickImage,
            ),
            _StepReview(
              listingType: _listingType,
              category: _selectedCategory,
              subType: _selectedSubType,
              grade: _selectedGrade,
              quantity: _quantityCtrl.text,
              price: _priceCtrl.text,
              notes: _notesCtrl.text,
              location: _locationCtrl.text,
              canCollect: _canCollect,
              canDeliver: _canDeliver,
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
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: SizedBox(
          height: 52,
          child: _step < 2
              ? ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _step == 0 ? 'Continue to Details' : 'Review Listing',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _listingType == _ListingType.recurringBuy
                                  ? Icons.autorenew_rounded
                                  : Icons.publish_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _listingType == _ListingType.recurringBuy
                                  ? 'Post Recurring Listing'
                                  : _listingType == _ListingType.sellListing
                                      ? 'Post Sell Listing'
                                      : 'Post Buy Order',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — LISTING TYPE + MATERIAL
// ─────────────────────────────────────────────────────────────────────────────

class _StepTypeMaterial extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final _ListingType listingType;
  final Map<String, dynamic>? selectedCategory;
  final Map<String, dynamic>? selectedSubType;
  final ValueChanged<_ListingType> onListingTypeChanged;
  final ValueChanged<Map<String, dynamic>> onCategorySelected;
  final ValueChanged<Map<String, dynamic>> onSubTypeSelected;

  const _StepTypeMaterial({
    required this.categories,
    required this.listingType,
    required this.selectedCategory,
    required this.selectedSubType,
    required this.onListingTypeChanged,
    required this.onCategorySelected,
    required this.onSubTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        _SectionLabel(label: 'What are you posting?'),
        const SizedBox(height: 10),
        _ListingTypeSelector(
          selected: listingType,
          onChanged: onListingTypeChanged,
        ),
        const SizedBox(height: 24),
        _SectionLabel(label: 'Material Category'),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          _CategoryGrid(
            categories: categories,
            selected: selectedCategory,
            onSelect: onCategorySelected,
          ),
        if (selectedCategory != null) ...[
          const SizedBox(height: 20),
          _SectionLabel(label: '${selectedCategory!['label']} — Sub-type'),
          const SizedBox(height: 10),
          _SubTypeList(
            category: selectedCategory!,
            selected: selectedSubType,
            onSelect: onSubTypeSelected,
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — DETAILS
// ─────────────────────────────────────────────────────────────────────────────

class _StepDetails extends StatelessWidget {
  final _ListingType listingType;
  final Map<String, dynamic>? subType;
  final String? selectedGrade;
  final ValueChanged<String?> onGradeChanged;
  final TextEditingController quantityCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController locationCtrl;
  final bool canCollect;
  final bool canDeliver;
  final ValueChanged<bool> onCollectChanged;
  final ValueChanged<bool> onDeliverChanged;
  final File? imageFile;
  final VoidCallback onPickImage;

  const _StepDetails({
    required this.listingType,
    required this.subType,
    required this.selectedGrade,
    required this.onGradeChanged,
    required this.quantityCtrl,
    required this.priceCtrl,
    required this.notesCtrl,
    required this.locationCtrl,
    required this.canCollect,
    required this.canDeliver,
    required this.onCollectChanged,
    required this.onDeliverChanged,
    required this.imageFile,
    required this.onPickImage,
  });

  List<String> get _grades {
    if (subType == null) return [];
    return (subType!['grades'] as List?)?.cast<String>() ?? [];
  }

  String get _unit => subType?['units'] as String? ?? 'kg';

  Map<String, dynamic>? get _priceHint =>
      subType?['price_hint_ksh'] as Map<String, dynamic>?;

  @override
  Widget build(BuildContext context) {
    final color = listingType.color;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        // Recurring note
        if (listingType == _ListingType.recurringBuy)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.autorenew_rounded, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recurring listing — this will appear as a standing offer. '
                    'Collectors will know you always buy this material.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.75),
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

        // Grade
        if (_grades.isNotEmpty) ...[
          _SectionLabel(label: 'Grade / Condition'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _grades.map((g) {
              final selected = selectedGrade == g;
              return GestureDetector(
                onTap: () => onGradeChanged(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? color
                          : color.withOpacity(0.20),
                    ),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : AppTheme.darkGreen.withOpacity(0.75),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Quantity
        if (listingType != _ListingType.recurringBuy) ...[
          _SectionLabel(
            label: 'Quantity',
            note: 'Unit: $_unit',
          ),
          const SizedBox(height: 8),
          _FieldBox(
            child: TextFormField(
              controller: quantityCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen),
              decoration: InputDecoration(
                hintText:
                    listingType == _ListingType.buyOrder ? '500' : '150',
                hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppTheme.darkGreen.withOpacity(0.30)),
                suffixText: _unit,
                suffixStyle: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.50),
                    fontWeight: FontWeight.w600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(0),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Price
        _SectionLabel(
          label: 'Price per $_unit (KSh)',
          note: _priceHint != null
              ? 'Market range: KSh ${_priceHint!['min']} – ${_priceHint!['max']}'
                  '${_priceHint!['note'] != null ? " (${_priceHint!['note']})" : ""}'
              : null,
        ),
        const SizedBox(height: 8),
        _FieldBox(
          child: TextFormField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen),
            decoration: InputDecoration(
              hintText: '28',
              hintStyle: TextStyle(
                  fontSize: 15,
                  color: AppTheme.darkGreen.withOpacity(0.30)),
              prefixText: 'KSh  ',
              prefixStyle: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(0),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ||
                    double.tryParse(v.trim()) == null
                ? 'Enter a valid price'
                : null,
          ),
        ),
        const SizedBox(height: 16),

        // Collection / delivery
        _SectionLabel(label: 'Logistics'),
        const SizedBox(height: 8),
        Row(
          children: [
            _LogisticsToggle(
              label: 'We collect',
              subLabel: '(we pick up from you)',
              selected: canCollect,
              icon: Icons.local_shipping_outlined,
              onTap: () => onCollectChanged(!canCollect),
              color: color,
            ),
            const SizedBox(width: 10),
            _LogisticsToggle(
              label: 'You deliver',
              subLabel: '(bring to us)',
              selected: canDeliver,
              icon: Icons.directions_walk_outlined,
              onTap: () => onDeliverChanged(!canDeliver),
              color: color,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Location
        _SectionLabel(label: 'Collection / delivery area'),
        const SizedBox(height: 8),
        _FieldBox(
          child: TextFormField(
            controller: locationCtrl,
            style: const TextStyle(fontSize: 14, color: AppTheme.darkGreen),
            decoration: InputDecoration(
              hintText: 'e.g. Kibera, Nairobi',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen.withOpacity(0.35)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(0),
              prefixIcon: Icon(Icons.location_on_outlined,
                  size: 18, color: color),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Notes
        _SectionLabel(label: 'Additional notes (optional)'),
        const SizedBox(height: 8),
        _FieldBox(
          child: TextFormField(
            controller: notesCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: AppTheme.darkGreen),
            decoration: InputDecoration(
              hintText:
                  'e.g. Must be clean and sorted. Contact before bringing.',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen.withOpacity(0.35)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(0),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Image
        _SectionLabel(label: 'Photo (optional)'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.20)),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageFile != null
                ? Image.file(imageFile!,
                    fit: BoxFit.cover, width: double.infinity)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 28, color: color.withOpacity(0.60)),
                      const SizedBox(height: 6),
                      Text('Add photo',
                          style: TextStyle(
                              fontSize: 12,
                              color: color.withOpacity(0.70),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — REVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _StepReview extends StatelessWidget {
  final _ListingType listingType;
  final Map<String, dynamic>? category;
  final Map<String, dynamic>? subType;
  final String? grade;
  final String quantity;
  final String price;
  final String notes;
  final String location;
  final bool canCollect;
  final bool canDeliver;
  final File? imageFile;

  const _StepReview({
    required this.listingType,
    required this.category,
    required this.subType,
    required this.grade,
    required this.quantity,
    required this.price,
    required this.notes,
    required this.location,
    required this.canCollect,
    required this.canDeliver,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    final color = listingType.color;
    final unit = subType?['units'] as String? ?? 'kg';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.85), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(listingType.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    listingType.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (listingType == _ListingType.recurringBuy) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'RECURRING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subType?['label'] as String? ?? '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                category?['label'] as String? ?? '',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Details
        _ReviewCard(
          rows: [
            if (grade != null) _ReviewRow(label: 'Grade', value: grade!),
            if (quantity.isNotEmpty)
              _ReviewRow(label: 'Quantity', value: '$quantity $unit'),
            if (price.isNotEmpty)
              _ReviewRow(label: 'Price', value: 'KSh $price per $unit'),
            _ReviewRow(
              label: 'Logistics',
              value: [
                if (canCollect) 'We collect',
                if (canDeliver) 'Seller delivers',
              ].join(' · '),
            ),
            if (location.isNotEmpty)
              _ReviewRow(label: 'Location', value: location),
            if (notes.isNotEmpty) _ReviewRow(label: 'Notes', value: notes),
          ],
        ),

        if (imageFile != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(imageFile!,
                height: 140, fit: BoxFit.cover, width: double.infinity),
          ),
        ],

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  listingType == _ListingType.recurringBuy
                      ? 'This listing will remain active until you manually close it. Other orgs can contact you when they have this material.'
                      : 'Your listing will be live immediately and visible to other environmental orgs on Canopy.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkGreen.withOpacity(0.70),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _ListingTypeSelector extends StatelessWidget {
  final _ListingType selected;
  final ValueChanged<_ListingType> onChanged;
  const _ListingTypeSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _ListingType.values.map((t) {
        final isSelected = selected == t;
        return GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? t.color : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? t.color : Colors.grey.shade200,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: t.color.withOpacity(0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.20)
                        : t.color.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(t.icon,
                      size: 20,
                      color: isSelected ? Colors.white : t.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.darkGreen,
                        ),
                      ),
                      Text(
                        t.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white.withOpacity(0.75)
                              : AppTheme.darkGreen.withOpacity(0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20)
                else
                  Icon(Icons.radio_button_unchecked,
                      color: Colors.grey.shade300, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _CategoryGrid(
      {required this.categories,
      required this.selected,
      required this.onSelect});

  Color _parseColor(String hex) {
    try {
      return Color(
          int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        final isSelected = selected?['id'] == cat['id'];
        final color = _parseColor(cat['color'] as String? ?? '#1B5E20');
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : color.withOpacity(0.20),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cat['emoji'] as String? ?? '♻️',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  cat['label'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.darkGreen.withOpacity(0.75),
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

class _SubTypeList extends StatelessWidget {
  final Map<String, dynamic> category;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _SubTypeList(
      {required this.category,
      required this.selected,
      required this.onSelect});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subTypes = (category['sub_types'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final color = _parseColor(category['color'] as String? ?? '#1B5E20');

    return Column(
      children: subTypes.map((s) {
        final isSelected = selected?['id'] == s['id'];
        final isRecurring = s['recurring'] as bool? ?? false;
        final hint = s['price_hint_ksh'] as Map<String, dynamic>?;

        return GestureDetector(
          onTap: () => onSelect(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.07) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s['label'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                          if (isRecurring) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE65100).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'High demand',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        s['description'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.55),
                        ),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'KSh ${hint['min']}–${hint['max']} / ${s['units'] ?? 'kg'}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? color : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final List<_ReviewRow> rows;
  const _ReviewCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGreen.withOpacity(0.45),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ReviewRow {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});
}

class _StepProgressBar extends StatelessWidget {
  final int step;
  final Color color;
  const _StepProgressBar({required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (step + 1) / 3,
      backgroundColor: color.withOpacity(0.10),
      valueColor: AlwaysStoppedAnimation(color),
      minHeight: 3,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? note;
  const _SectionLabel({required this.label, this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkGreen,
            letterSpacing: 0.2,
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              note!,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.darkGreen.withOpacity(0.50),
              ),
            ),
          ),
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

class _LogisticsToggle extends StatelessWidget {
  final String label;
  final String subLabel;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _LogisticsToggle(
      {required this.label,
      required this.subLabel,
      required this.selected,
      required this.icon,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.10) : const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? color : AppTheme.darkGreen.withOpacity(0.40)),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppTheme.darkGreen.withOpacity(0.65),
                ),
              ),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.darkGreen.withOpacity(0.40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
