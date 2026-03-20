# 🏝️ 大理洱海旅游地图 — Flutter App（v3 · 高德原生 SDK）

使用 **高德官方 Flutter 插件** `amap_flutter_map` 实现原生地图渲染，
搭配 Hive 本地持久化，全功能无后端旅游地图应用。

---

## 🔑 高德 Key 配置

| 平台 | Key 类型 | Key 值 | 配置位置 |
|------|---------|--------|---------|
| Android | tmap_android | `ce104b17baffde58b352cc8d288964f2` | `AndroidManifest.xml` + `map_screen.dart` |
| iOS | 待申请 | — | `Info.plist` + `map_screen.dart` |
| Web JS | `adb725bb39b7f4ec0dca22d69e74d780` | Web 端不使用原生 SDK | — |

> iOS Key 申请地址：https://console.amap.com/  
> 平台选择 **iOS**，BundleID 填写你的包名

---

## 📦 项目结构

```
lib/
├── main.dart                     ← 入口 + Hive初始化 + 高德隐私合规
├── models/
│   ├── spot.dart                 ← Hive 数据模型
│   └── spot.g.dart               ← TypeAdapter（手写，无需 build_runner）
├── providers/
│   ├── spot_provider.dart        ← 地点 CRUD、照片、筛选、导入导出
│   └── map_mode_provider.dart    ← 地图交互模式状态机
├── screens/
│   └── map_screen.dart           ← 主地图页（AMapWidget 集成）
├── services/
│   └── amap_service.dart         ← 高德 Key 管理 & 隐私合规工具
├── widgets/
│   ├── spot_detail_sheet.dart    ← 地点详情底部弹出
│   ├── add_spot_sheet.dart       ← 新增地点面板
│   ├── lightbox_widget.dart      ← 照片灯箱
│   └── measure_result_dialog.dart← 测距结果弹窗
└── utils/
    ├── app_theme.dart            ← 颜色/主题常量
    ├── color_utils.dart          ← HEX转Color + Haversine 距离
    └── default_spots.dart        ← 内置 8 个大理洱海景点
```

---

## 🚀 快速开始

```bash
cd travel_map_flutter
flutter pub get
flutter run -d android    # 需要 Android 设备或模拟器
```

---

## ✨ 功能清单

| 功能 | 实现 |
|------|------|
| 高德原生地图渲染 | `AMapWidget` + tmap_android Key |
| 地图风格切换 | 暗色 / 标准 / 卫星 / 导航 四档循环 |
| 景点标记（颜色分类） | `BitmapDescriptor.defaultMarkerWithHue` |
| 点击标记弹详情 | `InfoWindow.onTap` → `SpotDetailSheet` |
| 地点信息编辑 | 底部弹出内联编辑 → Hive 持久化 |
| 打卡照片管理 | `image_picker` + base64 + Hive |
| 照片灯箱 | `LightboxWidget`（缩放 + 翻页） |
| 📏 测距 | 两点点击 + Haversine 公式 |
| ➕ 新增地点 | 点地图取坐标 + 填写信息 |
| 🏷️ 分类筛选 | 多选 checkbox 筛选 |
| 🔍 本地搜索 | 名称 / 描述 / 分类模糊匹配 |
| 💾 数据导出 | JSON + `share_plus` |
| 📥 数据导入 | `file_picker` + JSON 解析 |

---

## ⚙️ 依赖说明

| 包 | 用途 |
|----|------|
| `amap_flutter_map` ^3.0.0 | 高德官方地图 Flutter SDK |
| `amap_flutter_base` ^3.0.1 | 高德基础库（LatLng、BitmapDescriptor 等） |
| `hive` + `hive_flutter` | 本地持久化 |
| `latlong2` | MapModeProvider 内部坐标类型 |
| `image_picker` | 选取打卡照片 |
| `file_picker` + `share_plus` | 数据导入导出 |
| `provider` | ChangeNotifier 状态管理 |
| `uuid` | 自定义地点唯一 ID |

---

## 📱 Android 关键配置

### `AndroidManifest.xml`
```xml
<!-- 高德 Key（必须） -->
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="ce104b17baffde58b352cc8d288964f2"/>
```

### `android/app/build.gradle`
```gradle
defaultConfig {
    minSdkVersion 21     // 高德 SDK 最低要求
    ndk {
        abiFilters "armeabi-v7a", "arm64-v8a", "x86_64"
    }
}
```

---

## 🍎 iOS 配置（待申请 Key 后补充）

1. 在高德控制台创建 iOS 应用，填写 `BundleID`
2. 将 Key 填入 `lib/screens/map_screen.dart` 的 `_amapKey.iosKey`
3. 在 `ios/Runner/Info.plist` 添加：
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要位置权限显示您在地图上的位置</string>
```

---

## ❗ 隐私合规说明

高德地图 SDK 要求在初始化前必须完成隐私合规调用。
本项目在 `main.dart` 的 `AMapService.init()` 中已调用：
```dart
AMapInitializer.updatePrivacyShow(true, true);
AMapInitializer.updatePrivacyAgree(true);
```
正式上架应用时，需在用户**同意隐私政策后**才调用 `updatePrivacyAgree(true)`，
可通过 `SharedPreferences` 记录用户是否已同意。
