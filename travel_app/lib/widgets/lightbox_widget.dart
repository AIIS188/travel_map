import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LightboxWidget extends StatefulWidget {
  final List<String> photos; // base64
  final int initialIndex;

  const LightboxWidget({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<LightboxWidget> createState() => _LightboxWidgetState();
}

class _LightboxWidgetState extends State<LightboxWidget> {
  late int _current;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _shift(int delta) {
    final next =
        (_current + delta + widget.photos.length) % widget.photos.length;
    _pageCtrl.animateToPage(next,
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  Uint8List _decode(String b64) => base64Decode(b64);

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (e) {
        if (e is KeyDownEvent) {
          if (e.logicalKey == LogicalKeyboardKey.arrowLeft) _shift(-1);
          if (e.logicalKey == LogicalKeyboardKey.arrowRight) _shift(1);
          if (e.logicalKey == LogicalKeyboardKey.escape) Navigator.pop(context);
        }
      },
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Photo viewer
              PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: widget.photos.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {}, // prevent close on image tap
                  child: Center(
                    child: InteractiveViewer(
                      child: Image.memory(
                        _decode(widget.photos[i]),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Close button
              Positioned(
                top: 16,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Prev arrow
              if (widget.photos.length > 1)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowBtn(
                        icon: Icons.chevron_left,
                        onTap: () => _shift(-1)),
                  ),
                ),

              // Next arrow
              if (widget.photos.length > 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowBtn(
                        icon: Icons.chevron_right,
                        onTap: () => _shift(1)),
                  ),
                ),

              // Counter
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Text(
                  '${_current + 1} / ${widget.photos.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
