import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/spot.dart';
import '../utils/color_utils.dart';

class SpotMarkerWidget extends StatelessWidget {
  final Spot spot;
  final bool isSelected;
  final bool isFiltered;

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
    final borderColor = isSelected ? const Color(0xFF34D399) : Colors.white;
    final borderWidth = isSelected ? 3.0 : 2.5;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 菱形 pin 容器 — 毛玻璃背景
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: pinColor.withOpacity(0.72),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: pinColor.withOpacity(0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                transform: Matrix4.rotationZ(-0.785398),
                transformAlignment: Alignment.center,
                child: Center(
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Text(
                      spot.emoji,
                      style: const TextStyle(
                        fontSize: 28,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 3)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          // 毛玻璃标签
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  spot.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
