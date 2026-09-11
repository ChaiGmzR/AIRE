import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.10:3001',
  );

  static String _baseUrl = _defaultBaseUrl;

  static Future<void> initialize({List<String> args = const []}) async {
    final configuredUrl = await _loadConfiguredBaseUrl(args);
    setBaseUrl(configuredUrl ?? _baseUrl);
  }

  static void setPort(int port) {
    final currentUri = Uri.tryParse(_baseUrl);
    final host = currentUri?.host.isNotEmpty == true
        ? currentUri!.host
        : '192.168.1.10';
    _baseUrl = 'http://$host:$port';
  }

  static void setBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      _baseUrl = trimmed.substring(0, trimmed.length - 1);
    } else {
      _baseUrl = trimmed;
    }
  }

  static String get baseUrl => _baseUrl;

  static Future<String?> _loadConfiguredBaseUrl(List<String> args) async {
    final argUrl = _getArgValue(args, '--api-base-url=');
    if (argUrl != null && argUrl.trim().isNotEmpty) {
      return argUrl.trim();
    }

    final envUrl = Platform.environment['API_BASE_URL'];
    if (envUrl != null && envUrl.trim().isNotEmpty) {
      return envUrl.trim();
    }

    for (final filePath in _configFileCandidates()) {
      final file = File(filePath);
      if (!await file.exists()) {
        continue;
      }

      try {
        final config = jsonDecode(await file.readAsString());
        if (config is Map<String, dynamic>) {
          final configuredUrl =
              config['apiBaseUrl'] ??
              config['baseUrl'] ??
              config['api_base_url'];
          if (configuredUrl is String && configuredUrl.trim().isNotEmpty) {
            return configuredUrl.trim();
          }
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  static String? _getArgValue(List<String> args, String prefix) {
    for (final arg in args) {
      if (arg.startsWith(prefix)) {
        return arg.substring(prefix.length);
      }
    }

    return null;
  }

  static List<String> _configFileCandidates() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;

    return [
      _joinPath(exeDir, 'api_config.json'),
      _joinPath(currentDir, 'api_config.json'),
    ];
  }

  static String _joinPath(String directory, String fileName) {
    if (directory.endsWith(Platform.pathSeparator)) {
      return '$directory$fileName';
    }

    return '$directory${Platform.pathSeparator}$fileName';
  }

  /// Register a new scan
  static Future<ScanResult> registerScan({
    required String boxCode,
    required String barcode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/scans'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'boxCode': boxCode, 'barcode': barcode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScanResult(
          success: true,
          serial: data['scan']['serial'],
          partNumber: data['scan']['partNumber'],
          scanTime: data['scan']['scanTime'],
          boxCount: data['counts']['box'],
          shiftCount: data['counts']['shift'],
        );
      } else {
        final error = jsonDecode(response.body);
        return ScanResult(
          success: false,
          error: error['error'] ?? 'Unknown error',
        );
      }
    } catch (e) {
      return ScanResult(success: false, error: 'Connection error: $e');
    }
  }

  /// Get shift count for a part number
  static Future<int> getShiftCount(String partNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/scans/count/$partNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get all scans for a box
  static Future<List<BoxScanItem>> getBoxScans(String boxCode) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/scans/box/$boxCode'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scans = data['scans'] as List;
        return scans
            .map(
              (s) => BoxScanItem(
                id: s['id'],
                serial: s['serial'],
                partNumber: s['partNumber'],
                firstScan: s['firstScan'],
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Clear all scans for a box
  static Future<bool> clearBoxScans(String boxCode) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/scans/box/$boxCode'),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete one pending scan from a box
  static Future<DeleteScanResult> deleteBoxScan({
    required String boxCode,
    required String barcode,
  }) async {
    try {
      final encodedBoxCode = Uri.encodeComponent(boxCode);
      final encodedBarcode = Uri.encodeComponent(barcode);
      final response = await http.delete(
        Uri.parse(
          '$_baseUrl/api/scans/box/$encodedBoxCode/scan/$encodedBarcode',
        ),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return DeleteScanResult(
          success: true,
          boxCount: data['counts']?['box'],
          shiftCount: data['counts']?['shift'],
          partNumber: data['currentPartNumber'],
        );
      }

      return DeleteScanResult(
        success: false,
        error: data['error'] ?? 'Unknown error',
      );
    } catch (e) {
      return DeleteScanResult(success: false, error: 'Connection error: $e');
    }
  }

  /// Send a completed box and generate its BOX DATA file
  static Future<SendBoxResult> sendBox(String boxCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/scans/box/$boxCode/send'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return SendBoxResult(
          success: true,
          fileName: data['file']?['name'],
          filePath: data['file']?['path'],
          rows: data['file']?['rows'],
        );
      }

      return SendBoxResult(
        success: false,
        error: data['error'] ?? 'Unknown error',
      );
    } catch (e) {
      return SendBoxResult(success: false, error: 'Connection error: $e');
    }
  }

  /// Get API status
  static Future<ApiStatus> getStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/scans/status'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiStatus(
          connected: true,
          shift: data['shift'] ?? '',
          serverTime: data['serverTime'] ?? '',
        );
      }
      return ApiStatus(connected: false);
    } catch (e) {
      return ApiStatus(connected: false, error: e.toString());
    }
  }

  /// Check if API is available
  static Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class ScanResult {
  final bool success;
  final String? serial;
  final String? partNumber;
  final String? scanTime;
  final int? boxCount;
  final int? shiftCount;
  final String? error;

  ScanResult({
    required this.success,
    this.serial,
    this.partNumber,
    this.scanTime,
    this.boxCount,
    this.shiftCount,
    this.error,
  });
}

class BoxScanItem {
  final int id;
  final String serial;
  final String partNumber;
  final String firstScan;

  BoxScanItem({
    required this.id,
    required this.serial,
    required this.partNumber,
    required this.firstScan,
  });
}

class DeleteScanResult {
  final bool success;
  final int? boxCount;
  final int? shiftCount;
  final String? partNumber;
  final String? error;

  DeleteScanResult({
    required this.success,
    this.boxCount,
    this.shiftCount,
    this.partNumber,
    this.error,
  });
}

class SendBoxResult {
  final bool success;
  final String? fileName;
  final String? filePath;
  final int? rows;
  final String? error;

  SendBoxResult({
    required this.success,
    this.fileName,
    this.filePath,
    this.rows,
    this.error,
  });
}

class ApiStatus {
  final bool connected;
  final String? shift;
  final String? serverTime;
  final String? error;

  ApiStatus({required this.connected, this.shift, this.serverTime, this.error});
}
