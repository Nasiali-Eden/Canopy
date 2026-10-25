// lib/Shared/Activities/create_activity.dart
//
// Create activity (v2). One calm form: cover + photos, what (title, category,
// description), where (city, area, venue), when (date, time), spots and
// registration, then one primary "Publish activity". Org callers pass
// orgId so the event can never be written orphaned.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Activities/activity_service.dart';
import '../Inputs/pin_picker_screen.dart';
import '../../theme/canopy_components.dart';
import 'activity.dart';
import 'activity_detail_screen.dart';

/// When [returnOnSuccess] is true, pops back to the caller with the new id
/// instead of opening the detail screen (org Operations uses this).
class CreateActivityScreen extends StatefulWidget {
  final bool returnOnSuccess;

  /// Org that owns the event. Callers already inside an org context pass it
  /// explicitly — re-deriving it needs a network read that can silently
  /// yield null and write an event no org can see.
  final String? orgId;

  const CreateActivityScreen({super.key, this.returnOnSuccess = false, this.orgId});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  /// Stored in `type`; must match the community filter keys.
  static const _categories = [
    ('cleanup', 'Clean-up', Icons.cleaning_services_outlined),
    ('tree_planting', 'Tree planting', Icons.park_outlined),
    ('awareness', 'Awareness', Icons.campaign_outlined),
    ('training', 'Training', Icons.school_outlined),
    ('monitoring', 'Monitoring', Icons.monitor_heart_outlined),
    ('other', 'Other', Icons.more_horiz),
  ];

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _venue = TextEditingController();
  int _spots = 10;
  String _type = 'cleanup';
  RegistrationState _registration = RegistrationState.open;

  String? _city, _area;
  double _lat = 0, _lng = 0;
  LatLng? _pin; // the exact spot; required
  Map<String, List<Map<String, dynamic>>> _cities = {};

  DateTime? _date;
  TimeOfDay? _time;
  final List<XFile?> _images = [null, null, null, null];
  bool _saving = false, _showErrors = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _venue.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final raw = await rootBundle.loadString('assets/Cities/African/KenyaCities.json');
      final map = (jsonDecode(raw) as Map<String, dynamic>)['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _cities = {for (final e in map.entries) e.key: (e.value as List).cast<Map<String, dynamic>>()};
        _city ??= _cities.containsKey('Nairobi') ? 'Nairobi' : null;
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _areas => _cities[_city] ?? const [];

  Future<String?> _pickFromList(String title, List<String> options) =>
      showCanopySheet<String>(context, tall: true, builder: (_) => _ListSheet(title: title, options: options));

  Future<void> _pickCity() async {
    final v = await _pickFromList('City or county', _cities.keys.toList()..sort());
    if (v != null) {
      setState(() {
        _city = v;
        _area = null;
        _lat = _lng = 0;
        _pin = null;
      });
    }
  }

  Future<void> _pickArea() async {
    final v = await _pickFromList('Area', [for (final a in _areas) a['area'] as String? ?? ''].where((a) => a.isNotEmpty).toList());
    if (v == null) return;
    final d = _areas.firstWhere((a) => a['area'] == v, orElse: () => {});
    final c = d['coordinates'] as Map<String, dynamic>? ?? {};
    setState(() {
      _area = v;
      _lat = (c['lat'] as num?)?.toDouble() ?? 0;
      _lng = (c['lng'] as num?)?.toDouble() ?? 0;
    });
  }

  /// The exact spot, chosen on a map (or from where you're standing). Every
  /// event has one, so it shows on the Events map.
  Future<void> _pickPin() async {
    final start = _pin ?? (_lat != 0 || _lng != 0 ? LatLng(_lat, _lng) : null);
    final at = await pickPin(context, initial: start, title: 'Where is the event?');
    if (at != null) setState(() => _pin = at);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickImage(int slot) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f != null && mounted) setState(() => _images[slot] = f);
  }

  String? get _error {
    if (_images[0] == null) return 'Add a cover photo.';
    if (_title.text.trim().isEmpty) return 'Give the activity a title.';
    if (_city == null) return 'Choose a city.';
    if (_pin == null) return 'Pin the exact location of the event on the map.';
    if (_date == null || _time == null) return 'Pick a date and a time.';
    return null;
  }

  Future<void> _create() async {
    setState(() => _showErrors = true);
    if (_error != null) return;
    final at = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    setState(() => _saving = true);
    try {
      final user = Provider.of<F_User?>(context, listen: false);
      final orgId = widget.orgId ?? await user?.orgId;
      // Opened from an org context but the org couldn't be confirmed —
      // writing now would orphan the event. Stop instead.
      if (widget.returnOnSuccess && orgId == null) {
        if (mounted) {
          showCanopySnack(context, "Couldn't confirm your organisation. Check your connection and try again.", error: true);
        }
        return;
      }
      String? organizerName;
      if (orgId != null) {
        try {
          final o = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
          organizerName = (o.data()?['org_name'] ?? o.data()?['name']) as String?;
        } catch (_) {}
      }
      final id = await ActivityService().createActivity(
        type: _type,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        location: ActivityLocation(area: _area ?? _city!, city: _city!, venue: _venue.text.trim(), lat: _pin!.latitude, lng: _pin!.longitude).toMap(),
        dateTime: at,
        requiredParticipants: _spots,
        createdBy: user?.uid,
        orgId: orgId,
        organizerName: organizerName,
        images: _images,
        registrationState: _registration,
      );
      if (!mounted) return;
      showCanopySnack(context, 'Activity published.');
      if (widget.returnOnSuccess) {
        Navigator.pop(context, id);
      } else {
        await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: id)));
      }
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't publish the activity. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    const gap = SizedBox(height: CanopySpace.s16);
    Widget eyebrow(String t) => Padding(
          padding: const EdgeInsets.only(top: CanopySpace.section, bottom: CanopySpace.s8),
          child: Text(t, style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
        );

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'New activity'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          // ── Photos ─────────────────────────────────────────────────────
          AspectRatio(aspectRatio: 16 / 9, child: _slot(0, p)),
          const SizedBox(height: CanopySpace.s8),
          Row(children: [
            for (var i = 1; i < 4; i++) ...[
              if (i > 1) const SizedBox(width: CanopySpace.s8),
              Expanded(child: AspectRatio(aspectRatio: 1, child: _slot(i, p))),
            ],
          ]),
          const SizedBox(height: CanopySpace.s4),
          Text('The first photo is the cover.', style: CanopyType.caption.copyWith(color: p.inkMuted)),

          // ── What ───────────────────────────────────────────────────────
          eyebrow('WHAT'),
          CanopyTextField(label: 'Title', hint: 'e.g. Saturday river clean-up', controller: _title, maxLength: 80, onChanged: (_) => setState(() {})),
          gap,
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final c in _categories)
              CanopyFilterChip(label: c.$2, icon: c.$3, selected: _type == c.$1, onTap: () => setState(() => _type = c.$1)),
          ]),
          gap,
          CanopyTextField(
            label: 'Description',
            hint: 'What people will do, what to bring',
            controller: _desc,
            minLines: 3,
            maxLines: 8,
            maxLength: 1500,
          ),

          // ── Where ──────────────────────────────────────────────────────
          eyebrow('WHERE'),
          CanopyPickerField(
            label: 'City or county',
            value: _city,
            placeholder: 'Choose',
            icon: Icons.location_city_outlined,
            onTap: _pickCity,
          ),
          if (_city != null && _areas.isNotEmpty) ...[
            gap,
            CanopyPickerField(label: 'Area', value: _area, placeholder: 'Choose', icon: Icons.place_outlined, onTap: _pickArea),
          ],
          gap,
          CanopyPickerField(
            label: 'Exact location (required)',
            value: _pin == null ? null : '${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
            placeholder: 'Pin it on the map',
            icon: Icons.push_pin_outlined,
            onTap: _pickPin,
          ),
          gap,
          CanopyTextField(label: 'Meeting point (optional)', hint: 'e.g. Gate 2, Karura Forest', controller: _venue),

          // ── When ───────────────────────────────────────────────────────
          eyebrow('WHEN'),
          Row(children: [
            Expanded(
              child: CanopyPickerField(
                label: 'Date',
                value: _date == null ? null : DateFormat('EEE d MMM').format(_date!),
                placeholder: 'Pick',
                icon: Icons.calendar_today_outlined,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: CanopyPickerField(
                label: 'Time',
                value: _time?.format(context),
                placeholder: 'Pick',
                icon: Icons.schedule,
                onTap: _pickTime,
              ),
            ),
          ]),

          // ── Who ────────────────────────────────────────────────────────
          eyebrow('WHO'),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Spots', style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                Text('How many people you need', style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ]),
            ),
            CanopyIconButton(
              icon: Icons.remove,
              tooltip: 'Fewer spots',
              onPressed: _spots > 1 ? () => setState(() => _spots = _spots > 5 ? _spots - 5 : _spots - 1) : null,
            ),
            SizedBox(
              width: 48,
              child: Text('$_spots', textAlign: TextAlign.center, style: CanopyType.title.copyWith(color: p.ink)),
            ),
            CanopyIconButton(
              icon: Icons.add,
              tooltip: 'More spots',
              onPressed: () => setState(() => _spots = _spots >= 5 ? _spots + 5 : _spots + 1),
            ),
          ]),
          gap,
          CanopySegmented<RegistrationState>(
            options: const [(RegistrationState.open, 'Registration open'), (RegistrationState.closed, 'Closed for now')],
            value: _registration,
            onChanged: (v) => setState(() => _registration = v),
          ),
          if (_showErrors && _error != null)
            Padding(
              padding: const EdgeInsets.only(top: CanopySpace.s16),
              child: Text(_error!, style: CanopyType.body.copyWith(color: p.danger)),
            ),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(label: 'Publish activity', expand: true, loading: _saving, onPressed: _create),
      ]),
    );
  }

  Widget _slot(int i, CanopyPalette p) {
    final f = _images[i];
    return ClipRRect(
      borderRadius: BorderRadius.circular(CanopyRadius.sm),
      child: Material(
        color: p.surfaceMuted,
        child: InkWell(
          onTap: () => _pickImage(i),
          child: Stack(fit: StackFit.expand, children: [
            if (f != null)
              Image.file(File(f.path), fit: BoxFit.cover)
            else
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: _showErrors && i == 0 ? p.danger : p.inkMuted),
                  if (i == 0) Text('Add a cover photo', style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ]),
              ),
            if (f != null)
              Positioned(
                top: 4,
                right: 4,
                child: CanopyIconButton(
                  icon: Icons.close,
                  tooltip: 'Remove photo',
                  onImage: true,
                  onPressed: () => setState(() => _images[i] = null),
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
