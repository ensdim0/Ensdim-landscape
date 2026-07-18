import 'package:flutter/material.dart';

/// A colored status chip for visit/task statuses.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  /// Factory for visit status chips.
  factory StatusChip.visitStatus(String status, String label) {
    final (color, icon) = switch (status) {
      'planned' => (Colors.blue, Icons.schedule),
      'in_progress' => (Colors.orange, Icons.play_circle_outline),
      'completed' => (Colors.green, Icons.check_circle_outline),
      'cancelled' => (Colors.red, Icons.cancel_outlined),
      _ => (Colors.grey, Icons.help_outline),
    };
    return StatusChip(label: label, color: color, icon: icon);
  }

  /// Factory for task status chips.
  factory StatusChip.taskStatus(String status, String label) {
    final (color, icon) = switch (status) {
      'pending' => (Colors.orange, Icons.hourglass_empty),
      'completed' => (Colors.blue, Icons.check),
      'verified' => (Colors.green, Icons.verified),
      'rejected' => (Colors.red, Icons.close),
      _ => (Colors.grey, Icons.help_outline),
    };
    return StatusChip(label: label, color: color, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
