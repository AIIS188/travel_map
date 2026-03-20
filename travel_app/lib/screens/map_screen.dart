import 'dart:io';

import 'package:amap_map/amap_map.dart' as amap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:x_amap_base/x_amap_base.dart' as xbase;

import '../models/spot.dart';
import '../providers/map_mode_provider.dart';
import '../providers/spot_provider.dart';
import '../services/amap_service.dart';
import '../utils/app_theme.dart';
import '../widgets/add_spot_sheet.dart';
import '../widgets/measure_result_dialog.dart';
import '../widgets/spot_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  amap.AMapController? _mapController;
  AMapStyleMode _styleMode = AMapStyleMode.night;

  final TextEditingController _searchCtrl = TextEditingController();
  bool _showSearch    = false;
  bool _showFilter    = false;
  bool _showDataPanel = false;

  String? _measureFirstName;

  @override
  void dispose() {
    _searchCtrl.dispose();
    // amap.AMapController 无 dispose 方法
    super.dispose();
  }

  // ── amap.Marker 构建 ────────────────────────────────────────────

  Set<amap.Marker> _buildMarkers(
    List<Spot> spots,
    List<String> measurePicks,
    xbase.LatLng? pendingCoord,
  ) {
    final result = <amap.Marker>{};

    for (final spot in spots) {
      result.add(amap.Marker(
        position: xbase.LatLng(spot.lat, spot.lng),
        infoWindow: amap.InfoWindow(
          title: '${spot.emoji} ${spot.name}',
          snippet: spot.meta.isNotEmpty ? spot.meta : spot.desc,
        ),
        onTap: (_) => _onMarkerTap(spot),
      ));
    }

    // 新增模式下的待确认坐标点
    if (pendingCoord != null) {
      result.add(amap.Marker(
        position: xbase.LatLng(pendingCoord.latitude, pendingCoord.longitude),
        infoWindow: const amap.InfoWindow(title: '📍 新地点', snippet: '确认后将添加'),
      ));
    }

    return result;
  }

  amap.BitmapDescriptor _spotIcon(Spot spot, bool isSelected) {
    if (isSelected) {
      return amap.BitmapDescriptor.defaultMarkerWithHue(amap.BitmapDescriptor.hueGreen);
    }
    final c = spot.color.toUpperCase();
    if (c.contains('FFB6C1') || c.contains('FF6B9D')) {
      return amap.BitmapDescriptor.defaultMarkerWithHue(amap.BitmapDescriptor.hueRose);
    } else if (c.contains('87CEEB') || c.contains('7DD3FC')) {
      return amap.BitmapDescriptor.defaultMarkerWithHue(amap.BitmapDescriptor.hueAzure);
    } else if (c.contains('DDA0DD') || c.contains('A78BFA')) {
      return amap.BitmapDescriptor.defaultMarkerWithHue(amap.BitmapDescriptor.hueViolet);
    }
    return amap.BitmapDescriptor.defaultMarkerWithHue(amap.BitmapDescriptor.hueOrange);
  }

  // ── 交互事件 ───────────────────────────────────────────────

  void _onMarkerTap(Spot spot) {
    final mp = context.read<MapModeProvider>();
    if (mp.mode == MapMode.measure) {
      _handleMeasureTap(spot);
    } else if (mp.mode == MapMode.normal) {
      _openDetail(spot);
    }
  }

  void _openDetail(Spot spot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotDetailSheet(spotId: spot.id),
    );
  }

  void _handleMeasureTap(Spot spot) {
    final mp = context.read<MapModeProvider>();
    if (mp.measurePicks.contains(spot.id)) return;

    final sp    = context.read<SpotProvider>();
    final coords = {for (final s in sp.spots) s.id: [s.lat, s.lng]};
    final dist   = mp.pickMeasureSpot(spot.id, spot.lat, spot.lng, coords);

    if (mp.measurePicks.length == 1) setState(() => _measureFirstName = spot.name);

    if (dist != null) {
      final from = _measureFirstName ?? '';
      mp.exitMeasure();
      setState(() => _measureFirstName = null);
      showDialog(
        context: context,
        builder: (_) => MeasureResultDialog(
          fromName: from,
          toName: spot.name,
          distanceKm: dist,
        ),
      );
    }
  }

  void _onMapTap(xbase.LatLng coord) {
    final mp = context.read<MapModeProvider>();
    if (mp.mode == MapMode.addSpot) {
      mp.setPendingCoord(coord);
    }
    if (_showSearch)    setState(() => _showSearch    = false);
    if (_showFilter)    setState(() => _showFilter    = false);
    if (_showDataPanel) setState(() => _showDataPanel = false);
  }

  // ── 数据操作 ───────────────────────────────────────────────

  Future<void> _exportData() async {
    final json = context.read<SpotProvider>().exportJson();
    final dir  = await getTemporaryDirectory();
    final now  = DateTime.now();
    final name = '洱海地图数据_${now.year}${_p(now.month)}${_p(now.day)}.json';
    final file = File('${dir.path}/$name')..writeAsStringSync(json);
    await Share.shareXFiles([XFile(file.path)], text: '大理洱海旅游地图数据');
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  Future<void> _importData() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (r == null || r.files.isEmpty) return;
    final path = r.files.first.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    final err = await context.read<SpotProvider>().importJson(content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? '✅ 数据导入成功！'),
        backgroundColor: err == null ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('恢复默认数据'),
        content: const Text('将清除所有自定义修改，恢复内置 8 个景点。确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await context.read<SpotProvider>().resetToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('✅ 已恢复默认数据')));
        setState(() => _showDataPanel = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // build
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildMapStack()),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Consumer<MapModeProvider>(
      builder: (_, mp, __) {
        final isMeasure = mp.mode == MapMode.measure;
        final isAdd     = mp.mode == MapMode.addSpot;
        return Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏝️ 大理洱海一日游',
                          style: TextStyle(color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('点击景点查看详情',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                _HeaderBtn(
                  label: isMeasure ? '❌ 取消' : '📏 测距',
                  active: isMeasure,
                  activeColor: AppTheme.green,
                  onTap: () {
                    if (isMeasure) { mp.exitMeasure(); setState(() => _measureFirstName = null); }
                    else mp.enterMeasure();
                  },
                ),
                const SizedBox(width: 6),
                _HeaderBtn(
                  label: isAdd ? '❌ 取消' : '➕ 添加',
                  active: isAdd,
                  activeColor: AppTheme.amber,
                  onTap: () {
                    if (isAdd) { mp.exitAddSpot(); }
                    else { mp.enterAddSpot(); _showAddSpotSheet(); }
                  },
                ),
                const SizedBox(width: 6),
                _HeaderBtn(
                  label: '💾 数据',
                  active: _showDataPanel,
                  activeColor: AppTheme.accent,
                  onTap: () => setState(() => _showDataPanel = !_showDataPanel),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  void _showAddSpotSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddSpotSheet(),
    ).then((_) {
      if (context.read<MapModeProvider>().mode == MapMode.addSpot) {
        context.read<MapModeProvider>().exitAddSpot();
      }
    });
  }

  // ── Map Stack ──────────────────────────────────────────────

  Widget _buildMapStack() {
    return Stack(children: [
      _buildAMap(),

      // 测距提示条
      Consumer<MapModeProvider>(builder: (_, mp, __) {
        if (mp.mode != MapMode.measure) return const SizedBox.shrink();
        return Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: AppTheme.bg.withOpacity(0.88),
            child: Text(
              mp.measurePicks.isEmpty
                  ? '请选择第一个地点…'
                  : '已选：$_measureFirstName，再选第二个地点',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        );
      }),

      // 新增地点提示条
      Consumer<MapModeProvider>(builder: (_, mp, __) {
        if (mp.mode != MapMode.addSpot) return const SizedBox.shrink();
        final hasCoord = mp.pendingCoord != null;
        return Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: AppTheme.amber.withOpacity(0.15),
            child: Text(
              hasCoord ? '✅ 坐标已选取，在面板填写名称后确认' : '📍 点击地图选取新地点的坐标',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasCoord ? Colors.green : AppTheme.amber,
                fontSize: 12,
              ),
            ),
          ),
        );
      }),

      // 搜索按钮
      Positioned(top: 12, right: 12, child: _buildSearchButton()),
      if (_showSearch) Positioned.fill(child: _buildSearchOverlay()),

      // 地图风格切换
      Positioned(bottom: 152, right: 12, child: _buildStyleToggle()),

      // 筛选按钮 & 面板
      Positioned(bottom: 100, right: 12, child: _buildFilterButton()),
      if (_showFilter) Positioned(bottom: 140, right: 12, child: _buildFilterPanel()),

      // 数据面板
      if (_showDataPanel) Positioned(top: 12, left: 12, child: _buildDataPanel()),

      // 图例
      Positioned(bottom: 16, left: 12, child: _buildLegend()),
    ]);
  }

  // ── amap.AMapWidget ─────────────────────────────────────────────

  Widget _buildAMap() {
    return Consumer2<SpotProvider, MapModeProvider>(
      builder: (_, sp, mp, __) {
        if (!sp.isInitialized) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final markers = _buildMarkers(
          sp.visibleSpots,
          mp.measurePicks,
          mp.pendingCoord,
        );

        return amap.AMapWidget(
          // 地图类型（风格）
          mapType: _styleMode.mapType,
          // 初始相机位置：大理洱海中心
          initialCameraPosition: const amap.CameraPosition(
            target: xbase.LatLng(25.82, 100.19),
            zoom: 12.0,
          ),
          // amap.Marker 集合
          markers: markers,
          // 地图创建完成回调
          onMapCreated: (ctrl) => setState(() => _mapController = ctrl),
          // 点击地图空白区域
          onTap: _onMapTap,
          // UI 控件
          compassEnabled: true,
          scaleEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: false,
        );
      },
    );
  }

  // ── 搜索 ───────────────────────────────────────────────────

  Widget _buildSearchButton() => GestureDetector(
        onTap: () => setState(() => _showSearch = true),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.search, color: Color(0xFF555555), size: 20),
        ),
      );

  Widget _buildSearchOverlay() {
    return Consumer<SpotProvider>(builder: (context, provider, _) {
      final q = _searchCtrl.text.toLowerCase();
      final results = q.isEmpty
          ? <Spot>[]
          : provider.spots
              .where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  s.desc.toLowerCase().contains(q) ||
                  s.category.toLowerCase().contains(q))
              .toList();

      return GestureDetector(
        onTap: () => setState(() { _showSearch = false; _searchCtrl.clear(); }),
        child: Container(
          color: Colors.black54,
          child: SafeArea(
            child: Column(children: [
              // 搜索栏
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                ),
                child: Row(children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '搜索景点名称、描述、分类…',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => setState(() { _showSearch = false; _searchCtrl.clear(); }),
                  ),
                ]),
              ),

              // 结果列表
              if (results.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 14),
                    itemBuilder: (_, i) {
                      final spot = results[i];
                      return ListTile(
                        dense: true,
                        leading: Text(spot.emoji, style: const TextStyle(fontSize: 20)),
                        title: Text(spot.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: spot.desc.isNotEmpty
                            ? Text(spot.desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11))
                            : null,
                        trailing: _CategoryChip(category: spot.category),
                        onTap: () {
                          setState(() { _showSearch = false; _searchCtrl.clear(); });
                          _mapController?.moveCamera(
                            amap.CameraUpdate.newLatLngZoom(xbase.LatLng(spot.lat, spot.lng), 15),
                          );
                        },
                      );
                    },
                  ),
                ),

              if (q.isNotEmpty && results.isEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: const Text('没有找到相关地点', style: TextStyle(color: Colors.grey)),
                ),
            ]),
          ),
        ),
      );
    });
  }

  // ── 风格切换 ───────────────────────────────────────────────

  Widget _buildStyleToggle() {
    return GestureDetector(
      onTap: () {
        final modes = AMapStyleMode.values;
        setState(() => _styleMode = modes[(modes.indexOf(_styleMode) + 1) % modes.length]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.bg.withOpacity(0.88),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🗺️', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(_styleMode.label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // ── 筛选 ───────────────────────────────────────────────────

  Widget _buildFilterButton() {
    return Consumer<SpotProvider>(builder: (_, provider, __) {
      final active = provider.activeCategories.isNotEmpty;
      return GestureDetector(
        onTap: () => setState(() => _showFilter = !_showFilter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.purple : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('🏷️', style: TextStyle(fontSize: 14, color: active ? Colors.white : Colors.black87)),
            const SizedBox(width: 4),
            Text(
              active ? '筛选中 (${provider.activeCategories.length})' : '筛选地点',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: active ? Colors.white : Colors.black87),
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildFilterPanel() {
    return Consumer<SpotProvider>(builder: (_, provider, __) {
      final cats = provider.allCategories.toList()..sort();
      return Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('分类筛选', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              if (provider.activeCategories.isNotEmpty)
                GestureDetector(
                  onTap: provider.clearFilter,
                  child: const Text('清除', style: TextStyle(color: AppTheme.accent, fontSize: 11)),
                ),
            ]),
            const SizedBox(height: 8),
            ...cats.map((cat) {
              final on = provider.activeCategories.isEmpty || provider.activeCategories.contains(cat);
              return GestureDetector(
                onTap: () => provider.toggleCategory(cat),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: on ? AppTheme.purple : Colors.transparent,
                        border: Border.all(color: AppTheme.purple, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: on ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(cat, style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  // ── 数据面板 ───────────────────────────────────────────────

  Widget _buildDataPanel() => Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('数据管理', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _DataBtn(label: '📤 导出数据', color: const Color(0xFFE9D5FF), textColor: const Color(0xFF6D28D9), onTap: _exportData),
            const SizedBox(height: 8),
            _DataBtn(label: '📥 导入数据', color: const Color(0xFFD1FAE5), textColor: const Color(0xFF065F46), onTap: _importData),
            const SizedBox(height: 8),
            _DataBtn(label: '🔄 恢复默认', color: const Color(0xFFFEE2E2), textColor: const Color(0xFF991B1B), onTap: _confirmReset),
            const SizedBox(height: 6),
            const Text('导出所有地点、坐标、图片、分类', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      );

  // ── 图例 ───────────────────────────────────────────────────

  Widget _buildLegend() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendItem(color: Color(0xFFFFB6C1), label: '西路景点'),
            SizedBox(height: 4),
            _LegendItem(color: Color(0xFF87CEEB), label: '东路景点'),
            SizedBox(height: 4),
            _LegendItem(color: Color(0xFFDDA0DD), label: '古城/自定义'),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// 辅助组件
// ══════════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFE9D5FF), borderRadius: BorderRadius.circular(8)),
        child: Text(category, style: const TextStyle(color: Color(0xFF6D28D9), fontSize: 11)),
      );
}

class _HeaderBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _HeaderBtn({required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? activeColor : Colors.white60, width: 1.5),
          ),
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      );
}

class _DataBtn extends StatelessWidget {
  final String label;
  final Color color, textColor;
  final VoidCallback onTap;
  const _DataBtn({required this.label, required this.color, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      );
}