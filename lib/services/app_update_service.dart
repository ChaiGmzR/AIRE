import 'dart:io';

import 'update_share_service.dart';

class AppUpdateService {
  static Future<String> downloadAndLaunchInstaller(String version) async {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Version de actualizacion invalida');
    }

    final installerFile =
        await UpdateShareService.copyInstallerToTemp(version);

    await _writeMarker('update.lock');
    try {
      await Process.start(
        installerFile.path,
        const <String>[
          '/VERYSILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
        ],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      await _deleteMarker('update.lock');
      rethrow;
    }
    return installerFile.path;
  }

  static Future<void> _writeMarker(String fileName) async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      return;
    }

    final marker = File(
      '$localAppData${Platform.pathSeparator}IlsanPackingSystem'
      '${Platform.pathSeparator}$fileName',
    );
    await marker.parent.create(recursive: true);
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  static Future<void> _deleteMarker(String fileName) async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      return;
    }

    final marker = File(
      '$localAppData${Platform.pathSeparator}IlsanPackingSystem'
      '${Platform.pathSeparator}$fileName',
    );
    if (await marker.exists()) {
      await marker.delete();
    }
  }

}
