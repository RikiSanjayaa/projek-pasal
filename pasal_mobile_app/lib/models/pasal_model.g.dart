// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pasal_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PasalModelAdapter extends TypeAdapter<PasalModel> {
  @override
  final int typeId = 1;

  @override
  PasalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PasalModel(
      id: fields[0] as String,
      undangUndangId: fields[1] as String,
      nomor: fields[2] as String,
      isi: fields[3] as String,
      penjelasan: fields[4] as String?,
      judul: fields[5] as String?,
      keywords: (fields[6] as List).cast<String>(),
      relatedIds: (fields[7] as List).cast<String>(),
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PasalModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.undangUndangId)
      ..writeByte(2)
      ..write(obj.nomor)
      ..writeByte(3)
      ..write(obj.isi)
      ..writeByte(4)
      ..write(obj.penjelasan)
      ..writeByte(5)
      ..write(obj.judul)
      ..writeByte(6)
      ..write(obj.keywords)
      ..writeByte(7)
      ..write(obj.relatedIds)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasalModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
