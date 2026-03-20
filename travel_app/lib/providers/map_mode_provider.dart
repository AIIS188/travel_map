import 'package:flutter/foundation.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../utils/color_utils.dart';

enum MapMode { normal, measure, addSpot }

class MapModeProvider extends ChangeNotifier {
  MapMode _mode = MapMode.normal;
  MapMode get mode => _mode;

  // ── 测距 ──────────────────────────────────────────────────
  final List<String> _measurePicks = [];
  List<String> get measurePicks => List.unmodifiable(_measurePicks);

  void enterMeasure() {
    _mode = MapMode.measure;
    _measurePicks.clear();
    notifyListeners();
  }

  void exitMeasure() {
    _mode = MapMode.normal;
    _measurePicks.clear();
    notifyListeners();
  }

  /// 选择测距点。选满两点后返回直线距离（km），否则返回 null。
  double? pickMeasureSpot(
    String spotId,
    double lat,
    double lng,
    Map<String, List<double>> coords,
  ) {
    if (_measurePicks.contains(spotId)) return null;
    _measurePicks.add(spotId);
    notifyListeners();

    if (_measurePicks.length == 2) {
      final a = coords[_measurePicks[0]];
      final b = coords[_measurePicks[1]];
      if (a != null && b != null) {

        final dist = haversineKm(a[0], a[1], b[0], b[1]);
        return double.parse(dist.toStringAsFixed(2));
      }
    }
    return null;
  }

  // ── 新增地点 ───────────────────────────────────────────────
  LatLng? _pendingCoord;
  LatLng? get pendingCoord => _pendingCoord;

  void enterAddSpot() {
    _mode = MapMode.addSpot;
    _pendingCoord = null;
    notifyListeners();
  }

  void exitAddSpot() {
    _mode = MapMode.normal;
    _pendingCoord = null;
    notifyListeners();
  }

  void setPendingCoord(LatLng latlng) {
    _pendingCoord = latlng;
    notifyListeners();
  }

  void clearPendingCoord() {
    _pendingCoord = null;
    notifyListeners();
  }
}
