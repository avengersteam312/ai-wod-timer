import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'beep_generator.dart';

enum SoundType {
  // Beeps (generated programmatically)
  countdown,
  go,
  complete,
  halfway,
  tenSeconds,
  nextRound,
  restBeep,
  // Voice (pre-recorded MP3 files from assets)
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

  // File paths for generated beeps (saved to temp directory)
  final Map<SoundType, String> _beepFilePaths = {};

  // File paths for pre-loaded voice files (copied from assets to temp)
  final Map<SoundType, String> _voiceFilePaths = {};

  // Dedicated pre-loaded players for each beep type (instant playback)
  final Map<SoundType, AudioPlayer> _beepPlayers = {};

  // Pool of AudioPlayers for voice playback
  final List<AudioPlayer> _voicePlayerPool = [];
  int _currentVoicePlayerIndex = 0;
  static const int _poolSize = 4;

  bool _isInitialized = false;
  bool _isVoiceMuted = true;
  double _volume = 1.5;

  bool get isMuted => _isVoiceMuted;
  bool get isVoiceMuted => _isVoiceMuted;
  double get volume => _volume;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Configure audio session to mix with other audio (e.g., music)
      final session = await audio_session.AudioSession.instance;
      await session.configure(audio_session.AudioSessionConfiguration(
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const audio_session.AndroidAudioAttributes(
          contentType: audio_session.AndroidAudioContentType.sonification,
          usage: audio_session.AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      debugPrint('Audio session configured for mixing with other audio');

      // Generate beep sounds and save to temp files
      await _generateAndSaveBeepSounds();

      // Pre-load voice files from assets to temp directory
      await _preloadVoiceFiles();

      // Create dedicated pre-loaded player for each beep type (instant playback)
      for (final entry in _beepFilePaths.entries) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(DeviceFileSource(entry.value));
        _beepPlayers[entry.key] = player;
        debugPrint('Pre-loaded beep player: ${entry.key}');
      }

      // Initialize voice player pool with low latency mode
      for (int i = 0; i < _poolSize; i++) {
        final voicePlayer = AudioPlayer();
        await voicePlayer.setReleaseMode(ReleaseMode.stop);
        await voicePlayer.setPlayerMode(PlayerMode.lowLatency);
        _voicePlayerPool.add(voicePlayer);
      }

      // Pre-warm voice players
      await _prewarmPlayers();

      _isInitialized = true;
      debugPrint('AudioService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize audio: $e');
    }
  }

  /// Generate beep sounds and save them to temporary files
  Future<void> _generateAndSaveBeepSounds() async {
    debugPrint('Generating beep sounds...');

    final tempDir = await getTemporaryDirectory();
    final beepDir = Directory('${tempDir.path}/audio/beeps');
    if (!await beepDir.exists()) {
      await beepDir.create(recursive: true);
    }

    // Generate and save each beep type
    final beeps = {
      SoundType.countdown: BeepGenerator.countdownBeep(),
      SoundType.go: BeepGenerator.goBeep(),
      SoundType.complete: BeepGenerator.completeBeep(),
      SoundType.halfway: BeepGenerator.halfwayBeep(),
      SoundType.tenSeconds: BeepGenerator.tenSecondsBeep(),
      SoundType.nextRound: BeepGenerator.nextRoundBeep(),
      SoundType.restBeep: BeepGenerator.restBeep(),
    };

    for (final entry in beeps.entries) {
      final filePath = '${beepDir.path}/${entry.key.name}.wav';
      final file = File(filePath);

      // Always regenerate to pick up any changes
      await file.writeAsBytes(entry.value);
      _beepFilePaths[entry.key] = filePath;
      debugPrint('Generated beep: ${entry.key}');
    }

    debugPrint('Beeps ready: ${_beepFilePaths.length}');
  }

  /// Pre-load voice MP3 files from assets to temp directory for fast playback
  Future<void> _preloadVoiceFiles() async {
    debugPrint('Pre-loading voice files...');

    final tempDir = await getTemporaryDirectory();
    final voiceDir = Directory('${tempDir.path}/audio/voices');
    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }

    // Map of sound types to asset paths
    final voiceAssets = {
      SoundType.voice3: 'assets/sounds/voice/3.mp3',
      SoundType.voice2: 'assets/sounds/voice/2.mp3',
      SoundType.voice1: 'assets/sounds/voice/1.mp3',
      SoundType.voiceGo: 'assets/sounds/voice/go.mp3',
      SoundType.voiceDone: 'assets/sounds/voice/done.mp3',
      SoundType.voiceRest: 'assets/sounds/voice/rest.mp3',
      SoundType.voiceHalfway: 'assets/sounds/voice/halfway.mp3',
      SoundType.voiceLastRound: 'assets/sounds/voice/last-round.mp3',
      SoundType.voiceNextRound: 'assets/sounds/voice/next-round.mp3',
      SoundType.voiceRoundOne: 'assets/sounds/voice/round-one.mp3',
      SoundType.voiceTenSeconds: 'assets/sounds/voice/ten-seconds.mp3',
    };

    for (final entry in voiceAssets.entries) {
      final fileName = entry.value.split('/').last;
      final filePath = '${voiceDir.path}/$fileName';
      final file = File(filePath);

      // Only copy if file doesn't exist (cache)
      if (!await file.exists()) {
        try {
          final data = await rootBundle.load(entry.value);
          await file.writeAsBytes(data.buffer.asUint8List());
          debugPrint('Pre-loaded voice: ${entry.key}');
        } catch (e) {
          debugPrint('Failed to load voice ${entry.key}: $e');
          continue;
        }
      }
      _voiceFilePaths[entry.key] = filePath;
    }

    debugPrint('Voices ready: ${_voiceFilePaths.length}');
  }

  /// Pre-warm voice players to reduce first-play latency
  Future<void> _prewarmPlayers() async {
    try {
      // Load a sound into each voice player without playing (sets up audio session)
      if (_voiceFilePaths.isNotEmpty) {
        final voicePath = _voiceFilePaths.values.first;
        for (final player in _voicePlayerPool) {
          await player.setSource(DeviceFileSource(voicePath));
        }
      }
      debugPrint('Voice players pre-warmed');
    } catch (e) {
      debugPrint('Pre-warm failed: $e');
    }
  }

  /// Play a beep sound (always plays, not affected by mute)
  void _playBeep(SoundType sound) {
    if (!_isInitialized) return;

    final player = _beepPlayers[sound];
    final filePath = _beepFilePaths[sound];
    if (player == null || filePath == null) {
      debugPrint('Beep player not available: $sound');
      return;
    }

    try {
      // Play directly from file source - most reliable for instant playback
      player.setVolume(_volume);
      player.play(DeviceFileSource(filePath));
    } catch (e) {
      debugPrint('Failed to play beep $sound: $e');
    }
  }

  /// Play a voice sound from pre-loaded files (affected by mute)
  Future<void> _playVoice(SoundType sound) async {
    if (_isVoiceMuted || !_isInitialized) return;

    final actualSound = _resolveVoiceAlias(sound);
    final filePath = _voiceFilePaths[actualSound];

    if (filePath == null) {
      debugPrint('Voice sound not available: $actualSound');
      return;
    }

    try {
      final player = _voicePlayerPool[_currentVoicePlayerIndex];
      _currentVoicePlayerIndex = (_currentVoicePlayerIndex + 1) % _poolSize;

      // Don't await - fire and forget for minimum latency
      player.setVolume(_volume);
      player.play(DeviceFileSource(filePath));
    } catch (e) {
      debugPrint('Failed to play voice $sound: $e');
    }
  }

  SoundType _resolveVoiceAlias(SoundType sound) {
    switch (sound) {
      case SoundType.intervalChange:
      case SoundType.roundComplete:
        return SoundType.voiceNextRound;
      case SoundType.workoutComplete:
        return SoundType.voiceDone;
      case SoundType.rest:
        return SoundType.voiceRest;
      default:
        return sound;
    }
  }

  /// Generic play method - routes to appropriate player
  Future<void> play(SoundType sound) async {
    if (!_isInitialized) return;

    if (_isBeepSound(sound)) {
      _playBeep(sound);
    } else {
      await _playVoice(sound);
    }
  }

  bool _isBeepSound(SoundType sound) {
    return sound == SoundType.countdown ||
        sound == SoundType.go ||
        sound == SoundType.complete ||
        sound == SoundType.halfway ||
        sound == SoundType.tenSeconds ||
        sound == SoundType.nextRound ||
        sound == SoundType.restBeep;
  }

  /// Play countdown with both beep and voice simultaneously
  Future<void> playCountdown(int count) async {
    if (!_isInitialized) return;

    switch (count) {
      case 3:
        _playBeep(SoundType.countdown);
        _playVoice(SoundType.voice3);
        break;
      case 2:
        _playBeep(SoundType.countdown);
        _playVoice(SoundType.voice2);
        break;
      case 1:
        _playBeep(SoundType.countdown);
        _playVoice(SoundType.voice1);
        break;
      case 0:
        _playBeep(SoundType.go);
        _playVoice(SoundType.voiceGo);
        break;
    }
  }

  Future<void> playGo() async {
    if (!_isInitialized) return;
    _playBeep(SoundType.go);
    _playVoice(SoundType.voiceGo);
  }

  Future<void> playComplete() async {
    if (!_isInitialized) return;
    _playBeep(SoundType.complete);
  }

  Future<void> playRest() async {
    if (!_isInitialized) return;
    _playBeep(SoundType.restBeep);
    _playVoice(SoundType.voiceRest);
  }

  Future<void> playHalfway() async {
    if (!_isInitialized) return;
    _playBeep(SoundType.halfway);
    _playVoice(SoundType.voiceHalfway);
  }

  Future<void> playLastRound() async {
    if (!_isInitialized) return;
    _playVoice(SoundType.voiceLastRound);
  }

  Future<void> playNextRound() async {
    if (!_isInitialized) return;
    _playBeep(SoundType.nextRound);
    _playVoice(SoundType.voiceNextRound);
  }

  /// Play only "next round" voice (before countdown)
  Future<void> playNextRoundVoice() async {
    if (!_isInitialized) return;
    _playVoice(SoundType.voiceNextRound);
  }

  /// Play only next round beep (when round starts)
  Future<void> playNextRoundBeep() async {
    if (!_isInitialized) return;
    _playBeep(SoundType.nextRound);
  }

  Future<void> playTenSeconds() async {
    if (!_isInitialized) return;
    _playBeep(SoundType.tenSeconds);
    _playVoice(SoundType.voiceTenSeconds);
  }

  void setMuted(bool muted) {
    _isVoiceMuted = muted;
  }

  void toggleMute() {
    _isVoiceMuted = !_isVoiceMuted;
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 2.0);
  }

  Future<void> stop() async {
    try {
      for (final player in _beepPlayers.values) {
        await player.stop();
      }
      for (final player in _voicePlayerPool) {
        await player.stop();
      }
    } catch (e) {
      debugPrint('Failed to stop audio: $e');
    }
  }

  Future<void> dispose() async {
    try {
      for (final player in _beepPlayers.values) {
        await player.dispose();
      }
      for (final player in _voicePlayerPool) {
        await player.dispose();
      }
      _beepPlayers.clear();
      _voicePlayerPool.clear();
      _beepFilePaths.clear();
      _voiceFilePaths.clear();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Failed to dispose audio: $e');
    }
  }
}
