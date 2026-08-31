import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// The two loops that make up the background bed. Assets are synthesised by
/// `tool/gen_music.py`.
///
/// Their lengths are deliberately coprime — 32 s and 21 s — so the pair only
/// returns to the same alignment every 11 minutes. Each file loops on its own,
/// but what the player hears is the combination, and that is what keeps a
/// couple of megabytes from wearing out its welcome.
enum MusicLayer {
  /// Slow chord wash. Carries the low end.
  pad('music/pad.wav', 0.50),

  /// Sparse bells over the top. Sits in the mids, so it is mixed lower to stay
  /// out of the way of the effects.
  motif('music/motif.wav', 0.30);

  const MusicLayer(this.asset, this.volume);

  final String asset;

  /// Level relative to the effects, which peak around 0.6–0.8. Background
  /// music that competes with the sound of your own move is not background.
  final double volume;
}

/// Looping background music.
///
/// Three separate things can silence it and they do not override one another:
/// the player turning music off, the global sound switch, and the app losing
/// the foreground. The bed plays only when all three agree, so coming back
/// from a phone call restores exactly the state you left.
class MusicBed {
  MusicBed._(this._players);

  /// Makes no sound and starts no timers. Used by tests and as the default
  /// binding, so nothing has to be stubbed to run a widget that happens to sit
  /// under the provider.
  factory MusicBed.silent() => MusicBed._(const {});

  final Map<MusicLayer, AudioPlayer> _players;

  bool _enabled = true;
  bool _muted = false;
  bool _foreground = true;

  /// Where the fade currently sits, 0–1, scaling every layer's own level.
  double _gain = 0.0;
  bool _playing = false;
  Timer? _fade;

  /// Whether the loops are actually rolling. Test-visible so the toggle can be
  /// asserted without a real audio device.
  @visibleForTesting
  bool get isPlaying => _playing;

  /// The player's music setting, independent of the global sound switch.
  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _sync();
  }

  /// The global sound switch, shared with [SoundBank].
  set muted(bool value) {
    if (_muted == value) return;
    _muted = value;
    _sync();
  }

  /// False while the app is backgrounded. Music that keeps playing over
  /// whatever the player switched to is a bug, not a feature.
  set foreground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _sync();
  }

  bool get _wanted => _enabled && !_muted && _foreground;

  /// Builds and warms up the bed. Failures are swallowed: music is polish,
  /// never a reason for the game not to start.
  static Future<MusicBed> load() async {
    // Never take the audio session away from whatever the player already had
    // going. A puzzle game that stops your podcast to play its own pad has
    // made the decision for you.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (error) {
      debugPrint('quadcraft: could not set audio context ($error)');
    }

    final players = <MusicLayer, AudioPlayer>{};
    for (final layer in MusicLayer.values) {
      try {
        final player = AudioPlayer(playerId: 'quadcraft-music-${layer.name}');
        // Long files: the low-latency path is for one-shots and on Android
        // will not loop them.
        await player.setPlayerMode(PlayerMode.mediaPlayer);
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setSource(AssetSource(layer.asset));
        await player.setVolume(0);
        players[layer] = player;
      } catch (error) {
        debugPrint('quadcraft: could not preload ${layer.asset} ($error)');
      }
    }
    return MusicBed._(players);
  }

  /// Applies the current settings, fading rather than cutting.
  void _sync() {
    if (_players.isEmpty) {
      _playing = _wanted;
      return;
    }
    if (_wanted) {
      if (!_playing) {
        _playing = true;
        for (final entry in _players.entries) {
          // Each layer is resumed where it left off, so the two loops keep
          // the offset they had drifted into rather than snapping back into
          // step every time the app is reopened.
          entry.value.resume().catchError((Object _) {});
        }
      }
      _rampTo(1.0, const Duration(milliseconds: 1400));
    } else {
      _rampTo(0.0, const Duration(milliseconds: 500), thenPause: true);
    }
  }

  void _rampTo(double target, Duration over, {bool thenPause = false}) {
    _fade?.cancel();
    const tick = Duration(milliseconds: 40);
    final steps = (over.inMilliseconds / tick.inMilliseconds).ceil();
    final delta = (target - _gain) / steps;
    if (delta == 0) {
      if (thenPause) _pauseAll();
      return;
    }
    _fade = Timer.periodic(tick, (timer) {
      _gain += delta;
      final done = delta > 0 ? _gain >= target : _gain <= target;
      if (done) {
        _gain = target;
        timer.cancel();
        _fade = null;
      }
      _applyGain();
      if (done && thenPause) _pauseAll();
    });
  }

  void _applyGain() {
    for (final entry in _players.entries) {
      entry.value.setVolume(entry.key.volume * _gain).catchError((Object _) {});
    }
  }

  void _pauseAll() {
    if (!_playing) return;
    _playing = false;
    for (final player in _players.values) {
      player.pause().catchError((Object _) {});
    }
  }

  /// Starts the bed if the settings allow it. Safe to call more than once.
  void start() => _sync();

  /// Applies an app lifecycle change.
  ///
  /// [AppLifecycleState.inactive] counts as foreground, and that is the whole
  /// point of this method. It fires for everything that takes focus without
  /// putting the game away - another window on desktop, a menu, a notification
  /// banner, the app switcher - and treating it as background makes the music
  /// stop and restart every time one of them happens. Only being genuinely put
  /// away should silence the bed.
  void handleLifecycle(AppLifecycleState state) {
    foreground = switch (state) {
      AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
    };
  }

  void dispose() {
    _fade?.cancel();
    _fade = null;
    for (final player in _players.values) {
      player.dispose();
    }
  }
}
