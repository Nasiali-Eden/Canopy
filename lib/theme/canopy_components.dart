// lib/theme/canopy_components.dart
//
// v2 component library (DESIGN_HANDOFF.md §1–§2). Everything here resolves to
// lib/theme/canopy_tokens.dart — no raw colours, sizes or durations in screens.
//
// Import this file (it re-exports the core tokens) in any screen migrated to
// v2. Don't also import lib/Shared/theme/app_theme.dart or
// lib/Shared/widgets/canopy_components.dart in the same file: the v1 token
// classes share names with v2 (CanopyRadius / CanopySpace / CanopyType).
//
// Global rules baked in here:
//   • status and points are typeset labels, never pills
//   • icons are bare glyphs, never on tinted wells
//   • primary button = ink fill, canvas text, radius 8, words only
//   • cards = 1px outline, no shadow; only floating things get shadows
//   • every data view has loading / empty / error / signed-out states

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'canopy_tokens.dart';

export 'canopy_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTEXT
// ─────────────────────────────────────────────────────────────────────────────

extension CanopyContext on BuildContext {
  /// The v2 palette for the current brightness.
  CanopyPalette get canopy =>
      Theme.of(this).extension<CanopyPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? CanopyPalette.dark
          : CanopyPalette.light);

  Brightness get brightness => Theme.of(this).brightness;

  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}

/// Frost blur for sticky bars and scrolled app bars.
final ui.ImageFilter canopyFrostBlur = ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16);

/// Glass blur (Heritage chrome over photos).
final ui.ImageFilter canopyGlassBlur = ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20);

/// Initials for avatars: "Green Belt Movement" → "GM".
String canopyInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// BUTTONS
// ─────────────────────────────────────────────────────────────────────────────

enum CanopyButtonVariant { primary, secondary, quiet, danger, quietDanger }

enum CanopyButtonSize { regular, compact }

/// Words only — no leading icons (v2). Loading swaps the label for a spinner
/// at the same width. Exactly one primary per screen.
class CanopyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CanopyButtonVariant variant;
  final CanopyButtonSize size;
  final bool loading;
  final bool expand;

  const CanopyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CanopyButtonVariant.primary,
    this.size = CanopyButtonSize.regular,
    this.loading = false,
    this.expand = false,
  });

  const CanopyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = CanopyButtonSize.regular,
    this.loading = false,
    this.expand = false,
  }) : variant = CanopyButtonVariant.secondary;

  const CanopyButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = CanopyButtonSize.regular,
    this.loading = false,
    this.expand = false,
  }) : variant = CanopyButtonVariant.quiet;

  const CanopyButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = CanopyButtonSize.regular,
    this.loading = false,
    this.expand = false,
  }) : variant = CanopyButtonVariant.danger;

  const CanopyButton.quietDanger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = CanopyButtonSize.regular,
    this.loading = false,
    this.expand = false,
  }) : variant = CanopyButtonVariant.quietDanger;

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final compact = size == CanopyButtonSize.compact;
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(
        compact ? CanopyRadius.buttonCompact : CanopyRadius.xs);

    Color bg = Colors.transparent;
    Color fg;
    BorderSide side = BorderSide.none;
    var underline = false;
    switch (variant) {
      case CanopyButtonVariant.primary:
        bg = enabled ? p.ink : p.surfaceMuted;
        fg = enabled ? p.canvas : p.inkFaint;
      case CanopyButtonVariant.secondary:
        fg = enabled ? p.ink : p.inkFaint;
        side = BorderSide(color: enabled ? p.ink : p.outline);
      case CanopyButtonVariant.quiet:
        fg = enabled ? p.ink : p.inkFaint;
        underline = true;
      case CanopyButtonVariant.danger:
        bg = enabled ? p.danger : p.surfaceMuted;
        fg = enabled ? p.canvas : p.inkFaint;
      case CanopyButtonVariant.quietDanger:
        fg = enabled ? p.danger : p.inkFaint;
        underline = true;
    }

    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: CanopyType.button.copyWith(
        color: fg,
        fontSize: compact ? 14 : null,
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: fg,
      ),
    );

    final content = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: loading ? 0 : 1, child: text),
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.25, color: fg),
          ),
      ],
    );

    final visualHeight = compact ? 36.0 : CanopySpace.minTouch;
    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: visualHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: underline
                    ? CanopySpace.s12
                    : (compact ? 14 : CanopySpace.s20)),
            child: Center(widthFactor: expand ? null : 1, child: content),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Padding(
        // Compact buttons are 36 visually but keep a 48 hit area.
        padding: EdgeInsets.symmetric(
            vertical: (CanopySpace.minTouch - visualHeight) / 2),
        child: expand ? SizedBox(width: double.infinity, child: button) : button,
      ),
    );
  }
}

/// 48dp icon-only button. `filled` = surface + outline; `float` = surface + e1;
/// `onImage` = dark translucent over photos.
class CanopyIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final bool float;
  final bool onImage;
  final bool dot;
  final Color? color;

  const CanopyIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.float = false,
    this.onImage = false,
    this.dot = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final bg = onImage
        ? p.scrim
        : (filled || float)
            ? p.surface
            : Colors.transparent;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: CanopySpace.minTouch,
        height: CanopySpace.minTouch,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: filled ? Border.all(color: p.outline) : null,
          boxShadow: float ? CanopyElevation.e1(context.brightness) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon,
                    size: CanopyIconSize.appBar,
                    color: color ?? (onImage ? CanopyPalette.onHero : p.ink)),
                if (dot)
                  Positioned(
                    top: 11,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.canvas, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted sticky footer carrying a screen's single primary action (+ an
/// optional caption or secondary action under it).
class StickyActionBar extends StatelessWidget {
  final List<Widget> children;
  const StickyActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return ClipRect(
      child: BackdropFilter(
        filter: canopyFrostBlur,
        child: Container(
          decoration: BoxDecoration(
            color: p.frost,
            border: Border(top: BorderSide(color: p.outline)),
          ),
          padding: EdgeInsets.fromLTRB(
            CanopySpace.gutter,
            CanopySpace.s12,
            CanopySpace.gutter,
            CanopySpace.s12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: CanopySpace.s8),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BARS
// ─────────────────────────────────────────────────────────────────────────────

/// Standard v2 app bar: canvas background, ink title, bare icon actions.
/// [large] puts the title under the bar in `display` (use with
/// [CanopyLargeTitle] in the body instead when the page scrolls).
PreferredSizeWidget canopyAppBar(
  BuildContext context, {
  String? title,
  List<Widget> actions = const [],
  Widget? leading,
  bool showBack = true,
  PreferredSizeWidget? bottom,
  bool transparent = false,
}) {
  final p = context.canopy;
  final canPop = Navigator.of(context).canPop();
  return AppBar(
    backgroundColor: transparent ? Colors.transparent : p.canvas,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: 56,
    centerTitle: false,
    titleSpacing: (showBack && canPop) || leading != null ? 0 : CanopySpace.gutter,
    systemOverlayStyle: context.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    automaticallyImplyLeading: false,
    leading: leading ??
        (showBack && canPop
            ? CanopyIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                color: transparent ? CanopyPalette.onHero : null,
                onImage: transparent,
                onPressed: () => Navigator.maybePop(context),
              )
            : null),
    title: title == null
        ? null
        : Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CanopyType.heading.copyWith(color: p.ink)),
    actions: [...actions, const SizedBox(width: CanopySpace.s4)],
    bottom: bottom,
  );
}

/// Large page title (display) with an optional caption under it.
class CanopyLargeTitle extends StatelessWidget {
  final String title;
  final String? caption;
  final String? eyebrow;
  const CanopyLargeTitle(this.title, {super.key, this.caption, this.eyebrow});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!.toUpperCase(),
                style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
            const SizedBox(height: CanopySpace.s4),
          ],
          Semantics(
            header: true,
            child: Text(title, style: CanopyType.display.copyWith(color: p.ink)),
          ),
          if (caption != null) ...[
            const SizedBox(height: CanopySpace.s4),
            Text(caption!, style: CanopyType.body.copyWith(color: p.inkMuted)),
          ],
        ],
      ),
    );
  }
}

/// Section header: `heading` title + optional "See all" link (primaryInk).
class CanopySectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  const CanopySectionHeader({
    super.key,
    required this.title,
    this.actionLabel = 'See all',
    this.onAction,
    this.padding = const EdgeInsets.only(
        left: CanopySpace.gutter, right: CanopySpace.s8, bottom: CanopySpace.s4),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title,
                    style: CanopyType.heading.copyWith(color: p.ink)),
              ),
            ),
            if (onAction != null)
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(CanopyRadius.xs),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      minHeight: CanopySpace.minTouch,
                      minWidth: CanopySpace.minTouch),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: CanopySpace.s12),
                    child: Center(
                      widthFactor: 1,
                      child: Text(actionLabel,
                          style:
                              CanopyType.label.copyWith(color: p.primaryInk)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUTS
// ─────────────────────────────────────────────────────────────────────────────

/// Label above (never floating); helper and error share one line; focus 2px
/// primary; error 2px danger. Covers phone (+254), currency (KSh), multiline
/// with counter, search, and tap-to-pick triggers (date / dropdown).
class CanopyTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final bool obscure;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const CanopyTextField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.prefixText,
    this.prefixIcon,
    this.suffix,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.obscure = false,
    this.onTap,
    this.focusNode,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.sentences,
  });

  /// Kenyan phone: "+254" prefix, digits only.
  const CanopyTextField.phone({
    super.key,
    this.label = 'Phone number',
    this.hint = '712 345 678',
    this.helper,
    this.error,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  })  : keyboardType = TextInputType.phone,
        minLines = 1,
        maxLines = 1,
        maxLength = null,
        prefixText = '+254 ',
        prefixIcon = null,
        suffix = null,
        obscure = false,
        onTap = null,
        inputFormatters = null,
        textCapitalization = TextCapitalization.none;

  /// Currency: "KSh" prefix, whole shillings only.
  CanopyTextField.money({
    super.key,
    this.label,
    this.hint = '0',
    this.helper,
    this.error,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  })  : keyboardType = TextInputType.number,
        minLines = 1,
        maxLines = 1,
        maxLength = null,
        prefixText = 'KSh ',
        prefixIcon = null,
        suffix = null,
        obscure = false,
        onTap = null,
        inputFormatters = [FilteringTextInputFormatter.digitsOnly],
        textCapitalization = TextCapitalization.none;

  /// Search: leading glyph, no label.
  const CanopyTextField.search({
    super.key,
    this.hint = 'Search',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
    this.suffix,
  })  : label = null,
        helper = null,
        error = null,
        initialValue = null,
        keyboardType = TextInputType.text,
        textInputAction = TextInputAction.search,
        minLines = 1,
        maxLines = 1,
        maxLength = null,
        prefixText = null,
        prefixIcon = Icons.search,
        readOnly = false,
        enabled = true,
        obscure = false,
        onTap = null,
        inputFormatters = null,
        textCapitalization = TextCapitalization.none;

  @override
  State<CanopyTextField> createState() => _CanopyTextFieldState();
}

class _CanopyTextFieldState extends State<CanopyTextField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final hasError = widget.error != null && widget.error!.isNotEmpty;
    final focused = _focus.hasFocus;
    final borderColor = hasError
        ? p.danger
        : focused
            ? p.primary
            : widget.enabled
                ? p.outlineStrong
                : p.outline;
    final borderWidth = (hasError || focused) ? 2.0 : 1.0;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CanopyRadius.sm),
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    );
    final bottomLine = hasError ? widget.error : widget.helper;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s4 + 2),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.controller == null ? widget.initialValue : null,
          focusNode: _focus,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          keyboardType: widget.maxLines > 1
              ? TextInputType.multiline
              : widget.keyboardType,
          textInputAction: widget.textInputAction,
          minLines: widget.minLines,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly || widget.onTap != null,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: widget.obscure,
          onTap: widget.onTap,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          style: CanopyType.body.copyWith(
              fontSize: 15,
              color: widget.enabled ? p.ink : p.inkFaint),
          cursorColor: p.primary,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: widget.enabled ? p.surface : p.surfaceMuted,
            hintText: widget.hint,
            hintStyle: CanopyType.body.copyWith(fontSize: 15, color: p.inkFaint),
            prefixText: widget.prefixText,
            prefixStyle: CanopyType.body.copyWith(
                fontSize: 15, color: p.inkMuted, fontWeight: FontWeight.w600),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon,
                    size: CanopyIconSize.button, color: p.inkMuted),
            suffixIcon: widget.suffix ??
                (widget.onTap != null
                    ? Icon(Icons.expand_more,
                        size: CanopyIconSize.button, color: p.inkMuted)
                    : null),
            counterStyle: CanopyType.caption.copyWith(color: p.inkMuted),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 15),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            disabledBorder: border,
            errorBorder: border,
            focusedErrorBorder: border,
          ),
        ),
        if (bottomLine != null && bottomLine.isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s4 + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasError) ...[
                Icon(Icons.error_outline, size: CanopyIconSize.s14, color: p.danger),
                const SizedBox(width: CanopySpace.s4 + 2),
              ],
              Expanded(
                child: Text(bottomLine,
                    style: CanopyType.caption
                        .copyWith(color: hasError ? p.danger : p.inkMuted)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Tap-to-pick field (date, dropdown). Looks like an input, opens a picker.
class CanopyPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final String? helper;
  final String? error;

  const CanopyPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Choose',
    this.icon = Icons.expand_more,
    this.helper,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final hasError = error != null && error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: CanopyType.label.copyWith(color: p.ink)),
        const SizedBox(height: CanopySpace.s4 + 2),
        Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CanopyRadius.sm),
            side: BorderSide(
                color: hasError ? p.danger : p.outlineStrong,
                width: hasError ? 2 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(CanopyRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(value ?? placeholder,
                          style: CanopyType.body.copyWith(
                              fontSize: 15,
                              color: value == null ? p.inkFaint : p.ink)),
                    ),
                    Icon(icon, size: CanopyIconSize.button, color: p.inkMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        if ((hasError ? error : helper) != null) ...[
          const SizedBox(height: CanopySpace.s4 + 2),
          Text((hasError ? error : helper)!,
              style: CanopyType.caption
                  .copyWith(color: hasError ? p.danger : p.inkMuted)),
        ],
      ],
    );
  }
}

/// Checkbox row (≥48dp), ink when on.
class CanopyCheckRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? caption;
  const CanopyCheckRow(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.label,
      this.caption});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(CanopyRadius.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? p.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: value ? null : Border.all(color: p.outlineStrong, width: 2),
              ),
              child: value
                  ? Icon(Icons.check, size: CanopyIconSize.s16, color: p.canvas)
                  : null,
            ),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: CanopyType.body.copyWith(color: p.ink)),
                  if (caption != null)
                    Text(caption!,
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radio indicator (used inside option cards).
class CanopyRadio extends StatelessWidget {
  final bool selected;
  const CanopyRadio({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? p.ink : p.outlineStrong, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.ink))
          : null,
    );
  }
}

/// Selectable option card: 1px outline; selected 2px ink + radio.
class CanopyOptionCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? caption;
  final IconData? icon;
  final Widget? trailing;
  final Widget? child;

  const CanopyOptionCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.title,
    this.caption,
    this.icon,
    this.trailing,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CanopyRadius.md),
        side: BorderSide(
            color: selected ? p.ink : p.outline, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CanopyRadius.md),
        child: Padding(
          padding: EdgeInsets.all(selected ? 15 : CanopySpace.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: CanopyIconSize.nav, color: p.ink),
                    const SizedBox(width: CanopySpace.s12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: CanopyType.subhead.copyWith(color: p.ink)),
                        if (caption != null) ...[
                          const SizedBox(height: CanopySpace.s2),
                          Text(caption!,
                              style: CanopyType.body
                                  .copyWith(color: p.inkMuted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: CanopySpace.s12),
                  trailing ?? CanopyRadio(selected: selected),
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: CanopySpace.s12),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch row: title + caption left, switch right (primary when on).
class CanopySwitchRow extends StatelessWidget {
  final String title;
  final String? caption;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const CanopySwitchRow(
      {super.key,
      required this.title,
      this.caption,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CanopySpace.rowMinHeight),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                  if (caption != null)
                    Text(caption!,
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: CanopyPalette.onHero,
              activeTrackColor: p.primary,
              inactiveThumbColor: p.surface,
              inactiveTrackColor: p.outlineStrong,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Step 2 of 4 · Details" + bars (ink done / outline todo).
class CanopyStepper extends StatelessWidget {
  final int step; // 1-based
  final int total;
  final String label;
  final List<String>? stepLabels;
  const CanopyStepper(
      {super.key,
      required this.step,
      required this.total,
      required this.label,
      this.stepLabels});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $step of $total · $label',
            style: CanopyType.label.copyWith(color: p.inkMuted)),
        const SizedBox(height: CanopySpace.s8),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: CanopySpace.s4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < step ? p.ink : p.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (stepLabels != null) ...[
          const SizedBox(height: CanopySpace.s4),
          Row(
            children: [
              for (var i = 0; i < stepLabels!.length; i++)
                Expanded(
                  child: Text(stepLabels![i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CanopyType.micro.copyWith(
                          color: i < step ? p.ink : p.inkFaint)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Segmented control — switches a *lens* on one dataset.
class CanopySegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, int>? counts;

  const CanopySegmented(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged,
      this.counts});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      padding: const EdgeInsets.all(CanopySpace.s4),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        border: Border.all(color: p.outline),
      ),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: Semantics(
                selected: v == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: CanopyMotion.tabSwitch,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? p.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: v == value ? Border.all(color: p.outline) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CanopyType.label.copyWith(
                                  fontSize: 14,
                                  color: v == value ? p.ink : p.inkMuted)),
                        ),
                        if ((counts?[v] ?? 0) > 0) ...[
                          const SizedBox(width: CanopySpace.s4 + 2),
                          CountBadge(count: counts![v]!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Underline tabs — switches between sibling *lists*.
class CanopyUnderlineTabs extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final Map<int, int>? badges;
  final bool scrollable;

  const CanopyUnderlineTabs(
      {super.key,
      required this.tabs,
      required this.index,
      required this.onChanged,
      this.badges,
      this.scrollable = false});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final items = [
      for (var i = 0; i < tabs.length; i++)
        InkWell(
          onTap: () => onChanged(i),
          child: Container(
            height: CanopySpace.minTouch,
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: i == index ? p.primary : Colors.transparent,
                    width: 3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tabs[i],
                    style: CanopyType.label.copyWith(
                        fontSize: 14, color: i == index ? p.ink : p.inkMuted)),
                if ((badges?[i] ?? 0) > 0) ...[
                  const SizedBox(width: CanopySpace.s4 + 2),
                  CountBadge(count: badges![i]!),
                ],
              ],
            ),
          ),
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.outline)),
      ),
      child: scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s8),
              child: Row(children: items),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s8),
              child: Row(children: items),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LABELS, CHIPS, BADGES
// ─────────────────────────────────────────────────────────────────────────────

/// Status is a typeset label: uppercase, status colour. `live` adds a 6px dot.
class StatusLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool live;
  final bool spinner;
  final IconData? icon;
  const StatusLabel(this.text,
      {super.key,
      required this.color,
      this.live = false,
      this.spinner = false,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (live) ...[
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: CanopySpace.s4 + 2),
        ],
        if (spinner) ...[
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.75, color: color),
          ),
          const SizedBox(width: CanopySpace.s4 + 2),
        ],
        if (icon != null) ...[
          Icon(icon, size: CanopyIconSize.s14, color: color),
          const SizedBox(width: CanopySpace.s4),
        ],
        Flexible(
          child: Text(text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CanopyType.statusLabel.copyWith(color: color)),
        ),
      ],
    );
  }
}

/// "+50 pts" in gold Bricolage numerals. Recognition only.
class PointsLabel extends StatelessWidget {
  final int points;
  final bool signed;
  final double? fontSize;
  const PointsLabel(this.points, {super.key, this.signed = true, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Text('${signed && points >= 0 ? '+' : ''}$points pts',
        style: CanopyType.points.copyWith(color: p.goldInk, fontSize: fontSize));
  }
}

/// "Your turn" marker — 7px dot + uppercase primaryInk.
class YourTurnLabel extends StatelessWidget {
  final String text;
  const YourTurnLabel({super.key, this.text = 'Your turn'});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: p.primaryInk, shape: BoxShape.circle)),
        const SizedBox(width: CanopySpace.s4),
        Text(text.toUpperCase(),
            style: CanopyType.statusLabel.copyWith(color: p.primaryInk)),
      ],
    );
  }
}

/// A row of labels separated by 1px outlineStrong hairlines with 10px padding.
class LabelRow extends StatelessWidget {
  final List<Widget> children;
  const LabelRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final visible = children.whereType<Widget>().toList();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: CanopySpace.s4,
      children: [
        for (var i = 0; i < visible.length; i++)
          Container(
            padding: EdgeInsets.only(
                left: i == 0 ? 0 : 10, right: i == visible.length - 1 ? 0 : 10),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(left: BorderSide(color: p.outlineStrong)),
            ),
            child: visible[i],
          ),
      ],
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.danger,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          style: CanopyType.micro.copyWith(
              color: context.brightness == Brightness.dark
                  ? p.canvas
                  : CanopyPalette.onHero,
              fontWeight: FontWeight.w700)),
    );
  }
}

class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
            color: context.canopy.primary, shape: BoxShape.circle),
      );
}

/// Filter chip: selected = ink fill, canvas text, no check mark.
class CanopyFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;
  final IconData? icon;
  final bool float;

  const CanopyFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    this.float = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final fg = selected ? p.canvas : p.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: selected ? p.ink : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CanopyRadius.xs),
            side: selected || float
                ? BorderSide.none
                : BorderSide(color: p.outlineStrong),
          ),
          elevation: 0,
          child: Container(
            decoration: float
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(CanopyRadius.xs),
                    boxShadow: CanopyElevation.e1(context.brightness))
                : null,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(CanopyRadius.xs),
              child: SizedBox(
                height: 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null && !selected) ...[
                        Icon(icon, size: CanopyIconSize.s16, color: fg),
                        const SizedBox(width: CanopySpace.s4 + 2),
                      ],
                      Text(label,
                          style: CanopyType.label
                              .copyWith(fontSize: 13.5, color: fg)),
                      if (count != null) ...[
                        const SizedBox(width: CanopySpace.s4 + 2),
                        Text('$count',
                            style: CanopyType.label.copyWith(
                                fontSize: 13.5,
                                color: selected
                                    ? p.canvas.withAlpha(0xB3)
                                    : p.inkMuted)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Active-filter chip with a remove affordance.
class CanopyRemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const CanopyRemovableChip(
      {super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Semantics(
      button: true,
      label: 'Remove filter $label',
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(CanopyRadius.xs),
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: CanopySpace.s12, right: 6),
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(CanopyRadius.xs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: CanopyType.label.copyWith(fontSize: 13.5, color: p.ink)),
              const SizedBox(width: CanopySpace.s4),
              Icon(Icons.close, size: CanopyIconSize.s16, color: p.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal chip rail with page gutters.
class CanopyChipRail extends StatelessWidget {
  final List<Widget> chips;
  const CanopyChipRail({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: CanopySpace.s8),
            chips[i],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARDS — the only six: Hero, Feed, Content, ListGroup/ListRow, StatTile, Callout
// ─────────────────────────────────────────────────────────────────────────────

/// Content card: surface, 1px outline, radius 16 (or [radius]), no shadow.
class CanopyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Color? color;

  const CanopyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CanopySpace.cardPadding),
    this.onTap,
    this.radius = CanopyRadius.md,
    this.borderColor,
    this.borderWidth = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    return Material(
      color: color ?? p.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor ?? p.outline, width: borderWidth),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Gradient hero (Home, Log Work, Profile header only) with hairline rings.
class CanopyHero extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const CanopyHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CanopySpace.s20),
    this.radius = CanopyRadius.xl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: context.canopy.gradientCanopy,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          const Positioned(right: -60, top: -70, child: _HeroRings()),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A tappable region on a gradient hero: ≥48dp with an accessible label.
class CanopyHeroTap extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  const CanopyHeroTap(
      {super.key, required this.label, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
          child: child,
        ),
      ),
    );
  }
}

/// Eyebrow + title + detail row on a gradient hero, chevron when tappable.
class CanopyHeroRow extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? detail;
  final VoidCallback? onTap;

  const CanopyHeroRow(
      {super.key,
      required this.eyebrow,
      required this.title,
      this.detail,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(top: CanopySpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(),
                    style: CanopyType.eyebrow
                        .copyWith(color: CanopyPalette.onHeroMuted)),
                const SizedBox(height: CanopySpace.s4),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        CanopyType.subhead.copyWith(color: CanopyPalette.onHero)),
                if (detail != null)
                  Text(detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CanopyType.caption
                          .copyWith(color: CanopyPalette.onHeroMuted)),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right,
                size: CanopyIconSize.button, color: CanopyPalette.onHero),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CanopyRadius.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
        child: row,
      ),
    );
  }
}

class _HeroRings extends StatelessWidget {
  const _HeroRings();

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, int alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CanopyPalette.onHero.withAlpha(alpha)),
          ),
        );
    return ExcludeSemantics(
      child: SizedBox(
        width: 362,
        height: 362,
        child: Stack(
          alignment: Alignment.center,
          children: [ring(362, 0x0F), ring(298, 0x14), ring(240, 0x1A)],
        ),
      ),
    );
  }
}

/// List group: surface, outline, radius 16, rows divided by 1px outline.
class CanopyListGroup extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  const CanopyListGroup({super.key, required this.children, this.header});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final group = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(CanopyRadius.md),
        border: Border.all(color: p.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.outline),
            children[i],
          ],
        ],
      ),
    );
    if (header == null) return group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              left: CanopySpace.s4, bottom: CanopySpace.s8),
          child: Text(header!.toUpperCase(),
              style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
        ),
        group,
      ],
    );
  }
}

/// List row: min 56, padding 12/16, bare leading glyph (inkMuted) or widget.
class CanopyListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? titleColor;
  final Widget? below;

  const CanopyListRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.titleColor,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CanopySpace.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: CanopySpace.s16, vertical: CanopySpace.s12),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 14),
            ] else if (icon != null) ...[
              Icon(icon, size: CanopyIconSize.nav, color: titleColor ?? p.inkMuted),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: CanopyType.bodyStrong
                          .copyWith(color: titleColor ?? p.ink)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!,
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  if (below != null) ...[
                    const SizedBox(height: CanopySpace.s4),
                    below!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: CanopySpace.s8),
              trailing!,
            ],
            if (onTap != null && chevron) ...[
              const SizedBox(width: CanopySpace.s4),
              Icon(Icons.chevron_right, size: CanopyIconSize.s18, color: p.inkFaint),
            ],
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Stat tile: value (Bricolage) + caption; optional 2px ink top rule
/// (workspace / field "signal" style) instead of a box.
class CanopyStatTile extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  final bool ruled;
  final Color? valueColor;

  const CanopyStatTile({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
    this.ruled = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CanopyType.title.copyWith(
                color: valueColor ?? p.ink,
                fontFeatures: const [ui.FontFeature.tabularFigures()])),
        const SizedBox(height: CanopySpace.s2),
        Text(label,
            maxLines: 2,
            style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
    );
    if (ruled) {
      final content = Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: CanopySpace.s8),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.ink, width: 2))),
        child: body,
      );
      return onTap == null
          ? content
          : InkWell(onTap: onTap, child: content);
    }
    return CanopyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: SizedBox(width: double.infinity, child: body),
    );
  }
}

enum CalloutKind { info, warning, success, danger, neutral }

/// Callout: transparent, 1px outlineStrong, radius 10, status glyph, ink text.
class CanopyCallout extends StatelessWidget {
  final CalloutKind kind;
  final String? title;
  final String text;
  final Widget? action;
  final IconData? icon;

  const CanopyCallout({
    super.key,
    this.kind = CalloutKind.info,
    this.title,
    required this.text,
    this.action,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final (color, glyph) = switch (kind) {
      CalloutKind.info => (p.info, Icons.info_outline),
      CalloutKind.warning => (p.warning, Icons.warning_amber_outlined),
      CalloutKind.success => (p.success, Icons.check_circle_outline),
      CalloutKind.danger => (p.danger, Icons.error_outline),
      CalloutKind.neutral => (p.inkMuted, Icons.info_outline),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: CanopySpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.outlineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? glyph, size: CanopyIconSize.s18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!,
                      style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                Text(text,
                    style: CanopyType.body
                        .copyWith(fontSize: 13.5, color: p.ink, height: 19 / 13.5)),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Date block: 56 wide, surfaceBrand, day in Bricolage 22, month micro caps.
class CanopyDateBlock extends StatelessWidget {
  final DateTime date;
  final bool ringed;
  const CanopyDateBlock({super.key, required this.date, this.ringed = false});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
      decoration: BoxDecoration(
        color: p.surfaceBrand,
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        border: ringed ? Border.all(color: p.surface, width: 3) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_days[date.weekday - 1].toUpperCase(),
              style: CanopyType.micro.copyWith(color: p.primaryInk, fontSize: 10.5)),
          Text('${date.day}',
              style: CanopyType.title.copyWith(color: p.ink, height: 26 / 22)),
          Text(_months[date.month - 1].toUpperCase(),
              style: CanopyType.micro.copyWith(
                  color: p.primaryInk, fontSize: 10.5, letterSpacing: 0.84)),
        ],
      ),
    );
  }
}

/// Progress bar (primary on surfaceMuted), 6 tall; [ink] for workspace bars.
class CanopyProgressBar extends StatelessWidget {
  final double value;
  final bool ink;
  const CanopyProgressBar({super.key, required this.value, this.ink = false});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          backgroundColor: p.surfaceMuted,
          color: ink ? p.ink : p.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA & IDENTITY
// ─────────────────────────────────────────────────────────────────────────────

/// Avatar 24/32/40/56/72; initials fallback; org = squircle (30%).
class CanopyAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool org;
  final Color? ring;

  const CanopyAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = 40,
    this.org = false,
    this.ring,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final initials = canopyInitials(name);
    final fallback = Center(
      child: initials.isEmpty
          ? Icon(org ? Icons.groups_outlined : Icons.person_outline,
              size: size * 0.5, color: p.primaryInk)
          : Text(initials,
              style: CanopyType.micro.copyWith(
                  color: p.primaryInk,
                  fontSize: size * 0.35,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0)),
    );
    final radius = BorderRadius.circular(org ? size * 0.3 : size / 2);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surfaceBrand,
        borderRadius: radius,
        border: ring == null ? null : Border.all(color: ring!, width: 2),
      ),
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(url!,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

/// Overlapping avatars (−8 overlap, 2px surface ring) + optional "+N".
class CanopyAvatarStack extends StatelessWidget {
  final List<(String? url, String name)> people;
  final int max;
  final double size;
  final int? total;
  const CanopyAvatarStack(
      {super.key, required this.people, this.max = 3, this.size = 24, this.total});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final shown = people.take(max).toList();
    final extra = (total ?? people.length) - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();
    final step = size - 8;
    return SizedBox(
      height: size,
      width: step * (count - 1) + size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: CanopyAvatar(
                  url: shown[i].$1, name: shown[i].$2, size: size, ring: p.surface),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 2),
                ),
                child: Text('+$extra',
                    style: CanopyType.micro.copyWith(
                        color: p.inkMuted, fontSize: size * 0.36, letterSpacing: 0)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Org chip: logo + name (transparent on canvas; dark glass on images).
class CanopyOrgChip extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool onImage;
  final VoidCallback? onTap;
  const CanopyOrgChip(
      {super.key,
      required this.name,
      this.logoUrl,
      this.onImage = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final chip = Container(
      height: 32,
      padding: EdgeInsets.only(left: onImage ? 4 : 0, right: onImage ? 12 : 0),
      decoration: onImage
          ? BoxDecoration(
              color: p.scrim, borderRadius: BorderRadius.circular(CanopyRadius.pill))
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CanopyAvatar(url: logoUrl, name: name, size: 24, org: true),
          const SizedBox(width: CanopySpace.s8),
          Flexible(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CanopyType.label.copyWith(
                    color: onImage ? CanopyPalette.onHero : p.ink)),
          ),
        ],
      ),
    );
    return onTap == null ? chip : InkWell(onTap: onTap, child: chip);
  }
}

/// Network image with the designed fallback (contour placeholder + glyph) for
/// missing URLs, loading and failures. Fades in over 240ms.
class CanopyImage extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;
  final BoxFit fit;
  final Alignment alignment;
  const CanopyImage({
    super.key,
    required this.url,
    this.fallbackIcon = Icons.eco_outlined,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = CanopyImageFallback(icon: fallbackIcon);
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => fallback,
      frameBuilder: (_, child, frame, sync) => sync
          ? child
          : AnimatedSwitcher(
              duration: context.reduceMotion
                  ? CanopyMotion.reduced
                  : CanopyMotion.imageFade,
              child: frame == null ? fallback : child,
            ),
    );
  }
}

/// Contour placeholder: surfaceBrand + concentric rings + glyph.
class CanopyImageFallback extends StatelessWidget {
  final IconData icon;
  const CanopyImageFallback({super.key, this.icon = Icons.eco_outlined});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CustomPaint(
      painter: _ContourPainter(p.primarySoft.withAlpha(0x1A)),
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Icon(icon, size: CanopyIconSize.s32, color: p.primarySoft),
      ),
    ).withBackground(p.surfaceBrand);
  }
}

extension on Widget {
  Widget withBackground(Color c) => ColoredBox(color: c, child: this);
}

class _ContourPainter extends CustomPainter {
  final Color color;
  _ContourPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final c = Offset(size.width * 0.2, size.height * 1.1);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height) * 1.2;
    for (double r = 15; r < maxR; r += 15) {
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_ContourPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// FEEDBACK — skeleton, empty, error, signed-out, coming-soon, offline
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton block: surfaceMuted + 1400ms linear shimmer (off under reduced
/// motion). Shape it like the content it stands in for.
class CanopySkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  const CanopySkeleton(
      {super.key, this.width, this.height, this.radius = CanopyRadius.xs});

  @override
  State<CanopySkeleton> createState() => _CanopySkeletonState();
}

class _CanopySkeletonState extends State<CanopySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: CanopyMotion.shimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final dark = context.brightness == Brightness.dark;
    final shine = Color.alphaBlend(
        CanopyPalette.onHero.withAlpha(dark ? 0x0F : 0x8C), p.surfaceMuted);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 4 - 2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [p.surfaceMuted, shine, p.surfaceMuted],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton list group with [rows] avatar + two-line rows.
class CanopyListSkeleton extends StatelessWidget {
  final int rows;
  final double leadingSize;
  const CanopyListSkeleton({super.key, this.rows = 3, this.leadingSize = 40});

  @override
  Widget build(BuildContext context) {
    return CanopyListGroup(
      children: List.generate(
        rows,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: CanopySpace.s16, vertical: CanopySpace.s12),
          child: Row(
            children: [
              CanopySkeleton(
                  width: leadingSize, height: leadingSize, radius: CanopyRadius.sm),
              const SizedBox(width: CanopySpace.s12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CanopySkeleton(height: 14),
                    SizedBox(height: CanopySpace.s8),
                    CanopySkeleton(width: 140, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton content card (16:9 media + three text lines).
class CanopyCardSkeleton extends StatelessWidget {
  final double aspectRatio;
  const CanopyCardSkeleton({super.key, this.aspectRatio = 16 / 9});

  @override
  Widget build(BuildContext context) {
    return CanopyCard(
      padding: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
              aspectRatio: aspectRatio,
              child: const CanopySkeleton(radius: 0)),
          const Padding(
            padding: EdgeInsets.all(CanopySpace.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CanopySkeleton(width: 80, height: 10),
                SizedBox(height: CanopySpace.s8),
                CanopySkeleton(height: 18),
                SizedBox(height: CanopySpace.s8),
                CanopySkeleton(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty: glyph + one line + one action. [boxed] draws it as a card inside a
/// section; unboxed centres it for a whole screen.
class CanopyEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? line;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool primaryAction;
  final bool boxed;

  const CanopyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.line,
    this.actionLabel,
    this.onAction,
    this.primaryAction = false,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: boxed ? CanopyIconSize.s32 : CanopyIconSize.empty,
            color: p.inkFaint),
        const SizedBox(height: CanopySpace.s12),
        Text(title,
            textAlign: TextAlign.center,
            style: (boxed ? CanopyType.bodyStrong : CanopyType.heading)
                .copyWith(color: p.ink)),
        if (line != null) ...[
          const SizedBox(height: CanopySpace.s4),
          Text(line!,
              textAlign: TextAlign.center,
              style: CanopyType.body.copyWith(color: p.inkMuted)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: CanopySpace.s12),
          primaryAction
              ? CanopyButton(label: actionLabel!, onPressed: onAction)
              : CanopyButton.secondary(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
    if (boxed) {
      return CanopyCard(
        padding: const EdgeInsets.symmetric(
            horizontal: CanopySpace.cardPadding, vertical: CanopySpace.s24),
        child: SizedBox(width: double.infinity, child: body),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CanopySpace.s32),
        child: body,
      ),
    );
  }
}

/// Error: danger glyph + message + retry (secondary). [inline] renders as a
/// callout inside a section.
class CanopyErrorState extends StatelessWidget {
  final String title;
  final String? line;
  final VoidCallback? onRetry;
  final bool inline;

  const CanopyErrorState({
    super.key,
    this.title = "Couldn't load this",
    this.line,
    this.onRetry,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (inline) {
      return Container(
        padding: const EdgeInsets.only(left: CanopySpace.s12, right: CanopySpace.s4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.outlineStrong),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: CanopyIconSize.s18, color: p.danger),
            const SizedBox(width: CanopySpace.s8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CanopySpace.s12),
                child: Text(title, style: CanopyType.body.copyWith(color: p.ink)),
              ),
            ),
            if (onRetry != null)
              CanopyButton.quiet(label: 'Try again', onPressed: onRetry),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CanopySpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: CanopyIconSize.empty, color: p.danger),
            const SizedBox(height: CanopySpace.s12),
            Text(title,
                textAlign: TextAlign.center,
                style: CanopyType.heading.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s4),
            Text(line ?? 'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: CanopyType.body.copyWith(color: p.inkMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: CanopySpace.s16),
              CanopyButton.secondary(label: 'Try again', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Signed-out: lock glyph + why + Sign in.
class CanopySignedOutState extends StatelessWidget {
  final String line;
  const CanopySignedOutState(
      {super.key, this.line = 'Sign in to see this and keep track of your impact.'});

  @override
  Widget build(BuildContext context) {
    return CanopyEmptyState(
      icon: Icons.lock_outline,
      title: "You're signed out",
      line: line,
      actionLabel: 'Sign in',
      primaryAction: true,
      onAction: () => Navigator.pushNamed(context, '/welcome'),
    );
  }
}

/// Coming soon: dashed outline glyph + "On the roadmap". Never styled like
/// empty or error.
class CanopyComingSoon extends StatelessWidget {
  final String title;
  final String line;
  final IconData icon;
  final String label;
  final bool boxed;

  const CanopyComingSoon({
    super.key,
    required this.title,
    required this.line,
    this.icon = Icons.schedule_outlined,
    this.label = 'On the roadmap',
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DashedBorder(
          color: p.outlineStrong,
          radius: 28,
          child: SizedBox(
            width: boxed ? 64 : 88,
            height: boxed ? 64 : 88,
            child: Icon(icon,
                size: boxed ? CanopyIconSize.s32 : CanopyIconSize.empty,
                color: p.inkMuted),
          ),
        ),
        const SizedBox(height: CanopySpace.s12),
        Text(label.toUpperCase(),
            style: CanopyType.statusLabel.copyWith(color: p.inkMuted)),
        const SizedBox(height: CanopySpace.s4),
        Text(title,
            textAlign: TextAlign.center,
            style: CanopyType.heading.copyWith(color: p.ink)),
        const SizedBox(height: CanopySpace.s4),
        Text(line,
            textAlign: TextAlign.center,
            style: CanopyType.body.copyWith(color: p.inkMuted)),
      ],
    );
    if (boxed) {
      return DashedBorder(
        color: p.outlineStrong,
        radius: CanopyRadius.md,
        child: Padding(
          padding: const EdgeInsets.all(CanopySpace.s20),
          child: SizedBox(width: double.infinity, child: body),
        ),
      );
    }
    return Center(
        child: Padding(padding: const EdgeInsets.all(CanopySpace.s32), child: body));
  }
}

/// Offline banner: warning glyph + one line, outline callout style.
class CanopyOfflineBanner extends StatelessWidget {
  final String text;
  const CanopyOfflineBanner(
      {super.key, this.text = "You're offline. Showing what was saved on this phone."});

  @override
  Widget build(BuildContext context) => CanopyCallout(
        kind: CalloutKind.warning,
        icon: Icons.wifi_off_outlined,
        text: text,
      );
}

/// Dashed rounded border (coming-soon, empty photo slots, "soon" cards).
class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = CanopyRadius.sm,
    this.strokeWidth = 1.5,
    this.dash = 6,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter:
            _DashedPainter(color, radius, strokeWidth, dash, gap),
        child: child,
      );
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius, stroke, dash, gap;
  _DashedPainter(this.color, this.radius, this.stroke, this.dash, this.gap);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset(stroke / 2, stroke / 2) &
            Size(size.width - stroke, size.height - stroke),
        Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.radius != radius;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEETS, DIALOGS, SNACKS
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet: surface, radius 24 top, handle, e2 shadow, scrim.
Future<T?> showCanopySheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool tall = false,
  bool dismissible = true,
}) {
  final p = context.canopy;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: p.scrim,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * (tall ? 0.92 : 0.85)),
      child: Container(
        decoration: BoxDecoration(
          color: ctx.canopy.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(CanopyRadius.xl)),
          boxShadow: CanopyElevation.e2(ctx.brightness),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: CanopySpace.s8),
                decoration: BoxDecoration(
                  color: ctx.canopy.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Standard sheet body: title, optional caption, content, footer actions.
class CanopySheetBody extends StatelessWidget {
  final String title;
  final String? caption;
  final List<Widget> children;
  final List<Widget> actions;

  const CanopySheetBody({
    super.key,
    required this.title,
    this.caption,
    this.children = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          CanopySpace.gutter,
          CanopySpace.s8,
          CanopySpace.gutter,
          CanopySpace.s16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: CanopyType.title.copyWith(color: p.ink)),
          if (caption != null) ...[
            const SizedBox(height: CanopySpace.s4),
            Text(caption!, style: CanopyType.body.copyWith(color: p.inkMuted)),
          ],
          if (children.isNotEmpty) const SizedBox(height: CanopySpace.s16),
          ...children,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: CanopySpace.s16),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: CanopySpace.s4),
              actions[i],
            ],
          ],
        ],
      ),
    );
  }
}

/// Confirm dialog. Primary = the action; quiet = keep. [danger] uses the
/// danger fill for irreversible actions.
Future<bool> showCanopyConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final p = context.canopy;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: p.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: ctx.canopy.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CanopyRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.s24, CanopySpace.s24, CanopySpace.s24, CanopySpace.s12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: CanopyType.title.copyWith(color: ctx.canopy.ink)),
            const SizedBox(height: CanopySpace.s8),
            Text(message,
                style: CanopyType.body.copyWith(color: ctx.canopy.inkMuted)),
            const SizedBox(height: CanopySpace.s20),
            danger
                ? CanopyButton.danger(
                    label: confirmLabel,
                    expand: true,
                    onPressed: () => Navigator.pop(ctx, true))
                : CanopyButton(
                    label: confirmLabel,
                    expand: true,
                    onPressed: () => Navigator.pop(ctx, true)),
            CanopyButton.quiet(
                label: cancelLabel,
                expand: true,
                onPressed: () => Navigator.pop(ctx, false)),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Snack: dark ink surface, one optional action.
void showCanopySnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool error = false,
}) {
  final p = context.canopy;
  final dark = context.brightness == Brightness.dark;
  final bg = dark ? p.ink : CanopyPalette.light.ink;
  final fg = dark ? CanopyPalette.light.ink : CanopyPalette.dark.ink;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CanopyRadius.sm)),
      content: Row(
        children: [
          if (error) ...[
            Icon(Icons.error_outline, size: CanopyIconSize.s18, color: p.danger),
            const SizedBox(width: CanopySpace.s8),
          ],
          Expanded(
            child: Text(message,
                style: CanopyType.body
                    .copyWith(color: fg, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: dark ? p.primary : CanopyPalette.light.primarySoft,
              onPressed: onAction ?? () {},
            ),
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// RECOGNITION
// ─────────────────────────────────────────────────────────────────────────────

enum MedalKind { gold, silver, bronze }

/// Medal disc 1/2/3.
class CanopyMedal extends StatelessWidget {
  final MedalKind kind;
  final double size;
  const CanopyMedal({super.key, required this.kind, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final (fill, n) = switch (kind) {
      MedalKind.gold => (p.gold, 1),
      MedalKind.silver => (p.medalSilver, 2),
      MedalKind.bronze => (p.medalBronze, 3),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Text('$n',
          style: CanopyType.points.copyWith(
              fontSize: size * 0.46, color: CanopyPalette.light.ink)),
    );
  }
}

/// Badge: earned (gold ring on goldSoft) · locked (muted, outline) · progress
/// (surface + primary ring at [progress]).
class CanopyBadge extends StatelessWidget {
  final IconData icon;
  final bool earned;
  final double? progress;
  final double size;
  const CanopyBadge(
      {super.key,
      required this.icon,
      this.earned = false,
      this.progress,
      this.size = 64});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (progress != null && !earned) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress!.clamp(0, 1).toDouble(),
                strokeWidth: 3,
                backgroundColor: p.outline,
                color: p.primary,
              ),
            ),
            Icon(icon, size: size * 0.42, color: p.primaryInk),
          ],
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? p.goldSoft : p.surfaceMuted,
        border: Border.all(
            color: earned ? p.gold : p.outlineStrong, width: earned ? 2 : 1.5),
      ),
      child: Icon(icon, size: size * 0.42, color: earned ? p.goldInk : p.inkFaint),
    );
  }
}

/// One gold ring burst (600ms, once) around [child]. No confetti, no loop.
class CanopyCheckInBurst extends StatefulWidget {
  final Widget child;
  final double size;
  const CanopyCheckInBurst({super.key, required this.child, this.size = 120});

  @override
  State<CanopyCheckInBurst> createState() => _CanopyCheckInBurstState();
}

class _CanopyCheckInBurstState extends State<CanopyCheckInBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: CanopyMotion.checkInBurst);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.reduceMotion && !_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = context.canopy.gold;
    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = CanopyMotion.emphasised.transform(_c.value);
              return Opacity(
                opacity: (1 - _c.value).clamp(0, 1).toDouble(),
                child: Container(
                  width: widget.size * (1 + 0.6 * t),
                  height: widget.size * (1 + 0.6 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 3 * (1 - t) + 1),
                  ),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Count-up numerals (900ms decelerate; instant under reduced motion).
class CanopyCountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  const CanopyCountUp(
      {super.key,
      required this.value,
      required this.style,
      this.prefix = '',
      this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return Text('$prefix$value$suffix', style: style);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: CanopyMotion.countUp,
      curve: Curves.decelerate,
      builder: (_, v, __) => Text('$prefix$v$suffix', style: style),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

/// Canvas-coloured scaffold with an optional sticky action bar.
class CanopyScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? sticky;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const CanopyScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.sticky,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canopy.canvas,
      appBar: appBar,
      body: body,
      bottomNavigationBar: sticky ?? bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// FAB: ink fill, canvas text, radius 14, e3.
class CanopyFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const CanopyFab(
      {super.key, required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: CanopyElevation.e3(context.brightness),
      ),
      child: Material(
        color: p.ink,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.only(left: CanopySpace.s16, right: CanopySpace.s20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: CanopyIconSize.nav, color: p.canvas),
                  const SizedBox(width: 10),
                  Text(label, style: CanopyType.button.copyWith(color: p.canvas)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled key/value row for detail groups ("Date · Sat 4 Oct").
class CanopyFactRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const CanopyFactRow(
      {super.key, this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) => CanopyListRow(
        icon: icon,
        title: value,
        subtitle: label,
        onTap: onTap,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE
// ─────────────────────────────────────────────────────────────────────────────

enum TimelineState { done, now, todo, failed }

class TimelineStep {
  final String title;
  final String? line;
  final TimelineState state;
  const TimelineStep(this.title, {this.line, this.state = TimelineState.todo});
}

/// 22dp dots with 2px connectors: done = primary + check · now = ring + dot on
/// a surfaceBrand halo · todo = outlineStrong ring · failed = danger + x.
class CanopyTimeline extends StatelessWidget {
  final List<TimelineStep> steps;
  const CanopyTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      _dot(p, steps[i].state),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: steps[i].state == TimelineState.done
                                ? p.primary
                                : p.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: CanopySpace.s8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i == steps.length - 1 ? 0 : 14, top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].title,
                            style: CanopyType.bodyStrong.copyWith(
                                color: steps[i].state == TimelineState.todo
                                    ? p.inkMuted
                                    : steps[i].state == TimelineState.failed
                                        ? p.danger
                                        : p.ink)),
                        if (steps[i].line != null)
                          Text(steps[i].line!,
                              style: CanopyType.caption
                                  .copyWith(color: p.inkMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(CanopyPalette p, TimelineState s) {
    switch (s) {
      case TimelineState.done:
        return Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
          child: Icon(Icons.check, size: CanopyIconSize.s14, color: p.onPrimary),
        );
      case TimelineState.failed:
        return Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: p.danger, shape: BoxShape.circle),
          child: Icon(Icons.close, size: CanopyIconSize.s14, color: p.canvas),
        );
      case TimelineState.now:
        return Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: p.surfaceBrand, shape: BoxShape.circle),
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.primary, width: 2),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: p.primary, shape: BoxShape.circle),
            ),
          ),
        );
      case TimelineState.todo:
        return Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: p.surface,
            shape: BoxShape.circle,
            border: Border.all(color: p.outlineStrong, width: 2),
          ),
        );
    }
  }
}
