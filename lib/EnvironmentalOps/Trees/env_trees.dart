import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../Shared/theme/app_theme.dart';
import '../Shared/zone_drawing_controller.dart';

// ─── Enums & models ───────────────────────────────────────────────────────────
enum TreeStatus { current, overdue, critical, unconfirmed }

enum VerificationStage { pending, stage1, full }

class PlantingPost {
  final String id;
  final String species;
  final int quantity;
  final DateTime plantedDate;
  final double lat, lng;
  final List<String> photoUrls;
  final VerificationStage stage;
  final DateTime? followUp30;
  final DateTime? followUp90;
  final String createdBy;

  const PlantingPost({
    required this.id,
    required this.species,
    required this.quantity,
    required this.plantedDate,
    required this.lat,
    required this.lng,
    required this.photoUrls,
    required this.stage,
    this.followUp30,
    this.followUp90,
    required this.createdBy,
  });

  factory PlantingPost.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PlantingPost(
      id: doc.id,
      species: d['species'] as String? ?? '',
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      plantedDate:
          (d['planted_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      photoUrls: List<String>.from(d['photo_urls'] as List? ?? []),
      stage: VerificationStage.values.firstWhere(
        (s) => s.name == (d['stage'] as String? ?? 'pending'),
        orElse: () => VerificationStage.pending,
      ),
      followUp30: (d['follow_up_30'] as Timestamp?)?.toDate(),
      followUp90: (d['follow_up_90'] as Timestamp?)?.toDate(),
      createdBy: d['created_by'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class EnvTreesScreen extends StatefulWidget {
  const EnvTreesScreen({super.key});

  @override
  State<EnvTreesScreen> createState() => _EnvTreesScreenState();
}

class _EnvTreesScreenState extends State<EnvTreesScreen> {
  bool _showMap = false;
  List<PlantingPost> _posts = [];
  bool _loading = true;

  static const String _mapStyle = '''
  [
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","stylers":[{"saturation":-30}]},
    {"featureType":"landscape","stylers":[{"color":"#F5F1EB"}]},
    {"featureType":"water","stylers":[{"color":"#A8C5C0"}]},
    {"featureType":"poi.park","stylers":[{"color":"#C8DCCA"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      Query q = FirebaseFirestore.instance
          .collection('planting_posts')
          .orderBy('planted_date', descending: true)
          .limit(20);
      if (uid != null) q = q.where('created_by', isEqualTo: uid);
      final snap = await q.get();
      if (mounted) {
        setState(() {
          _posts = snap.docs.map(PlantingPost.fromFirestore).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildStatStrip(),
            const SizedBox(height: 12),
            _buildMapListToggle(),
            const SizedBox(height: 12),
            _buildCreditProgress(),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _showMap
                      ? _buildMapView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPostWizard(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Planting',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildStatStrip() {
    final planted = _posts.fold(0, (s, p) => s + p.quantity);
    final verified = _posts.where(
            (p) => p.stage == VerificationStage.full).length;
    final pending = _posts.where(
            (p) => p.stage == VerificationStage.pending).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Trees Planted', '$planted')),
          const SizedBox(width: 10),
          Expanded(
              child: _buildStatCard('Fully Verified',
                  '$verified', isGood: verified > 0)),
          const SizedBox(width: 10),
          Expanded(
              child: _buildStatCard('Pending Review', '$pending',
                  isOverdue: pending > 10)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value,
      {bool isOverdue = false, bool isGood = false}) {
    Color valueColor = AppTheme.darkGreen;
    if (isOverdue) valueColor = Colors.amber;
    if (isGood) valueColor = AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: valueColor)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildMapListToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.darkGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _ToggleOption(
                label: 'List',
                active: !_showMap,
                onTap: () => setState(() => _showMap = false)),
            _ToggleOption(
                label: 'Map',
                active: _showMap,
                onTap: () => setState(() => _showMap = true)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditProgress() {
    final total = _posts.fold(0, (s, p) => s + p.quantity);
    final confirmed = _posts
        .where((p) => p.stage == VerificationStage.full)
        .fold(0, (s, p) => s + p.quantity);
    final progress = total > 0 ? confirmed / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Urban Greening Credit',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.primary)),
                const Spacer(),
                Text('$confirmed of $total trees confirmed',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkGreen.withOpacity(0.7))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              total == 0
                  ? 'Create your first planting post to start earning credits'
                  : 'Confirm ${total - confirmed} more trees at 90 days to unlock your next credit',
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.darkGreen.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.park_outlined,
                size: 48, color: AppTheme.primary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('No planting posts yet',
                style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.darkGreen.withOpacity(0.5))),
            const SizedBox(height: 6),
            Text('Tap "New Planting" to record your first post',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkGreen.withOpacity(0.35))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PlantingPostCard(post: _posts[i]),
    );
  }

  Widget _buildMapView() {
    final markers = _posts.map((p) {
      final hue = p.stage == VerificationStage.full
          ? BitmapDescriptor.hueGreen
          : p.stage == VerificationStage.stage1
              ? BitmapDescriptor.hueCyan
              : BitmapDescriptor.hueOrange;
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: p.species,
          snippet: '${p.quantity} trees · ${p.stage.name}',
        ),
      );
    }).toSet();

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-1.3133, 36.7862),
        zoom: 14,
      ),
      onMapCreated: (c) => c.setMapStyle(_mapStyle),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: markers,
    );
  }

  void _openPostWizard() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const _PlantingWizard()),
    );
    if (result == true) _loadPosts();
  }
}

// ─── Toggle option ────────────────────────────────────────────────────────────
class _ToggleOption extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleOption(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active ? AppTheme.darkGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active
                  ? Colors.white
                  : AppTheme.darkGreen.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Post card ────────────────────────────────────────────────────────────────
class _PlantingPostCard extends StatelessWidget {
  final PlantingPost post;

  const _PlantingPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusText) = switch (post.stage) {
      VerificationStage.pending => (Colors.orange, 'Pending Review'),
      VerificationStage.stage1 => (AppTheme.accent, 'Stage 1 Verified'),
      VerificationStage.full => (AppTheme.primary, 'Fully Verified'),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 90,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.species,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.darkGreen),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (post.stage == VerificationStage.full)
                              const Icon(Icons.verified,
                                  size: 12, color: AppTheme.primary),
                            const SizedBox(width: 3),
                            Text(statusText,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.park_outlined,
                          size: 12,
                          color: AppTheme.darkGreen.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text('${post.quantity} trees',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.darkGreen.withOpacity(0.6))),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_outlined,
                          size: 12,
                          color: AppTheme.darkGreen.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                          DateFormat('d MMM yyyy').format(post.plantedDate),
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.darkGreen.withOpacity(0.6))),
                    ],
                  ),
                  if (post.followUp30 != null || post.followUp90 != null) ...[
                    const SizedBox(height: 6),
                    _FollowUpChips(post: post),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpChips extends StatelessWidget {
  final PlantingPost post;

  const _FollowUpChips({required this.post});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final chips = <Widget>[];

    if (post.followUp30 != null) {
      final overdue = now.isAfter(post.followUp30!);
      chips.add(_chip('30d check-in', overdue ? Colors.red : Colors.orange,
          overdue ? Icons.warning_amber_rounded : Icons.schedule));
    }
    if (post.followUp90 != null) {
      final overdue = now.isAfter(post.followUp90!);
      chips.add(_chip('90d check-in', overdue ? Colors.red : AppTheme.accent,
          overdue ? Icons.warning_amber_rounded : Icons.schedule));
    }

    return Row(children: chips.map((c) => Padding(
        padding: const EdgeInsets.only(right: 6), child: c)).toList());
  }

  Widget _chip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANTING POST WIZARD — 4-step stepper
// ─────────────────────────────────────────────────────────────────────────────
class _PlantingWizard extends StatefulWidget {
  const _PlantingWizard();

  @override
  State<_PlantingWizard> createState() => _PlantingWizardState();
}

class _PlantingWizardState extends State<_PlantingWizard> {
  int _step = 0;
  bool _saving = false;

  // Step 1 — Record
  final _speciesCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  DateTime _plantedDate = DateTime.now();
  Position? _gpsPosition;
  bool _gpsLoading = false;

  // Step 2 — Photos
  final List<File> _photos = [];

  // Step 3 — Map pin
  LatLng? _pinLocation;
  bool _useZone = false;
  ZoneDrawingResult? _zoneResult;

  static const _steps = ['Record', 'Photos', 'Map Pin', 'Review'];

  @override
  void initState() {
    super.initState();
    _captureGps();
  }

  @override
  void dispose() {
    _speciesCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    setState(() => _gpsLoading = true);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _gpsPosition = pos;
          _pinLocation = LatLng(pos.latitude, pos.longitude);
          _gpsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        for (final x in picked) {
          if (_photos.length < 10) _photos.add(File(x.path));
        }
      });
    }
  }

  bool get _step0Complete =>
      _speciesCtrl.text.trim().isNotEmpty &&
      int.tryParse(_quantityCtrl.text) != null &&
      int.parse(_quantityCtrl.text) > 0 &&
      _gpsPosition != null;

  bool get _step1Complete => _photos.length >= 3;

  bool get _step2Complete => _pinLocation != null || _zoneResult != null;

  void _next() {
    if (_step < 3) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final photoUrls = <String>[];

      // Upload photos to Firebase Storage
      for (int i = 0; i < _photos.length; i++) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('planting_photos/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putFile(_photos[i]);
        final url = await ref.getDownloadURL();
        photoUrls.add(url);
      }

      final now = DateTime.now();
      final vertices = _zoneResult?.vertices ?? [];
      final lat = _pinLocation?.latitude ?? _gpsPosition?.latitude ?? 0;
      final lng = _pinLocation?.longitude ?? _gpsPosition?.longitude ?? 0;

      await FirebaseFirestore.instance.collection('planting_posts').add({
        'species': _speciesCtrl.text.trim(),
        'quantity': int.parse(_quantityCtrl.text),
        'planted_date': Timestamp.fromDate(_plantedDate),
        'lat': lat,
        'lng': lng,
        'photo_urls': photoUrls,
        'stage': 'pending',
        'created_by': uid,
        'created_at': Timestamp.fromDate(now),
        'follow_up_30': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'follow_up_90': Timestamp.fromDate(now.add(const Duration(days: 90))),
        if (vertices.isNotEmpty)
          'zone_vertices': vertices
              .map((v) => {'lat': v.latitude, 'lng': v.longitude})
              .toList(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('New Planting Post',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
                fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Step indicator ──
          _StepIndicator(currentStep: _step, steps: _steps),

          // ── Content ──
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _StepRecord(
                  speciesCtrl: _speciesCtrl,
                  quantityCtrl: _quantityCtrl,
                  plantedDate: _plantedDate,
                  gpsPosition: _gpsPosition,
                  gpsLoading: _gpsLoading,
                  onDateChanged: (d) => setState(() => _plantedDate = d),
                  onRefreshGps: _captureGps,
                ),
                _StepPhotos(
                  photos: _photos,
                  onPickPhotos: _pickPhotos,
                  onRemove: (i) => setState(() => _photos.removeAt(i)),
                ),
                _StepMapPin(
                  initialPosition: _pinLocation ??
                      const LatLng(-1.3133, 36.7862),
                  useZone: _useZone,
                  zoneResult: _zoneResult,
                  onPinChanged: (pos) =>
                      setState(() => _pinLocation = pos),
                  onToggleMode: () =>
                      setState(() => _useZone = !_useZone),
                  onZoneClosed: (r) =>
                      setState(() => _zoneResult = r),
                ),
                _StepReview(
                  species: _speciesCtrl.text,
                  quantity: int.tryParse(_quantityCtrl.text) ?? 0,
                  plantedDate: _plantedDate,
                  photoCount: _photos.length,
                  pinLocation: _pinLocation,
                  zoneResult: _zoneResult,
                ),
              ],
            ),
          ),

          // ── Navigation buttons ──
          _WizardNav(
            step: _step,
            totalSteps: _steps.length,
            canProceed: [_step0Complete, _step1Complete, _step2Complete, true][_step],
            saving: _saving,
            onBack: _back,
            onNext: _next,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// ─── Step indicator ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const _StepIndicator({required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done
                            ? AppTheme.primary
                            : active
                                ? AppTheme.primary
                                : Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(steps[i],
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: active
                                ? AppTheme.primary
                                : Colors.grey)),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: done
                          ? AppTheme.primary
                          : Colors.grey.withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Wizard nav buttons ────────────────────────────────────────────────────────
class _WizardNav extends StatelessWidget {
  final int step;
  final int totalSteps;
  final bool canProceed;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _WizardNav({
    required this.step,
    required this.totalSteps,
    required this.canProceed,
    required this.saving,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x1A000000))),
      ),
      child: Row(
        children: [
          if (step > 0)
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: const Text('Back',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          if (step > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: canProceed && !saving
                  ? (step == totalSteps - 1 ? onSubmit : onNext)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      step == totalSteps - 1 ? 'Submit Post' : 'Continue',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1: Record ────────────────────────────────────────────────────────────
class _StepRecord extends StatelessWidget {
  final TextEditingController speciesCtrl;
  final TextEditingController quantityCtrl;
  final DateTime plantedDate;
  final Position? gpsPosition;
  final bool gpsLoading;
  final void Function(DateTime) onDateChanged;
  final VoidCallback onRefreshGps;

  const _StepRecord({
    required this.speciesCtrl,
    required this.quantityCtrl,
    required this.plantedDate,
    required this.gpsPosition,
    required this.gpsLoading,
    required this.onDateChanged,
    required this.onRefreshGps,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Species name *'),
          TextField(
            controller: speciesCtrl,
            decoration: _inputDecoration('e.g. Grevillea robusta'),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Quantity planted *'),
          TextField(
            controller: quantityCtrl,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Number of trees'),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Planting date *'),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: plantedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) onDateChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Text(DateFormat('d MMM yyyy').format(plantedDate),
                      style: const TextStyle(
                          color: AppTheme.darkGreen, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('GPS coordinates (auto-captured)'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: gpsPosition != null
                  ? AppTheme.primary.withOpacity(0.06)
                  : Colors.orange.withOpacity(0.06),
              border: Border.all(
                  color: gpsPosition != null
                      ? AppTheme.primary.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  gpsLoading
                      ? Icons.gps_not_fixed
                      : gpsPosition != null
                          ? Icons.gps_fixed
                          : Icons.gps_off,
                  size: 16,
                  color: gpsPosition != null ? AppTheme.primary : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: gpsLoading
                      ? const Text('Acquiring location...',
                          style: TextStyle(
                              color: Colors.orange, fontSize: 13))
                      : gpsPosition != null
                          ? Text(
                              '${gpsPosition!.latitude.toStringAsFixed(6)}, '
                              '${gpsPosition!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                  color: AppTheme.darkGreen, fontSize: 13))
                          : const Text('Location unavailable',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 13)),
                ),
                if (!gpsLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        size: 16, color: AppTheme.accent),
                    onPressed: onRefreshGps,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

// ─── Step 2: Photos ────────────────────────────────────────────────────────────
class _StepPhotos extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onPickPhotos;
  final void Function(int index) onRemove;

  const _StepPhotos({
    required this.photos,
    required this.onPickPhotos,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _FieldLabel('Site photos'),
              const Spacer(),
              Text('${photos.length}/3 minimum',
                  style: TextStyle(
                      fontSize: 12,
                      color: photos.length >= 3
                          ? AppTheme.primary
                          : Colors.orange,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Photos are automatically tagged with GPS coordinates and timestamp. '
            'Minimum 3 required for verification.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              ...List.generate(photos.length, (i) => _PhotoThumb(
                    file: photos[i],
                    onRemove: () => onRemove(i),
                  )),
              if (photos.length < 10)
                GestureDetector(
                  onTap: onPickPhotos,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.4),
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                      color: AppTheme.primary.withOpacity(0.05),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 24,
                            color: AppTheme.primary.withOpacity(0.6)),
                        const SizedBox(height: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primary.withOpacity(0.6))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 3: Map Pin ───────────────────────────────────────────────────────────
class _StepMapPin extends StatefulWidget {
  final LatLng initialPosition;
  final bool useZone;
  final ZoneDrawingResult? zoneResult;
  final void Function(LatLng) onPinChanged;
  final VoidCallback onToggleMode;
  final void Function(ZoneDrawingResult) onZoneClosed;

  const _StepMapPin({
    required this.initialPosition,
    required this.useZone,
    required this.zoneResult,
    required this.onPinChanged,
    required this.onToggleMode,
    required this.onZoneClosed,
  });

  @override
  State<_StepMapPin> createState() => _StepMapPinState();
}

class _StepMapPinState extends State<_StepMapPin> {
  LatLng? _pinPos;

  @override
  void initState() {
    super.initState();
    _pinPos = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mode toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Drop a pin',
                  icon: Icons.location_on_outlined,
                  active: !widget.useZone,
                  onTap: () {
                    if (widget.useZone) widget.onToggleMode();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeButton(
                  label: 'Draw zone',
                  icon: Icons.draw_outlined,
                  active: widget.useZone,
                  onTap: () {
                    if (!widget.useZone) widget.onToggleMode();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.useZone
              ? ZoneDrawingController(
                  config: ZoneDrawingConfig.plantingDefault,
                  onZoneClosed: widget.onZoneClosed,
                  initialPosition: CameraPosition(
                    target: widget.initialPosition,
                    zoom: 15,
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: widget.initialPosition,
                        zoom: 15,
                      ),
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onTap: (pos) {
                        setState(() => _pinPos = pos);
                        widget.onPinChanged(pos);
                      },
                      markers: _pinPos == null
                          ? {}
                          : {
                              Marker(
                                markerId: const MarkerId('planting_pin'),
                                position: _pinPos!,
                                draggable: true,
                                onDrag: (p) {
                                  setState(() => _pinPos = p);
                                  widget.onPinChanged(p);
                                },
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueCyan),
                              ),
                            },
                    ),
                    if (_pinPos == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Tap the map to drop a pin at the planting site',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? AppTheme.primary
                  : Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: active ? Colors.white : AppTheme.darkGreen),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppTheme.darkGreen)),
          ],
        ),
      ),
    );
  }
}

// ─── Step 4: Review ────────────────────────────────────────────────────────────
class _StepReview extends StatelessWidget {
  final String species;
  final int quantity;
  final DateTime plantedDate;
  final int photoCount;
  final LatLng? pinLocation;
  final ZoneDrawingResult? zoneResult;

  const _StepReview({
    required this.species,
    required this.quantity,
    required this.plantedDate,
    required this.photoCount,
    required this.pinLocation,
    required this.zoneResult,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Pending Verification',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(species,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen)),
                const SizedBox(height: 8),
                _ReviewRow(Icons.park_outlined, '$quantity trees planted'),
                _ReviewRow(Icons.calendar_today_outlined,
                    DateFormat('d MMM yyyy').format(plantedDate)),
                _ReviewRow(Icons.photo_library_outlined,
                    '$photoCount photo${photoCount == 1 ? '' : 's'} attached'),
                if (pinLocation != null)
                  _ReviewRow(
                      Icons.location_on_outlined,
                      '${pinLocation!.latitude.toStringAsFixed(5)}, '
                          '${pinLocation!.longitude.toStringAsFixed(5)}'),
                if (zoneResult != null)
                  _ReviewRow(Icons.draw_outlined,
                      'Planting zone: ${zoneResult!.vertices.length} vertices'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Follow-up check-ins will be scheduled at 30 days and 90 days. '
                    'Geotagged photos are required at the same GPS coordinates '
                    '(within 50m) to unlock Full Verification.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReviewRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.darkGreen)),
          ),
        ],
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen)),
    );
  }
}
