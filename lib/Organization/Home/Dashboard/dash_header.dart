import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Models/organization.dart';
import '../../../Shared/theme/app_theme.dart';
import 'dash_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashHeader — gradient banner with org identity, stats bar, and cover support
// ─────────────────────────────────────────────────────────────────────────────

class DashHeader extends StatelessWidget {
  final Organization? org;
  final String? orgId;
  final FirebaseFirestore firestore;
  final void Function({required String fieldName, required String storagePath})
      onUploadImage;
  final VoidCallback onNotifications;

  const DashHeader({
    super.key,
    required this.org,
    required this.orgId,
    required this.firestore,
    required this.onUploadImage,
    required this.onNotifications,
  });

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final w = name.trim().split(' ');
    return w.length == 1
        ? w[0][0].toUpperCase()
        : (w[0][0] + w[w.length - 1][0]).toUpperCase();
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withOpacity(0.12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  @override
  Widget build(BuildContext context) {
    final orgName     = org?.name       ?? 'Organisation';
    final designation = org?.designation;
    final city        = org?.city       ?? 'Kenya';
    final isVerified  = org?.verified   ?? false;
    final memberCount = org?.memberCount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kDashHeaderStart,
            kDashHeaderEnd.withOpacity(org?.hasCover == true ? 0.6 : 1.0),
          ],
        ),
      ),
      child: Stack(
        children: [
          if (org?.hasCover == true)
            Positioned.fill(
              child: Image.network(
                org!.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (org?.hasCover == true)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.68),
                    ],
                  ),
                ),
              ),
            ),
          if (org?.hasCover != true)
            Positioned.fill(child: CustomPaint(painter: _HeaderDecorPainter())),

          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _OrgAvatar(
                            initials: _initials(orgName),
                            logoUrl: org?.logoUrl,
                            onAddLogo: org?.hasLogo == false
                                ? () => onUploadImage(
                                      fieldName: 'logoUrl',
                                      storagePath:
                                          'organizations/$orgId/logo.jpg',
                                    )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (designation != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.tertiary.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppTheme.tertiary
                                              .withOpacity(0.3),
                                          width: 0.5),
                                    ),
                                    child: Text(
                                      designation.toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.tertiary,
                                          letterSpacing: 0.8),
                                    ),
                                  ),
                                Text(
                                  orgName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isVerified) ...[
                                      const Icon(Icons.verified,
                                          size: 11,
                                          color: AppTheme.tertiary),
                                      const SizedBox(width: 3),
                                      const Text('Verified · ',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.tertiary,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                    Icon(Icons.location_on_outlined,
                                        size: 10,
                                        color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(width: 2),
                                    Text(city,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white.withOpacity(0.55),
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _NotifButton(onTap: onNotifications),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (org?.hasCover == false)
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => onUploadImage(
                              fieldName: 'coverImageUrl',
                              storagePath:
                                  'organizations/$orgId/cover.jpg',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 12,
                                      color: Colors.white.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text('Add cover',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot>(
                        stream: firestore
                            .collection('orgPartners')
                            .where('orgId', isEqualTo: orgId)
                            .where('status', isEqualTo: 'active')
                            .snapshots(),
                        builder: (context, partnerSnap) {
                          final partnerCount =
                              partnerSnap.data?.docs.length ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.5),
                            ),
                            child: Row(
                              children: [
                                _HeaderStat(
                                  value: memberCount != null
                                      ? '$memberCount'
                                      : '—',
                                  label: 'Members',
                                  icon: Icons.people_outline,
                                ),
                                _divider(),
                                _HeaderStat(
                                  value: partnerSnap.hasData
                                      ? '$partnerCount'
                                      : '—',
                                  label: 'Partners',
                                  icon: Icons.handshake_outlined,
                                ),
                                _divider(),
                                _HeaderStat(
                                  value: org?.activeSinceLabel ?? '—',
                                  label: 'Active since',
                                  icon: Icons.eco_outlined,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Container(
                height: 22,
                decoration: const BoxDecoration(
                  color: kDashPageBg,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal widgets
// ─────────────────────────────────────────────────────────────────────────────

class _OrgAvatar extends StatelessWidget {
  final String initials;
  final String? logoUrl;
  final VoidCallback? onAddLogo;
  const _OrgAvatar({required this.initials, this.logoUrl, this.onAddLogo});

  bool get _hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: !_hasLogo ? onAddLogo : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppTheme.tertiary.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.tertiary.withOpacity(0.2),
                    blurRadius: 14)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _hasLogo
                  ? Image.network(logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback())
                  : _fallback(),
            ),
          ),
          if (!_hasLogo)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                    color: AppTheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)),
                child: const Icon(Icons.add, size: 11, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D7A4F), Color(0xFF3B8A7A)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
      );
}

class _NotifButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withOpacity(0.18), width: 0.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 20),
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: AppTheme.tertiary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _HeaderStat(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1)),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 9, color: Colors.white.withOpacity(0.45)),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    p
      ..color = const Color(0xFF4A9B6E).withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.1), size.width * 0.38, p);
    p
      ..color = const Color(0xFF3B8A7A).withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(
        Offset(size.width * 0.08, size.height * 0.75), size.width * 0.25, p);
    p
      ..color = const Color(0xFFC4A961).withOpacity(0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(
        Offset(size.width * 0.55, size.height * 0.45), size.width * 0.15, p);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = null;
    ring.color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.6), 80, ring);
    ring.color = Colors.white.withOpacity(0.03);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.6), 130, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
