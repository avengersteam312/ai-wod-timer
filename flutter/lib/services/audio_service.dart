import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum SoundType {
  // Beeps
  countdown,
  go,
  complete,
  // Voice
  voice3,
  voice2,
  voice1,
  voiceGo,
  voiceDone,
  voiceRest,
  voiceHalfway,
  voiceLastRound,
  voiceNextRound,
  voiceRoundOne,
  voiceTenSeconds,
  // Aliases for provider compatibility
  warning,
  intervalChange,
  roundComplete,
  workoutComplete,
  rest,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static AudioService get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isMuted = false;
  double _volume = 1.0;
  bool _useVoice = true; // Toggle between voice and beeps

  bool get isMuted => _isMuted;
  double get volume => _volume;
  bool get useVoice => _useVoice;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize audio: $e');
    }
  }

  Future<void> play(SoundType sound) async {
    if (_isMuted || !_isInitialized) return;

    try {
      final assetPath = _getAssetPath(sound);
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Failed to play sound $sound: $e');
    }
  }

  Future<void> playCountdown(int count) async {
    if (_useVoice) {
      switch (count) {
        case 3:
          await play(SoundType.voice3);
          break;
        case 2:
          await play(SoundType.voice2);
          break;
        case 1:
          await play(SoundType.voice1);
          break;
        case 0:
          await play(SoundType.voiceGo);
          break;
      }
    } else {
      // Use beep for countdown
      if (count > 0) {
        await play(SoundType.countdown);
      } else {
        await play(SoundType.go);
      }
    }
  }

  Future<void> playGo() async {
    await play(_useVoice ? SoundType.voiceGo : SoundType.go);
  }

  Future<void> playComplete() async {
    await play(_useVoice ? SoundType.voiceDone : SoundType.complete);
  }

  Future<void> playRest() async {
    if (_useVoice) {
      await play(SoundType.voiceRest);
    }
  }

  Future<void> playHalfway() async {
    if (_useVoice) {
      await play(SoundType.voiceHalfway);
    }
  }

  Future<void> playLastRound() async {
    if (_useVoice) {
      await play(SoundType.voiceLastRound);
    }
  }

  Future<void> playNextRound() async {
    if (_useVoice) {
      await play(SoundType.voiceNextRound);
    }
  }

  Future<void> playTenSeconds() async {
    if (_useVoice) {
      await play(SoundType.voiceTenSeconds);
    }
  }

  String _getAssetPath(SoundType sound) {
    switch (sound) {
      // Beeps
      case SoundType.countdown:
        return 'sounds/beeps/countdown.mp3';
      case SoundType.go:
        return 'sounds/beeps/go.mp3';
      case SoundType.complete:
        return 'sounds/beeps/complete.mp3';
      // Voice
      case SoundType.voice3:
        return 'sounds/voice/3.mp3';
      case SoundType.voice2:
        return 'sounds/voice/2.mp3';
      case SoundType.voice1:
        return 'sounds/voice/1.mp3';
      case SoundType.voiceGo:
        return 'sounds/voice/go.mp3';
      case SoundType.voiceDone:
        return 'sounds/voice/done.mp3';
      case SoundType.voiceRest:
        return 'sounds/voice/rest.mp3';
      case SoundType.voiceHalfway:
        return 'sounds/voice/halfway.mp3';
      case SoundType.voiceLastRound:
        return 'sounds/voice/last-round.mp3';
      case SoundType.voiceNextRound:
        return 'sounds/voice/next-round.mp3';
      case SoundType.voiceRoundOne:
        return 'sounds/voice/round-one.mp3';
      case SoundType.voiceTenSeconds:
        return 'sounds/voice/ten-seconds.mp3';
      // Aliases - map to appropriate sounds
      case SoundType.warning:
        return 'sounds/voice/ten-seconds.mp3';
      case SoundType.intervalChange:
        return 'sounds/voice/next-round.mp3';
      case SoundType.roundComplete:
        return 'sounds/voice/next-round.mp3';
      case SoundType.workoutComplete:
        return 'sounds/voice/done.mp3';
      case SoundType.rest:
        return 'sounds/voice/rest.mp3';
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  void setUseVoice(bool useVoice) {
    _useVoice = useVoice;
  }

  void toggleVoice() {
    _useVoice = !_useVoice;
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Failed to stop audio: $e');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    _isInitialized = false;
  }
}
