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
  final _formKey   = GlobalKey<FormState>();
  final _picker    = ImagePicker();
  final _scrollCtrl = ScrollController();

  // ── Section completion flags ───────────────────────────────────────────────
  // S1 (Type) is always done — ProgrammeType has a valid default from the start.
  bool _s1Done = true;
  bool _s2Done = false; // Basic Info
  bool _s3Done = false; // Schedule
  bool _s4Done = false; // Location (only relevant when !_isOnline)
  bool _s5Done = false; // Engagement & Contact

  final List<GlobalKey> _sectionKeys = List.generate(6, (_) => GlobalKey());

  // ── Form state ─────────────────────────────────────────────────────────────
  late ProgrammeType _type;
  late ProgrammeStatus _status;
  late EngagementModel _engagement;
  late ProgrammeContactMode _contactMode;
  late RecurrencePattern _recurrence;

  final _titleCtrl    = TextEditingController();
  final _summaryCtrl  = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _eligCtrl     = TextEditingController();
  final _linkCtrl     = TextEditingController();
  final _venueCtrl    = TextEditingController();

  bool _isOnline       = false;
  bool _certificate    = false;
  bool _enquiryEnabled = true;
  DateTime? _startDate;
  DateTime? _endDate;

  // Location picker
  String? _selectedCity;
  String? _selectedArea;
  double _lat = 0, _lng = 0;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  // Images — slot 0 = cover, slots 1-5 = supporting (hard cap)
  final List<XFile?>   _imageSlots   = List.filled(6, null);
  final List<String?>  _existingUrls = List.filled(6, null);

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type           = e?.type                     ?? ProgrammeType.workshop;
    _status         = e?.status                   ?? ProgrammeStatus.draft;
    _engagement     = e?.details.engagementModel  ?? EngagementModel.free;
    _contactMode    = e?.contact.mode             ?? ProgrammeContactMode.enquiry;
    _recurrence     = e?.schedule.recurrence      ?? RecurrencePattern.oneTime;
    _isOnline       = e?.schedule.isOnline        ?? false;
    _certificate    = e?.details.certificateOffered ?? false;
    _enquiryEnabled = e?.contact.enquiryEnabled   ?? true;
    _startDate      = e?.schedule.startDate;
    _endDate        = e?.schedule.endDate;

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
      // Edit mode: all sections pre-complete so all cards expand immediately.
      _s2Done = _s3Done = _s4Done = _s5Done = true;
    }
    _loadCities();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    for (final c in [
      _titleCtrl, _summaryCtrl, _descCtrl, _priceCtrl, _durationCtrl,
      _eligCtrl, _linkCtrl, _venueCtrl,
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

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImage(int slot) async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 82);
    if (!mounted || file == null) return;
    setState(() => _imageSlots[slot] = file);
  }

  void _removeImage(int slot) =>
      setState(() { _imageSlots[slot] = null; _existingUrls[slot] = null; });

  // ── Date pickers ───────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary),
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

  // ── Save ───────────────────────────────────────────────────────────────────

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

      final storagePath = 'programmes/${widget.orgId}/$programmeId';
      Future<String?> upload(int slot, String name) async {
        final file = _imageSlots[slot];
        if (file == null) return _existingUrls[slot];
        final ref = FirebaseStorage.instance.ref().child('$storagePath/$name.jpg');
        await ref.putFile(File(file.path));
        return await ref.getDownloadURL();
      }

      final coverUrl   = await upload(0, 'cover');
      final supporting = <String>[];
      for (int i = 1; i <= 5; i++) {
        final url = await upload(i, 'support_$i');
        if (url != null) supporting.add(url);
      }

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
          externalLink: _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Section scroll helper ──────────────────────────────────────────────────

  void _scrollToSection(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0);
      }
    });
  }

  // ── Section validation ─────────────────────────────────────────────────────

  bool _validateS2() {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Programme title is required.');
      return false;
    }
    return true;
  }

  bool _validateS4() {
    if (!_isOnline && _selectedCity == null) {
      _snack('Select a city for in-person programmes.');
      return false;
    }
    return true;
  }

  bool _validateS5() {
    if (_engagement == EngagementModel.paid &&
        double.tryParse(_priceCtrl.text.trim()) == null) {
      _snack('Enter a valid price for paid programmes.');
      return false;
    }
    if (_type == ProgrammeType.onlineCourse && _linkCtrl.text.trim().isEmpty) {
      _snack('Online courses require an external link.');
      return false;
    }
    return true;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool locationRelevant = !_isOnline;
    final bool s5Unlocked = locationRelevant ? _s4Done : _s3Done;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        foregroundColor: AppTheme.darkGreen,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 15, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _isEdit ? 'Edit Programme' : 'New Programme',
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
              fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress bar
              _EditorProgressBar(
                completedSections: [
                  _s1Done, _s2Done, _s3Done,
                  if (locationRelevant) _s4Done,
                  _s5Done,
                ],
              ),
              const SizedBox(height: 24),

              // ── S1: Programme Type ────────────────────────────────────────
              _SectionWrapper(
                key: _sectionKeys[0],
                index: 1,
                title: 'Programme Type',
                subtitle: 'What kind of programme are you creating?',
                icon: Icons.category_outlined,
                isLocked: false,
                isDone: _s1Done,
                showCompleteButton: false,
                child: _typeSelector(),
              ),
              const SizedBox(height: 16),

              // ── S2: Basic Info ────────────────────────────────────────────
              _SectionWrapper(
                key: _sectionKeys[1],
                index: 2,
                title: 'Basic Info',
                subtitle: 'Name, summary, and full description',
                icon: Icons.description_outlined,
                isLocked: !_s1Done,
                isDone: _s2Done,
                onComplete: _s2Done
                    ? null
                    : () {
                        if (_validateS2()) {
                          setState(() => _s2Done = true);
                          _scrollToSection(2);
                        }
                      },
                child: _basicInfoSection(),
              ),
              const SizedBox(height: 16),

              // ── S3: Schedule ──────────────────────────────────────────────
              _SectionWrapper(
                key: _sectionKeys[2],
                index: 3,
                title: 'Schedule',
                subtitle: 'Dates, recurrence, and delivery format',
                icon: Icons.calendar_month_outlined,
                isLocked: !_s2Done,
                isDone: _s3Done,
                onComplete: _s3Done
                    ? null
                    : () {
                        setState(() => _s3Done = true);
                        _scrollToSection(locationRelevant ? 3 : 4);
                      },
                child: _scheduleSection(),
              ),
              const SizedBox(height: 16),

              // ── S4: Location (in-person only) ─────────────────────────────
              if (locationRelevant) ...[
                _SectionWrapper(
                  key: _sectionKeys[3],
                  index: 4,
                  title: 'Location',
                  subtitle: 'Where the programme takes place',
                  icon: Icons.location_on_outlined,
                  isLocked: !_s3Done,
                  isDone: _s4Done,
                  onComplete: _s4Done
                      ? null
                      : () {
                          if (_validateS4()) {
                            setState(() => _s4Done = true);
                            _scrollToSection(4);
                          }
                        },
                  child: _locationSection(),
                ),
                const SizedBox(height: 16),
              ],

              // ── S5: Engagement & Contact ──────────────────────────────────
              _SectionWrapper(
                key: _sectionKeys[4],
                index: locationRelevant ? 5 : 4,
                title: 'Engagement & Contact',
                subtitle: 'Pricing, eligibility, and how people reach you',
                icon: Icons.handshake_outlined,
                isLocked: !s5Unlocked,
                isDone: _s5Done,
                onComplete: _s5Done
                    ? null
                    : () {
                        if (_validateS5()) {
                          setState(() => _s5Done = true);
                          _scrollToSection(5);
                        }
                      },
                child: _engagementContactSection(),
              ),
              const SizedBox(height: 16),

              // ── S6: Images & Status ───────────────────────────────────────
              _SectionWrapper(
                key: _sectionKeys[5],
                index: locationRelevant ? 6 : 5,
                title: 'Images & Status',
                subtitle: 'Cover photo, gallery, and programme visibility',
                icon: Icons.photo_library_outlined,
                isLocked: !_s5Done,
                isDone: false,
                showCompleteButton: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusRow(),
                    const SizedBox(height: 20),
                    _imageGrid(),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isEdit ? 'Save changes' : 'Publish programme',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section content builders ───────────────────────────────────────────────

  Widget _basicInfoSection() {
    return Column(
      children: [
        TextFormField(
          controller: _titleCtrl,
          decoration: _inputDec(
            label: 'Programme title',
            icon: Icons.title_outlined,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _summaryCtrl,
          maxLines: 2,
          decoration: _inputDec(
            label: 'Summary (shown on cards)',
            icon: Icons.short_text_outlined,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descCtrl,
          maxLines: 5,
          decoration: _inputDec(
            label: 'Full description',
            icon: Icons.notes_outlined,
          ),
        ),
      ],
    );
  }

  Widget _engagementContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Pricing model'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: EngagementModel.values.map((e) {
            final active = _engagement == e;
            return GestureDetector(
              onTap: () => setState(() => _engagement = e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.primary.withOpacity(0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppTheme.primary : Colors.grey.shade200,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  e.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? AppTheme.primary : AppTheme.darkGreen,
                  ),
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
            decoration: _inputDec(
                label: 'Price (KES)', icon: Icons.payments_outlined),
            validator: (v) =>
                _engagement == EngagementModel.paid &&
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
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _eligCtrl,
          decoration: _inputDec(
            label: 'Eligibility',
            hint: 'Who can join? (leave blank if open to all)',
            icon: Icons.people_outline,
          ),
        ),
        const SizedBox(height: 16),
        _sectionLabel('How people reach you'),
        const SizedBox(height: 10),
        DropdownButtonFormField<ProgrammeContactMode>(
          value: _contactMode,
          decoration: _inputDec(
            label: 'Contact method',
            icon: Icons.contact_mail_outlined,
          ),
          items: ProgrammeContactMode.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: (v) => setState(() => _contactMode = v!),
        ),
        if (_contactMode != ProgrammeContactMode.enquiry ||
            _type == ProgrammeType.onlineCourse) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _linkCtrl,
            keyboardType: TextInputType.url,
            decoration: _inputDec(
              label: _type == ProgrammeType.onlineCourse
                  ? 'Course link (required)'
                  : 'External link',
              icon: Icons.link_outlined,
            ),
            validator: (_type == ProgrammeType.onlineCourse ||
                    _contactMode != ProgrammeContactMode.enquiry)
                ? (v) =>
                    (v == null || v.trim().isEmpty) ? 'Link is required' : null
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

  Widget _statusRow() {
    final visible = [
      ProgrammeStatus.draft,
      ProgrammeStatus.upcoming,
      ProgrammeStatus.active,
      ProgrammeStatus.completed,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Visibility status'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visible.map((s) {
            final active = _status == s;
            return GestureDetector(
              onTap: () => setState(() => _status = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.primary.withOpacity(0.1)
                      : Colors.white,
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
        ),
      ],
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
            if (t == ProgrammeType.membership ||
                t == ProgrammeType.mentorship) {
              _contactMode = ProgrammeContactMode.enquiry;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  // ── Schedule section ───────────────────────────────────────────────────────

  Widget _scheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        DropdownButtonFormField<RecurrencePattern>(
          value: _recurrence,
          decoration: _inputDec(
              label: 'Recurrence', icon: Icons.repeat_outlined),
          items: RecurrencePattern.values
              .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
              .toList(),
          onChanged: (v) => setState(() => _recurrence = v!),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _durationCtrl,
          decoration: _inputDec(
            label: 'Duration',
            hint: 'e.g. 3 hours / 6 weeks',
            icon: Icons.timelapse_outlined,
          ),
        ),
        const SizedBox(height: 12),
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
          decoration: _inputDec(
              label: 'City', icon: Icons.location_city_outlined),
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
          decoration: _inputDec(
              label: 'Area / neighbourhood', icon: Icons.place_outlined),
          items: _areas
              .map((a) => DropdownMenuItem(
                  value: a['area'] as String, child: Text(a['area'] as String)))
              .toList(),
          onChanged: _onAreaSelected,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _venueCtrl,
          decoration: _inputDec(
            label: 'Venue',
            hint: 'e.g. Community Hall, Gate 2',
            icon: Icons.business_outlined,
          ),
        ),
      ],
    );
  }

  // ── Image grid ─────────────────────────────────────────────────────────────

  Widget _imageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Photos (slot 1 = cover, up to 5 supporting)'),
        const SizedBox(height: 12),
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
                                ? Image.file(File(_imageSlots[i]!.path),
                                    fit: BoxFit.cover)
                                : Image.network(
                                    existingUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined,
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
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.darkGreen.withOpacity(0.55),
          letterSpacing: 0.3),
    );
  }

  InputDecoration _inputDec({
    required String label,
    String? hint,
    IconData icon = Icons.edit_outlined,
    Color accent = AppTheme.primary,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: accent.withOpacity(0.75), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(10),
        child: _IconPill(icon: icon, color: accent),
      ),
      prefixIconConstraints:
          const BoxConstraints(minWidth: 52, minHeight: 52),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withOpacity(0.22))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionWrapper — progressive-lock card (adapted from org_register_wizard)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionWrapper extends StatefulWidget {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLocked;
  final bool isDone;
  final Widget child;
  final VoidCallback? onComplete;
  final String? completeLabel;
  final bool showCompleteButton;

  const _SectionWrapper({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLocked,
    required this.isDone,
    required this.child,
    this.onComplete,
    this.completeLabel,
    this.showCompleteButton = true,
  });

  @override
  State<_SectionWrapper> createState() => _SectionWrapperState();
}

class _SectionWrapperState extends State<_SectionWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _unlockAnim;
  late Animation<double> _unlockFade;
  late Animation<double> _unlockScale;
  bool _wasLocked = true;

  @override
  void initState() {
    super.initState();
    _wasLocked = widget.isLocked;
    _unlockAnim = AnimationController(
        duration: const Duration(milliseconds: 450), vsync: this);
    _unlockFade =
        CurvedAnimation(parent: _unlockAnim, curve: Curves.easeOut);
    _unlockScale = Tween<double>(begin: 0.97, end: 1.0).animate(
        CurvedAnimation(parent: _unlockAnim, curve: Curves.easeOutBack));
    if (!widget.isLocked) _unlockAnim.value = 1.0;
  }

  @override
  void didUpdateWidget(_SectionWrapper old) {
    super.didUpdateWidget(old);
    if (_wasLocked && !widget.isLocked) {
      _wasLocked = false;
      _unlockAnim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _unlockAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone   = widget.isDone;
    final isLocked = widget.isLocked;

    final headerColor = isDone
        ? AppTheme.primary
        : isLocked
            ? AppTheme.darkGreen.withOpacity(0.35)
            : AppTheme.darkGreen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? AppTheme.primary.withOpacity(0.4)
              : isLocked
                  ? Colors.grey.withOpacity(0.15)
                  : AppTheme.lightGreen.withOpacity(0.35),
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone
                ? AppTheme.primary.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: isDone ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppTheme.primary
                      : isLocked
                          ? Colors.grey.withOpacity(0.12)
                          : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : isLocked
                          ? Icons.lock_outline_rounded
                          : widget.icon,
                  color: isDone
                      ? Colors.white
                      : isLocked
                          ? Colors.grey.withOpacity(0.45)
                          : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          'Step ${widget.index}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: headerColor.withOpacity(0.55),
                              letterSpacing: 0.5),
                        ),
                        if (isDone) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Complete',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(widget.title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: headerColor)),
                      Text(widget.subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: headerColor.withOpacity(0.6))),
                    ]),
              ),
            ]),
          ),

          // Locked overlay vs content
          if (isLocked)
            _LockedPlaceholder()
          else
            FadeTransition(
              opacity: _unlockFade,
              child: ScaleTransition(
                scale: _unlockScale,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: widget.child,
                      ),
                      if (widget.showCompleteButton && !isDone) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          child: FilledButton(
                            onPressed: widget.onComplete,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.completeLabel ?? 'Continue',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ]),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 18),
                      ],
                    ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _LockedPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(children: [
        Icon(Icons.lock_outline_rounded,
            size: 28, color: Colors.grey.withOpacity(0.3)),
        const SizedBox(height: 8),
        Text('Complete the previous section to continue',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.withOpacity(0.55))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EditorProgressBar
// ─────────────────────────────────────────────────────────────────────────────

class _EditorProgressBar extends StatelessWidget {
  final List<bool> completedSections;

  const _EditorProgressBar({required this.completedSections});

  @override
  Widget build(BuildContext context) {
    final done  = completedSections.where((b) => b).length;
    final total = completedSections.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$done of $total steps complete',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen)),
        const Spacer(),
        Text('${((done / total) * 100).round()}%',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: done / total,
          backgroundColor: AppTheme.lightGreen.withOpacity(0.18),
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IconPill
// ─────────────────────────────────────────────────────────────────────────────

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconPill({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DateButton
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
                    fontWeight:
                        date != null ? FontWeight.w600 : FontWeight.w400,
                    color: date != null
                        ? AppTheme.darkGreen
                        : Colors.grey.shade400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
