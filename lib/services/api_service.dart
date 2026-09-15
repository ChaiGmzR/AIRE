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

  static Map<String, dynamic>? _tryDecodeJsonObject(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String _errorFromResponse(http.Response response, String fallback) {
    final data = _tryDecodeJsonObject(response.body);
    final error = data?['error'];
    if (error is String && error.trim().isNotEmpty) {
      return _translateError(error.trim());
    }

    final body = response.body.trim();
    if (response.statusCode == 404 &&
        body.startsWith('<!DOCTYPE html>') &&
        body.contains('Cannot DELETE')) {
      return 'El endpoint para eliminar no esta desplegado en el backend. Actualiza/reinicia el servidor.';
    }

    return '$fallback (HTTP ${response.statusCode})';
  }

  static String _translateError(String message) {
    final trimmed = message.trim();
    final exact = <String, String>{
      'Box ID is required': 'El Box Id es requerido',
      'Invalid Box ID format': 'Formato de Box Id invalido',
      'BarCode is required': 'El BarCode es requerido',
      'BarCode too short (minimum 11 characters)':
          'BarCode demasiado corto (minimo 11 caracteres)',
      'Could not extract part number from BarCode':
          'No se pudo extraer el numero de parte del BarCode',
      'Barcode already scanned in this box':
          'Este BarCode ya fue escaneado en esta caja',
      'No pending scans for this box':
          'No hay escaneos pendientes para esta caja',
      'Barcode not found in this box': 'BarCode no encontrado en esta caja',
      'ICT status not found for this barcode':
          'No se encontro estatus ICT para este BarCode',
      'FCT status not found for this barcode':
          'No se encontro estatus FCT para este BarCode',
      'Electrical test status not found for this barcode':
          'No se encontro prueba electrica para este BarCode',
      'Invalid production type. Allowed values: MAIN PCB, DISPLAY':
          'Tipo de produccion invalido. Valores permitidos: MAIN PCB, DISPLAY',
      'DISPLAY flow not deployed on backend. Update/restart server.':
          'El flujo DISPLAY no esta desplegado en el backend. Actualiza/reinicia el servidor.',
      'Failed to register scan': 'Error al registrar el escaneo',
      'Failed to send box file': 'Error al generar el archivo BOX',
      'Failed to delete scan': 'Error al eliminar el escaneo',
      'Failed to clear box scans':
          'Error al limpiar los escaneos pendientes de la caja',
    };
    final exactTranslation = exact[trimmed];
    if (exactTranslation != null) {
      return exactTranslation;
    }

    final invalidLine = RegExp(
      r'^Invalid line for (.+)\. Allowed lines: (.+)$',
    ).firstMatch(trimmed);
    if (invalidLine != null) {
      return 'Linea invalida para ${invalidLine.group(1)}. Lineas permitidas: ${invalidLine.group(2)}';
    }

    final productionMismatch = RegExp(
      r'^Production line mismatch\. Expected (.+), got (.+)$',
    ).firstMatch(trimmed);
    if (productionMismatch != null) {
      return 'La linea de produccion no coincide. Esperado ${productionMismatch.group(1)}, recibido ${productionMismatch.group(2)}';
    }

    final partMismatch = RegExp(
      r'^Part number mismatch\. Expected (.+), got (.+)$',
    ).firstMatch(trimmed);
    if (partMismatch != null) {
      return 'Numero de parte distinto. Esperado ${partMismatch.group(1)}, recibido ${partMismatch.group(2)}';
    }

    final ictNotOk = RegExp(
      r'^ICT status must be OK\. Current status: (.+)$',
    ).firstMatch(trimmed);
    if (ictNotOk != null) {
      return 'El estatus ICT debe ser OK. Estatus actual: ${ictNotOk.group(1)}';
    }

    final fctNotOk = RegExp(
      r'^FCT status must be OK\. Current status: (.+)$',
    ).firstMatch(trimmed);
    if (fctNotOk != null) {
      return 'El estatus FCT debe ser OK. Estatus actual: ${fctNotOk.group(1)}';
    }

    final electricalNotOk = RegExp(
      r'^Electrical test must be OK\. Current status: (.+)$',
    ).firstMatch(trimmed);
    if (electricalNotOk != null) {
      return 'La prueba electrica debe estar OK. Estatus actual: ${electricalNotOk.group(1)}';
    }

    final electricalLineMismatch = RegExp(
      r'^Electrical test line mismatch\. Expected (.+), got (.+)$',
    ).firstMatch(trimmed);
    if (electricalLineMismatch != null) {
      return 'La linea de prueba electrica no coincide. Esperado ${electricalLineMismatch.group(1)}, recibido ${electricalLineMismatch.group(2)}';
    }

    return trimmed;
  }

  /// Register a new scan
  static Future<ScanResult> registerScan({
    required String boxCode,
    required String barcode,
    required String productionType,
    required String lineCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/scans'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'boxCode': boxCode,
          'barcode': barcode,
          'productionType': productionType,
          'lineCode': lineCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = _tryDecodeJsonObject(response.body);
        if (data == null) {
          return ScanResult(
            success: false,
            error: 'Respuesta invalida del servidor',
          );
        }

        return ScanResult(
          success: true,
          serial: data['scan']?['serial'],
          partNumber: data['scan']?['partNumber'],
          scanTime: data['scan']?['scanTime'],
          boxCount: data['counts']?['box'],
          shiftCount: data['counts']?['shift'],
          productionType: data['scan']?['productionType'],
          lineCode: data['scan']?['lineCode'],
        );
      } else {
        return ScanResult(
          success: false,
          error: _errorFromResponse(response, 'Error al registrar el escaneo'),
        );
      }
    } catch (e) {
      return ScanResult(success: false, error: 'Error de conexion: $e');
    }
  }

  /// Get shift count for a part number
  static Future<int> getShiftCount(String partNumber) async {
    try {
      final encodedPartNumber = Uri.encodeComponent(partNumber);
      final response = await http.get(
        Uri.parse('$_baseUrl/api/scans/count/$encodedPartNumber'),
      );

      if (response.statusCode == 200) {
        final data = _tryDecodeJsonObject(response.body);
        return _asInt(data?['count']);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get all scans for a box
  static Future<List<BoxScanItem>> getBoxScans(String boxCode) async {
    try {
      final encodedBoxCode = Uri.encodeComponent(boxCode);
      final response = await http.get(
        Uri.parse('$_baseUrl/api/scans/box/$encodedBoxCode'),
      );

      if (response.statusCode == 200) {
        final data = _tryDecodeJsonObject(response.body);
        final scans = data?['scans'];
        if (scans is! List) {
          return [];
        }

        return scans
            .whereType<Map>()
            .map(
              (s) => BoxScanItem(
                id: _asInt(s['id']),
                serial: _asString(s['serial']),
                partNumber: _asString(s['partNumber']),
                firstScan: _asString(s['firstScan']),
              ),
            )
            .where((s) => s.serial.isNotEmpty)
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

      final data = _tryDecodeJsonObject(response.body);
      if (response.statusCode == 200) {
        if (data == null) {
          return DeleteScanResult(
            success: false,
            error: 'Respuesta invalida del servidor',
          );
        }

        return DeleteScanResult(
          success: true,
          boxCount: data['counts']?['box'],
          shiftCount: data['counts']?['shift'],
          partNumber: data['currentPartNumber'],
        );
      }

      return DeleteScanResult(
        success: false,
        error: _errorFromResponse(response, 'Error al eliminar el escaneo'),
      );
    } catch (e) {
      return DeleteScanResult(success: false, error: 'Error de conexion: $e');
    }
  }

  /// Send a completed box and generate its BOX DATA file
  static Future<SendBoxResult> sendBox(String boxCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/scans/box/$boxCode/send'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = _tryDecodeJsonObject(response.body);
      if (response.statusCode == 200) {
        if (data == null) {
          return SendBoxResult(
            success: false,
            error: 'Respuesta invalida del servidor',
          );
        }

        return SendBoxResult(
          success: true,
          fileName: data['file']?['name'],
          filePath: data['file']?['path'],
          rows: data['file']?['rows'],
        );
      }

      return SendBoxResult(
        success: false,
        error: _errorFromResponse(response, 'Error al generar el archivo BOX'),
      );
    } catch (e) {
      return SendBoxResult(success: false, error: 'Error de conexion: $e');
    }
  }

  /// Validate client/backend version compatibility
  static Future<VersionValidationResult> validateVersion({
    required String clientVersion,
  }) async {
    const invalidVersionMessage =
        'No se pudo validar la version del backend. Actualiza/reinicia el servidor.';

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/version'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return VersionValidationResult(
          valid: false,
          message: invalidVersionMessage,
        );
      }

      final data = _tryDecodeJsonObject(response.body);
      if (data == null) {
        return VersionValidationResult(
          valid: false,
          message: 'Respuesta invalida del servidor al validar version.',
        );
      }

      final serverVersion = _asString(data['version']);
      final requiredClientVersion = _asString(data['requiredClientVersion']);
      final minimumClientVersion = _asString(data['minimumClientVersion']);
      final expectedClientVersion = requiredClientVersion.isNotEmpty
          ? requiredClientVersion
          : minimumClientVersion.isNotEmpty
          ? minimumClientVersion
          : serverVersion;

      if (serverVersion.isEmpty || expectedClientVersion.isEmpty) {
        return VersionValidationResult(
          valid: false,
          message: invalidVersionMessage,
        );
      }

      if (expectedClientVersion != clientVersion) {
        return VersionValidationResult(
          valid: false,
          serverVersion: serverVersion,
          message:
              'Version incompatible. App $clientVersion, requerida $expectedClientVersion.',
        );
      }

      return VersionValidationResult(valid: true, serverVersion: serverVersion);
    } catch (_) {
      return VersionValidationResult(
        valid: false,
        message: invalidVersionMessage,
      );
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

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
  }
}

class ScanResult {
  final bool success;
  final String? serial;
  final String? partNumber;
  final String? scanTime;
  final int? boxCount;
  final int? shiftCount;
  final String? productionType;
  final String? lineCode;
  final String? error;

  ScanResult({
    required this.success,
    this.serial,
    this.partNumber,
    this.scanTime,
    this.boxCount,
    this.shiftCount,
    this.productionType,
    this.lineCode,
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

class VersionValidationResult {
  final bool valid;
  final String message;
  final String? serverVersion;

  VersionValidationResult({
    required this.valid,
    this.message = '',
    this.serverVersion,
  });
}
