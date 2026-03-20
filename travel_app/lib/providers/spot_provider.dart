import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/spot.dart';
import '../utils/default_spots.dart';

class SpotProvider extends ChangeNotifier {
  static const String _boxName = 'spots';

  late Box<Spot> _box;
  List<Spot> _spots = [];
  Set<String> _activeCategories = {}; // empty = show all
  bool _isInitialized = false;

  List<Spot> get spots => _spots;
  Set<String> get activeCategories => _activeCategories;
  bool get isInitialized => _isInitialized;

  /// All unique categories
  Set<String> get allCategories =>
      _spots.map((s) => s.category.isEmpty ? '打卡' : s.category).toSet();

  /// Filtered spots for display
  List<Spot> get visibleSpots {
    if (_activeCategories.isEmpty) return List.from(_spots);
    return _spots
        .where((s) => _activeCategories.contains(s.category))
        .toList();
  }

  Future<void> init() async {
    _box = await Hive.openBox<Spot>(_boxName);

    if (_box.isEmpty) {
      // First run: seed with default spots
      for (final s in kDefaultSpots) {
        await _box.put(s.id, s);
      }
    }
    _spots = _box.values.toList();
    _isInitialized = true;
    notifyListeners();
  }

  // ── CRUD ────────────────────────────────────────────────

  Future<void> addSpot(Spot spot) async {
    await _box.put(spot.id, spot);
    _spots = _box.values.toList();
    notifyListeners();
  }

  Future<void> updateSpot(Spot spot) async {
    await _box.put(spot.id, spot);
    final idx = _spots.indexWhere((s) => s.id == spot.id);
    if (idx >= 0) _spots[idx] = spot;
    notifyListeners();
  }

  Future<void> deleteSpot(String id) async {
    await _box.delete(id);
    _spots.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Spot? getById(String id) {
    try {
      return _spots.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Photos ───────────────────────────────────────────────

  Future<void> addPhoto(String spotId, String base64) async {
    final spot = getById(spotId);
    if (spot == null) return;
    final updated = spot.copyWith(
        photoBase64: [...spot.photoBase64, base64]);
    await updateSpot(updated);
  }

  Future<void> deletePhoto(String spotId, int index) async {
    final spot = getById(spotId);
    if (spot == null) return;
    final photos = List<String>.from(spot.photoBase64)..removeAt(index);
    await updateSpot(spot.copyWith(photoBase64: photos));
  }

  // ── Filter ───────────────────────────────────────────────

  void toggleCategory(String cat) {
    if (_activeCategories.contains(cat)) {
      _activeCategories.remove(cat);
    } else {
      _activeCategories.add(cat);
    }
    notifyListeners();
  }

  void clearFilter() {
    _activeCategories.clear();
    notifyListeners();
  }

  // ── Export / Import ──────────────────────────────────────

  String exportJson() {
    final data = {
      'version': 1,
      'exportTime': DateTime.now().toIso8601String(),
      'spots': _spots.map((s) => s.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  Future<String?> importJson(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data['version'] == null) return '无效的数据文件';
      final list = (data['spots'] as List)
          .map((j) => Spot.fromJson(j as Map<String, dynamic>))
          .toList();
      for (final s in list) {
        await _box.put(s.id, s);
      }
      _spots = _box.values.toList();
      notifyListeners();
      return null; // success
    } catch (e) {
      return '导入失败：$e';
    }
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    await _box.clear();
    for (final s in kDefaultSpots) {
      await _box.put(s.id, s);
    }
    _spots = _box.values.toList();
    notifyListeners();
  }
}
