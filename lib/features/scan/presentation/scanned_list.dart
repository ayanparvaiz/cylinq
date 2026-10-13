import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/models/cylinder.dart';
import '../../../core/widgets/status_chip.dart';
import '../../moves/move_rules.dart';

class ScannedItem {
  const ScannedItem(this.cylinder, this.check);

  final Cylinder cylinder;
  final MoveCheck check;
}

/// Cylinders scanned so far, each with its current state and any warning.
class ScannedList extends StatelessWidget {
  const ScannedList({super.key, required this.items, required this.onRemove, this.emptyText = 'Scanned cylinders appear here'});

  final List<ScannedItem> items;
  final void Function(ScannedItem item) onRemove;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(emptyText, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ),
      );
    }
    return Column(
      children: [
        for (final item in items.reversed)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              title: Row(
                children: [
                  Text(item.cylinder.serial, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Flexible(child: StatusChip(item.cylinder, dense: true)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.cylinder.typeName),
                  if (item.check.warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.flameDeep),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.check.warning!,
                              style: const TextStyle(color: AppColors.flameDeep, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close),
                onPressed: () => onRemove(item),
              ),
            ),
          ),
      ],
    );
  }
}
