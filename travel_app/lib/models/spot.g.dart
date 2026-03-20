// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpotAdapter extends TypeAdapter<Spot> {
  @override
  final int typeId = 0;

  @override
  Spot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Spot(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      lat: fields[3] as double,
      lng: fields[4] as double,
      meta: fields[5] as String,
      desc: fields[6] as String,
      color: fields[7] as String,
      category: fields[8] as String,
      isCustom: fields[9] as bool,
      photoBase64: (fields[10] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Spot obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.lat)
      ..writeByte(4)
      ..write(obj.lng)
      ..writeByte(5)
      ..write(obj.meta)
      ..writeByte(6)
      ..write(obj.desc)
      ..writeByte(7)
      ..write(obj.color)
      ..writeByte(8)
      ..write(obj.category)
      ..writeByte(9)
      ..write(obj.isCustom)
      ..writeByte(10)
      ..write(obj.photoBase64);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
