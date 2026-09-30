import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/feeding_stats.dart';

enum DetectionMode { yolo, sahi }


class TrackerService extends ChangeNotifier {
  String serverUrl = 'http://127.0.0.1:4002';

  io.Socket? _socket;
  bool connected = false;
  bool running = false;
  Uint8List? frame;
  FeedingStats stats = const FeedingStats();
  final List<int> visibleHistory = [];
  final List<FeedingStats> finishedSessions = [];
  String? error;

  void connect([String? url]) {
    if (url != null) serverUrl = url;
    _socket?.dispose();
    error = null;

    final s = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(5)
          .build(),
    );
    _socket = s;

    s.onConnect((_) => _set(() => connected = true));
    s.onDisconnect((_) => _set(() {
          connected = false;
          running = false;
        }));
    s.onConnectError((_) => _set(() {
          connected = false;
          error = 'Cannot reach $serverUrl. Is the backend running?';
        }));

    s.on('frame', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _set(() {
        frame = base64Decode(map['frame'] as String);
        stats = FeedingStats.fromJson(Map<String, dynamic>.from(map['stats']));
        visibleHistory.add(stats.visiblePellets);
        if (visibleHistory.length > 200) visibleHistory.removeAt(0);
      });
    });

    s.on('status', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['state'] == 'running') {
        _set(() => running = true);
      } else if (map['state'] == 'finished') {
        _set(() {
          running = false;
          if (map['summary'] != null) {
            finishedSessions.insert(
                0, FeedingStats.fromJson(Map<String, dynamic>.from(map['summary'])));
          }
        });
      }
    });

    s.on('error', (data) {
      final msg = (data is Map ? data['message'] : data).toString();
      _set(() {
        error = msg;
        running = false;
      });
    });

    s.connect();
  }

  void start({required String source, required DetectionMode mode, double conf = 0.35}) {
    if (!connected) {
      _set(() => error = 'Not connected to the backend.');
      return;
    }
    _set(() {
      error = null;
      frame = null;
      stats = const FeedingStats();
      visibleHistory.clear();
    });
    _socket!.emit('start_detection', {
      'source': source,
      'mode': mode.name,
      'conf': conf,
    });
  }

  void stop() => _socket?.emit('stop_detection');

  void clearError() => _set(() => error = null);

  void _set(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
