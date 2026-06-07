// lib/Organization/Map/org_map_ops.dart
//
// Allows org reps to add community map pins (amenities, dumpsites, landmarks).
// Opened from the community map; roles determine available pin types.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PIN TYPE MODEL
// ─────────────────────────────────────────────────────────────────────────────

enum _PinRole { all, envOps, specialOps }

class _PinType {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final _PinRole role;
  final bool hasDumpsteFields; // needs managing-org section

  const _PinType({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.role,
    this.hasDumpsteFields = false,
  });
}

const _allPinTypes = <_PinType>[
  // ── Common — all orgs ─────────────────────────────────────────────────────
  _PinType(
    id: 'police_station',
    label: 'Police Station',
    description: 'Police post or station in the community',
    icon: Icons.local_police_outlined,
    color: Color(0xFF1565C0),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'public_toilet',
    label: 'Public Toilet',
    description: 'Public washroom or sanitation facility',
    icon: Icons.wc_outlined,
    color: Color(0xFF6A1B9A),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'water_point',
    label: 'Water Point',
    description: 'Borehole, tap, or public water access',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF1E88E5),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'community_center',
    label: 'Community Centre',
    description: 'Community hall, meeting place, or gathering spot',
    icon: Icons.people_outlined,
    color: Color(0xFF00838F),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'market',
    label: 'Market / Trading Area',
    description: 'Local market, duka cluster, or street market',
    icon: Icons.storefront_outlined,
    color: Color(0xFFEF6C00),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'school',
    label: 'School',
    description: 'Primary, secondary, or informal learning centre',
    icon: Icons.school_outlined,
    color: Color(0xFF0277BD),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'health_clinic',
    label: 'Health Clinic / Dispensary',
    description: 'Clinic, dispensary, or health post',
    icon: Icons.local_hospital_outlined,
    color: Color(0xFFAD1457),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'place_of_worship',
    label: 'Place of Worship',
    description: 'Church, mosque, temple, or shrine',
    icon: Icons.church_outlined,
    color: Color(0xFF4E342E),
    role: _PinRole.all,
  ),
  _PinType(
    id: 'landmark',
    label: 'Community Landmark',
    description: 'Notable local landmark or point of interest',
    icon: Icons.location_city_outlined,
    color: Color(0xFF455A64),
    role: _PinRole.all,
  ),

  // ── Environmental orgs ─────────────────────────────────────────────────────
  _PinType(
    id: 'dumpsite',
    label: 'Dumpsite',
    description: 'Active or monitored waste disposal site',
    icon: Icons.delete_outline,
    color: Color(0xFFE53935),
    role: _PinRole.envOps,
    hasDumpsteFields: true,
  ),
  _PinType(
    id: 'recycling_dropoff',
    label: 'Recycling Drop-Off',
    description: 'Designated point for recyclable materials',
    icon: Icons.recycling,
    color: Color(0xFF43A047),
    role: _PinRole.envOps,
  ),
  _PinType(
    id: 'tree_site',
    label: 'Tree Planting Site',
    description: 'Active or planned tree planting location',
    icon: Icons.park_outlined,
    color: Color(0xFF2E7D32),
    role: _PinRole.envOps,
  ),

  // ── Special ops ────────────────────────────────────────────────────────────
  _PinType(
    id: 'cleanup_event',
    label: 'Cleanup Event',
    description: 'Scheduled or active community cleanup site',
    icon: Icons.cleaning_services_outlined,
    color: Color(0xFF00897B),
    role: _PinRole.specialOps,
  ),
  _PinType(
    id: 'canopy_hub',
    label: 'Canopy Hub',
    description: 'Official Canopy programme hub or activity centre',
    icon: Icons.solar_power_outlined,
    color: AppTheme.tertiary,
    role: _PinRole.specialOps,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class OrgMapOpsScreen extends StatefulWidget {
  final Map<String, dynamic> orgData;

  const OrgMapOpsScreen({required this.orgData, Key? key}) : super(key: key);

  @override
  State<OrgMapOpsScreen> createState() => _OrgMapOpsScreenState();
}

class _OrgMapOpsScreenState extends State<OrgMapOpsScreen> {
  GoogleMapController? _mapController;

  LatLng? _pickedLocation;
  bool _formVisible = false;

  // Form fields
  _PinType? _selectedType;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();

  // Dumpsite-only fields
  bool _selfManaged = true;
  final _linkedOrgCtrl = TextEditingController();
  String? _linkedOrgId;
  List<Map<String, dynamic>> _orgSearchResults = [];
  bool _searchingOrg = false;
  Timer? _orgSearchDebounce;

  // Image
  File? _imageFile;
  bool _uploading = false;

  final _formKey = GlobalKey<FormState>();

  bool get _isEnvOrg {
    final sector = widget.orgData['sectorId'] as String? ?? '';
    final envStatus = widget.orgData['envOpsStatus'] as String? ?? '';
    return sector == 'sector_env' || envStatus == 'approved';
  }

  bool get _isSpecialOps {
    final env = widget.orgData['envOpsStatus'] as String? ?? '';
    final mkt = widget.orgData['marketplaceStatus'] as String? ?? '';
    return env == 'approved' || mkt == 'approved';
  }

  List<_PinType> get _availableTypes {
    return _allPinTypes.where((t) {
      if (t.role == _PinRole.all) return true;
      if (t.role == _PinRole.envOps && _isEnvOrg) return true;
      if (t.role == _PinRole.specialOps && _isSpecialOps) return true;
      return false;
    }).toList();
  }

  static const _initialPosition = CameraPosition(
    target: LatLng(-1.2921, 36.8219),
    zoom: 13,
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _linkedOrgCtrl.dispose();
    _orgSearchDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Map tap ──────────────────────────────────────────────────────────────

  void _onMapTap(LatLng pos) {
    setState(() {
      _pickedLocation = pos;
      _formVisible = true;
    });
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (xFile != null) {
      setState(() => _imageFile = File(xFile.path));
    }
  }

  // ── Org search (for dumpsite linking) ────────────────────────────────────

  void _onLinkedOrgChanged(String value) {
    _orgSearchDebounce?.cancel();
    if (value.length < 2) {
      setState(() => _orgSearchResults = []);
      return;
    }
    _orgSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searchingOrg = true);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('organizations')
            .get();
        final q = value.toLowerCase();
        final results = snap.docs
            .where((d) {
              final data = d.data();
              final name = ((data['org_name'] ?? data['name'] ?? '') as String)
                  .toLowerCase();
              return name.contains(q) && d.id != widget.orgData['orgId'];
            })
            .map((d) {
              final data = d.data();
              return {
                'id': d.id,
                'name': (data['org_name'] ?? data['name'] ?? 'Unknown') as String,
                'city': data['city'] as String? ?? '',
              };
            })
            .take(5)
            .toList();
        if (mounted) setState(() => _orgSearchResults = results);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _searchingOrg = false);
      }
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap the map to place a pin')),
      );
      return;
    }
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pin type')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
        final ref = FirebaseStorage.instance
            .ref('map_pins/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      final orgId = widget.orgData['orgId'] as String? ?? '';
      final orgName =
          (widget.orgData['org_name'] ?? widget.orgData['name'] ?? '') as String;

      final Map<String, dynamic> pinData = {
        'pin_type': _selectedType!.id,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'location': GeoPoint(
          _pickedLocation!.latitude,
          _pickedLocation!.longitude,
        ),
        'image_url': imageUrl,
        'operating_hours': _hoursCtrl.text.trim().isEmpty
            ? null
            : _hoursCtrl.text.trim(),
        'added_by_org_id': orgId,
        'added_by_org_name': orgName,
        'country': widget.orgData['country'] as String? ?? 'Kenya',
        'city': widget.orgData['city'] as String? ?? '',
        'area': widget.orgData['area'] as String? ?? '',
        'is_active': true,
        'is_verified': false,
        'created_at': FieldValue.serverTimestamp(),
      };

      if (_selectedType!.hasDumpsteFields) {
        pinData['managing_org_id'] = _selfManaged ? orgId : _linkedOrgId;
        pinData['managing_org_name'] =
            _selfManaged ? orgName : _linkedOrgCtrl.text.trim();
        pinData['self_managed'] = _selfManaged;
      }

      await FirebaseFirestore.instance.collection('map_pins').add(pinData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pin added — pending community verification'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (c) => _mapController = c,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLocation!,
                      draggable: true,
                      onDragEnd: (pos) => setState(() => _pickedLocation = pos),
                    ),
                  },
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _MapIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      _pickedLocation == null
                          ? 'Tap the map to place a pin'
                          : 'Pin placed — fill in details below',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen.withOpacity(0.80),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Form sheet (slides up once pin is placed)
          if (_formVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _FormSheet(
                formKey: _formKey,
                availableTypes: _availableTypes,
                selectedType: _selectedType,
                onTypeSelected: (t) => setState(() => _selectedType = t),
                nameCtrl: _nameCtrl,
                descCtrl: _descCtrl,
                hoursCtrl: _hoursCtrl,
                imageFile: _imageFile,
                onPickImage: _pickImage,
                selfManaged: _selfManaged,
                onSelfManagedChanged: (v) => setState(() => _selfManaged = v),
                linkedOrgCtrl: _linkedOrgCtrl,
                onLinkedOrgChanged: _onLinkedOrgChanged,
                orgSearchResults: _orgSearchResults,
                searchingOrg: _searchingOrg,
                onSelectLinkedOrg: (org) {
                  setState(() {
                    _linkedOrgId = org['id'];
                    _linkedOrgCtrl.text = org['name'] ?? '';
                    _orgSearchResults = [];
                  });
                },
                uploading: _uploading,
                onSubmit: _submit,
                bottomPad: bottomPad,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _FormSheet extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<_PinType> availableTypes;
  final _PinType? selectedType;
  final ValueChanged<_PinType> onTypeSelected;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController hoursCtrl;
  final File? imageFile;
  final VoidCallback onPickImage;
  final bool selfManaged;
  final ValueChanged<bool> onSelfManagedChanged;
  final TextEditingController linkedOrgCtrl;
  final ValueChanged<String> onLinkedOrgChanged;
  final List<Map<String, dynamic>> orgSearchResults;
  final bool searchingOrg;
  final ValueChanged<Map<String, dynamic>> onSelectLinkedOrg;
  final bool uploading;
  final VoidCallback onSubmit;
  final double bottomPad;

  const _FormSheet({
    required this.formKey,
    required this.availableTypes,
    required this.selectedType,
    required this.onTypeSelected,
    required this.nameCtrl,
    required this.descCtrl,
    required this.hoursCtrl,
    required this.imageFile,
    required this.onPickImage,
    required this.selfManaged,
    required this.onSelfManagedChanged,
    required this.linkedOrgCtrl,
    required this.onLinkedOrgChanged,
    required this.orgSearchResults,
    required this.searchingOrg,
    required this.onSelectLinkedOrg,
    required this.uploading,
    required this.onSubmit,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Add to Community Map',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pin type selector
                    _SectionLabel(
                        label: 'Pin Type',
                        note: availableTypes.any((t) => t.role != _PinRole.all)
                            ? 'Showing types available for your org role'
                            : null),
                    const SizedBox(height: 8),
                    _PinTypeGrid(
                      types: availableTypes,
                      selected: selectedType,
                      onSelect: onTypeSelected,
                    ),
                    const SizedBox(height: 16),

                    // Name
                    _SectionLabel(label: 'Name'),
                    const SizedBox(height: 6),
                    _TextField(
                      controller: nameCtrl,
                      hint: 'e.g. Kangemi Police Post',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Description
                    _SectionLabel(label: 'Description'),
                    const SizedBox(height: 6),
                    _TextField(
                      controller: descCtrl,
                      hint: 'Brief description of this place',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Image
                    _SectionLabel(label: 'Photo (optional)'),
                    const SizedBox(height: 6),
                    _ImagePicker(
                        imageFile: imageFile, onTap: onPickImage),
                    const SizedBox(height: 14),

                    // Operating hours
                    _SectionLabel(label: 'Operating Hours (optional)'),
                    const SizedBox(height: 6),
                    _TextField(
                      controller: hoursCtrl,
                      hint: 'e.g. Mon–Fri 8am–5pm',
                    ),

                    // Dumpsite managing-org section
                    if (selectedType?.hasDumpsteFields == true) ...[
                      const SizedBox(height: 18),
                      _SectionLabel(
                        label: 'Who Manages this Dumpsite?',
                        note: 'If another registered org manages this site, '
                            'link them so their profile is connected',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ManagementToggle(
                            label: 'Our Organisation',
                            selected: selfManaged,
                            onTap: () => onSelfManagedChanged(true),
                          ),
                          const SizedBox(width: 10),
                          _ManagementToggle(
                            label: 'Link Another Org',
                            selected: !selfManaged,
                            onTap: () => onSelfManagedChanged(false),
                          ),
                        ],
                      ),
                      if (!selfManaged) ...[
                        const SizedBox(height: 12),
                        _TextField(
                          controller: linkedOrgCtrl,
                          hint: 'Search registered org by name…',
                          onChanged: onLinkedOrgChanged,
                        ),
                        if (searchingOrg)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        if (orgSearchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: orgSearchResults.map((org) {
                                return ListTile(
                                  dense: true,
                                  leading: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.lightGreen,
                                    child: Icon(Icons.business_outlined,
                                        size: 14, color: AppTheme.darkGreen),
                                  ),
                                  title: Text(org['name'] as String,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(org['city'] as String? ?? '',
                                      style: const TextStyle(fontSize: 11)),
                                  onTap: () => onSelectLinkedOrg(org),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: uploading ? null : onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: uploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Add Pin to Map',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN TYPE GRID
// ─────────────────────────────────────────────────────────────────────────────

class _PinTypeGrid extends StatelessWidget {
  final List<_PinType> types;
  final _PinType? selected;
  final ValueChanged<_PinType> onSelect;

  const _PinTypeGrid(
      {required this.types, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.90,
      ),
      itemCount: types.length,
      itemBuilder: (_, i) {
        final t = types[i];
        final isSelected = selected?.id == t.id;
        return GestureDetector(
          onTap: () => onSelect(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSelected ? t.color : t.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? t.color : t.color.withOpacity(0.20),
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon,
                    size: 24,
                    color: isSelected ? Colors.white : t.color),
                const SizedBox(height: 6),
                Text(
                  t.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.darkGreen.withOpacity(0.80),
                  ),
                ),
                if (t.role == _PinRole.envOps)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Env Ops',
                      style: TextStyle(
                        fontSize: 8,
                        color: isSelected
                            ? Colors.white.withOpacity(0.75)
                            : t.color.withOpacity(0.70),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (t.role == _PinRole.specialOps)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Special Ops',
                      style: TextStyle(
                        fontSize: 8,
                        color: isSelected
                            ? Colors.white.withOpacity(0.75)
                            : t.color.withOpacity(0.70),
                        fontWeight: FontWeight.w600,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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
                fontSize: 11,
                color: AppTheme.darkGreen.withOpacity(0.50),
              ),
            ),
          ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppTheme.darkGreen),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.35)),
        filled: true,
        fillColor: const Color(0xFFF4F6F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final File? imageFile;
  final VoidCallback onTap;
  const _ImagePicker({required this.imageFile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.20),
            style: BorderStyle.solid,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageFile != null
            ? Image.file(imageFile!, fit: BoxFit.cover, width: double.infinity)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 26, color: AppTheme.primary.withOpacity(0.60)),
                  const SizedBox(height: 5),
                  Text(
                    'Add a photo',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary.withOpacity(0.70),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ManagementToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ManagementToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.darkGreen.withOpacity(0.60),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: AppTheme.darkGreen),
      ),
    );
  }
}
