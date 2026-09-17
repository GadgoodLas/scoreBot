import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// États possibles de l'enregistrement audio.
enum RecordingState {
  idle,
  recording,
  processing,
}

/// Service de gestion du microphone et de l'enregistrement audio.
class AudioService {
  AudioService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentRecordingPath;

  RecordingState _state = RecordingState.idle;
  RecordingState get state => _state;

  bool get isRecording => _state == RecordingState.recording;

  /// Vérifie et demande la permission micro si nécessaire.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Démarre l'enregistrement audio.
  /// Lance un fichier WAV dans le répertoire temporaire.
  Future<void> startRecording() async {
    if (_state == RecordingState.recording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw AudioException('Permission microphone refusée');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = p.join(tempDir.path, 'scorebot_$timestamp.wav');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000, // 16kHz optimal pour la transcription
        numChannels: 1, // Mono suffisant pour la voix
      ),
      path: _currentRecordingPath!,
    );

    _state = RecordingState.recording;
  }

  /// Arrête l'enregistrement et retourne les données audio.
  Future<Uint8List> stopRecording() async {
    if (_state != RecordingState.recording) {
      throw AudioException('Aucun enregistrement en cours');
    }

    _state = RecordingState.processing;

    final path = await _recorder.stop();
    if (path == null) {
      _state = RecordingState.idle;
      throw AudioException('Échec de l\'arrêt de l\'enregistrement');
    }

    final file = File(path);
    if (!await file.exists()) {
      _state = RecordingState.idle;
      throw AudioException('Fichier audio introuvable: $path');
    }

    final bytes = await file.readAsBytes();

    // Nettoyage du fichier temporaire
    await file.delete();
    _currentRecordingPath = null;
    _state = RecordingState.idle;

    if (bytes.isEmpty) {
      throw AudioException('Enregistrement vide, veuillez réessayer');
    }

    return bytes;
  }

  /// Annule l'enregistrement en cours.
  Future<void> cancelRecording() async {
    if (_state != RecordingState.recording) return;

    await _recorder.cancel();

    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _currentRecordingPath = null;
    }

    _state = RecordingState.idle;
  }

  /// Libère les ressources.
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

/// Exception spécifique au service audio.
class AudioException implements Exception {
  const AudioException(this.message);
  final String message;

  @override
  String toString() => 'AudioException: $message';
}

