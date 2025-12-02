import 'dart:math';

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

  /// Overall condition to decide whether a current session should be
  /// promoted to the past (last) charge graph.
  ///
  /// - Data must span more than 4 minutes.
  /// - At least one point must have value >= 0.1A.
  static bool checkDataConditions(List<GraphValuesDataHive> dataPoints) {
    if (dataPoints.isEmpty) {
      return false;
    }

    // Ensure sorted by time.
    dataPoints.sort((a, b) => a.dataKey.compareTo(b.dataKey));

    final double firstTime = dataPoints.first.dataKey;
    final double lastTime = dataPoints.last.dataKey;
    final double timeDifference = lastTime - firstTime;

    final bool hasValueAboveThreshold = dataPoints.any(
      (point) => point.value >= 0.1,
    );

    const double fourMinutesInSeconds = 4 * 60;
    final bool timeCondition = timeDifference > fourMinutesInSeconds;

    return timeCondition && hasValueAboveThreshold;
  }

  // /// DEBUG / TESTING ONLY:
  // /// Seed the current graph box with synthetic data for a given duration.
  // ///
  // /// This lets you simulate very long sessions (e.g. 4 days) and then
  // /// restart the app to observe how long it takes to promote data into
  // /// the past charge graph.
  // static Future<void> seedDummyCurrentData({
  //   required Duration duration,
  //   required Duration sampleEvery,
  // }) async {
  //   final box = await _openBox(currentBoxName);
  //   await box.clear();

  //   final totalSeconds = duration.inSeconds;
  //   final step = sampleEvery.inSeconds;

  //   for (int elapsed = 0; elapsed <= totalSeconds; elapsed += step) {
  //     final seconds = elapsed.toDouble();
  //     // Pseudo current waveform between ~0 and 3A with some variation.
  //     final waveform = sin(elapsed / 1800.0) + 1.5;
  //     final noise = 0.2 * sin(elapsed / 60.0);
  //     final current = (waveform + noise).clamp(0.0, 3.0);

  //     await box.add(GraphValuesDataHive(dataKey: seconds, value: current));
  //   }
  // }
}
