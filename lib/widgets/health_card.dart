import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/prediction.dart';
import 'ui_kit.dart';

/// Stat tile: tinted icon chip + count-up headline number + label.
class HealthCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const HealthCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppTheme.primaryGreen,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Animate pure numbers; render mixed values (e.g. "98%") directly.
    final numeric = num.tryParse(value);
    final headlineStyle = text.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppTheme.inkPrimary,
      letterSpacing: -.5,
    );

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: numeric != null
                      ? AnimatedCount(value: numeric, style: headlineStyle)
                      : Text(value,
                          maxLines: 1, style: headlineStyle),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: text.bodySmall?.copyWith(
                    color: AppTheme.inkSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.labelSmall?.copyWith(
                      color: AppTheme.inkMuted,
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

/// Risk level chip — status color always paired with icon + label so
/// meaning never rides on color alone.
class RiskChip extends StatelessWidget {
  final RiskLevel level;
  final bool compact;

  const RiskChip({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 14,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: compact ? 14 : 16, color: level.color),
          const SizedBox(width: 6),
          Text(
            level.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.inkPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Section heading used across forms and detail pages.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const SectionHeader({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.softMint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: AppTheme.deepGreen),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
