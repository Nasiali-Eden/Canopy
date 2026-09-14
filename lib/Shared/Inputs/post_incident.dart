// lib/Shared/Inputs/post_incident.dart
//
// Report an environmental issue (a problem someone observed — dumping,
// burning, a blocked waterway, deforestation), distinct from Contributions
// (work a member did themselves, logged via LogContributionScreen). The two
// are separate concepts on purpose: this screen and the `Incidents`
// collection behind it existed before but were never reachable — no route,
// no entry point anywhere in the app — and unconditionally redirected to
// `/contributions/log` on build. That redirect is removed here and this is
// wired up as its own real screen; see IncidentsService/IncidentReport for
// the read side and IncidentsFeedScreen for where reports are displayed.
//
// JUDGMENT CALL: the original category list (Fire/Accident/Health/Floods/
// Other) read like a generic emergency-report app, not Canopy's
// environmental focus. Replaced with the categories the verification-system
// brief actually describes (dumping/burning/waterway/deforestation/other).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../Services/Incidents/incident_upload.dart';
import '../../Services/Incidents/map_selection.dart';
import '../../Community/Incidents/incidents_feed_screen.dart';
import '../theme/app_theme.dart';

class _IncidentCategory {
  final String id;
  final String label;
  final IconData icon;
  const _IncidentCategory(this.id, this.label, this.icon);
}

const List<_IncidentCategory> _kCategories = [
  _IncidentCategory('Plastic Dumpsite', 'Plastic Dumpsite', Icons.delete_outline_rounded),
  _IncidentCategory('Illegal Burning', 'Illegal Burning', Icons.local_fire_department_outlined),
  _IncidentCategory('Blocked Waterway', 'Blocked Waterway', Icons.water_outlined),
  _IncidentCategory('Deforested Area', 'Deforested Area', Icons.forest_outlined),
  _IncidentCategory('Other', 'Other', Icons.report_gmailerrorred_outlined),
];

class PostIncident extends StatefulWidget {
  const PostIncident({super.key});

  @override
  State<PostIncident> createState() => _PostIncidentState();
}

class _PostIncidentState extends State<PostIncident> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _headlineController = TextEditingController();
  final UploadIncident _uploadIncident = UploadIncident();

  String _selectedType = '';
  LatLng? _selectedLatLng;
  List<File> _selectedImages = [];
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _headlineController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    List<File> images = await _uploadIncident.pickAndCropImages();
    if (!mounted) return;
    setState(() => _selectedImages = images);
  }

  Future<void> _getCurrentLocation() async {
    String? location = await _uploadIncident.getCurrentLocation();
    if (location != null) {
      List<String> latLng = location.split(",");
      if (!mounted) return;
      setState(() {
        _selectedLatLng =
            LatLng(double.parse(latLng[0]), double.parse(latLng[1]));
      });
    }
  }

  Future<void> _selectCustomLocation() async {
    LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapSelectionScreen()),
    );

    if (selectedLocation != null && mounted) {
      setState(() {
        _selectedLatLng = selectedLocation;
      });
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _postIncident() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedType.isEmpty) {
      _showSnack('Please pick a category.', Colors.orange.shade700);
      return;
    }
    if (_selectedLatLng == null) {
      _showSnack('Please set a location.', Colors.orange.shade700);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _uploadIncident.uploadIncident(
        headline: _headlineController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        images: _selectedImages,
        customLocation: _selectedLatLng,
        context: context,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncidentsFeedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.tertiary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 15, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Report an Issue',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        actions: [
          TextButton(
            onPressed: _openReports,
            child: const Text('Reports',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Category'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kCategories.map((c) {
                    final sel = _selectedType == c.id;
                    return ChoiceChip(
                      label: Text(c.label),
                      avatar: Icon(c.icon,
                          size: 16,
                          color: sel ? Colors.white : AppTheme.darkGreen),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppTheme.darkGreen,
                      ),
                      selected: sel,
                      selectedColor: AppTheme.primary,
                      backgroundColor: Colors.white,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: sel
                              ? AppTheme.primary
                              : AppTheme.lightGreen.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedType = c.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                const _Label('Headline'),
                const SizedBox(height: 10),
                _field(_headlineController, 'Dumping behind the market stalls'),
                const SizedBox(height: 22),

                const _Label('Description'),
                const SizedBox(height: 10),
                _field(
                  _descriptionController,
                  "What's happening, how long it's been there, anything else verifiers should know…",
                  maxLines: 4,
                ),
                const SizedBox(height: 22),

                const _Label('Location'),
                const SizedBox(height: 10),
                _LocationCard(
                  selected: _selectedLatLng,
                  onUseCurrent: _getCurrentLocation,
                  onChooseOnMap: _selectCustomLocation,
                ),
                const SizedBox(height: 22),

                _Label('Photo Evidence',
                    trailing: '${_selectedImages.length}/4'),
                const SizedBox(height: 10),
                _PhotoRow(images: _selectedImages, onAdd: _pickImages),
                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppTheme.tertiary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 17, color: Color(0xFF7A6329)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your report is visible on the Reported Issues feed right away. '
                          'A status moves it through review as the app\'s verification '
                          'process comes online — this is not yet tied to an automatic '
                          'verifier queue.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF7A6329), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _submitting ? null : _postIncident,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Submit Report',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.darkGreen, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.35), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? trailing;
  const _Label(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
                letterSpacing: 0.3)),
        if (trailing != null) ...[
          const Spacer(),
          Text(trailing!,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.5))),
        ],
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LatLng? selected;
  final VoidCallback onUseCurrent;
  final VoidCallback onChooseOnMap;

  const _LocationCard({
    required this.selected,
    required this.onUseCurrent,
    required this.onChooseOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on,
                  color: selected != null
                      ? AppTheme.primary
                      : AppTheme.darkGreen.withOpacity(0.4),
                  size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected != null
                      ? '${selected!.latitude.toStringAsFixed(5)}, ${selected!.longitude.toStringAsFixed(5)}'
                      : 'Location not set',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected != null
                          ? AppTheme.darkGreen
                          : AppTheme.darkGreen.withOpacity(0.55)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onUseCurrent,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Use My Location',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onChooseOnMap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Choose on Map',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final List<File> images;
  final VoidCallback onAdd;
  const _PhotoRow({required this.images, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...images.map((f) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(f, width: 76, height: 76, fit: BoxFit.cover),
            )),
        if (images.length < 4)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.darkGreen.withOpacity(0.25),
                    style: BorderStyle.solid),
              ),
              child: Icon(Icons.add,
                  color: AppTheme.darkGreen.withOpacity(0.5), size: 24),
            ),
          ),
      ],
    );
  }
}
