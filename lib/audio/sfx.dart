import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Every sound in the game. Assets are synthesised by `tool/gen_sfx.py`.
enum Sfx {
  rotate('sfx/rotate.wav', Buzz.selection),
  cut('sfx/cut.wav', Buzz.medium),
  drop('sfx/drop.wav', Buzz.light),
  paint('sfx/paint.wav', Buzz.light),
  win('sfx/win.wav', Buzz.heavy),
  tap('sfx/tap.wav', Buzz.selection),
  pickup('sfx/pickup.wav', Buzz.selection),
  blocked('sfx/blocked.wav', Buzz.medium);

  const Sfx(this.asset, this.buzz);

  final String asset;
  final Buzz buzz;
}

/// Haptic weight paired with a sound.
enum Buzz { none, selection, light, medium, heavy }

/// Preloaded one-shot player. One [AudioPlayer] per clip so overlapping
/// sounds (a drop landing while the win sting plays) never cut each other off.
class SoundBank {
  SoundBank._(this._players, {bool haptics = true}) : _hapticsEnabled = haptics;

  /// Makes no sound and no vibration. Used by tests.
  factory SoundBank.silent() =>
      SoundBank._(const {}, haptics: false)..muted = true;

  final Map<Sfx, AudioPlayer> _players;
  bool _muted = false;
  bool _hapticsEnabled;

  bool get muted => _muted;

  set muted(bool value) {
    _muted = value;
    if (value) {
      for (final player in _players.values) {
        player.stop();
      }
    }
  }

  /// Builds and warms up the bank. Failures are swallowed: audio is polish,
  /// never a reason for the game not to start.
  static Future<SoundBank> load() async {
    final players = <Sfx, AudioPlayer>{};
    for (final sfx in Sfx.values) {
      try {
        final player = AudioPlayer(playerId: 'quadcraft-${sfx.name}');
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(sfx.asset));
        await player.setVolume(_volumeFor(sfx));
        players[sfx] = player;
      } catch (error) {
        debugPrint('quadcraft: could not preload ${sfx.asset} ($error)');
      }
    }
    return SoundBank._(players);
  }

  static double _volumeFor(Sfx sfx) => switch (sfx) {
    Sfx.win => 0.7,
    Sfx.paint => 0.65,
    // Louder than it looks like it should be. Alone it is a soft tick, but it
    // is also the only effect quiet enough for the music to bury outright, and
    // a button press that makes no sound reads as a button that did not work.
    Sfx.tap => 0.62,
    Sfx.pickup => 0.45,
    _ => 0.6,
  };

  void play(Sfx sfx) {
    _haptic(sfx.buzz);
    if (_muted) return;
    final player = _players[sfx];
    if (player == null) return;
    // Fire and forget; restarting from zero keeps rapid taps responsive.
    player.stop().then((_) => player.resume()).catchError((Object _) {});
  }

  void _haptic(Buzz buzz) {
    if (!_hapticsEnabled || buzz == Buzz.none) return;
    try {
      switch (buzz) {
        case Buzz.selection:
          HapticFeedback.selectionClick();
        case Buzz.light:
          HapticFeedback.lightImpact();
        case Buzz.medium:
          HapticFeedback.mediumImpact();
        case Buzz.heavy:
          HapticFeedback.heavyImpact();
        case Buzz.none:
          break;
      }
    } catch (_) {
      _hapticsEnabled = false;
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
  }
}
