import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class MeasureResultDialog extends StatelessWidget {
  final String fromName;
  final String toName;
  final double distanceKm;

  const MeasureResultDialog({
    super.key,
    required this.fromName,
    required this.toName,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$fromName  →  $toName',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              distanceKm.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.green,
              ),
            ),
            const Text('公里（直线距离）',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              ),
              child: const Text('关闭',
                  style: TextStyle(color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }
}
