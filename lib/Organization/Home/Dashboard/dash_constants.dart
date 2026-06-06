import 'package:flutter/material.dart';

const kDashPageBg      = Color(0xFFF0F3EE);
const kDashHeaderStart = Color(0xFF102A1B);
const kDashHeaderEnd   = Color(0xFF1F5539);

enum DashAttentionType { action, info }

class DashAttentionItem {
  final DashAttentionType type;
  final IconData icon;
  final String message;
  final String actionLabel;
  final String route;
  const DashAttentionItem({
    required this.type,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.route,
  });
}
