import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liion_app/app/modules/leo_empty/models/graph_point.dart';
import 'package:liion_app/app/modules/leo_empty/utils/graph_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('graph_storage_benchmark');
    GraphStorageService.debugDirectoryOverride = tempDir;
  });

  tearDown(() async {
    await GraphStorageService.clearCurrentGraph();
    GraphStorageService.debugDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('graph storage saves and loads ~3 days of samples', () async {
    final data = _generateSessionData(
      duration: const Duration(days: 3),
      sampleEvery: const Duration(seconds: 5),
    );

    final saveWatch = Stopwatch()..start();
    await GraphStorageService.saveCurrentGraph(data);
    saveWatch.stop();

    final loadWatch = Stopwatch()..start();
    final restored = await GraphStorageService.loadCurrentGraph();
    loadWatch.stop();

    expect(restored, isNotNull, reason: 'Stored session should load back');
    expect(restored!.points.length, data.points.length);
    expect(restored.startTime, data.startTime);
    expect(restored.points.first.seconds, data.points.first.seconds);
    expect(restored.points.last.seconds, data.points.last.seconds);

    debugPrint(
      'Benchmark (3 days, ${data.points.length} samples) '
      'save=${saveWatch.elapsed}, load=${loadWatch.elapsed}',
    );
  });
}

GraphSessionData _generateSessionData({
  required Duration duration,
  required Duration sampleEvery,
}) {
  final start = DateTime(2024, 1, 1, 8);
  final totalSeconds = duration.inSeconds;
  final step = sampleEvery.inSeconds;
  final points = <GraphPoint>[];

  for (int elapsed = 0; elapsed <= totalSeconds; elapsed += step) {
    final seconds = elapsed.toDouble();
    // Some pseudo current waveform (between 0 and 3 amps) for realism.
    final waveform = sin(elapsed / 1800) + 1.5;
    final noise = 0.2 * sin(elapsed / 60);
    final current = (waveform + noise).clamp(0.0, 3.0);
    points.add(GraphPoint(seconds: seconds, current: current));
  }

  return GraphSessionData(startTime: start, points: points);
}
