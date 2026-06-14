// lib/Organization/Home/Dashboard/edit_org_details_screen.dart
//
// Edit all editable organisation details in one place:
//   • Logo / profile photo      → logoUrl (+ profilePhoto mirror)
//   • Cover image               → coverImageUrl
//   • Name, designation, city
//   • Background / about         → background (+ about mirror)
//   • Phone, website
//   • Founded year, member count
//
// Images are picked locally and only uploaded on Save, so cancelling leaves
// the org untouched. Returns `true` via Navigator.pop when changes are saved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Shared/theme/app_theme.dart';

class EditOrgDetailsScreen extends StatefulWidget {
  final String orgId;
  const EditOrgDetailsScreen({super.key, required this.orgId});

  @override
  State<EditOrgDetailsScreen> createState() => _EditOrgDetailsScreenState();
}

class _EditOrgDetailsScreenState extends State<EditOrgDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _backgroundCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _foundedCtrl = TextEditingController();
  final _membersCtrl = TextEditingController();

  String? _logoUrl;
  String? _coverUrl;
  File? _newLogo;
  File? _newCover;

  // Heritage: country + per-country background image (cultural Country screen).
  String? _country;
  String? _countryBgUrl;
  File? _newCountryBg;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _cityCtrl.dispose();
    _backgroundCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _foundedCtrl.dispose();
    _membersCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .get();
      final d = doc.data() ?? {};
      _nameCtrl.text = (d['org_name'] ?? d['name'] ?? '') as String;
      _designationCtrl.text = (d['orgDesignation'] ?? d['designation'] ?? '') as String;
      _cityCtrl.text = (d['city'] ?? '') as String;
      _backgroundCtrl.text =
          (d['background'] ?? d['about'] ?? d['bio'] ?? '') as String;
      _phoneCtrl.text = (d['phone'] ?? '') as String;
      _websiteCtrl.text = (d['website'] ?? '') as String;
      final founded = d['foundedAt'];
      if (founded is Timestamp) _foundedCtrl.text = '${founded.toDate().year}';
      final members = d['memberCount'];
      if (members is num) _membersCtrl.text = '${members.toInt()}';
      _logoUrl = (d['logoUrl'] ?? d['profilePhoto']) as String?;
      _coverUrl = d['coverImageUrl'] as String?;
      _country = (d['country'] as String?)?.trim();
      if (_country != null && _country!.isEmpty) _country = null;
      _countryBgUrl = (d['country_bg_image_url'] as String?);
    } catch (e) {
      debugPrint('EditOrgDetails load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool isLogo) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;
    setState(() {
      if (isLogo) {
        _newLogo = File(file.path);
      } else {
        _newCover = File(file.path);
      }
    });
  }

  Future<void> _pickCountryBg() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _newCountryBg = File(file.path));
  }

  Future<void> _openCountryPicker() async {
    List<String> names;
    try {
      final raw = await rootBundle.loadString('assets/WorldCountries.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = (decoded['countries'] as List?) ?? const [];
      names = list
          .map((e) => (e as Map<String, dynamic>)['name'] as String?)
          .whereType<String>()
          .toList()
        ..sort();
    } catch (e) {
      debugPrint('Country list load error: $e');
      return;
    }
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _CountryPickerSheet(countries: names),
    );
    if (selected != null && mounted) {
      setState(() => _country = selected);
    }
  }

  /// Maps a country display name to the heritage hierarchy node id used by the
  /// Country screen / registry (e.g. "Kenya" → "country_kenya",
  /// "South Africa" → "country_south_africa").
  String _heritageCountryNodeId(String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'country_$slug';
  }

  Future<String> _upload(File file, String name) async {
    final ref = FirebaseStorage.instance.ref().child(
        'organizations/${widget.orgId}/${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? logoUrl = _logoUrl;
      String? coverUrl = _coverUrl;
      String? countryBgUrl = _countryBgUrl;
      if (_newLogo != null) logoUrl = await _upload(_newLogo!, 'logo');
      if (_newCover != null) coverUrl = await _upload(_newCover!, 'cover');
      if (_newCountryBg != null) {
        countryBgUrl = await _upload(_newCountryBg!, 'country_bg');
      }

      final foundedYear = int.tryParse(_foundedCtrl.text.trim());
      final members = int.tryParse(_membersCtrl.text.trim());
      final background = _backgroundCtrl.text.trim();

      final update = <String, dynamic>{
        'org_name': _nameCtrl.text.trim(),
        'orgDesignation': _designationCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        // Write both keys so the public view (background) and model (about) agree.
        'background': background,
        'about': background,
        'phone': _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        if (logoUrl != null) 'logoUrl': logoUrl,
        // Mirror to profilePhoto for older readers.
        if (logoUrl != null) 'profilePhoto': logoUrl,
        if (coverUrl != null) 'coverImageUrl': coverUrl,
        if (foundedYear != null)
          'foundedAt': Timestamp.fromDate(DateTime(foundedYear)),
        if (members != null) 'memberCount': members,
        // Heritage fields.
        if (_country != null && _country!.isNotEmpty) 'country': _country,
        if (countryBgUrl != null) 'country_bg_image_url': countryBgUrl,
      };

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .update(update);

      // The public Country screen reads its backdrop from
      // heritage_hierarchy/{country_node}.bg_image_url — mirror the uploaded
      // country background there so it actually appears.
      if (_country != null &&
          _country!.isNotEmpty &&
          countryBgUrl != null &&
          countryBgUrl.isNotEmpty) {
        final nodeId = _heritageCountryNodeId(_country!);
        await FirebaseFirestore.instance
            .collection('heritage_hierarchy')
            .doc(nodeId)
            .set({'bg_image_url': countryBgUrl}, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organisation details updated'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('EditOrgDetails save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Edit Organisation',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  _buildImagesHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Identity'),
                        _field(
                          controller: _nameCtrl,
                          label: 'Organisation name',
                          icon: Icons.business_outlined,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        _field(
                          controller: _designationCtrl,
                          label: 'Designation (e.g. NGO, CBO)',
                          icon: Icons.workspace_premium_outlined,
                        ),
                        _field(
                          controller: _cityCtrl,
                          label: 'City / County',
                          icon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 8),
                        _sectionLabel('About'),
                        _field(
                          controller: _backgroundCtrl,
                          label: 'Background',
                          icon: Icons.notes_outlined,
                          maxLines: 6,
                          hint: 'Tell people what your organisation does…',
                        ),
                        const SizedBox(height: 8),
                        _sectionLabel('Contact'),
                        _field(
                          controller: _phoneCtrl,
                          label: 'Phone',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        _field(
                          controller: _websiteCtrl,
                          label: 'Website',
                          icon: Icons.language_outlined,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 8),
                        _sectionLabel('Details'),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _foundedCtrl,
                                label: 'Founded year',
                                icon: Icons.event_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                controller: _membersCtrl,
                                label: 'Members',
                                icon: Icons.people_outline,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _sectionLabel('Heritage'),
                        _countryPickerField(),
                        const SizedBox(height: 12),
                        _countryBgUploader(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomSheet: _loading
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              color: Colors.white,
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
    );
  }

  // ── Cover + logo editor ────────────────────────────────────────────────────
  Widget _buildImagesHeader() {
    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover
          GestureDetector(
            onTap: () => _pick(false),
            child: Container(
              height: 170,
              width: double.infinity,
              color: AppTheme.lightGreen.withOpacity(0.18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_newCover != null)
                    Image.file(_newCover!, fit: BoxFit.cover)
                  else if (_coverUrl != null && _coverUrl!.isNotEmpty)
                    Image.network(_coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _coverPlaceholder())
                  else
                    _coverPlaceholder(),
                  Container(color: Colors.black.withOpacity(0.18)),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _editChip(Icons.add_photo_alternate_outlined,
                        'Change cover'),
                  ),
                ],
              ),
            ),
          ),
          // Logo
          Positioned(
            left: 20,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _pick(true),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _newLogo != null
                        ? Image.file(_newLogo!, fit: BoxFit.cover)
                        : (_logoUrl != null && _logoUrl!.isNotEmpty)
                            ? Image.network(_logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _logoPlaceholder())
                            : _logoPlaceholder(),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        color: AppTheme.lightGreen.withOpacity(0.18),
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined,
            size: 40, color: AppTheme.darkGreen.withOpacity(0.3)),
      );

  Widget _logoPlaceholder() => Container(
        color: AppTheme.primary.withOpacity(0.12),
        alignment: Alignment.center,
        child: const Icon(Icons.add_a_photo_outlined,
            size: 26, color: AppTheme.primary),
      );

  Widget _editChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppTheme.darkGreen.withOpacity(0.5),
        ),
      ),
    );
  }

  // Tappable field that opens the country picker.
  Widget _countryPickerField() {
    final hasCountry = _country != null && _country!.isNotEmpty;
    return InkWell(
      onTap: _openCountryPicker,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Country',
          labelStyle: TextStyle(
              fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6)),
          filled: true,
          fillColor: Colors.white,
          prefixIcon:
              const Icon(Icons.public_outlined, size: 19, color: AppTheme.primary),
          suffixIcon:
              Icon(Icons.expand_more, size: 20, color: AppTheme.darkGreen.withOpacity(0.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Text(
          hasCountry ? _country! : 'Select country',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: hasCountry
                ? AppTheme.darkGreen
                : AppTheme.darkGreen.withOpacity(0.45),
          ),
        ),
      ),
    );
  }

  // Country background uploader. Emphasised when the background is missing
  // (the cultural Country screen needs it); compact "replace" affordance when
  // one is already set.
  Widget _countryBgUploader() {
    final hasBg = _newCountryBg != null ||
        (_countryBgUrl != null && _countryBgUrl!.isNotEmpty);
    return GestureDetector(
      onTap: _pickCountryBg,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppTheme.lightGreen.withOpacity(0.12),
          border: Border.all(
            color: hasBg ? Colors.grey.shade200 : AppTheme.tertiary.withOpacity(0.6),
            width: hasBg ? 1 : 1.4,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_newCountryBg != null)
              Image.file(_newCountryBg!, fit: BoxFit.cover)
            else if (_countryBgUrl != null && _countryBgUrl!.isNotEmpty)
              Image.network(_countryBgUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _countryBgPrompt(false))
            else
              _countryBgPrompt(true),
            if (hasBg)
              Positioned(
                right: 12,
                top: 12,
                child: _editChip(
                    Icons.add_photo_alternate_outlined, 'Replace background'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _countryBgPrompt(bool missing) {
    return Container(
      color: AppTheme.lightGreen.withOpacity(0.12),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wallpaper_outlined,
              size: 32, color: AppTheme.primary.withOpacity(0.7)),
          const SizedBox(height: 8),
          Text(
            missing ? 'Add a country background' : 'Country background',
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkGreen),
          ),
          const SizedBox(height: 4),
          Text(
            'Used as the backdrop on the cultural Country screen.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.darkGreen.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
            fontSize: 14, color: AppTheme.darkGreen, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
              fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6)),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, size: 19, color: AppTheme.primary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY PICKER SHEET — searchable list backed by assets/WorldCountries.json
// ─────────────────────────────────────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  final List<String> countries;
  const _CountryPickerSheet({required this.countries});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late List<String> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.countries
          : widget.countries
              .where((c) => c.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('No matches',
                          style: TextStyle(color: Colors.grey.shade500)),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final name = _filtered[i];
                        return ListTile(
                          title: Text(name,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGreen)),
                          onTap: () => Navigator.of(context).pop(name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
