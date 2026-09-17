import 'dart:io';

class AppUpdateService {
  static Future<String> downloadAndLaunchInstaller(String version) async {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Version de actualizacion invalida');
    }

    final installerUrl = Uri.parse(
      'https://github.com/ChaiGmzR/AIRE/releases/download/v$version/'
      'pcb_boxing_system_${version}_installer.exe',
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
          'GitHub respondio HTTP ${response.statusCode}',
          uri: installerUrl,
        );
      }

      await response.pipe(installerFile.openWrite());
      final fileSize = await installerFile.length();
      if (fileSize < 1024 * 1024) {
        throw const FormatException('El instalador descargado esta incompleto');
      }

      await Process.start(
        installerFile.path,
        const <String>[],
        mode: ProcessStartMode.detached,
      );
      return installerFile.path;
    } finally {
      client.close(force: true);
    }
  }

  static String _temporaryInstallerPath(String version) {
    final separator = Platform.pathSeparator;
    return '${Directory.systemTemp.path}$separator'
        'pcb_boxing_system_update_$version.exe';
  }
}
