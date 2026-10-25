// lib/Shared/Inputs/post_incident.dart
//
// Report an issue (v2): something someone saw — dumping, burning, a blocked
// waterway, cleared trees. Distinct from Contributions (work you did).
// Category → what → where (GPS or pin, plus a landmark) → photos → send.
// On success it opens your reports; on failure it says so and keeps the form.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Community/Incidents/incidents_feed_screen.dart';
import '../../Services/Incidents/incident_upload.dart';
import '../../Services/Incidents/map_selection.dart';
import '../../theme/canopy_components.dart';

const List<(String, IconData)> kIncidentCategories = [
  ('Plastic Dumpsite', Icons.delete_outline),
  ('Illegal Burning', Icons.local_fire_department_outlined),
  ('Blocked Waterway', Icons.water_outlined),
  ('Deforested Area', Icons.forest_outlined),
  ('Other', Icons.report_outlined),
];

IconData incidentTypeIcon(String type) =>
    kIncidentCategories.firstWhere((c) => c.$1 == type, orElse: () => kIncidentCategories.last).$2;

class PostIncident extends StatefulWidget {
  const PostIncident({super.key});

  @override
  State<PostIncident> createState() => _PostIncidentState();
}

class _PostIncidentState extends State<PostIncident> {
  final _headline = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _upload = UploadIncident();

  String? _type;
  LatLng? _position;
  bool _positionIsGps = false, _locating = false, _sending = false, _showErrors = false;
  final List<File> _photos = [];
  String? _progress;

  @override
  void dispose() {
    for (final c in [_headline, _description, _place]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    final here = await _upload.currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (here != null) {
        _position = here;
        _positionIsGps = true;
      }
    });
    if (here == null) showCanopySnack(context, "Couldn't get your location. Pick the spot on the map.", error: true);
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => MapSelectionScreen(initial: _position)));
    if (picked != null && mounted) {
      setState(() {
        _position = picked;
        _positionIsGps = false;
      });
    }
  }

  Future<void> _addPhotos({bool camera = false}) async {
    final room = UploadIncident.maxPhotos - _photos.length;
    if (room <= 0) return;
    try {
      final files = camera ? [if (await _upload.takePhoto() case final f?) f] : await _upload.pickImages(max: room);
      if (mounted) setState(() => _photos.addAll(files.take(room)));
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't open photos. Check the app's permissions.", error: true);
    }
  }

  String? get _blocker {
    if (_type == null) return 'Pick what kind of problem it is.';
    if (_headline.text.trim().isEmpty) return 'Add a short headline.';
    if (_position == null) return 'Set where it is.';
    return null;
  }

  Future<void> _send() async {
    setState(() => _showErrors = true);
    final b = _blocker;
    if (b != null) {
      showCanopySnack(context, b, error: true);
      return;
    }
    setState(() {
      _sending = true;
      _progress = _photos.isEmpty ? null : 'Uploading photos 0 of ${_photos.length}';
    });
    try {
      await _upload.uploadIncident(
        headline: _headline.text.trim(),
        description: _description.text.trim(),
        type: _type!,
        images: _photos,
        position: _position!,
        place: _place.text.trim(),
        onProgress: (d, t) {
          if (mounted) setState(() => _progress = 'Uploading photos $d of $t');
        },
      );
      if (!mounted) return;
      showCanopySnack(context, 'Report sent.');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IncidentsFeedScreen(initialMine: true)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _progress = null;
        });
        showCanopySnack(context, "Couldn't send the report. Check your connection and try again.", error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Report an issue', actions: [
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentsFeedScreen())),
          child: const Text('Reports'),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Text('Something wrong in your area? Tell organisations nearby.', style: CanopyType.body.copyWith(color: p.inkMuted)),
          const CanopySectionHeader(title: 'What is it?', padding: EdgeInsets.only(top: CanopySpace.section)),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final (label, icon) in kIncidentCategories)
              CanopyFilterChip(label: label, icon: icon, selected: _type == label, onTap: () => setState(() => _type = label)),
          ]),
          if (_showErrors && _type == null) ...[
            const SizedBox(height: CanopySpace.s4),
            Text('Pick one.', style: CanopyType.caption.copyWith(color: p.danger)),
          ],
          const SizedBox(height: CanopySpace.section),
          CanopyTextField(
            label: 'Headline',
            hint: 'e.g. Dumping behind the market stalls',
            controller: _headline,
            error: _showErrors && _headline.text.trim().isEmpty ? 'Add a short headline.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'What did you see? (optional)',
            hint: 'How big, how long it has been there, anything that helps',
            controller: _description,
            maxLines: 4,
          ),
          const CanopySectionHeader(title: 'Where is it?', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.my_location,
              title: _locating ? 'Finding you…' : 'Use where I am',
              subtitle: _position != null && _positionIsGps ? 'Pinned from your GPS' : null,
              trailing: _position != null && _positionIsGps ? Icon(Icons.check_circle, color: p.success) : null,
              chevron: false,
              onTap: _locating ? null : _useGps,
            ),
            CanopyListRow(
              icon: Icons.map_outlined,
              title: 'Pick on the map',
              subtitle: _position != null && !_positionIsGps ? 'Pinned on the map' : null,
              trailing: _position != null && !_positionIsGps ? Icon(Icons.check_circle, color: p.success) : null,
              onTap: _pickOnMap,
            ),
          ]),
          if (_showErrors && _position == null) ...[
            const SizedBox(height: CanopySpace.s4),
            Text('Set where it is.', style: CanopyType.caption.copyWith(color: p.danger)),
          ],
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(label: 'Landmark (optional)', hint: 'e.g. Behind Toi Market, near the footbridge', controller: _place),
          Row(children: [
            const Expanded(child: CanopySectionHeader(title: 'Photos', padding: EdgeInsets.only(top: CanopySpace.section))),
            Padding(
              padding: const EdgeInsets.only(top: CanopySpace.section),
              child: Text('${_photos.length} of ${UploadIncident.maxPhotos}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ),
          ]),
          SizedBox(
            height: 88,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < _photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: CanopySpace.s8),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(CanopyRadius.sm),
                      child: Image.file(_photos[i], width: 88, height: 88, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: CanopyIconButton(
                        icon: Icons.close,
                        tooltip: 'Remove photo',
                        onImage: true,
                        onPressed: () => setState(() => _photos.removeAt(i)),
                      ),
                    ),
                  ]),
                ),
              if (_photos.length < UploadIncident.maxPhotos) ...[
                _AddTile(icon: Icons.photo_camera_outlined, label: 'Camera', onTap: () => _addPhotos(camera: true)),
                const SizedBox(width: CanopySpace.s8),
                _AddTile(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: _addPhotos),
              ],
            ]),
          ),
          const SizedBox(height: CanopySpace.section),
          const CanopyCallout(
            kind: CalloutKind.info,
            text: 'Anyone signed in can see this report. It starts as Pending; no one reviews reports yet.',
          ),
        ],
      ),
      sticky: StickyActionBar(children: [
        if (_progress != null) ...[
          Text(_progress!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s8),
        ],
        CanopyButton(label: 'Send report', expand: true, loading: _sending, onPressed: _sending ? null : _send),
      ]),
    );
  }
}

class _AddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Semantics(
      button: true,
      label: 'Add photo from $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        child: DashedBorder(
          color: p.outlineStrong,
          child: SizedBox(
            width: 88,
            height: 88,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: p.inkMuted),
              const SizedBox(height: CanopySpace.s4),
              Text(label, style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
          ),
        ),
      ),
    );
  }
}
