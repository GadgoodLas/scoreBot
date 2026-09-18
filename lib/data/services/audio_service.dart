import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// États possibles de l'enregistrement audio.
enum RecordingState {
  idle,
  starting,
  recording,
  processing,
}

/// Service de gestion du microphone et de l'enregistrement audio.
/// Compatible Web, Android, iOS et Windows.
class AudioService {
  AudioService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentRecordingPath;
  Future<void>? _startFuture;
  DateTime? _recordingStartTime;

  RecordingState _state = RecordingState.idle;
  RecordingState get state => _state;

  bool get isRecording =>
      _state == RecordingState.recording || _state == RecordingState.starting;

  /// Type MIME adapté à la plateforme courante.
  String get mimeType => kIsWeb ? 'audio/webm' : 'audio/wav';

  /// Vérifie et demande la permission micro si nécessaire.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Démarre l'enregistrement audio.
  Future<void> startRecording() async {
    if (_state != RecordingState.idle) return;

    _state = RecordingState.starting;
    _startFuture = _executeStart();

    try {
      await _startFuture;
      _state = RecordingState.recording;
      _recordingStartTime = DateTime.now();
    } catch (e) {
      _state = RecordingState.idle;
      _startFuture = null;
      rethrow;
    }
  }

  Future<void> _executeStart() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw AudioException(
        'Permission microphone non accordée. Veuillez autoriser le microphone.',
      );
    }

    if (kIsWeb) {
      // Configuration pour le Web (Opus / WebM)
      const config = RecordConfig(
        encoder: AudioEncoder.opus,
        sampleRate: 48000,
        numChannels: 1,
      );
      await _recorder.start(config, path: '');
    } else {
      // Configuration native (WAV 16kHz mono — idéal pour Gemini)
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = p.join(tempDir.path, 'scorebot_$timestamp.wav');

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      );
      await _recorder.start(config, path: _currentRecordingPath!);
    }
  }

  /// Arrête l'enregistrement et retourne les données audio.
  Future<Uint8List> stopRecording() async {
    // Si l'enregistrement est encore en cours d'initialisation, attendre qu'il démarre
    if (_startFuture != null) {
      try {
        await _startFuture;
      } catch (_) {}
      _startFuture = null;
    }

    if (_state != RecordingState.recording) {
      throw AudioException('Aucun enregistrement en cours');
    }

    // Assurer une durée minimale d'enregistrement (au moins 500ms)
    if (_recordingStartTime != null) {
      final elapsedMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
      if (elapsedMs < 500) {
        await Future.delayed(Duration(milliseconds: 500 - elapsedMs));
      }
    }

    _state = RecordingState.processing;

    try {
      final path = await _recorder.stop();
      if (path == null) {
        throw AudioException('Échec de l\'arrêt de l\'enregistrement');
      }

      Uint8List bytes;

      if (kIsWeb) {
        // Sur le Web, `path` est une Blob URL (ex: blob:http://localhost...)
        final response = await http.get(Uri.parse(path));
        bytes = response.bodyBytes;
      } else {
        final file = File(path);
        if (!await file.exists()) {
          throw AudioException('Fichier audio introuvable: $path');
        }
        bytes = await file.readAsBytes();

        // Nettoyage du fichier temporaire
        try {
          await file.delete();
        } catch (_) {}
      }

      _currentRecordingPath = null;
      _recordingStartTime = null;

      if (bytes.isEmpty) {
        throw AudioException(
          'Enregistrement vide. Maintenez le bouton ou cliquez pour parler.',
        );
      }

      return bytes;
    } finally {
      _state = RecordingState.idle;
    }
  }

  /// Annule l'enregistrement en cours.
  Future<void> cancelRecording() async {
    if (_startFuture != null) {
      try {
        await _startFuture;
      } catch (_) {}
      _startFuture = null;
    }

    if (_state != RecordingState.recording) {
      _state = RecordingState.idle;
      return;
    }

    try {
      await _recorder.cancel();
      if (!kIsWeb && _currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}

    _currentRecordingPath = null;
    _recordingStartTime = null;
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
