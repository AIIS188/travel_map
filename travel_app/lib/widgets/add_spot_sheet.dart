import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../models/spot.dart';
import '../providers/map_mode_provider.dart';
import '../providers/spot_provider.dart';
import '../utils/app_theme.dart';

class AddSpotSheet extends StatefulWidget {
  const AddSpotSheet({super.key});

  @override
  State<AddSpotSheet> createState() => _AddSpotSheetState();
}

class _AddSpotSheetState extends State<AddSpotSheet> {
  final _nameCtrl  = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '📍');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写地点名称')));
      return;
    }
    final mp    = context.read<MapModeProvider>();
    final coord = mp.pendingCoord; // x_amap_base LatLng
    if (coord == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先在地图上点击选取位置')));
      return;
    }

    final spot = Spot(
      id: 'custom_${const Uuid().v4()}',
      name: name,
      emoji: _emojiCtrl.text.trim().isEmpty ? '📍' : _emojiCtrl.text.trim(),
      lat: coord.latitude,
      lng: coord.longitude,
      isCustom: true,
      color: '#a78bfa',
      category: '自定义',
    );

    await context.read<SpotProvider>().addSpot(spot);
    mp.exitAddSpot();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mp    = context.watch<MapModeProvider>();
    final coord = mp.pendingCoord;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E30),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖动条
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text('📍 新增地点',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          _darkField(_nameCtrl, '地点名称', '如：南诏风情岛'),
          const SizedBox(height: 10),
          _darkField(_emojiCtrl, 'Emoji 图标', '如 🌟 🏖️ 🍜'),
          const SizedBox(height: 14),

          // 坐标状态提示
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: coord != null
                  ? Colors.green.withOpacity(0.15)
                  : Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: coord != null ? Colors.green : Colors.amber),
            ),
            child: coord != null
                ? Text(
                    '✅ 已选：${coord.latitude.toStringAsFixed(5)}, '
                    '${coord.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                  )
                : const Text(
                    '⚠️ 请在地图上点击选取坐标位置',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
          ),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightBlue,
                    foregroundColor: AppTheme.bg),
                child: const Text('✅ 添加地点'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  mp.exitAddSpot();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24)),
                child: const Text('取消'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _darkField(TextEditingController ctrl, String label, String hint) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white54)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
        ),
      ]);
}
