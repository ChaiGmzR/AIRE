import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playError() => _play('error.mp3');

  Future<void> playValidated() => _play('validado.mp3');

  Future<void> playSent() => _play('enviado.mp3');

  Future<void> _play(String assetName) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(assetName));
    } catch (_) {
      // Audio feedback must never interrupt the packing workflow.
    }
  }

  Future<void> dispose() => _player.dispose();
}
