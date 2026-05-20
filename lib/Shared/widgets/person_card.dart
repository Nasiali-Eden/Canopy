import 'package:flutter/material.dart';
import '../../Organization/Home/People/org_people.dart';
import '../../Shared/theme/app_theme.dart';

class PersonCard extends StatelessWidget {
  final PersonData data;
  final bool showStatus;
  final VoidCallback? onTap;

  const PersonCard({
    super.key,
    required this.data,
    this.showStatus = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
              backgroundImage: data.avatarUrl != null
                  ? NetworkImage(data.avatarUrl!)
                  : null,
              child: data.avatarUrl == null
                  ? Text(
                      data.name.split(' ').map((e) => e[0]).join(''),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGreen,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (data.isVerified)
                        const Icon(Icons.verified, color: AppTheme.tertiary, size: 18),
                    ],
                  ),
                  Text(
                    data.role,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkGreen.withOpacity(0.7),
                    ),
                  ),
                  if (data.services.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: data.services
                          .map((s) => Chip(
                                label: Text(s, style: const TextStyle(fontSize: 10)),
                                backgroundColor: AppTheme.lightGreen.withOpacity(0.15),
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),

            if (showStatus && data.status != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.status!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.tertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}