import 'dart:io';

import 'api_service.dart';

class AppUpdateService {
  static Future<String> downloadAndLaunchInstaller(String version) async {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Version de actualizacion invalida');
    }

    final installerUrl = Uri.parse(
      '${ApiService.baseUrl}/api/updates/download/$version',
    );
    final installerPath = _temporaryInstallerPath(version);
    final installerFile = File(installerPath);
    final client = HttpClient();

    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(installerUrl);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'El backend respondio HTTP ${response.statusCode}',
          uri: installerUrl,
        );
      }

      await response.pipe(installerFile.openWrite());
      final fileSize = await installerFile.length();
      if (fileSize < 1024 * 1024) {
        throw const FormatException('El instalador descargado esta incompleto');
      }

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
    } finally {
      client.close(force: true);
    }
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

  static String _temporaryInstallerPath(String version) {
    final separator = Platform.pathSeparator;
    return '${Directory.systemTemp.path}$separator'
        'AIRE_Setup_update_$version.exe';
  }
}
