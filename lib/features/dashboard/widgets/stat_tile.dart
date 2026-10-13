import 'package:flutter/material.dart';

/// A labelled number. [hero] makes it the one big figure the page leads with.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.iconColor,
    this.hero = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;

  /// Status tiles carry an icon in their state colour; the text stays ink.
  final IconData? icon;
  final Color? iconColor;
  final bool hero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge?.copyWith(color: muted)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: (hero ? text.displaySmall : text.headlineSmall)?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(caption!, style: text.bodySmall?.copyWith(color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays tiles out in as many equal columns as fit, at least [minWidth] each.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minWidth = 170, this.spacing = 12});

  final List<Widget> children;
  final double minWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = ((box.maxWidth + spacing) / (minWidth + spacing)).floor().clamp(1, children.length);
        final w = (box.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      },
    );
  }
}
