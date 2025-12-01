import 'package:hive/hive.dart';

part 'graph_values_hive_model.g.dart';

@HiveType(typeId: 10)
class GraphValuesDataHive {
  GraphValuesDataHive({required this.dataKey, required this.value});

  /// Seconds since the start of the session.
  @HiveField(0)
  final double dataKey;

  /// Current value at this point in time.
  @HiveField(1)
  final double value;
}
