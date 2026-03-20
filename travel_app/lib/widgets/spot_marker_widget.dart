import 'package:flutter/material.dart';
import '../models/spot.dart';
import '../utils/color_utils.dart';

class SpotMarkerWidget extends StatelessWidget {
  final Spot spot;
  final bool isSelected; // measure selected
  final bool isFiltered; // filtered out

  const SpotMarkerWidget({
    super.key,
    required this.spot,
    this.isSelected = false,
    this.isFiltered = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isFiltered) return const SizedBox.shrink();

    final pinColor = hexToColor(spot.color);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isFiltered ? 0 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: pinColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isSelected ? const Color(0xFF34D399) : Colors.white,
                width: isSelected ? 3 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            transform: Matrix4.rotationZ(-0.785398), // -45 degrees
            transformAlignment: Alignment.center,
            child: Center(
              child: Transform.rotate(
                angle: 0.785398, // +45 to cancel parent rotation
                child: Text(
                  spot.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              spot.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
