import 'dart:io';

class UpdateShareCredentials {
  final String username;
  final String password;

  const UpdateShareCredentials({
    required this.username,
    required this.password,
  });
}

class UpdateShareException implements Exception {
  final String message;

  const UpdateShareException(this.message);

  @override
  String toString() => message;
}

class UpdateShareCredentialsRequired extends UpdateShareException {
  const UpdateShareCredentialsRequired()
      : super('Se requieren credenciales para acceder al recurso de actualizaciones.');
}

class UpdateShareInstaller {
  final String version;
  final String fileName;

  const UpdateShareInstaller({required this.version, required this.fileName});
}

class UpdateShareService {
  static const String shareRoot =
      r'\\192.168.1.10\updates\CALIDAD\AIRE';
  static const String connectionRoot = r'\\192.168.1.10\updates';
  static final RegExp _installerPattern =
      RegExp(r'^AIRE_Setup_(\d+\.\d+\.\d+)\.exe$', caseSensitive: false);

  static UpdateShareCredentials? _cachedCredentials;

  static void setCredentials(UpdateShareCredentials credentials) {
    _cachedCredentials = credentials;
  }

  static bool get hasCachedCredentials => _cachedCredentials != null;

  static Future<UpdateShareInstaller> getLatestInstaller() async {
    final session = await _openSession();
    try {
      final entries = Directory(shareRoot).list(followLinks: false);
      final installers = <UpdateShareInstaller>[];

      await for (final entry in entries) {
        if (entry is! File) continue;
        final name = _fileName(entry.path);
        final match = _installerPattern.firstMatch(name);
        if (match != null) {
          installers.add(
            UpdateShareInstaller(version: match.group(1)!, fileName: name),
          );
        }
      }

      if (installers.isEmpty) {
        throw const UpdateShareException(
          'No hay instaladores AIRE disponibles en el recurso compartido.',
        );
      }

      installers.sort(
        (left, right) => _compareVersions(right.version, left.version),
      );
      return installers.first;
    } finally {
      await session.close();
    }
  }

  static Future<File> copyInstallerToTemp(String version) async {
    if (!_installerPattern.hasMatch('AIRE_Setup_$version.exe')) {
      throw const UpdateShareException('Version de actualizacion invalida.');
    }

    final session = await _openSession();
    final tempFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'AIRE_Setup_update_$version.exe',
    );
    final partialFile = File('${tempFile.path}.part');

    try {
      final source = File('$shareRoot${Platform.pathSeparator}'
          'AIRE_Setup_$version.exe');
      if (!await source.exists()) {
        throw const UpdateShareException(
          'El instalador solicitado no existe en el recurso compartido.',
        );
      }

      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      await source.copy(partialFile.path);
      await _validateInstaller(partialFile);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return await partialFile.rename(tempFile.path);
    } catch (_) {
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      rethrow;
    } finally {
      await session.close();
    }
  }

  static Future<_ShareSession> _openSession() async {
    if (!Platform.isWindows) {
      throw const UpdateShareException(
        'Las actualizaciones SMB requieren Windows.',
      );
    }

    if (await Directory(shareRoot).exists()) {
      return const _ShareSession();
    }

    final credentials = _cachedCredentials;
    if (credentials == null) {
      throw const UpdateShareCredentialsRequired();
    }

    final result = await Process.run(
      'net.exe',
      [
        'use',
        connectionRoot,
        credentials.password,
        '/user:${credentials.username}',
        '/persistent:no',
      ],
      runInShell: false,
    );

    final authenticated = result.exitCode == 0;
    final shareExists = await Directory(shareRoot).exists();
    if (!authenticated || !shareExists) {
      if (authenticated) {
        await _disconnectSession();
      }
      final output = '${result.stdout}\n${result.stderr}';
      if (output.contains('1219')) {
        throw const UpdateShareException(
          'Windows ya tiene una conexion al servidor con otras credenciales. '
          'Cierre esa conexion e intente nuevamente.',
        );
      }
      throw const UpdateShareException(
        'No se pudo autenticar el recurso de actualizaciones.',
      );
    }

    return const _ShareSession(authenticated: true);
  }

  static String _fileName(String path) {
    final separator = Platform.pathSeparator;
    final index = path.lastIndexOf(separator);
    return index >= 0 ? path.substring(index + 1) : path;
  }

  static Future<void> _validateInstaller(File file) async {
    final size = await file.length();
    if (size < 1024 * 1024) {
      throw const UpdateShareException('El instalador descargado esta incompleto.');
    }

    final handle = await file.open();
    try {
      final header = await handle.read(2);
      if (header.length != 2 || header[0] != 0x4d || header[1] != 0x5a) {
        throw const UpdateShareException('El archivo descargado no es un EXE valido.');
      }
    } finally {
      await handle.close();
    }
  }

  static int _compareVersions(String left, String right) {
    final leftParts = left.split('.').map(int.parse).toList();
    final rightParts = right.split('.').map(int.parse).toList();
    for (var index = 0; index < 3; index++) {
      if (leftParts[index] != rightParts[index]) {
        return leftParts[index].compareTo(rightParts[index]);
      }
    }
    return 0;
  }

  static Future<void> _disconnectSession() async {
    await Process.run(
      'net.exe',
      ['use', connectionRoot, '/delete', '/y'],
      runInShell: false,
    );
  }
}

class _ShareSession {
  final bool authenticated;

  const _ShareSession({this.authenticated = false});

  Future<void> close() async {
    if (!authenticated) return;
    await UpdateShareService._disconnectSession();
  }
}
