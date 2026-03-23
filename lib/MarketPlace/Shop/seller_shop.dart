import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum ListingSide {
  regenerative,
  creative;

  String get label => this == regenerative ? 'Regenerative' : 'Creative';
}

enum PricingUnit {
  perKg('per kg'),
  perUnit('per unit'),
  perTonne('per tonne'),
  perBale('per bale'),
  perLitre('per litre'),
  fixed('fixed price');

  final String label;
  const PricingUnit(this.label);
}

enum MaterialCondition {
  raw('Raw', 'Unprocessed'),
  sorted('Sorted', 'Cleaned & separated'),
  processed('Processed', 'Pellets / sheets');

  final String label;
  final String sublabel;
  const MaterialCondition(this.label, this.sublabel);
}

class _Category {
  final String label;
  final IconData icon;
  final int impactScore;
  final String impactLabel;

  const _Category({
    required this.label,
    required this.icon,
    required this.impactScore,
    required this.impactLabel,
  });
}

const _regenerativeCategories = <_Category>[
  _Category(label: 'Plastics', icon: Icons.recycling, impactScore: 90, impactLabel: 'Plastics — High Impact'),
  _Category(label: 'Metals', icon: Icons.hardware_outlined, impactScore: 70, impactLabel: 'Metals — Medium Impact'),
  _Category(label: 'Glass', icon: Icons.wine_bar_outlined, impactScore: 50, impactLabel: 'Glass — Medium Impact'),
  _Category(label: 'Paper & Cardboard', icon: Icons.inventory_2_outlined, impactScore: 60, impactLabel: 'Paper — Medium Impact'),
  _Category(label: 'Rubber & Composites', icon: Icons.settings_outlined, impactScore: 55, impactLabel: 'Rubber — Medium Impact'),
  _Category(label: 'Reclaimed Wood', icon: Icons.forest_outlined, impactScore: 45, impactLabel: 'Wood — Lower Impact'),
  _Category(label: 'Textiles', icon: Icons.dry_cleaning_outlined, impactScore: 65, impactLabel: 'Textiles — Medium-High'),
  _Category(label: 'Electronics & Parts', icon: Icons.memory_outlined, impactScore: 75, impactLabel: 'Electronics — High Impact'),
];

const _creativeCategories = <_Category>[
  _Category(label: 'Sculpture & 3D Art', icon: Icons.architecture_outlined, impactScore: 80, impactLabel: 'Sculpture — High Craft'),
  _Category(label: 'Furniture & Objects', icon: Icons.chair_outlined, impactScore: 75, impactLabel: 'Furniture — High Value'),
  _Category(label: 'Jewellery & Accessories', icon: Icons.diamond_outlined, impactScore: 70, impactLabel: 'Jewellery — Premium'),
  _Category(label: 'Fashion & Textiles', icon: Icons.checkroom_outlined, impactScore: 65, impactLabel: 'Fashion — Upcycled'),
  _Category(label: 'Painting & Mixed Media', icon: Icons.palette_outlined, impactScore: 72, impactLabel: 'Painting — Original'),
  _Category(label: 'Ceramics & Glass Art', icon: Icons.emoji_food_beverage_outlined, impactScore: 68, impactLabel: 'Ceramics — Handmade'),
  _Category(label: 'Home & Lifestyle', icon: Icons.home_outlined, impactScore: 60, impactLabel: 'Home — Functional'),
  _Category(label: 'Print & Paper Art', icon: Icons.print_outlined, impactScore: 55, impactLabel: 'Print — Limited Edition'),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SellerShopPage extends StatefulWidget {
  const SellerShopPage({super.key});

  @override
  State<SellerShopPage> createState() => _SellerShopPageState();
}

class _SellerShopPageState extends State<SellerShopPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── State ────────────────────────────────────────────────────────────────
  ListingSide _side = ListingSide.regenerative;
  int _selectedCategoryIndex = 0;
  MaterialCondition _condition = MaterialCondition.raw;
  PricingUnit _pricingUnit = PricingUnit.perKg;
  bool _circularCraftBadge = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _makerController = TextEditingController();
  final _priceController = TextEditingController();
  final _venueController = TextEditingController();
  final _qtyController = TextEditingController();
  final _storyController = TextEditingController();
  final _dnaController = TextEditingController();

  final List<XFile?> _images = [null, null, null, null];
  final _picker = ImagePicker();
  bool _saving = false;

  // ── Computed ─────────────────────────────────────────────────────────────
  List<_Category> get _categories =>
      _side == ListingSide.regenerative ? _regenerativeCategories : _creativeCategories;

  _Category get _selectedCategory => _categories[_selectedCategoryIndex];

  Color get _sideAccent =>
      _side == ListingSide.regenerative ? AppTheme.primary : AppTheme.tertiary;

  Color get _sideAccentLight =>
      _side == ListingSide.regenerative
          ? AppTheme.lightGreen.withOpacity(0.18)
          : AppTheme.tertiary.withOpacity(0.12);

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _makerController.text.trim().isNotEmpty &&
      _priceController.text.trim().isNotEmpty &&
      _images[0] != null;

  int get _progressScore {
    int s = 0;
    if (_titleController.text.trim().isNotEmpty) s++;
    if (_makerController.text.trim().isNotEmpty) s++;
    if (_priceController.text.trim().isNotEmpty) s++;
    if (_images[0] != null) s++;
    return s;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 380), vsync: this)
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    for (final c in [_titleController, _makerController, _priceController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in [
      _titleController, _descController, _makerController,
      _priceController, _venueController, _qtyController,
      _storyController, _dnaController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Image helpers ─────────────────────────────────────────────────────────
  Future<void> _pickImage(int slot) async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (!mounted || file == null) return;
    setState(() => _images[slot] = file);
  }

  void _removeImage(int slot) => setState(() => _images[slot] = null);

  // ── Side switch ───────────────────────────────────────────────────────────
  void _setSide(ListingSide side) {
    if (_side == side) return;
    setState(() {
      _side = side;
      _selectedCategoryIndex = 0;
    });
    _animController
      ..reset()
      ..forward();
  }

  // ── Submit placeholder ────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Listing ready for submission'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: Column(children: [
            _ProgressBar(score: _progressScore),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSideToggle(),
                    const SizedBox(height: 22),
                    _buildCategorySection(),
                    const SizedBox(height: 22),
                    _buildBasicInfo(),
                    const SizedBox(height: 22),
                    if (_side == ListingSide.regenerative) ...[
                      _buildMaterialSpec(),
                      const SizedBox(height: 22),
                      _buildStoryField(),
                      const SizedBox(height: 22),
                    ] else ...[
                      _buildCreatorDetails(),
                      const SizedBox(height: 22),
                    ],
                    _buildPhotos(),
                    const SizedBox(height: 22),
                    _buildImpactScore(),
                    const SizedBox(height: 22),
                    _buildPriceSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close, size: 18, color: AppTheme.darkGreen),
          ),
        ),
      ),
      centerTitle: true,
      title: const Text(
        'Create Listing',
        style: TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
          ),
          child: const Text(
            'MARKETPLACE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppTheme.accent,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIDE TOGGLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSideToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.storefront_outlined,
          label: 'Listing Side',
          color: AppTheme.primary,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _SideCard(
              selected: _side == ListingSide.regenerative,
              icon: Icons.recycling_rounded,
              name: 'Regenerative',
              desc: 'Raw or processed materials for processors & manufacturers',
              accentColor: AppTheme.primary,
              lightColor: AppTheme.lightGreen.withOpacity(0.18),
              onTap: () => _setSide(ListingSide.regenerative),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SideCard(
              selected: _side == ListingSide.creative,
              icon: Icons.palette_outlined,
              name: 'Creative',
              desc: 'Original works made from recycled or recovered materials',
              accentColor: AppTheme.tertiary,
              lightColor: AppTheme.tertiary.withOpacity(0.1),
              onTap: () => _setSide(ListingSide.creative),
            ),
          ),
        ]),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CATEGORY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.grid_view_rounded,
          label: 'Category',
          color: _sideAccent,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_categories.length, (i) {
            final cat = _categories[i];
            final selected = _selectedCategoryIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategoryIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? _sideAccent : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? _sideAccent
                        : AppTheme.lightGreen.withOpacity(0.3),
                    width: selected ? 0 : 1.2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _sideAccent.withOpacity(0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 13,
                      color: selected ? Colors.white : _sideAccent.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : AppTheme.darkGreen.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BASIC INFO
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBasicInfo() {
    final makerLabel = _side == ListingSide.creative ? 'Creator Name' : 'Seller / Collector Name';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.edit_outlined,
          label: 'Listing Details',
          color: AppTheme.primary,
        ),
        const SizedBox(height: 10),
        _StyledField(
          controller: _titleController,
          label: 'Listing Title',
          hint: _side == ListingSide.regenerative
              ? 'e.g. Sorted PET Bottle Bale — 50kg'
              : 'e.g. Reclaimed Copper Wire Pendant',
          icon: Icons.title_rounded,
          accentColor: AppTheme.primary,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: 12),
        _StyledTextArea(
          controller: _descController,
          label: 'Description',
          hint: _side == ListingSide.regenerative
              ? 'Describe the material, grade, condition, and any processing done…'
              : 'Describe your piece — techniques, dimensions, and what makes it unique…',
          accentColor: AppTheme.primary,
        ),
        const SizedBox(height: 12),
        _StyledField(
          controller: _makerController,
          label: makerLabel,
          hint: 'Your name or business name',
          icon: Icons.person_outline_rounded,
          accentColor: AppTheme.accent,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? '$makerLabel is required' : null,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MATERIAL SPEC (Regenerative only)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMaterialSpec() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.science_outlined,
          label: 'Material Specification',
          color: AppTheme.secondary,
        ),
        const SizedBox(height: 10),
        // Qty + unit row
        Row(children: [
          Expanded(
            child: _StyledField(
              controller: _qtyController,
              label: 'Quantity',
              hint: '50',
              icon: Icons.inventory_2_outlined,
              accentColor: AppTheme.secondary,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StyledDropdown<String>(
              value: _pricingUnit == PricingUnit.perKg
                  ? 'kg'
                  : _pricingUnit == PricingUnit.perTonne
                      ? 'tonnes'
                      : _pricingUnit == PricingUnit.perBale
                          ? 'bales'
                          : _pricingUnit == PricingUnit.perLitre
                              ? 'litres'
                              : 'units',
              items: const ['kg', 'tonnes', 'bales', 'litres', 'units'],
              label: 'Unit',
              icon: Icons.scale_outlined,
              accentColor: AppTheme.secondary,
              onChanged: (_) {},
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Condition chips
        Text(
          'Condition / Grade',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGreen.withOpacity(0.55),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: MaterialCondition.values.map((c) {
            final selected = _condition == c;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _condition = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                    right: c != MaterialCondition.processed ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.secondary.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppTheme.secondary
                          : AppTheme.lightGreen.withOpacity(0.3),
                      width: selected ? 1.8 : 1.2,
                    ),
                  ),
                  child: Column(children: [
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppTheme.secondary : AppTheme.darkGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.sublabel,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.darkGreen.withOpacity(0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _StyledField(
          controller: _venueController,
          label: 'Pickup Location',
          hint: 'e.g. Kibera, Nairobi',
          icon: Icons.place_outlined,
          accentColor: AppTheme.accent,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STORY FIELD (Regenerative only)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.auto_stories_outlined,
          label: 'Story',
          color: AppTheme.accent,
        ),
        const SizedBox(height: 10),
        _StoryCard(
          controller: _storyController,
          headerLabel: 'Where was this collected?',
          hint:
              'Tell buyers where and how you collected this material. Your story builds trust and often earns better prices…',
          accentColor: AppTheme.accent,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATOR DETAILS (Creative only)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCreatorDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.auto_awesome_outlined,
          label: 'Creator Details',
          color: AppTheme.tertiary,
        ),
        const SizedBox(height: 10),
        // Circular Craft Badge toggle
        GestureDetector(
          onTap: () => setState(() => _circularCraftBadge = !_circularCraftBadge),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _circularCraftBadge
                  ? AppTheme.tertiary.withOpacity(0.07)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _circularCraftBadge
                    ? AppTheme.tertiary
                    : AppTheme.lightGreen.withOpacity(0.3),
                width: _circularCraftBadge ? 1.8 : 1.2,
              ),
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_outlined,
                      size: 20, color: AppTheme.tertiary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apply for Circular Craft Badge',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Materials sourced from Canopy supply chain',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkGreen.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              _ToggleSwitch(active: _circularCraftBadge, activeColor: AppTheme.tertiary),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // Material DNA
        _SectionLabel(
          icon: Icons.link_rounded,
          label: 'Material DNA',
          color: AppTheme.accent,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Provenance Chain',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
                const Spacer(),
                Text(
                  'Optional — strengthens listing',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.darkGreen.withOpacity(0.4),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Link to the supply-side source this piece was made from — showing buyers the complete chain from collection to creation.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.55),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _dnaController,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search collector or supply listing ID…',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.35),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.08),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(9)),
                      border: Border(
                        left: BorderSide(
                            color: AppTheme.accent.withOpacity(0.15)),
                      ),
                    ),
                    child: const Text(
                      'Browse',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Process journal
        _SectionLabel(
          icon: Icons.auto_stories_outlined,
          label: 'Process Journal',
          color: AppTheme.accent,
        ),
        const SizedBox(height: 10),
        _StoryCard(
          controller: _storyController,
          headerLabel: 'How did you make this?',
          hint:
              'Describe your process, the materials you gathered, the techniques used, and what inspired this piece…',
          accentColor: AppTheme.accent,
        ),
        const SizedBox(height: 14),
        _StyledField(
          controller: _venueController,
          label: 'Location / Studio',
          hint: 'e.g. Kibera, Nairobi',
          icon: Icons.place_outlined,
          accentColor: AppTheme.accent,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHOTOS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPhotos() {
    final filledCount = _images.where((i) => i != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.photo_library_outlined,
          label: 'Photos ($filledCount/4)',
          color: AppTheme.darkGreen,
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: List.generate(4, (i) => _ImageSlot(
            index: i,
            file: _images[i],
            onPick: () => _pickImage(i),
            onRemove: () => _removeImage(i),
          )),
        ),
        const SizedBox(height: 6),
        Text(
          'First photo is the listing cover. Add background context images.',
          style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.38)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMPACT SCORE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildImpactScore() {
    final score = _selectedCategory.impactScore;
    final pct = score / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.bolt_outlined,
          label: 'Impact Score',
          color: AppTheme.primary,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.lightGreen.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.eco_outlined, size: 18, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environmental impact if unrecycled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedCategory.impactLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRICE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.payments_outlined,
          label: 'Price (KES)',
          color: AppTheme.tertiary,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.tertiary, width: 2),
            color: AppTheme.tertiary.withOpacity(0.03),
          ),
          child: Row(children: [
            // KES label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
                border: Border(
                  right: BorderSide(color: AppTheme.tertiary.withOpacity(0.2)),
                ),
              ),
              child: const Center(
                child: Text(
                  'KES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.tertiary,
                  ),
                ),
              ),
            ),
            // Amount input
            Expanded(
              child: TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.darkGreen.withOpacity(0.25),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Price is required' : null,
              ),
            ),
            // Per unit dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withOpacity(0.06),
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(12)),
                border: Border(
                  left: BorderSide(color: AppTheme.tertiary.withOpacity(0.2)),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PricingUnit>(
                  value: _pricingUnit,
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.tertiary,
                    fontFamily: 'Roboto',
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppTheme.tertiary),
                  items: PricingUnit.values
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.label),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _pricingUnit = val);
                  },
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.info_outline,
              size: 12, color: AppTheme.lightGreen.withOpacity(0.8)),
          const SizedBox(width: 5),
          Text(
            'Payment via M-Pesa · Direct to buyer — no middlemen',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.38),
            ),
          ),
        ]),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.darkGreen,
              side: BorderSide(color: AppTheme.lightGreen.withOpacity(0.5)),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _canSubmit
                    ? [AppTheme.darkGreen, AppTheme.primary, AppTheme.secondary]
                    : [Colors.grey.shade400, Colors.grey.shade400],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _canSubmit
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      )
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: (_saving || !_canSubmit) ? null : _submit,
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.publish_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Publish Listing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
// PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int score; // 0–4
  const _ProgressBar({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: List.generate(4, (i) {
              final filled = i < score;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                  decoration: BoxDecoration(
                    color: filled
                        ? AppTheme.primary
                        : AppTheme.lightGreen.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SideCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String name;
  final String desc;
  final Color accentColor;
  final Color lightColor;
  final VoidCallback onTap;

  const _SideCard({
    required this.selected,
    required this.icon,
    required this.name,
    required this.desc,
    required this.accentColor,
    required this.lightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : AppTheme.lightGreen.withOpacity(0.28),
            width: selected ? 1.8 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const Spacer(),
              if (selected)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
            ]),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? accentColor : AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.darkGreen.withOpacity(0.5),
                height: 1.4,
              ),
            ),
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

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(height: 1, color: color.withOpacity(0.12)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STYLED FIELD
// ─────────────────────────────────────────────────────────────────────────────

OutlineInputBorder _fieldBorder(Color c, {double width = 1.2}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: width),
    );

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: AppTheme.darkGreen,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: AppTheme.darkGreen.withOpacity(0.3),
        ),
        labelStyle: TextStyle(
          color: accentColor.withOpacity(0.75),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 14, color: accentColor),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 50, minHeight: 50),
        border: _fieldBorder(accentColor.withOpacity(0.2)),
        enabledBorder: _fieldBorder(accentColor.withOpacity(0.22)),
        focusedBorder: _fieldBorder(accentColor, width: 2),
        errorBorder: _fieldBorder(Colors.red.shade300),
        focusedErrorBorder: _fieldBorder(Colors.red.shade400, width: 2),
      ),
      validator: validator,
    );
  }
}

class _StyledTextArea extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final Color accentColor;

  const _StyledTextArea({
    required this.controller,
    required this.label,
    required this.hint,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(color: AppTheme.darkGreen, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: AppTheme.darkGreen.withOpacity(0.3),
        ),
        alignLabelWithHint: true,
        labelStyle: TextStyle(
          color: accentColor.withOpacity(0.75),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 68),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.notes_rounded, size: 14, color: accentColor),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 50, minHeight: 50),
        border: _fieldBorder(accentColor.withOpacity(0.2)),
        enabledBorder: _fieldBorder(accentColor.withOpacity(0.22)),
        focusedBorder: _fieldBorder(accentColor, width: 2),
        errorBorder: _fieldBorder(Colors.red.shade300),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Description is required' : null,
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String label;
  final IconData icon;
  final Color accentColor;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: Colors.white,
      menuMaxHeight: 260,
      style: const TextStyle(
        color: AppTheme.darkGreen,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: accentColor.withOpacity(0.6), size: 20),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: accentColor.withOpacity(0.75),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 14, color: accentColor),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 50, minHeight: 50),
        border: _fieldBorder(accentColor.withOpacity(0.2)),
        enabledBorder: _fieldBorder(accentColor.withOpacity(0.22)),
        focusedBorder: _fieldBorder(accentColor, width: 2),
        errorBorder: _fieldBorder(Colors.red.shade300),
      ),
      items: items
          .map((i) =>
              DropdownMenuItem<T>(value: i, child: Text(i.toString())))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STORY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final TextEditingController controller;
  final String headerLabel;
  final String hint;
  final Color accentColor;

  const _StoryCard({
    required this.controller,
    required this.headerLabel,
    required this.hint,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.22)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(color: accentColor.withOpacity(0.12)),
              ),
            ),
            child: Row(children: [
              Icon(Icons.auto_stories_outlined, size: 14, color: accentColor),
              const SizedBox(width: 7),
              Text(
                headerLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              Text(
                'Shown on listing',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.darkGreen.withOpacity(0.38),
                ),
              ),
            ]),
          ),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.darkGreen,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppTheme.darkGreen.withOpacity(0.3),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE SLOT
// ─────────────────────────────────────────────────────────────────────────────

class _ImageSlot extends StatelessWidget {
  final int index;
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImageSlot({
    required this.index,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isCover = index == 0;
    return GestureDetector(
      onTap: file == null ? onPick : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: file != null
              ? Colors.transparent
              : AppTheme.lightGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null
                ? AppTheme.primary.withOpacity(0.3)
                : isCover
                    ? AppTheme.primary.withOpacity(0.35)
                    : AppTheme.lightGreen.withOpacity(0.3),
            width: (isCover && file == null) ? 2 : 1.2,
            style: (file == null && !isCover)
                ? BorderStyle.solid
                : BorderStyle.solid,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                      color: isCover
                          ? AppTheme.primary.withOpacity(0.5)
                          : AppTheme.lightGreen.withOpacity(0.6),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isCover ? 'Cover Photo' : 'Photo ${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCover
                            ? AppTheme.primary.withOpacity(0.6)
                            : AppTheme.darkGreen.withOpacity(0.38),
                      ),
                    ),
                    if (isCover) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.primary.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppTheme.lightGreen.withOpacity(0.15),
                      child: const Center(
                        child: Icon(Icons.image_outlined,
                            size: 28, color: AppTheme.primary),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 4)
                            ],
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.red),
                        ),
                      ),
                    ),
                    if (isCover)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cover',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
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
// TOGGLE SWITCH
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleSwitch extends StatelessWidget {
  final bool active;
  final Color activeColor;

  const _ToggleSwitch({required this.active, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        color: active ? activeColor : AppTheme.lightGreen.withOpacity(0.3),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: 3,
            left: active ? 19 : 3,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}