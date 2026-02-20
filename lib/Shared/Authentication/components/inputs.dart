import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class InputHelpers {
  static InputDecoration inputDec({String? label, String? hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF1a1a1a), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  static Widget sectionHeader(IconData icon, String title, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.darkGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
        ),
      ],
    );
  }

  static Widget primaryButton({required String label, VoidCallback? onPressed, bool loading = false}) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
    );
  }

  static Color hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class PrimaryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const PrimaryTextField({super.key, required this.controller, required this.label, required this.icon, this.hint, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      keyboardType: keyboardType,
      decoration: InputHelpers.inputDec(label: label, icon: icon, hint: hint),
      validator: validator,
    );
  }
}

class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  const PasswordField({super.key, required this.controller, required this.label, required this.obscure, required this.onToggle, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: InputHelpers.inputDec(label: label, icon: Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black54),
          onPressed: onToggle,
        ),
      ),
      validator: validator ?? (v) => v!.length < 6 ? 'At least 6 characters' : null,
    );
  }
}

class TextAreaField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int maxWords;
  const TextAreaField({super.key, required this.controller, this.hint, this.maxWords = 150});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 5,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: InputHelpers.inputDec(hint: hint ?? '', icon: Icons.notes).copyWith(alignLabelWithHint: true),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Please provide a background description';
        final wordCount = v.trim().split(RegExp(r'\s+')).length;
        if (wordCount > maxWords) return 'Maximum $maxWords words (currently $wordCount words)';
        return null;
      },
    );
  }
}
