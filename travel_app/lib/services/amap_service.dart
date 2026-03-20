import 'package:amap_map/amap_map.dart' as amap;
import 'package:x_amap_base/x_amap_base.dart' as xbase;

/// 高德地图 Key 与隐私合规配置（amap_map ^1.0.15 + x_amap_base ^2.0.0+2）
class AMapService {
  static const String androidKey = 'ce104b17baffde58b352cc8d288964f2';
  static const String iosKey     = 'ce104b17baffde58b352cc8d288964f2';

  static const xbase.AMapApiKey apiKey = xbase.AMapApiKey(
    androidKey: androidKey,
    iosKey: iosKey,
  );

  static const xbase.AMapPrivacyStatement privacyStatement =
      xbase.AMapPrivacyStatement(
    hasContains: true,
    hasShow: true,
    hasAgree: true,
  );
}

/// 地图风格枚举 —— mapType 来自 amap_map 包
enum AMapStyleMode {
  night    (label: '暗色', mapType: amap.MapType.night),
  normal   (label: '标准', mapType: amap.MapType.normal),
  satellite(label: '卫星', mapType: amap.MapType.satellite),
  navi     (label: '导航', mapType: amap.MapType.navi);

  const AMapStyleMode({required this.label, required this.mapType});
  final String label;
  final amap.MapType mapType;
}