import 'package:flutter/material.dart';

class RoleCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const RoleCard({super.key, required this.title, required this.subtitle, required this.icon, required this.accent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? accent : Colors.grey.shade200, width: selected ? 2.5 : 1.5),
          boxShadow: selected
              ? [BoxShadow(color: accent.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: selected ? accent : accent.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: selected ? Colors.white : accent, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: selected ? accent : Colors.black87)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
