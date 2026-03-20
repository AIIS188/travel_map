import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:amap_map/amap_map.dart' as amap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:x_amap_base/x_amap_base.dart' as xbase;

import '../models/spot.dart';
import '../providers/map_mode_provider.dart';
import '../providers/spot_provider.dart';
import '../services/amap_service.dart';
import '../utils/app_theme.dart';
import '../utils/color_utils.dart';
import '../widgets/measure_result_dialog.dart';
import '../widgets/spot_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  amap.AMapController? _mapController;
  AMapStyleMode _styleMode = AMapStyleMode.normal;

  // 默认视角（从 SharedPreferences 读取/保存）
  static const _defaultLat  = 25.82;
  static const _defaultLng  = 100.19;
  static const _defaultZoom = 12.0;
  double _initLat  = _defaultLat;
  double _initLng  = _defaultLng;
  double _initZoom = _defaultZoom;

  // 跟踪当前地图视角（用于保存默认视角）
  xbase.LatLng _currentCenter = const xbase.LatLng(_defaultLat, _defaultLng);
  double _currentZoom = _defaultZoom;

  @override
  void initState() {
    super.initState();
    _loadDefaultView();
  }

  Future<void> _loadDefaultView() async {
    final prefs = await SharedPreferences.getInstance();
    final lat  = prefs.getDouble('default_lat');
    final lng  = prefs.getDouble('default_lng');
    final zoom = prefs.getDouble('default_zoom');
    if (lat != null && lng != null && zoom != null && mounted) {
      setState(() { _initLat = lat; _initLng = lng; _initZoom = zoom; });
    }
  }

  Future<void> _saveDefaultView() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('default_lat',  _currentCenter.latitude);
    await prefs.setDouble('default_lng',  _currentCenter.longitude);
    await prefs.setDouble('default_zoom', _currentZoom);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 默认视角已保存'), duration: Duration(seconds: 2)),
      );
    }
  }

  final TextEditingController _searchCtrl = TextEditingController();
  bool _showSearch    = false;
  bool _showFilter    = false;
  bool _showDataPanel = false;
  List<Map<String, dynamic>> _searchPoiResults = [];
  bool _isSearching = false;

  // 添加地点面板
  final TextEditingController _addNameCtrl  = TextEditingController();
  final TextEditingController _addEmojiCtrl = TextEditingController(text: '📍');

  // 移动地点：待移动的 spot id
  String? _movingSpotId;

  // marker 图片缓存 key=spotId_selected
  final Map<String, amap.BitmapDescriptor> _markerIconCache = {};

  // 保留上一帧 markers，避免 FutureBuilder 重建时闪烁
  Set<amap.Marker> _lastMarkers = {};

  String? _measureFirstName;

  // 用 Canvas 绘制 emoji + 名称标签，生成 BitmapDescriptor（带缓存）
  Future<amap.BitmapDescriptor> _spotBitmap(Spot spot, {bool selected = false}) async {
    final key = '${spot.id}_$selected';
    if (_markerIconCache.containsKey(key)) return _markerIconCache[key]!;

    const double px = 3.0; // 像素倍率
    const double pinW = 48 * px, pinH = 48 * px;
    const double labelPad = 8 * px, labelH = 20 * px;
    const double gap = 4 * px;

    // 测量标签文字宽度
    final namePainter = TextPainter(
      text: TextSpan(
        text: spot.name,
        style: TextStyle(fontSize: 10 * px, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelW = namePainter.width + labelPad * 2;

    final totalW = labelW > pinW ? labelW : pinW;
    final totalH = pinH + gap + labelH;
    final pinOffsetX = (totalW - pinW) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, totalW, totalH));

    // 1. 绘制菱形 pin
    final pinRect = RRect.fromLTRBAndCorners(
      pinOffsetX, 0, pinOffsetX + pinW, pinH,
      topLeft: const Radius.circular(22 * px),
      topRight: const Radius.circular(22 * px),
      bottomRight: const Radius.circular(22 * px),
      bottomLeft: Radius.zero,
    );
    final pinColor = hexToColor(spot.color);
    // 阴影
    canvas.drawShadow(Path()..addRRect(pinRect), Colors.black, 8, true);
    // 背景
    canvas.drawRRect(pinRect, Paint()..color = pinColor.withOpacity(0.85));
    // 边框
    canvas.drawRRect(
      pinRect,
      Paint()
        ..color = selected ? const Color(0xFF34D399) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 * px : 2.5 * px,
    );

    // 2. 绘制 emoji（居中）
    final emojiPainter = TextPainter(
      text: TextSpan(
        text: spot.emoji,
        style: TextStyle(fontSize: 20 * px),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emojiPainter.paint(
      canvas,
      Offset(
        pinOffsetX + (pinW - emojiPainter.width) / 2,
        (pinH - emojiPainter.height) / 2,
      ),
    );

    // 3. 绘制毛玻璃标签（用半透明白色模拟）
    final labelTop = pinH + gap;
    final labelLeft = (totalW - labelW) / 2;
    final labelRect = RRect.fromLTRBR(
      labelLeft, labelTop, labelLeft + labelW, labelTop + labelH,
      const Radius.circular(10 * px),
    );
    canvas.drawShadow(Path()..addRRect(labelRect), Colors.black, 4, false);
    canvas.drawRRect(labelRect, Paint()..color = Colors.white.withOpacity(0.82));
    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = px,
    );
    namePainter.paint(
      canvas,
      Offset(labelLeft + labelPad, labelTop + (labelH - namePainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(totalW.toInt(), totalH.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final desc = amap.BitmapDescriptor.fromBytes(bytes);
    _markerIconCache[key] = desc;
    return desc;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addNameCtrl.dispose();
    _addEmojiCtrl.dispose();
    super.dispose();
  }

  // ── amap.Marker 构建 ────────────────────────────────────────────

  Future<Set<amap.Marker>> _buildMarkersAsync(
    List<Spot> spots,
    List<String> measurePicks,
    xbase.LatLng? pendingCoord,
    MapMode mode,
  ) async {
    final result = <amap.Marker>{};
    final isDragMode = mode == MapMode.moveSpot;

    for (final spot in spots) {
      final isSelected = measurePicks.contains(spot.id);
      final icon = await _spotBitmap(spot, selected: isSelected);
      result.add(amap.Marker(
        position: xbase.LatLng(spot.lat, spot.lng),
        icon: icon,
        draggable: isDragMode,
        infoWindowEnable: !isDragMode,
        infoWindow: amap.InfoWindow(
          title: '${spot.emoji} ${spot.name}',
          snippet: spot.meta.isNotEmpty ? spot.meta : spot.desc,
        ),
        onTap: isDragMode ? null : (_) => _onMarkerTap(spot),
        onDragEnd: isDragMode
            ? (_, endPos) => _onSpotDragEnd(spot, endPos)
            : null,
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

  // ── 交互事件 ───────────────────────────────────────────────

  void _onMarkerTap(Spot spot) {
    final mp = context.read<MapModeProvider>();
    if (mp.mode == MapMode.measure) {
      _handleMeasureTap(spot);
    } else if (mp.mode == MapMode.moveSpot) {
      // 在编辑模式显示操作菜单（移动 / 删除）
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Text('${spot.emoji} ${spot.name}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.open_with, color: Color(0xFF059669)),
                  title: const Text('移动位置'),
                  subtitle: const Text('选中后点击地图设置新位置'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _movingSpotId = spot.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已选中「${spot.name}」，点击地图选择新位置'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('删除地标', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(spot);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    } else if (mp.mode == MapMode.normal) {
      _openDetail(spot);
    }
  }

  Future<void> _confirmDelete(Spot spot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除「${spot.name}」'),
        content: const Text('确认删除这个地标？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _markerIconCache.remove('${spot.id}_false');
      _markerIconCache.remove('${spot.id}_true');
      final sp = context.read<SpotProvider>();
      await sp.deleteSpot(spot.id);
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

  void _onSpotDragEnd(Spot spot, xbase.LatLng newPos) {
    final updated = spot.copyWith(lat: newPos.latitude, lng: newPos.longitude);
    context.read<SpotProvider>().updateSpot(updated);
  }

  void _onMapTap(xbase.LatLng coord) {
    final mp = context.read<MapModeProvider>();
    if (mp.mode == MapMode.addSpot) {
      mp.setPendingCoord(coord);
    } else if (mp.mode == MapMode.moveSpot && _movingSpotId != null) {
      // 移动地标到新坐标
      final sp = context.read<SpotProvider>();
      final spot = sp.spots.firstWhere((s) => s.id == _movingSpotId, orElse: () => throw StateError(''));
      final updated = spot.copyWith(lat: coord.latitude, lng: coord.longitude);
      sp.updateSpot(updated);
      setState(() => _movingSpotId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${spot.name}」位置已更新'), duration: const Duration(seconds: 2)),
      );
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
        final isMove    = mp.mode == MapMode.moveSpot;
        return Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToolBtn(
                    icon: Icons.add_location_alt_outlined,
                    label: isAdd ? '取消' : '添加',
                    active: isAdd,
                    activeColor: AppTheme.amber,
                    onTap: () {
                      if (isAdd) mp.exitAddSpot();
                      else mp.enterAddSpot();
                    },
                  ),
                  _ToolBtn(
                    icon: Icons.open_with,
                    label: isMove ? '取消' : '移动',
                    active: isMove,
                    activeColor: const Color(0xFF34D399),
                    onTap: () {
                      if (isMove) mp.exitMoveSpot();
                      else mp.enterMoveSpot();
                    },
                  ),
                  _ToolBtn(
                    icon: Icons.straighten,
                    label: isMeasure ? '取消' : '测距',
                    active: isMeasure,
                    activeColor: AppTheme.green,
                    onTap: () {
                      if (isMeasure) { mp.exitMeasure(); setState(() => _measureFirstName = null); }
                      else mp.enterMeasure();
                    },
                  ),
                  _ToolBtn(
                    icon: Icons.my_location,
                    label: '视角',
                    active: false,
                    activeColor: AppTheme.accent,
                    onTap: _saveDefaultView,
                  ),
                  _ToolBtn(
                    icon: Icons.storage_outlined,
                    label: '数据',
                    active: _showDataPanel,
                    activeColor: AppTheme.accent,
                    onTap: () => setState(() => _showDataPanel = !_showDataPanel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

      // 移动地点提示条
      Consumer<MapModeProvider>(builder: (_, mp, __) {
        if (mp.mode != MapMode.moveSpot) return const SizedBox.shrink();
        return Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: const Color(0xFF34D399).withOpacity(0.18),
            child: const Text(
              '✏️ 编辑模式：点击地标可移动或删除',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF059669), fontSize: 12),
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

      // 添加地点悬浮面板（置于最顶层，addSpot 模式时显示）
      Consumer<MapModeProvider>(builder: (_, mp, __) {
        if (mp.mode != MapMode.addSpot) return const SizedBox.shrink();
        return Positioned(bottom: 0, left: 0, right: 0, child: _buildAddSpotPanel(mp));
      }),
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

        return FutureBuilder<Set<amap.Marker>>(
          future: _buildMarkersAsync(
            sp.visibleSpots,
            mp.measurePicks,
            mp.pendingCoord,
            mp.mode,
          ),
          builder: (_, snapshot) {
            if (snapshot.hasData) _lastMarkers = snapshot.data!;
            final markers = _lastMarkers;
            return amap.AMapWidget(
              mapType: _styleMode.mapType,
              initialCameraPosition: amap.CameraPosition(
                target: xbase.LatLng(_initLat, _initLng),
                zoom: _initZoom,
              ),
              markers: markers,
              onMapCreated: (ctrl) => setState(() => _mapController = ctrl),
              onCameraMove: (pos) {
                _currentCenter = pos.target;
                _currentZoom   = pos.zoom;
              },
              onTap: _onMapTap,
              compassEnabled: true,
              scaleEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: false,
            );
          },
        );
      },
    );
  }

  // ── 添加地点悬浮面板 ────────────────────────────────────────

  Widget _buildAddSpotPanel(MapModeProvider mp) {
    final coord = mp.pendingCoord;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📍 新增地点', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _addNameCtrl,
                  decoration: InputDecoration(
                    labelText: '地点名称',
                    hintText: '如：南诏风情岛',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _addEmojiCtrl,
                  decoration: InputDecoration(
                    labelText: 'Emoji',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // 坐标状态
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: coord != null ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: coord != null ? Colors.green : Colors.amber),
              ),
              child: Text(
                coord != null
                    ? '✅ 已选坐标：${coord.latitude.toStringAsFixed(5)}, ${coord.longitude.toStringAsFixed(5)}'
                    : '⚠️ 请在上方地图点击选取位置',
                style: TextStyle(fontSize: 12, color: coord != null ? Colors.green[700] : Colors.amber[800]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name = _addNameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请填写地点名称')));
                      return;
                    }
                    if (coord == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请先在地图上点击选取位置')));
                      return;
                    }
                    final spot = Spot(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      emoji: _addEmojiCtrl.text.trim().isEmpty ? '📍' : _addEmojiCtrl.text.trim(),
                      lat: coord.latitude,
                      lng: coord.longitude,
                      isCustom: true,
                      color: '#a78bfa',
                      category: '自定义',
                    );
                    await context.read<SpotProvider>().addSpot(spot);
                    _addNameCtrl.clear();
                    _addEmojiCtrl.text = '📍';
                    mp.exitAddSpot();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lightBlue, foregroundColor: Colors.white),
                  child: const Text('✅ 添加'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _addNameCtrl.clear();
                    _addEmojiCtrl.text = '📍';
                    mp.exitAddSpot();
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey, side: const BorderSide(color: Colors.grey)),
                  child: const Text('取消'),
                ),
              ),
            ]),
          ],
        ),
      ),
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

  Future<void> _doAmapSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://restapi.amap.com/v3/place/text'
        '?key=8c3faf15f80a0890e19055920fb35a99'
        '&keywords=${Uri.encodeComponent(keyword)}'
        '&city=大理&citylimit=false&offset=10&page=1&extensions=base',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final pois = (data['pois'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() { _searchPoiResults = pois; _isSearching = false; });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Widget _buildSearchOverlay() {
    return Consumer<SpotProvider>(builder: (context, provider, _) {
      final q = _searchCtrl.text.toLowerCase();
      final localResults = q.isEmpty
          ? <Spot>[]
          : provider.spots
              .where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  s.desc.toLowerCase().contains(q) ||
                  s.category.toLowerCase().contains(q))
              .toList();

      return GestureDetector(
        onTap: () => setState(() {
          _showSearch = false;
          _searchCtrl.clear();
          _searchPoiResults = [];
        }),
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
                      onChanged: (_) => setState(() { _searchPoiResults = []; }),
                      onSubmitted: (v) => _doAmapSearch(v),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: '搜索地点名称（回车搜地图）',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else ...[
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _searchPoiResults = [];
                        }),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => setState(() {
                        _showSearch = false;
                        _searchCtrl.clear();
                        _searchPoiResults = [];
                      }),
                    ),
                  ],
                ]),
              ),

              // 搜索结果（可滚动）
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(children: [

              // 高德 POI 搜索结果
              if (_searchPoiResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Text('地图搜索结果', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _searchPoiResults.length > 8 ? 8 : _searchPoiResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 14),
                        itemBuilder: (_, i) {
                          final poi = _searchPoiResults[i];
                          // location 格式: "lng,lat"
                          final loc = (poi['location'] as String? ?? '').split(',');
                          final lng = loc.length == 2 ? double.tryParse(loc[0]) : null;
                          final lat = loc.length == 2 ? double.tryParse(loc[1]) : null;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place, color: Colors.redAccent, size: 22),
                            title: Text(poi['name'] as String? ?? '未知地点',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(poi['address'] as String? ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11)),
                            onTap: () {
                              if (lat != null && lng != null) {
                                setState(() {
                                  _showSearch = false;
                                  _searchCtrl.clear();
                                  _searchPoiResults = [];
                                });
                                _mapController?.moveCamera(
                                  amap.CameraUpdate.newLatLngZoom(xbase.LatLng(lat, lng), 16),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // 本地地标结果
              if (localResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Text('我的地标', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: localResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 14),
                        itemBuilder: (_, i) {
                          final spot = localResults[i];
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
                              setState(() {
                                _showSearch = false;
                                _searchCtrl.clear();
                                _searchPoiResults = [];
                              });
                              _mapController?.moveCamera(
                                amap.CameraUpdate.newLatLngZoom(xbase.LatLng(spot.lat, spot.lng), 15),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

              if (q.isNotEmpty && localResults.isEmpty && _searchPoiResults.isEmpty && !_isSearching)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: const Text('没有找到相关地点，按回车搜索高德地图', style: TextStyle(color: Colors.grey)),
                ),
              ]),  // Column
                ),  // SingleChildScrollView
              ),   // Expanded
            ]),   // 外层 Column
          ),      // SafeArea
        ),        // Container
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

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? activeColor : Colors.white38, width: 1.2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
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