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

  // ── Hive 本地数据库 ──────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(SpotAdapter());

  runApp(const TravelMapApp());
}

class TravelMapApp extends StatelessWidget {
  const TravelMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ── 高德 SDK 初始化（需在第一个 Widget build 时调用）───
    // amap_map ^1.0.15 要求在 context 可用时初始化
    AMapInitializer.init(context, apiKey: AMapService.apiKey);
    AMapInitializer.updatePrivacyAgree(AMapService.privacyStatement);

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
