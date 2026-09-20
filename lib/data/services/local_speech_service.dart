import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service de reconnaissance vocale locale (On-Device STT).
/// Utilise le moteur de reconnaissance vocale natif d'Android et d'iOS sans connexion cloud.
class LocalSpeechService {
  LocalSpeechService({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isAvailable => _speech.isAvailable;
  bool get isListening => _speech.isListening;

  /// Initialise le moteur de reconnaissance vocale natif.
  Future<bool> init() async {
    if (_isInitialized) return _speech.isAvailable;

    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => debugPrint('[LocalSpeech] Erreur : ${val.errorMsg}'),
        onStatus: (val) => debugPrint('[LocalSpeech] Statut : $val'),
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('[LocalSpeech] Échec d\'initialisation : $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Démarre l'écoute locale avec la locale spécifiée ('en_US' par défaut ou 'fr_FR').
  Future<void> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      final available = await init();
      if (!available) {
        throw StateError('Le moteur de reconnaissance vocale local n\'est pas disponible.');
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
      // ignore: deprecated_member_use
      localeId: localeId,
      // ignore: deprecated_member_use
      listenFor: listenFor,
      // ignore: deprecated_member_use
      pauseFor: pauseFor,
    );
  }

  /// Arrête l'écoute et finalise la reconnaissance.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Annule immédiatement l'écoute sans produire de résultat final.
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
