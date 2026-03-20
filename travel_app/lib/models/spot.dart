import 'package:hive/hive.dart';

part 'spot.g.dart';

@HiveType(typeId: 0)
class Spot extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String emoji;

  @HiveField(3)
  double lat;

  @HiveField(4)
  double lng;

  @HiveField(5)
  String meta;

  @HiveField(6)
  String desc;

  @HiveField(7)
  String color; // hex string e.g. '#FFB6C1'

  @HiveField(8)
  String category;

  @HiveField(9)
  bool isCustom;

  @HiveField(10)
  List<String> photoBase64; // base64 encoded images

  Spot({
    required this.id,
    required this.name,
    required this.emoji,
    required this.lat,
    required this.lng,
    this.meta = '',
    this.desc = '',
    this.color = '#a78bfa',
    this.category = '打卡',
    this.isCustom = false,
    List<String>? photoBase64,
  }) : photoBase64 = photoBase64 ?? [];

  Spot copyWith({
    String? name,
    String? emoji,
    double? lat,
    double? lng,
    String? meta,
    String? desc,
    String? color,
    String? category,
    List<String>? photoBase64,
  }) {
    return Spot(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      meta: meta ?? this.meta,
      desc: desc ?? this.desc,
      color: color ?? this.color,
      category: category ?? this.category,
      isCustom: isCustom,
      photoBase64: photoBase64 ?? List.from(this.photoBase64),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'lat': lat,
        'lng': lng,
        'meta': meta,
        'desc': desc,
        'color': color,
        'category': category,
        'isCustom': isCustom,
        'photoBase64': photoBase64,
      };

  factory Spot.fromJson(Map<String, dynamic> j) => Spot(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '📍',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        meta: j['meta'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        color: j['color'] as String? ?? '#a78bfa',
        category: j['category'] as String? ?? '打卡',
        isCustom: j['isCustom'] as bool? ?? false,
        photoBase64: List<String>.from(j['photoBase64'] as List? ?? []),
      );
}
