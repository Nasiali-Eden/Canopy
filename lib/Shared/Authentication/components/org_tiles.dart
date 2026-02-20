import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/org_taxonomy_models.dart';

class OrgTypeCard extends StatelessWidget {
  final OrgType type;
  final bool selected;
  final VoidCallback onTap;

  const OrgTypeCard({super.key, required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${type.color.replaceFirst('#', '')}', radix: 16));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 2 : 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: selected ? color : color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.business_center_outlined, color: selected ? Colors.white : color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected ? color : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(type.description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

class DesignationTile extends StatelessWidget {
  final LegalDesignation designation;
  final bool selected;
  final VoidCallback onTap;

  const DesignationTile({super.key, required this.designation, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.primary : Colors.grey.shade200, width: selected ? 2 : 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(color: selected ? AppTheme.primary : AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(designation.acronym, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppTheme.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(designation.fullForm, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(designation.description, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ),
            if (selected) Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class BeneficiaryChip extends StatelessWidget {
  final BeneficiaryGroup group;
  final bool selected;
  final VoidCallback onTap;

  const BeneficiaryChip({super.key, required this.group, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${group.color.replaceFirst('#', '')}', radix: 16));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: selected ? color : color.withOpacity(0.07), borderRadius: BorderRadius.circular(22), border: Border.all(color: selected ? color : color.withOpacity(0.3), width: selected ? 0 : 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, size: 16),
          const SizedBox(width: 6),
          Text(group.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : color)),
        ]),
      ),
    );
  }
}

class FacilityTile extends StatelessWidget {
  final String id, label, icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const FacilityTile({super.key, required this.id, required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: selected ? color.withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 2 : 1.5)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: selected ? color : color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.apartment_outlined, color: selected ? Colors.white : color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? color : Colors.black87))),
          if (selected) Icon(Icons.check_circle, color: color, size: 20),
        ]),
      ),
    );
  }
}
