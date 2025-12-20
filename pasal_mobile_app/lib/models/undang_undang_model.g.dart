// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'undang_undang_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UndangUndangModelAdapter extends TypeAdapter<UndangUndangModel> {
  @override
  final int typeId = 0;

  @override
  UndangUndangModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UndangUndangModel(
      id: fields[0] as String,
      kode: fields[1] as String,
      nama: fields[2] as String,
      namaLengkap: fields[3] as String?,
      tahun: fields[4] as int,
      isActive: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UndangUndangModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.kode)
      ..writeByte(2)
      ..write(obj.nama)
      ..writeByte(3)
      ..write(obj.namaLengkap)
      ..writeByte(4)
      ..write(obj.tahun)
      ..writeByte(5)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UndangUndangModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
