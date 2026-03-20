import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:amap_map/amap_map.dart';

import 'models/spot.dart';
import 'providers/spot_provider.dart';
import 'providers/map_mode_provider.dart';
import 'screens/map_screen.dart';
import 'services/amap_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 高德地图 SDK 初始化（必须在 Hive 之前）────────────────
  // 注：x_amap_base 2.x 不再需要在 main.dart 初始化，由 amap_map 插件内部处理
  // 但仍需设置隐私合规声明
  AMapInitializer.updatePrivacyAgree(AMapService.privacyStatement);

  // ── Hive 本地数据库 ──────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(SpotAdapter());

  runApp(const TravelMapApp());
}

class TravelMapApp extends StatelessWidget {
  const TravelMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpotProvider()..init()),
        ChangeNotifierProvider(create: (_) => MapModeProvider()),
      ],
      child: MaterialApp(
        title: '大理洱海旅游地图',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const MapScreen(),
      ),
    );
  }
}
