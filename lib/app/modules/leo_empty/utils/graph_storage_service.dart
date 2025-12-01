import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/graph_point.dart';

class GraphSessionData {
  const GraphSessionData({required this.startTime, required this.points});

  final DateTime startTime;
  final List<GraphPoint> points;

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'points': points
          .map((p) => {'seconds': p.seconds, 'current': p.current})
          .toList(),
    };
  }

  factory GraphSessionData.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    return GraphSessionData(
      startTime: DateTime.parse(json['startTime'] as String),
      points: rawPoints
          .map(
            (e) => GraphPoint(
              seconds: (e['seconds'] as num).toDouble(),
              current: (e['current'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }
}

class GraphStorageService {
  static const _fileName = 'current_charge_graph.json';
  static Directory? debugDirectoryOverride;

  static Future<File> _getFile() async {
    final dir =
        debugDirectoryOverride ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Persist the current charging session graph to local storage.
  static Future<void> saveCurrentGraph(GraphSessionData data) async {
    try {
      final file = await _getFile();
      // Heavy JSON encoding done in a background isolate.
      final jsonString = await compute<_EncodeParam, String>(
        _encodeGraphSession,
        _EncodeParam(data),
      );
      await file.writeAsString(jsonString, flush: true);
    } catch (_) {
      // Silent failure – graph persistence is non-critical.
    }
  }

  /// Load previously saved current charging session graph, if any.
  static Future<GraphSessionData?> loadCurrentGraph() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final jsonString = await file.readAsString();
      if (jsonString.isEmpty) return null;
      // Heavy JSON decoding done in a background isolate.
      return await compute<String, GraphSessionData?>(
        _decodeGraphSession,
        jsonString,
      );
    } catch (_) {
      return null;
    }
  }

  /// Remove any stored current charging session graph.
  static Future<void> clearCurrentGraph() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore – safe to fail here.
    }
  }
}

/// Helper type for encoding in an isolate (since `compute` requires a
/// single positional argument).
class _EncodeParam {
  _EncodeParam(this.data);

  final GraphSessionData data;
}

String _encodeGraphSession(_EncodeParam param) {
  return jsonEncode(param.data.toJson());
}

GraphSessionData? _decodeGraphSession(String jsonString) {
  try {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return GraphSessionData.fromJson(decoded);
  } catch (_) {
    return null;
  }
}
