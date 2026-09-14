// lib/Shared/Pages/coming_soon_screen.dart
//
// Generic "deferred feature" screen — Phase 1.1 / Phase 4.1 of the Minimal
// Release Roadmap ("Services button... opening to a 'Coming soon' screen —
// the same deferred-feature pattern the Marketplace Seller doc already uses
// for its own Phase 2 blog feature"). Reusable for any not-yet-built tab or
// action so the app never routes to a dead screen.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.icon = Icons.hourglass_top_rounded,
    this.message = "We're building this out. Check back soon.",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              Text('Coming Soon',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen)),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.darkGreen.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
