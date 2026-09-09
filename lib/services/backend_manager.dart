import 'dart:io';
import 'package:flutter/foundation.dart';

class BackendManager {
  static Process? _process;
  static int? _port;
  static bool _isRunning = false;

  static int? get port => _port;
  static bool get isRunning => _isRunning;

  /// Start the backend server
  static Future<bool> start() async {
    if (_isRunning) {
      debugPrint('Backend already running on port $_port');
      return true;
    }

    try {
      // Get the backend directory path
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent.path;
      
      // Try multiple possible locations for the separated backend.
      final possiblePaths = [
        '$exeDir\\..\\AIRE_API_SERVER',
        '${Directory.current.path}\\..\\AIRE_API_SERVER',
        '${Directory.current.path}\\_API_SERVER',
      ];

      String? backendPath;
      for (final path in possiblePaths) {
        if (await Directory(path).exists()) {
          backendPath = path;
          break;
        }
      }

      if (backendPath == null) {
        debugPrint('Backend directory not found');
        return false;
      }

      debugPrint('Starting backend from: $backendPath');

      // Start Node.js server
      _process = await Process.start(
        'node',
        ['server.js'],
        workingDirectory: backendPath,
        runInShell: true,
      );

      // Listen to stdout
      _process!.stdout.transform(const SystemEncoding().decoder).listen((data) {
        debugPrint('Backend: $data');
        
        // Parse port from output
        final portMatch = RegExp(r'running on [^:]+:(\d+)').firstMatch(data);
        if (portMatch != null) {
          _port = int.parse(portMatch.group(1)!);
          _isRunning = true;
          debugPrint('Backend started on port $_port');
        }
      });

      // Listen to stderr
      _process!.stderr.transform(const SystemEncoding().decoder).listen((data) {
        debugPrint('Backend Error: $data');
      });

      // Wait for server to start
      await Future.delayed(const Duration(seconds: 3));

      // Try to read port from file
      if (_port == null) {
        final portFile = File('$backendPath\\.port');
        if (await portFile.exists()) {
          final portStr = await portFile.readAsString();
          _port = int.tryParse(portStr.trim());
          if (_port != null) {
            _isRunning = true;
          }
        }
      }

      return _isRunning;
    } catch (e) {
      debugPrint('Failed to start backend: $e');
      return false;
    }
  }

  /// Stop the backend server
  static Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
      _isRunning = false;
      _port = null;
      debugPrint('Backend stopped');
    }
  }

  /// Restart the backend server
  static Future<bool> restart() async {
    await stop();
    await Future.delayed(const Duration(seconds: 1));
    return start();
  }
}
