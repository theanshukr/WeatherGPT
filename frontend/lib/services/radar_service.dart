import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RadarFrame {
  final int time;
  final String path;
  final String label;
  final bool isNowcast;
  final bool isLive;

  const RadarFrame({
    required this.time,
    required this.path,
    required this.label,
    this.isNowcast = false,
    this.isLive = false,
  });

  /// Builds a real-time tile URL template for flutter_map TileLayer
  /// colorScheme: 2 (Universal Blue/Green/Yellow/Red) or 4 (Smooth RainViewer theme)
  String getTileUrlTemplate({String host = 'https://tilecache.rainviewer.com', int colorScheme = 2}) {
    return '$host$path/256/{z}/{x}/{y}/$colorScheme/1_1.png';
  }
}

class RadarTimelineData {
  final String host;
  final List<RadarFrame> frames;
  final int defaultLiveIndex;

  const RadarTimelineData({
    required this.host,
    required this.frames,
    required this.defaultLiveIndex,
  });
}

class RadarService {
  static const String _rainViewerApiUrl = 'https://api.rainviewer.com/public/weather-maps.json';
  
  static RadarTimelineData? _cachedData;
  static DateTime? _cacheTimestamp;

  /// Fetches real Doppler radar frames from RainViewer (Past observations + Future Nowcast)
  Future<RadarTimelineData?> getRadarTimeline({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedData != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!).inMinutes < 5) {
      return _cachedData;
    }

    try {
      final response = await http.get(Uri.parse(_rainViewerApiUrl)).timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final host = data['host'] as String? ?? 'https://tilecache.rainviewer.com';
        final radar = data['radar'] as Map<String, dynamic>?;

        if (radar != null) {
          final pastList = (radar['past'] as List<dynamic>?) ?? [];
          final nowcastList = (radar['nowcast'] as List<dynamic>?) ?? [];

          final List<RadarFrame> frames = [];

          // 1. Extract 2 Past frames (-30m, -15m) and 1 LIVE frame
          if (pastList.isNotEmpty) {
            int pastLen = pastList.length;
            int indexMinus30 = (pastLen - 4).clamp(0, pastLen - 1);
            int indexMinus15 = (pastLen - 2).clamp(0, pastLen - 1);
            int indexLive = pastLen - 1;

            if (indexMinus30 < pastLen) {
              final item = pastList[indexMinus30];
              frames.add(RadarFrame(
                time: item['time'] as int? ?? 0,
                path: item['path'] as String? ?? '',
                label: '-30m',
              ));
            }

            if (indexMinus15 < pastLen && indexMinus15 != indexMinus30) {
              final item = pastList[indexMinus15];
              frames.add(RadarFrame(
                time: item['time'] as int? ?? 0,
                path: item['path'] as String? ?? '',
                label: '-15m',
              ));
            }

            // Latest Live Doppler Frame
            final liveItem = pastList[indexLive];
            frames.add(RadarFrame(
              time: liveItem['time'] as int? ?? 0,
              path: liveItem['path'] as String? ?? '',
              label: 'LIVE',
              isLive: true,
            ));
          }

          int liveFrameIndex = frames.isNotEmpty ? frames.length - 1 : 0;

          // 2. Extract Nowcast (+15m, +30m) forecast frames
          if (nowcastList.isNotEmpty) {
            int nowcastLen = nowcastList.length;
            int indexPlus15 = 0;
            int indexPlus30 = (nowcastLen > 1) ? 1 : 0;

            if (indexPlus15 < nowcastLen) {
              final item = nowcastList[indexPlus15];
              frames.add(RadarFrame(
                time: item['time'] as int? ?? 0,
                path: item['path'] as String? ?? '',
                label: '+15m',
                isNowcast: true,
              ));
            }

            if (indexPlus30 < nowcastLen && indexPlus30 != indexPlus15) {
              final item = nowcastList[indexPlus30];
              frames.add(RadarFrame(
                time: item['time'] as int? ?? 0,
                path: item['path'] as String? ?? '',
                label: '+30m',
                isNowcast: true,
              ));
            }
          }

          if (frames.isNotEmpty) {
            final timelineData = RadarTimelineData(
              host: host,
              frames: frames,
              defaultLiveIndex: liveFrameIndex,
            );

            _cachedData = timelineData;
            _cacheTimestamp = DateTime.now();
            return timelineData;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading RainViewer radar timeline: $e');
    }

    return _cachedData;
  }
}
