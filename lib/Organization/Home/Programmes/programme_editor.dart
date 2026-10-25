// lib/Organization/Home/Programmes/programme_editor.dart
//
// Programme editor (ORG_HANDOFF §3.6, F). Six SectionCards — Type · Basic
// info · Schedule · Location · Engagement & contact · Images & status.
// done: number + check + summary + Edit · open: 1.5 ink border · locked:
// dashed "Complete section N to continue". Drafts autosave ("Saved 2 min
// ago" in the app bar); a published programme saves explicitly so half-made
// edits never go live. The sticky button names the next section.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Models/programme.dart';
import '../../../Shared/Activities/activity.dart' show ActivityLocation;
import '../../../theme/canopy_components.dart';
import '../../../theme/tokens/services_tokens.dart' show CanopyFees;
import '../../org_ui.dart';
import 'programme_logic.dart';

const kProgrammeSections = [
  'Type',
  'Basic info',
  'Schedule',
  'Location',
  'Engagement & contact',
  'Images & status',
];

IconData programmeTypeIcon(ProgrammeType t) => switch (t) {
      ProgrammeType.course => Icons.school_outlined,
      ProgrammeType.onlineCourse => Icons.laptop_outlined,
      ProgrammeType.workshop => Icons.construction_outlined,
      ProgrammeType.service => Icons.handyman_outlined,
      ProgrammeType.mentorship => Icons.people_outline,
      ProgrammeType.membership => Icons.card_membership_outlined,
    };

String programmeTypeCaption(ProgrammeType t) => switch (t) {
      ProgrammeType.course => 'Several sessions with a set curriculum',
      ProgrammeType.onlineCourse => 'Taught online through an external link',
      ProgrammeType.workshop => 'A hands-on session, often one day',
      ProgrammeType.service => 'Something you offer on request',
      ProgrammeType.mentorship => 'One-to-one or small-group guidance',
      ProgrammeType.membership => 'Ongoing membership with benefits',
    };

/// "KSh 1,200", "Free" or "Volunteer" — v2 money format.
String programmePrice(Programme p) {
  if (p.isPaid && p.details.price != null) return CanopyFees.ksh(p.details.price!.round());
  return p.isVolunteer ? 'Volunteer' : 'Free';
}

class ProgrammeEditor extends StatefulWidget {
  final String orgId;

  /// Null means create mode.
  final Programme? existing;

  const ProgrammeEditor({super.key, required this.orgId, this.existing});

  @override
  State<ProgrammeEditor> createState() => _ProgrammeEditorState();
}

class _ProgrammeEditorState extends State<ProgrammeEditor> {
  late final String _id =
      widget.existing?.id ?? FirebaseFirestore.instance.collection('programmes').doc().id;

  late ProgrammeType _type;
  late ProgrammeStatus _status;
  late ProgrammeStatus _publishAs;
  late EngagementModel _engagement;
  late RecurrencePattern _recurrence;
  bool _isOnline = false, _certificate = false, _enquiryEnabled = true;
  DateTime? _startDate, _endDate;
  String? _city, _area;
  double _lat = 0, _lng = 0;
  Map<String, List<Map<String, dynamic>>> _cities = {};

  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _capacity = TextEditingController();
  final _duration = TextEditingController();
  final _elig = TextEditingController();
  final _link = TextEditingController();
  final _venue = TextEditingController();

  /// Slot 0 = cover, 1–5 supporting. Uploaded as soon as they're picked.
  final List<String?> _urls = List.filled(6, null);
  final Set<int> _uploading = {};

  int? _open;
  bool _showErrors = false, _busy = false, _everSaved = false;
  DateTime? _savedAt;
  Timer? _debounce, _clock;

  bool get _isPublished => widget.existing != null && widget.existing!.status != ProgrammeStatus.draft;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? ProgrammeType.workshop;
    _status = e?.status ?? ProgrammeStatus.draft;
    _publishAs = (_status == ProgrammeStatus.draft) ? ProgrammeStatus.upcoming : _status;
    _engagement = e?.details.engagementModel ?? EngagementModel.free;
    _recurrence = e?.schedule.recurrence ?? RecurrencePattern.oneTime;
    _isOnline = e?.schedule.isOnline ?? false;
    _certificate = e?.details.certificateOffered ?? false;
    _enquiryEnabled = e?.contact.enquiryEnabled ?? true;
    _startDate = e?.schedule.startDate;
    _endDate = e?.schedule.endDate;
    if (e != null) {
      _everSaved = true;
      _title.text = e.title;
      _summary.text = e.summary;
      _desc.text = e.description;
      _duration.text = e.details.duration;
      _elig.text = e.details.eligibility;
      _link.text = e.contact.externalLink ?? '';
      if (e.details.price != null) _price.text = e.details.price!.toStringAsFixed(0);
      if (e.details.capacity != null) _capacity.text = '${e.details.capacity}';
      final loc = e.schedule.location;
      if (loc != null) {
        _city = loc.city;
        _area = loc.area;
        _venue.text = loc.venue;
        _lat = loc.lat;
        _lng = loc.lng;
      }
      _urls[0] = e.coverImageUrl;
      for (var i = 0; i < e.supportingImageUrls.length && i < 5; i++) {
        _urls[i + 1] = e.supportingImageUrls[i];
      }
      _savedAt = e.updatedAt;
    }
    // New: open the first section. Existing draft: open the first gap.
    final done = ProgrammeLogic.sectionsDone(_build());
    final gap = done.indexOf(false);
    _open = e == null ? 0 : (gap >= 0 && !_isPublished ? gap : null);
    for (final c in [_title, _summary, _desc, _price, _capacity, _duration, _elig, _link, _venue]) {
      c.addListener(_changed);
    }
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
    _loadCities();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clock?.cancel();
    if (!_isPublished && _debounce != null) _autosave();
    for (final c in [_title, _summary, _desc, _price, _capacity, _duration, _elig, _link, _venue]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final raw = await rootBundle.loadString('assets/Cities/African/KenyaCities.json');
      final map = (jsonDecode(raw) as Map<String, dynamic>)['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      if (mounted) {
        setState(() => _cities = {
              for (final e in map.entries) e.key: (e.value as List).cast<Map<String, dynamic>>(),
            });
      }
    } catch (_) {}
  }

  // ── Model ────────────────────────────────────────────────────────────────

  Programme _build({ProgrammeStatus? status}) {
    final st = status ?? _status;
    final link = _link.text.trim();
    return Programme(
      id: _id,
      orgId: widget.orgId,
      type: _type,
      status: st,
      title: _title.text.trim(),
      summary: _summary.text.trim(),
      description: _desc.text.trim(),
      coverImageUrl: _urls[0],
      supportingImageUrls: _urls.skip(1).whereType<String>().toList(),
      schedule: ProgrammeSchedule(
        startDate: _startDate,
        endDate: _recurrence == RecurrencePattern.ongoing ? null : _endDate,
        recurrence: _recurrence,
        isOnline: _isOnline,
        location: !_isOnline && _city != null
            ? ActivityLocation(city: _city!, area: _area ?? _city!, venue: _venue.text.trim(), lat: _lat, lng: _lng)
            : null,
      ),
      details: ProgrammeDetails(
        engagementModel: _engagement,
        price: _engagement == EngagementModel.paid ? double.tryParse(_price.text.trim()) : null,
        capacity: int.tryParse(_capacity.text.trim()),
        duration: _duration.text.trim(),
        certificateOffered: _certificate,
        eligibility: _elig.text.trim(),
      ),
      contact: ProgrammeContact(
        mode: link.isEmpty
            ? ProgrammeContactMode.enquiry
            : (_enquiryEnabled ? ProgrammeContactMode.both : ProgrammeContactMode.externalLink),
        externalLink: link.isEmpty ? null : link,
        enquiryEnabled: _enquiryEnabled,
      ),
      createdBy: widget.existing?.createdBy ?? FirebaseAuth.instance.currentUser?.uid,
      createdAt: widget.existing?.createdAt,
      publishedAt: st == ProgrammeStatus.draft ? null : (widget.existing?.publishedAt ?? DateTime.now()),
    );
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_isPublished) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _autosave);
  }

  void _set(VoidCallback f) {
    setState(f);
    _changed();
  }

  Future<void> _autosave() async {
    _debounce = null;
    // Nothing worth keeping until it has a name.
    if (_title.text.trim().isEmpty && !_everSaved) return;
    try {
      await ProgrammeLogic.saveProgramme(_build(status: ProgrammeStatus.draft));
      _everSaved = true;
      if (mounted) setState(() => _savedAt = DateTime.now());
    } catch (_) {}
  }

  String? get _savedLabel {
    if (_isPublished) return null;
    if (_debounce != null) return 'Saving…';
    final t = _savedAt;
    if (t == null) return null;
    final m = DateTime.now().difference(t).inMinutes;
    return m < 1 ? 'Saved just now' : (m < 60 ? 'Saved $m min ago' : 'Saved ${DateFormat('d MMM, HH:mm').format(t)}');
  }

  // ── Section validation ───────────────────────────────────────────────────

  String? _errorFor(int i) {
    switch (i) {
      case 1:
        if (_title.text.trim().isEmpty) return 'Give it a title.';
        if (_summary.text.trim().isEmpty) return 'Add a one-line summary.';
      case 2:
        if (_recurrence != RecurrencePattern.ongoing && _startDate == null) return 'Pick a start date.';
        if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
          return 'The end date is before the start.';
        }
      case 3:
        if (!_isOnline && _city == null) return 'Choose a city, or switch to online.';
      case 4:
        if (_engagement == EngagementModel.paid && (double.tryParse(_price.text.trim()) ?? 0) <= 0) {
          return 'Enter a price.';
        }
        if (_type == ProgrammeType.onlineCourse && _link.text.trim().isEmpty) return 'Online courses need a link.';
        if (!_enquiryEnabled && _link.text.trim().isEmpty) return 'Turn on questions or add a link so people can reach you.';
      case 5:
        if (_urls[0] == null) return 'Add a cover photo.';
    }
    return null;
  }

  void _continue() {
    final i = _open;
    if (i == null) return;
    if (_errorFor(i) != null) {
      setState(() => _showErrors = true);
      return;
    }
    final done = ProgrammeLogic.sectionsDone(_build());
    final next = [for (var k = 0; k < 6; k++) k].firstWhere((k) => k != i && !done[k], orElse: () => -1);
    setState(() {
      _showErrors = false;
      _open = next < 0 ? null : next;
    });
  }

  Future<void> _publish() async {
    for (var i = 0; i < 6; i++) {
      if (_errorFor(i) != null) {
        setState(() {
          _open = i;
          _showErrors = true;
        });
        return;
      }
    }
    _debounce?.cancel();
    _debounce = null;
    setState(() => _busy = true);
    try {
      await ProgrammeLogic.saveProgramme(_build(status: _publishAs));
      if (!mounted) return;
      showCanopySnack(context, _isPublished ? 'Changes saved.' : 'Published — members can find it on your page.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final draft = !_isPublished;
    final ok = await showCanopyConfirm(context,
        title: draft ? 'Delete this draft?' : 'Archive this programme?',
        message: draft
            ? "It's removed for good."
            : 'It disappears from your public page. Enquiries already received stay in your inbox.',
        confirmLabel: draft ? 'Delete draft' : 'Archive',
        danger: true);
    if (!ok) return;
    _debounce?.cancel();
    _debounce = null;
    setState(() => _busy = true);
    try {
      if (draft) {
        if (_everSaved) await ProgrammeLogic.deleteProgramme(_id);
      } else {
        await ProgrammeLogic.archiveProgramme(_id);
      }
      _everSaved = false;
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showCanopySnack(context, "Couldn't do that. Try again.", error: true);
      }
    }
  }

  // ── Pickers ──────────────────────────────────────────────────────────────

  Future<void> _pickImage(int slot) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (f == null || !mounted) return;
    setState(() => _uploading.add(slot));
    try {
      final ref = FirebaseStorage.instance
          .ref('programmes/${widget.orgId}/$_id/${slot == 0 ? 'cover' : 'support_$slot'}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(f.path));
      final url = await ref.getDownloadURL();
      if (mounted) _set(() => _urls[slot] = url);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't upload that photo. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _uploading.remove(slot));
    }
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _startDate : _endDate) ?? _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d != null) _set(() => start ? _startDate = d : _endDate = d);
  }

  Future<void> _pickFromList(String title, List<String> options, ValueChanged<String> onPick) async {
    final v = await showCanopySheet<String>(context, tall: true, builder: (_) => _ListSheet(title: title, options: options));
    if (v != null) onPick(v);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final done = ProgrammeLogic.sectionsDone(_build());
    final firstGap = done.indexOf(false);
    final saved = _savedLabel;

    SectionCardState stateOf(int i) {
      if (_open == i) return SectionCardState.open;
      if (done[i]) return SectionCardState.done;
      return (firstGap >= 0 && i > firstGap) ? SectionCardState.locked : SectionCardState.open;
    }

    final nextLabel = () {
      final i = _open;
      if (i == null) return _isPublished ? 'Save changes' : 'Publish programme';
      final after = [for (var k = 0; k < 6; k++) k].where((k) => k != i && !done[k]).toList();
      if (after.isEmpty) return _isPublished ? 'Save changes' : 'Publish programme';
      return 'Continue to ${kProgrammeSections[after.first]}';
    }();
    final finishing = nextLabel == 'Save changes' || nextLabel == 'Publish programme';

    return CanopyScaffold(
      appBar: canopyAppBar(
        context,
        title: widget.existing == null ? 'New programme' : (_isPublished ? 'Edit programme' : 'Draft programme'),
        actions: [
          if (saved != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: CanopySpace.gutter),
                child: Text(saved, style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Row(children: [
            Text('${done.where((d) => d).length} of 6 sections', style: CanopyType.label.copyWith(color: p.inkMuted)),
            const SizedBox(width: CanopySpace.s12),
            Expanded(child: CanopyProgressBar(value: done.where((d) => d).length / 6, ink: true)),
          ]),
          const SizedBox(height: CanopySpace.s16),
          for (var i = 0; i < 6; i++) ...[
            SectionCard(
              number: i + 1,
              title: kProgrammeSections[i],
              state: stateOf(i),
              summary: _summaryFor(i),
              onEdit: () => setState(() {
                _open = i;
                _showErrors = false;
              }),
              child: stateOf(i) == SectionCardState.open ? _section(i, p) : null,
            ),
            const SizedBox(height: CanopySpace.s12),
          ],
          const SizedBox(height: CanopySpace.s8),
          if (widget.existing != null || _everSaved)
            Center(
              child: CanopyButton.quietDanger(
                label: _isPublished ? 'Archive programme' : 'Delete draft',
                onPressed: _busy ? null : _delete,
              ),
            ),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: nextLabel,
          expand: true,
          loading: _busy && finishing,
          onPressed: _busy ? null : (finishing && (_open == null || _errorFor(_open!) == null) ? _publish : _continue),
        ),
      ]),
    );
  }

  String? _summaryFor(int i) {
    switch (i) {
      case 0:
        return _type.label;
      case 1:
        return _title.text.trim().isEmpty ? null : _title.text.trim();
      case 2:
        final bits = [
          _recurrence.label,
          if (_startDate != null) 'from ${DateFormat('d MMM yyyy').format(_startDate!)}',
          if (_endDate != null && _recurrence != RecurrencePattern.ongoing) 'to ${DateFormat('d MMM').format(_endDate!)}',
        ];
        return bits.join(' · ');
      case 3:
        if (_isOnline) return 'Online';
        return [_venue.text.trim(), _area, _city].whereType<String>().where((s) => s.isNotEmpty).join(', ');
      case 4:
        final b = _build();
        return [programmePrice(b), if (_enquiryEnabled) 'Questions on', if (_link.text.trim().isNotEmpty) 'Link'].join(' · ');
      case 5:
        final n = _urls.skip(1).whereType<String>().length;
        return [
          _urls[0] == null ? 'No cover' : 'Cover${n > 0 ? ' + $n photo${n == 1 ? '' : 's'}' : ''}',
          _isPublished ? _publishAs.label : 'Publishes as ${_publishAs.label.toLowerCase()}',
        ].join(' · ');
    }
    return null;
  }

  Widget _error(int i, CanopyPalette p) {
    final e = _showErrors ? _errorFor(i) : null;
    if (e == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: CanopySpace.s12),
      child: Text(e, style: CanopyType.caption.copyWith(color: p.danger)),
    );
  }

  Widget _section(int i, CanopyPalette p) {
    const gap = SizedBox(height: CanopySpace.s16);
    final body = switch (i) {
      0 => Column(children: [
          for (final t in ProgrammeType.values) ...[
            CanopyOptionCard(
              selected: _type == t,
              icon: programmeTypeIcon(t),
              title: t.label,
              caption: programmeTypeCaption(t),
              onTap: () => _set(() {
                _type = t;
                if (t == ProgrammeType.onlineCourse) _isOnline = true;
              }),
            ),
            const SizedBox(height: CanopySpace.s8),
          ],
        ]),
      1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CanopyTextField(label: 'Title', hint: 'e.g. Tree nursery basics', controller: _title, maxLength: 80),
          gap,
          CanopyTextField(
              label: 'Summary', hint: 'One line people see on your page', controller: _summary, maxLength: 140),
          gap,
          CanopyTextField(
              label: 'Description',
              hint: 'What people do, learn or get',
              controller: _desc,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000),
        ]),
      2 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CanopySegmented<RecurrencePattern>(
            options: [for (final r in RecurrencePattern.values) (r, r.label)],
            value: _recurrence,
            onChanged: (v) => _set(() => _recurrence = v),
          ),
          gap,
          CanopyPickerField(
            label: _recurrence == RecurrencePattern.ongoing ? 'Starts (optional)' : 'Starts',
            value: _startDate == null ? null : DateFormat('EEE d MMM yyyy').format(_startDate!),
            placeholder: 'Pick a date',
            icon: Icons.calendar_today_outlined,
            onTap: () => _pickDate(true),
          ),
          if (_recurrence != RecurrencePattern.ongoing) ...[
            gap,
            CanopyPickerField(
              label: 'Ends (optional)',
              value: _endDate == null ? null : DateFormat('EEE d MMM yyyy').format(_endDate!),
              placeholder: 'Pick a date',
              icon: Icons.event_outlined,
              onTap: () => _pickDate(false),
            ),
          ],
          gap,
          CanopyTextField(label: 'Duration (optional)', hint: 'e.g. 6 weeks, 2 hours a session', controller: _duration),
        ]),
      3 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CanopySwitchRow(
            title: 'Online',
            caption: 'No venue — people join from anywhere',
            value: _isOnline,
            onChanged: (v) => _set(() => _isOnline = v),
          ),
          if (!_isOnline) ...[
            gap,
            CanopyPickerField(
              label: 'City or county',
              value: _city,
              placeholder: 'Choose',
              icon: Icons.location_city_outlined,
              onTap: () => _pickFromList('City or county', _cities.keys.toList()..sort(),
                  (v) => _set(() {
                        _city = v;
                        _area = null;
                        _lat = _lng = 0;
                      })),
            ),
            if (_city != null && (_cities[_city] ?? const []).isNotEmpty) ...[
              gap,
              CanopyPickerField(
                label: 'Area',
                value: _area,
                placeholder: 'Choose',
                icon: Icons.place_outlined,
                onTap: () => _pickFromList(
                    'Area',
                    [for (final a in _cities[_city]!) a['area'] as String? ?? ''].where((a) => a.isNotEmpty).toList(),
                    (v) => _set(() {
                          _area = v;
                          final d = _cities[_city]!.firstWhere((a) => a['area'] == v, orElse: () => {});
                          final c = d['coordinates'] as Map<String, dynamic>? ?? {};
                          _lat = (c['lat'] as num?)?.toDouble() ?? 0;
                          _lng = (c['lng'] as num?)?.toDouble() ?? 0;
                        })),
              ),
            ],
            gap,
            CanopyTextField(label: 'Venue (optional)', hint: 'e.g. Community hall, Gate 2', controller: _venue),
          ],
        ]),
      4 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CanopySegmented<EngagementModel>(
            options: const [(EngagementModel.free, 'Free'), (EngagementModel.paid, 'Paid'), (EngagementModel.volunteer, 'Volunteer')],
            value: _engagement,
            onChanged: (v) => _set(() => _engagement = v),
          ),
          if (_engagement == EngagementModel.paid) ...[
            gap,
            CanopyTextField.money(label: 'Price', controller: _price),
            const SizedBox(height: CanopySpace.s4),
            Text("People pay you directly — Canopy doesn't take payment for programmes.",
                style: CanopyType.caption.copyWith(color: p.inkMuted)),
          ],
          gap,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: CanopyTextField(
                  label: 'Spaces (optional)',
                  hint: '20',
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            ),
          ]),
          gap,
          CanopyTextField(label: 'Who can join (optional)', hint: 'e.g. Ages 16+, farmers in Kiambu', controller: _elig),
          gap,
          CanopySwitchRow(
            title: 'Certificate',
            caption: 'People get a certificate when they finish',
            value: _certificate,
            onChanged: (v) => _set(() => _certificate = v),
          ),
          CanopySwitchRow(
            title: 'Questions from members',
            caption: 'They land in your Enquiries inbox',
            value: _enquiryEnabled,
            onChanged: (v) => _set(() => _enquiryEnabled = v),
          ),
          gap,
          CanopyTextField(
            label: _type == ProgrammeType.onlineCourse ? 'Course link' : 'Sign-up link (optional)',
            hint: 'https://',
            controller: _link,
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
          ),
        ]),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cover', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          AspectRatio(aspectRatio: 16 / 9, child: _slot(0, p)),
          gap,
          Text('More photos (up to 5)', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: CanopySpace.s8,
            crossAxisSpacing: CanopySpace.s8,
            children: [for (var s = 1; s < 6; s++) _slot(s, p)],
          ),
          gap,
          Text(_isPublished ? 'Status' : 'When published, show as', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          CanopySegmented<ProgrammeStatus>(
            options: const [
              (ProgrammeStatus.upcoming, 'Upcoming'),
              (ProgrammeStatus.active, 'Running'),
              (ProgrammeStatus.completed, 'Finished'),
            ],
            value: _publishAs,
            onChanged: (v) => _set(() => _publishAs = v),
          ),
          const SizedBox(height: CanopySpace.s4),
          Text('Finished programmes move to your Track record.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ]),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [body, _error(i, p)]);
  }

  Widget _slot(int s, CanopyPalette p) {
    final url = _urls[s];
    final busy = _uploading.contains(s);
    return ClipRRect(
      borderRadius: BorderRadius.circular(CanopyRadius.sm),
      child: Material(
        color: p.surfaceMuted,
        child: InkWell(
          onTap: busy ? null : () => _pickImage(s),
          child: Stack(fit: StackFit.expand, children: [
            if (url != null)
              CanopyImage(url: url)
            else
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: p.inkMuted),
                  if (s == 0) Text('Add a cover photo', style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ]),
              ),
            if (busy) Container(color: p.canvas.withValues(alpha: .6), child: const Center(child: CircularProgressIndicator())),
            if (url != null && !busy)
              Positioned(
                top: 4,
                right: 4,
                child: CanopyIconButton(
                  onImage: true,
                  icon: Icons.close,
                  tooltip: 'Remove photo',
                  onPressed: () => _set(() => _urls[s] = null),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _ListSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  const _ListSheet({required this.title, required this.options});

  @override
  State<_ListSheet> createState() => _ListSheetState();
}

class _ListSheetState extends State<_ListSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.options.where((o) => o.toLowerCase().contains(_q)).take(80).toList();
    return CanopySheetBody(title: widget.title, children: [
      if (widget.options.length > 10) ...[
        CanopyTextField.search(hint: 'Search', onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
        const SizedBox(height: CanopySpace.s12),
      ],
      CanopyListGroup(children: [
        for (final o in list) CanopyListRow(title: o, chevron: false, onTap: () => Navigator.pop(context, o)),
      ]),
    ]);
  }
}
