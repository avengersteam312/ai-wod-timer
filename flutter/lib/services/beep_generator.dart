import 'dart:math';
import 'dart:typed_data';

/// Generates beep sounds programmatically as WAV audio data.
/// No external sound files needed - creates tones in memory.
class BeepGenerator {
  static const int sampleRate = 44100;
  static const int bitsPerSample = 16;
  static const int numChannels = 1; // Mono

  /// Generate a countdown beep (short, high-pitched tick)
  static Uint8List countdownBeep() {
    return generateBeep(
      frequency: 880, // A5 note
      durationMs: 80,
      volume: 0.7,
      fadeOutPercent: 30,
    );
  }

  /// Generate a "Go!" beep (clean, professional start signal)
  static Uint8List goBeep() {
    // Sharp, professional single tone - like gym/sports timer
    return generateBeep(
      frequency: 1000, // 1kHz - clear, attention-grabbing
      durationMs: 500,
      volume: 0.8,
      fadeInPercent: 2,
      fadeOutPercent: 20,
    );
  }

  /// Generate a completion beep (dual-tone chord - satisfying end)
  static Uint8List completeBeep() {
    // Two-tone chord: C5 + E5 (major third - sounds positive/complete)
    final tone1 = _generateTone(
      frequency: 523, // C5
      durationMs: 300,
      volume: 0.5,
      fadeInPercent: 5,
      fadeOutPercent: 50,
    );
    final tone2 = _generateTone(
      frequency: 659, // E5
      durationMs: 300,
      volume: 0.5,
      fadeInPercent: 5,
      fadeOutPercent: 50,
    );

    // Mix the two tones
    return _mixAndCreateWav(tone1, tone2, 300);
  }

  /// Generate a halfway beep (2 beeps)
  static Uint8List halfwayBeep() {
    final beep = _generateTone(
      frequency: 1000,
      durationMs: 80,
      volume: 0.7,
      fadeOutPercent: 30,
    );

    // Double beep with short gap
    return _concatenateWithGapsAndCreateWav([beep, beep], 60);
  }

  /// Generate a 10 seconds warning beep (3 beeps)
  static Uint8List tenSecondsBeep() {
    final beep = _generateTone(
      frequency: 1000,
      durationMs: 80,
      volume: 0.7,
      fadeOutPercent: 30,
    );

    // Triple beep with short gaps
    return _concatenateWithGapsAndCreateWav([beep, beep, beep], 60);
  }

  /// Generate a next round beep (like go but short)
  static Uint8List nextRoundBeep() {
    return generateBeep(
      frequency: 1000, // Same as go - clear, professional
      durationMs: 80,
      volume: 0.8,
      fadeOutPercent: 30,
    );
  }

  /// Generate a rest period beep (softer, lower tone)
  static Uint8List restBeep() {
    return generateBeep(
      frequency: 440, // A4 - lower, calmer
      durationMs: 150,
      volume: 0.5,
      fadeInPercent: 10,
      fadeOutPercent: 50,
    );
  }

  /// Generate a custom beep with full control
  static Uint8List generateBeep({
    required int frequency,
    required int durationMs,
    double volume = 0.8,
    int fadeInPercent = 5,
    int fadeOutPercent = 20,
  }) {
    final samples = _generateTone(
      frequency: frequency,
      durationMs: durationMs,
      volume: volume,
      fadeInPercent: fadeInPercent,
      fadeOutPercent: fadeOutPercent,
    );

    return _createWavFile(samples);
  }

  /// Generate raw PCM samples for a tone
  static Float32List _generateTone({
    required int frequency,
    required int durationMs,
    required double volume,
    int fadeInPercent = 5,
    int fadeOutPercent = 20,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Float32List(numSamples);

    final fadeInSamples = (numSamples * fadeInPercent / 100).round();
    final fadeOutSamples = (numSamples * fadeOutPercent / 100).round();
    final fadeOutStart = numSamples - fadeOutSamples;

    for (int i = 0; i < numSamples; i++) {
      // Generate sine wave
      double sample = sin(2 * pi * frequency * i / sampleRate);

      // Apply volume
      sample *= volume;

      // Apply fade-in envelope
      if (i < fadeInSamples) {
        sample *= i / fadeInSamples;
      }

      // Apply fade-out envelope
      if (i >= fadeOutStart) {
        sample *= (numSamples - i) / fadeOutSamples;
      }

      samples[i] = sample;
    }

    return samples;
  }

  /// Mix two tones together
  static Uint8List _mixAndCreateWav(Float32List tone1, Float32List tone2, int durationMs) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final mixed = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final s1 = i < tone1.length ? tone1[i] : 0.0;
      final s2 = i < tone2.length ? tone2[i] : 0.0;
      mixed[i] = (s1 + s2).clamp(-1.0, 1.0);
    }

    return _createWavFile(mixed);
  }

  /// Concatenate multiple tones with gaps between them
  static Uint8List _concatenateWithGapsAndCreateWav(List<Float32List> tones, int gapMs) {
    final gapSamples = (sampleRate * gapMs / 1000).round();

    // Calculate total length
    int totalSamples = 0;
    for (final tone in tones) {
      totalSamples += tone.length;
    }
    totalSamples += gapSamples * (tones.length - 1); // Gaps between tones

    final combined = Float32List(totalSamples);
    int offset = 0;

    for (int t = 0; t < tones.length; t++) {
      final tone = tones[t];
      for (int i = 0; i < tone.length; i++) {
        combined[offset + i] = tone[i];
      }
      offset += tone.length;

      // Add gap (silence) between tones
      if (t < tones.length - 1) {
        offset += gapSamples; // Already initialized to 0
      }
    }

    return _createWavFile(combined);
  }

  /// Create a WAV file from raw samples
  static Uint8List _createWavFile(Float32List samples) {
    final numSamples = samples.length;
    const byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = numSamples * blockAlign;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // 'R'
    buffer.setUint8(offset++, 0x49); // 'I'
    buffer.setUint8(offset++, 0x46); // 'F'
    buffer.setUint8(offset++, 0x46); // 'F'
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // 'W'
    buffer.setUint8(offset++, 0x41); // 'A'
    buffer.setUint8(offset++, 0x56); // 'V'
    buffer.setUint8(offset++, 0x45); // 'E'

    // fmt subchunk
    buffer.setUint8(offset++, 0x66); // 'f'
    buffer.setUint8(offset++, 0x6D); // 'm'
    buffer.setUint8(offset++, 0x74); // 't'
    buffer.setUint8(offset++, 0x20); // ' '
    buffer.setUint32(offset, 16, Endian.little); // Subchunk1Size (16 for PCM)
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // AudioFormat (1 = PCM)
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data subchunk
    buffer.setUint8(offset++, 0x64); // 'd'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint8(offset++, 0x74); // 't'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Write samples as 16-bit PCM
    for (int i = 0; i < numSamples; i++) {
      // Convert float [-1, 1] to int16 [-32768, 32767]
      final intSample = (samples[i] * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}
