import 'dart:convert';
import 'dart:io';

class AppSettingsService {
  static const String _folderName = 'IlsanPackingSystem';
  static const String _fileName = 'settings.json';

  static Future<ProductionLineSettings?> loadProductionLineSettings() async {
    try {
      final file = await _settingsFile(createDirectory: false);
      if (!await file.exists()) {
        return null;
      }

      final data = jsonDecode(await file.readAsString());
      if (data is! Map) {
        return null;
      }

      return ProductionLineSettings(
        productionType: data['productionType']?.toString() ?? '',
        lineCode: data['lineCode']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProductionLineSettings({
    required String productionType,
    required String lineCode,
  }) async {
    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'productionType': productionType,
        'lineCode': lineCode,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<File> _settingsFile({bool createDirectory = true}) async {
    final directory = Directory(_settingsDirectoryPath());
    if (createDirectory) {
      await directory.create(recursive: true);
    }

    return File(_joinPath(directory.path, _fileName));
  }

  static String _settingsDirectoryPath() {
    final basePath =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;

    return _joinPath(basePath, _folderName);
  }

  static String _joinPath(String directory, String name) {
    if (directory.endsWith(Platform.pathSeparator)) {
      return '$directory$name';
    }

    return '$directory${Platform.pathSeparator}$name';
  }
}

class ProductionLineSettings {
  final String productionType;
  final String lineCode;

  const ProductionLineSettings({
    required this.productionType,
    required this.lineCode,
  });
}
