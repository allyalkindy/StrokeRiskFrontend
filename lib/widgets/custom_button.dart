import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Primary action button: brand gradient, soft glow, built-in loading state.
/// `outlined: true` renders the quiet secondary variant instead.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;
  final bool expanded;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: outlined ? AppTheme.primaryGreen : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    if (outlined) {
      final button =
          OutlinedButton(onPressed: enabled ? onPressed : null, child: content);
      return expanded
          ? SizedBox(width: double.infinity, child: button)
          : button;
    }

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.buttonGradient : null,
        color: enabled ? null : const Color(0xFFBFD8CA),
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        boxShadow: enabled ? AppTheme.glow(AppTheme.primaryGreen) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return expanded ? button : IntrinsicWidth(child: button);
  }
}
