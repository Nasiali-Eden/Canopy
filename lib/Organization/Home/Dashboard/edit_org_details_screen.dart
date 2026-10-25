// lib/Organization/Home/Dashboard/edit_org_details_screen.dart
//
// Edit org details (ORG_HANDOFF §3.3, T): cover + logo, name, designation,
// city, country, about, phone, website, founded year, member count, and a
// link to Heritage backgrounds. Images upload only on Save, so cancelling
// leaves the org untouched. Pops `true` when saved.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Community/Heritage/heritage_ui.dart';
import '../../../Culture/Heritage/Create/heritage_backgrounds_screen.dart';
import '../../../theme/tokens/heritage_tokens.dart' show HeritageGlass;
import '../../../theme/canopy_components.dart';

class EditOrgDetailsScreen extends StatefulWidget {
  final String orgId;
  const EditOrgDetailsScreen({super.key, required this.orgId});

  @override
  State<EditOrgDetailsScreen> createState() => _EditOrgDetailsScreenState();
}

class _EditOrgDetailsScreenState extends State<EditOrgDetailsScreen> {
  final _name = TextEditingController();
  final _designation = TextEditingController();
  final _city = TextEditingController();
  final _about = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _founded = TextEditingController();
  final _members = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String? _logoUrl, _coverUrl, _country;
  File? _newLogo, _newCover;
  bool _loading = true, _loadFailed = false, _saving = false, _showErrors = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _designation, _city, _about, _phone, _website, _founded, _members, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final d = (await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).get())
              .data() ??
          {};
      _name.text = (d['org_name'] ?? d['name'] ?? '') as String;
      _designation.text = (d['orgDesignation'] ?? d['designation'] ?? '') as String;
      _city.text = (d['city'] ?? '') as String;
      _about.text = (d['background'] ?? d['about'] ?? d['bio'] ?? '') as String;
      _phone.text = (d['phone'] ?? '') as String;
      _website.text = (d['website'] ?? '') as String;
      if (d['foundedAt'] is Timestamp) _founded.text = '${(d['foundedAt'] as Timestamp).toDate().year}';
      if (d['memberCount'] is num) _members.text = '${(d['memberCount'] as num).toInt()}';
      final gp = d['location'];
      final lat = gp is GeoPoint ? gp.latitude : (d['lat'] as num?)?.toDouble();
      final lng = gp is GeoPoint ? gp.longitude : (d['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _lat.text = lat.toStringAsFixed(6);
        _lng.text = lng.toStringAsFixed(6);
      }
      _logoUrl = (d['logoUrl'] ?? d['profilePhoto']) as String?;
      _coverUrl = d['coverImageUrl'] as String?;
      final c = (d['country'] as String?)?.trim();
      _country = (c == null || c.isEmpty) ? null : c;
    } catch (_) {
      _loadFailed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool logo) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (f == null || !mounted) return;
    setState(() => logo ? _newLogo = File(f.path) : _newCover = File(f.path));
  }

  Future<void> _pickCountry() async {
    List<String> names;
    try {
      final raw = await rootBundle.loadString('assets/WorldCountries.json');
      names = ((jsonDecode(raw) as Map<String, dynamic>)['countries'] as List? ?? const [])
          .map((e) => (e as Map<String, dynamic>)['name'] as String?)
          .whereType<String>()
          .toList()
        ..sort();
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't load the country list.", error: true);
      return;
    }
    if (!mounted) return;
    final picked = await showCanopySheet<String>(context, tall: true, builder: (_) => _CountrySheet(names));
    if (picked != null) setState(() => _country = picked);
  }

  bool _locating = false;

  /// Fills the coordinate fields from the phone's GPS. Nothing is saved until
  /// "Save details".
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showCanopySnack(context, 'Allow location access to use your position.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      if (!mounted) return;
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't get your position. Try again outside.", error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Fills the coordinate fields from the city (Kenyan cities only).
  Future<void> _fromCity() async {
    try {
      final data = jsonDecode(await rootBundle.loadString('assets/Cities/African/KenyaCities.json')) as Map<String, dynamic>;
      final all = data['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      final key = all.keys.firstWhere((k) => k.toLowerCase() == _city.text.trim().toLowerCase(), orElse: () => '');
      final entries = key.isEmpty ? null : (all[key] as List).cast<Map<String, dynamic>>();
      final c = (entries == null || entries.isEmpty) ? null : entries.first['coordinates'] as Map<String, dynamic>?;
      final lat = (c?['lat'] as num?)?.toDouble();
      final lng = (c?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        if (mounted) showCanopySnack(context, 'No coordinates on file for that city. Enter them or use your location.', error: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _lat.text = lat.toStringAsFixed(6);
        _lng.text = lng.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't look that up.", error: true);
    }
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Both or neither; within range.
  String? get _locationError {
    final a = _lat.text.trim(), b = _lng.text.trim();
    if (a.isEmpty && b.isEmpty) return null;
    final lat = _num(_lat), lng = _num(_lng);
    if (lat == null || lng == null) return 'Enter both latitude and longitude as numbers.';
    if (lat < -90 || lat > 90) return 'Latitude is between -90 and 90.';
    if (lng < -180 || lng > 180) return 'Longitude is between -180 and 180.';
    return null;
  }

  Future<String> _upload(File f, String name) async {
    final ref = FirebaseStorage.instance
        .ref('organizations/${widget.orgId}/${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(f);
    return ref.getDownloadURL();
  }

  String? get _nameError => _name.text.trim().isEmpty ? 'Your organisation needs a name.' : null;
  String? get _foundedError {
    final t = _founded.text.trim();
    if (t.isEmpty) return null;
    final y = int.tryParse(t);
    return y == null || y < 1800 || y > DateTime.now().year ? 'Enter a year like 2018.' : null;
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (_nameError != null || _foundedError != null || _locationError != null) return;
    setState(() => _saving = true);
    try {
      final logo = _newLogo != null ? await _upload(_newLogo!, 'logo') : _logoUrl;
      final cover = _newCover != null ? await _upload(_newCover!, 'cover') : _coverUrl;
      final founded = int.tryParse(_founded.text.trim());
      final members = int.tryParse(_members.text.trim());
      final lat = _num(_lat), lng = _num(_lng);
      await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).update({
        'org_name': _name.text.trim(),
        'orgDesignation': _designation.text.trim(),
        'city': _city.text.trim(),
        // Both keys so the public view (background) and model (about) agree.
        'background': _about.text.trim(),
        'about': _about.text.trim(),
        'phone': _phone.text.trim(),
        'website': _website.text.trim(),
        if (logo != null) 'logoUrl': logo,
        if (logo != null) 'profilePhoto': logo,
        if (cover != null) 'coverImageUrl': cover,
        if (founded != null) 'foundedAt': Timestamp.fromDate(DateTime(founded)),
        if (members != null) 'memberCount': members,
        if (_country != null) 'country': _country,
        if (lat != null && lng != null) ...{'location': GeoPoint(lat, lng), 'lat': lat, 'lng': lng},
      });
      if (!mounted) return;
      showCanopySnack(context, 'Organisation details saved.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Same glass design as the Heritage pages: the org's cover (or the Heritage
  // photo) fills the screen under the page scrim; the form floats in glass.
  @override
  Widget build(BuildContext context) => HeritageTheme(child: Builder(builder: _buildForm));

  Widget _buildForm(BuildContext context) {
    final p = context.canopy;
    if (_loading) {
      return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Organisation details'),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadFailed) {
      return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Organisation details'),
          body: CanopyErrorState(title: "Couldn't load your details", onRetry: _load));
    }
    Widget gap() => const SizedBox(height: CanopySpace.s16);
    final g = HeritageGlass.of(Theme.of(context).brightness);
    final fallbackPhoto = Image.asset('images/BG.png', fit: BoxFit.cover);
    final Widget photo = _newCover != null
        ? Image.file(_newCover!, fit: BoxFit.cover)
        : (_coverUrl ?? '').isNotEmpty
            ? Image.network(_coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallbackPhoto)
            : fallbackPhoto;
    return Stack(children: [
      Positioned.fill(child: photo),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: g.pageScrim))),
      Scaffold(
      backgroundColor: Colors.transparent,
      appBar: canopyAppBar(context, title: 'Organisation details'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
        children: [
          // Cover + logo
          SizedBox(
            height: 150 + 36,
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
                        if (_newCover != null)
                          Image.file(_newCover!, fit: BoxFit.cover)
                        else if (_coverUrl != null)
                          CanopyImage(url: _coverUrl)
                        else
                          Center(
                            child: Text('Add a cover photo',
                                style: CanopyType.label.copyWith(color: p.inkMuted)),
                          ),
                        Positioned(
                          right: CanopySpace.s8,
                          bottom: CanopySpace.s8,
                          child: Icon(Icons.edit_outlined, color: p.ink),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: CanopySpace.s16,
                top: 150 - 36,
                child: GestureDetector(
                  onTap: () => _pick(true),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: p.canvas, borderRadius: BorderRadius.circular(24)),
                    child: _newLogo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.file(_newLogo!, width: 72, height: 72, fit: BoxFit.cover))
                        : CanopyAvatar(url: _logoUrl, name: _name.text, size: 72, org: true),
                  ),
                ),
              ),
            ]),
          ),
          Text('Tap the cover or logo to change them.',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
          gap(),
          ReadingGlass(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CanopyTextField(
              label: 'Name',
              controller: _name,
              error: _showErrors ? _nameError : null,
              onChanged: (_) => setState(() {})),
          gap(),
          CanopyTextField(label: 'Designation', hint: 'CBO, NGO, company…', controller: _designation),
          gap(),
          CanopyTextField(label: 'City or town', controller: _city),
          gap(),
          CanopyPickerField(label: 'Country', value: _country, placeholder: 'Choose country', onTap: _pickCountry),
          gap(),
          CanopyTextField(
              label: 'About',
              hint: 'What you do and who you work with',
              controller: _about,
              minLines: 4,
              maxLines: 10,
              maxLength: 1200),
          gap(),
          CanopyTextField.phone(label: 'Phone', controller: _phone),
          gap(),
          CanopyTextField(
              label: 'Website',
              hint: 'example.org',
              controller: _website,
              keyboardType: TextInputType.url,
              textCapitalization: TextCapitalization.none),
          gap(),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: CanopyTextField(
                  label: 'Founded',
                  hint: '2018',
                  controller: _founded,
                  keyboardType: TextInputType.number,
                  error: _showErrors ? _foundedError : null,
                  onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: CanopyTextField(
                  label: 'Members', hint: '40', controller: _members, keyboardType: TextInputType.number),
            ),
          ]),
          const SizedBox(height: CanopySpace.section),
          Text('Map location', style: CanopyType.title.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s4),
          Text(
              _lat.text.trim().isEmpty && _lng.text.trim().isEmpty
                  ? 'Not set — your organisation will not appear on the map.'
                  : 'Shown on the map as your organisation pin.',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
          gap(),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: CanopyTextField(
                  label: 'Latitude',
                  hint: '-1.286389',
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: CanopyTextField(
                  label: 'Longitude',
                  hint: '36.817223',
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  error: _showErrors ? _locationError : null,
                  onChanged: (_) => setState(() {})),
            ),
          ]),
          const SizedBox(height: CanopySpace.s8),
          Row(children: [
            Expanded(
              child: CanopyButton(
                  label: 'Use my location',
                  variant: CanopyButtonVariant.secondary,
                  size: CanopyButtonSize.compact,
                  loading: _locating,
                  expand: true,
                  onPressed: _locating ? null : _useMyLocation),
            ),
            const SizedBox(width: CanopySpace.s8),
            Expanded(
              child: CanopyButton(
                  label: 'From my city',
                  variant: CanopyButtonVariant.secondary,
                  size: CanopyButtonSize.compact,
                  expand: true,
                  onPressed: _fromCity),
            ),
          ]),
          const SizedBox(height: CanopySpace.section),
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.landscape_outlined,
              title: 'Heritage backgrounds',
              subtitle: 'Country, category and community images on Heritage',
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => HeritageBackgroundsScreen(orgId: widget.orgId))),
            ),
          ]),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(children: [
        CanopyButton(label: 'Save details', expand: true, loading: _saving, onPressed: _save),
      ]),
    ),
    ]);
  }
}

class _CountrySheet extends StatefulWidget {
  final List<String> names;
  const _CountrySheet(this.names);

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.names.where((n) => n.toLowerCase().contains(_q)).take(60).toList();
    return CanopySheetBody(
      title: 'Country',
      children: [
        CanopyTextField.search(
            hint: 'Search countries', autofocus: true, onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
        const SizedBox(height: CanopySpace.s12),
        CanopyListGroup(children: [
          for (final n in list) CanopyListRow(title: n, chevron: false, onTap: () => Navigator.pop(context, n)),
        ]),
      ],
    );
  }
}
