// GENERATED CODE - MANUALLY WRITTEN ADAPTER (no build_runner).

part of 'graph_values_hive_model.dart';

class GraphValuesDataHiveAdapter extends TypeAdapter<GraphValuesDataHive> {
  @override
  final int typeId = 10;

  @override
  GraphValuesDataHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GraphValuesDataHive(
      dataKey: (fields[0] as num).toDouble(),
      value: (fields[1] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, GraphValuesDataHive obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.dataKey)
      ..writeByte(1)
      ..write(obj.value);
  }
}


