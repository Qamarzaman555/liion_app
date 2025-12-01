import 'package:hive/hive.dart';

import '../models/graph_values_hive_model.dart';

class GraphHiveStorageService {
  static const String currentBoxName = 'currentChargeGraphData';
  static const String pastBoxName = 'pastChargeGraphData';

  static Future<Box<GraphValuesDataHive>> _openBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<GraphValuesDataHive>(boxName);
    }
    return await Hive.openBox<GraphValuesDataHive>(boxName);
  }

  /// Append a single sample to the "current" graph box.
  static Future<void> appendCurrentSample({
    required double seconds,
    required double current,
  }) async {
    final box = await _openBox(currentBoxName);
    await box.add(GraphValuesDataHive(dataKey: seconds, value: current));
  }

  /// Get all samples for the current session, sorted by time.
  static Future<List<GraphValuesDataHive>> getCurrentSamples() async {
    final box = await _openBox(currentBoxName);
    final data = box.values.toList();
    data.sort((a, b) => a.dataKey.compareTo(b.dataKey));
    return data;
  }

  /// Clear all current-session samples.
  static Future<void> clearCurrentSamples() async {
    final box = await _openBox(currentBoxName);
    await box.clear();
  }

  /// Get all samples for the past (last) session, sorted by time.
  static Future<List<GraphValuesDataHive>> getPastSamples() async {
    final box = await _openBox(pastBoxName);
    final data = box.values.toList();
    data.sort((a, b) => a.dataKey.compareTo(b.dataKey));
    return data;
  }

  /// Replace the past-session samples with the given list.
  static Future<void> replacePastSamples(
    List<GraphValuesDataHive> samples,
  ) async {
    final box = await _openBox(pastBoxName);
    await box.clear();
    // Using addAll keeps write operations efficient.
    await box.addAll(samples);
  }
}
