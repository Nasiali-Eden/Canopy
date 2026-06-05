import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Models/programme.dart';
import '../../../Shared/Activities/activity.dart' show ActivityLocation;
import '../../../Shared/theme/app_theme.dart';
import 'programme_logic.dart';

const _kBg = Color(0xFFF7F5F0);

// ─────────────────────────────────────────────────────────────────────────────
// Programme Editor — create / edit a programme
// ─────────────────────────────────────────────────────────────────────────────

class ProgrammeEditor extends StatefulWidget {
  final String orgId;

  /// Null means create mode; non-null means edit mode.
  final Programme? existing;

  const ProgrammeEditor({super.key, required this.orgId, this.existing});

  @override
  State<ProgrammeEditor> createState() => _ProgrammeEditorState();
}

class _ProgrammeEditorState extends State<ProgrammeEditor> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ── Form state ──────────────────────────────────────────────────────────────
  late ProgrammeType _type;
  late ProgrammeStatus _status;
  late EngagementModel _engagement;
  late ProgrammeContactMode _contactMode;
  late RecurrencePattern _recurrence;

  final _titleCtrl   = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _priceCtrl   = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _eligCtrl    = TextEditingController();
  final _linkCtrl    = TextEditingController();
  final _venueCtrl   = TextEditingController();

  bool _isOnline = false;
  bool _certificate = false;
  bool _enquiryEnabled = true;
  int? _capacity;
  DateTime? _startDate;
  DateTime? _endDate;

  // Location picker
  String? _selectedCity;
  String? _selectedArea;
  double _lat = 0, _lng = 0;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  // Images — slot 0 = cover, slots 1-5 = supporting (hard cap)
  final List<XFile?> _imageSlots = List.filled(6, null);
  final List<String?> _existingUrls = List.filled(6, null);

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type        = e?.type              ?? ProgrammeType.workshop;
    _status      = e?.status            ?? ProgrammeStatus.draft;
    _engagement  = e?.details.engagementModel ?? EngagementModel.free;
    _contactMode = e?.contact.mode      ?? ProgrammeContactMode.enquiry;
    _recurrence  = e?.schedule.recurrence ?? RecurrencePattern.oneTime;
    _isOnline    = e?.schedule.isOnline ?? false;
    _certificate = e?.details.certificateOffered ?? false;
    _enquiryEnabled = e?.contact.enquiryEnabled ?? true;
    _startDate   = e?.schedule.startDate;
    _endDate     = e?.schedule.endDate;

    if (e != null) {
      _titleCtrl.text    = e.title;
      _summaryCtrl.text  = e.summary;
      _descCtrl.text     = e.description;
      _durationCtrl.text = e.details.duration;
      _eligCtrl.text     = e.details.eligibility;
      _linkCtrl.text     = e.contact.externalLink ?? '';
      _venueCtrl.text    = e.schedule.location?.venue ?? '';
      if (e.details.price != null) {
        _priceCtrl.text = e.details.price!.toStringAsFixed(0);
      }
      _existingUrls[0] = e.coverImageUrl;
      for (int i = 0; i < e.supportingImageUrls.length && i < 5; i++) {
        _existingUrls[i + 1] = e.supportingImageUrls[i];
      }
    }
    _loadCities();
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _summaryCtrl, _descCtrl, _priceCtrl, _durationCtrl,
      _eligCtrl, _linkCtrl, _venueCtrl
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final json = await rootBundle
          .loadString('assets/Cities/African/KenyaCities.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      final map  = data['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      final parsed = <String, List<Map<String, dynamic>>>{};
      for (final e in map.entries) {
        parsed[e.key] = (e.value as List).cast<Map<String, dynamic>>();
      }
      if (mounted) {
        setState(() {
          _kenyaCities = parsed;
          if (_selectedCity == null) {
            _selectedCity = parsed.keys.contains('Nairobi')
                ? 'Nairobi'
                : (parsed.keys.isNotEmpty ? parsed.keys.first : null);
          }
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _areas =>
      _selectedCity != null ? (_kenyaCities[_selectedCity!] ?? []) : [];

  void _onAreaSelected(String? area) {
    setState(() {
      _selectedArea = area;
      final d = _areas.firstWhere((a) => a['area'] == area, orElse: () => {});
      final coords = d['coordinates'] as Map<String, dynamic>? ?? {};
      _lat = (coords['lat'] as num?)?.toDouble() ?? 0;
      _lng = (coords['lng'] as num?)?.toDouble() ?? 0;
    });
  }

  // ── Image picking ────────────────────────────────────────────────────────────

  Future<void> _pickImage(int slot) async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 82);
    if (!mounted || file == null) return;
    setState(() => _imageSlots[slot] = file);
  }

  void _removeImage(int slot) =>
      setState(() { _imageSlots[slot] = null; _existingUrls[slot] = null; });

  // ── Date pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (mounted && picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_type == ProgrammeType.onlineCourse && _linkCtrl.text.trim().isEmpty) {
      _snack('Online courses require an external link.');
      return;
    }
    if (_engagement == EngagementModel.paid &&
        (double.tryParse(_priceCtrl.text.trim()) == null)) {
      _snack('Enter a valid price for paid programmes.');
      return;
    }
    if (!_isOnline && _selectedCity == null) {
      _snack('Select a city for in-person programmes.');
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final programmeId = widget.existing?.id ??
          FirebaseFirestore.instance.collection('programmes').doc().id;

      // Upload new images
      final storagePath =
          'programmes/${widget.orgId}/$programmeId';
      Future<String?> _upload(int slot, String name) async {
        final file = _imageSlots[slot];
        if (file == null) return _existingUrls[slot];
        final ref = FirebaseStorage.instance
            .ref()
            .child('$storagePath/$name.jpg');
        await ref.putFile(File(file.path));
        return await ref.getDownloadURL();
      }

      final coverUrl     = await _upload(0, 'cover');
      final supporting   = <String>[];
      for (int i = 1; i <= 5; i++) {
        final url = await _upload(i, 'support_$i');
        if (url != null) supporting.add(url);
      }

      // Build location
      ActivityLocation? location;
      if (!_isOnline && _selectedCity != null) {
        location = ActivityLocation(
          city:  _selectedCity!,
          area:  _selectedArea ?? _selectedCity!,
          venue: _venueCtrl.text.trim(),
          lat:   _lat,
          lng:   _lng,
        );
      }

      // Build programme
      final publishedAt = _status != ProgrammeStatus.draft
          ? (widget.existing?.publishedAt ?? DateTime.now())
          : null;

      final programme = Programme(
        id:          programmeId,
        orgId:       widget.orgId,
        type:        _type,
        status:      _status,
        title:       _titleCtrl.text.trim(),
        summary:     _summaryCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        coverImageUrl:       coverUrl,
        supportingImageUrls: supporting,
        schedule: ProgrammeSchedule(
          startDate:  _startDate,
          endDate:    _endDate,
          recurrence: _recurrence,
          isOnline:   _isOnline,
          location:   location,
        ),
        details: ProgrammeDetails(
          engagementModel:    _engagement,
          price: _engagement == EngagementModel.paid
              ? double.tryParse(_priceCtrl.text.trim())
              : null,
          duration:           _durationCtrl.text.trim(),
          certificateOffered: _certificate,
          eligibility:        _eligCtrl.text.trim(),
        ),
        contact: ProgrammeContact(
          mode: _contactMode,
          externalLink: _linkCtrl.text.trim().isEmpty
              ? null
              : _linkCtrl.text.trim(),
          enquiryEnabled: _enquiryEnabled,
        ),
        createdBy:   uid,
        publishedAt: publishedAt,
      );

      if (_isEdit) {
        await ProgrammeLogic.updateProgramme(programme);
      } else {
        await ProgrammeLogic.createProgramme(programme);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.darkGreen,
          behavior: SnackBarBehavior.floating),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: Text(
          _isEdit ? 'Edit Programme' : 'New Programme',
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
        ),
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2)),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
          children: [
            _section('Type'),
            _typeSelector(),
            const SizedBox(height: 24),

            _section('Basic info'),
            _field(_titleCtrl,   'Title',   'e.g. Waste Sorting Masterclass', required: true),
            const SizedBox(height: 12),
            _field(_summaryCtrl, 'Summary (shown on cards)', 'One sentence overview', maxLines: 2),
            const SizedBox(height: 12),
            _field(_descCtrl,    'Full description', 'What participants will learn or do',
                maxLines: 5),
            const SizedBox(height: 24),

            _section('Schedule'),
            _scheduleSection(),
            const SizedBox(height: 24),

            if (!_isOnline) ...[
              _section('Location'),
              _locationSection(),
              const SizedBox(height: 24),
            ],

            _section('Engagement'),
            _engagementSection(),
            const SizedBox(height: 24),

            _section('Contact & reach'),
            _contactSection(),
            const SizedBox(height: 24),

            _section('Status'),
            _statusSelector(),
            const SizedBox(height: 24),

            _section('Images (cover + up to 5 supporting)'),
            _imageGrid(),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text(
                _isEdit ? 'Save changes' : 'Publish programme',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────────────────────

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.darkGreen.withOpacity(0.45)),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.lightGreen.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  // ── Type selector ──────────────────────────────────────────────────────────

  Widget _typeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ProgrammeType.values.map((t) {
        final active = _type == t;
        return GestureDetector(
          onTap: () => setState(() {
            _type = t;
            if (t == ProgrammeType.onlineCourse) _isOnline = true;
            if (t == ProgrammeType.membership || t == ProgrammeType.mentorship) {
              _contactMode = ProgrammeContactMode.enquiry;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppTheme.accent.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? AppTheme.accent : Colors.grey.shade200,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Text(
              t.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppTheme.accent : AppTheme.darkGreen),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Status selector ────────────────────────────────────────────────────────

  Widget _statusSelector() {
    final visible = [
      ProgrammeStatus.draft,
      ProgrammeStatus.upcoming,
      ProgrammeStatus.active,
      ProgrammeStatus.completed,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: visible.map((s) {
        final active = _status == s;
        return GestureDetector(
          onTap: () => setState(() => _status = s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppTheme.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active ? AppTheme.primary : Colors.grey.shade200,
                  width: active ? 1.5 : 1),
            ),
            child: Text(
              s.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppTheme.primary : AppTheme.darkGreen),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Schedule section ───────────────────────────────────────────────────────

  Widget _scheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Online toggle (disabled if type forces online)
        SwitchListTile.adaptive(
          value: _isOnline,
          activeColor: AppTheme.primary,
          onChanged: _type == ProgrammeType.onlineCourse
              ? null
              : (v) => setState(() => _isOnline = v),
          title: const Text('Online / remote',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.darkGreen)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 10),
        // Recurrence
        DropdownButtonFormField<RecurrencePattern>(
          value: _recurrence,
          decoration: _inputDeco('Recurrence'),
          items: RecurrencePattern.values
              .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
              .toList(),
          onChanged: (v) => setState(() => _recurrence = v!),
        ),
        const SizedBox(height: 12),
        // Duration text
        _field(_durationCtrl, 'Duration', 'e.g. 3 hours / 6 weeks'),
        const SizedBox(height: 12),
        // Date row
        Row(
          children: [
            Expanded(
              child: _DateButton(
                label: 'Start date',
                date: _startDate,
                onTap: () => _pickDate(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateButton(
                label: 'End date',
                date: _endDate,
                onTap: () => _pickDate(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Certificate
        SwitchListTile.adaptive(
          value: _certificate,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _certificate = v),
          title: const Text('Certificate offered',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.darkGreen)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  // ── Location section ───────────────────────────────────────────────────────

  Widget _locationSection() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCity,
          decoration: _inputDeco('City'),
          items: _kenyaCities.keys
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() {
            _selectedCity = v;
            _selectedArea = null;
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedArea,
          decoration: _inputDeco('Area / neighbourhood'),
          items: _areas
              .map((a) => DropdownMenuItem(
                  value: a['area'] as String,
                  child: Text(a['area'] as String)))
              .toList(),
          onChanged: _onAreaSelected,
        ),
        const SizedBox(height: 10),
        _field(_venueCtrl, 'Venue', 'e.g. Community Hall, Gate 2'),
      ],
    );
  }

  // ── Engagement section ─────────────────────────────────────────────────────

  Widget _engagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: EngagementModel.values.map((e) {
            final active = _engagement == e;
            return GestureDetector(
              onTap: () => setState(() => _engagement = e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.tertiary.withOpacity(0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active
                          ? AppTheme.tertiary
                          : Colors.grey.shade200,
                      width: active ? 1.5 : 1),
                ),
                child: Text(
                  e.label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppTheme.tertiary
                          : AppTheme.darkGreen),
                ),
              ),
            );
          }).toList(),
        ),
        if (_engagement == EngagementModel.paid) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: _inputDeco('Price (KES)'),
            validator: (v) => _engagement == EngagementModel.paid &&
                    (v == null || double.tryParse(v.trim()) == null)
                ? 'Enter a valid price'
                : null,
          ),
        ],
        if (_engagement == EngagementModel.volunteer) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Volunteer programmes link to People › Volunteers for enrolment.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _field(_eligCtrl, 'Eligibility', 'Who can join? (leave blank if open to all)'),
      ],
    );
  }

  // ── Contact section ────────────────────────────────────────────────────────

  Widget _contactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ProgrammeContactMode>(
          value: _contactMode,
          decoration: _inputDeco('How people reach you'),
          items: ProgrammeContactMode.values
              .map((m) =>
                  DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: (v) => setState(() => _contactMode = v!),
        ),
        if (_contactMode != ProgrammeContactMode.enquiry ||
            _type == ProgrammeType.onlineCourse) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _linkCtrl,
            keyboardType: TextInputType.url,
            decoration: _inputDeco(
              _type == ProgrammeType.onlineCourse
                  ? 'Course link (required for online courses)'
                  : 'External link',
            ),
            validator: (_type == ProgrammeType.onlineCourse ||
                    _contactMode != ProgrammeContactMode.enquiry)
                ? (v) => (v == null || v.trim().isEmpty) ? 'Link is required' : null
                : null,
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _enquiryEnabled,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _enquiryEnabled = v),
          title: const Text('Allow enquiries',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.darkGreen)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  // ── Image grid ─────────────────────────────────────────────────────────────

  Widget _imageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: 6,
          itemBuilder: (ctx, i) {
            final hasNew      = _imageSlots[i] != null;
            final existingUrl = _existingUrls[i];
            final hasImage    = hasNew || existingUrl != null;
            return GestureDetector(
              onTap: () => _pickImage(i),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: hasImage
                          ? AppTheme.primary.withOpacity(0.3)
                          : Colors.grey.shade200),
                ),
                child: hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: hasNew
                                ? Image.file(
                                    File(_imageSlots[i]!.path),
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    existingUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image_outlined,
                                            color: Colors.grey),
                                  ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                          if (i == 0)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('Cover',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: Colors.grey.shade400, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            i == 0 ? 'Cover' : 'Photo ${i + 1}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Slot 1 is the cover. Slots 2–6 are supporting images (hard cap: 5 supporting).',
          style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.4)),
        ),
      ],
    );
  }

  // ── Input decoration helper ────────────────────────────────────────────────

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppTheme.lightGreen.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date button
// ─────────────────────────────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateButton(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppTheme.primary.withOpacity(0.4)
                : AppTheme.lightGreen.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: date != null ? AppTheme.primary : Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? '${date!.day}/${date!.month}/${date!.year}'
                    : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                  color: date != null
                      ? AppTheme.darkGreen
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
