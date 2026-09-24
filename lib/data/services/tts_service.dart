import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service de synthèse vocale (Text-To-Speech) hors-ligne.
/// Diffuse des alertes vocales en cours de match (pause, fin de match).
class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _isInitialized = false;
  bool _isEnabled = true;
  String _currentLanguage = 'fr-FR';
  VoidCallback? _onCompletion;

  bool get isEnabled => _isEnabled;
  void setEnabled(bool value) => _isEnabled = value;

  void setCompletionHandler(VoidCallback? handler) {
    _onCompletion = handler;
  }

  /// Initialise la voix et configure le volume, le pitch et le débit.
  Future<void> init({String languageCode = 'fr'}) async {
    if (_isInitialized) return;
    try {
      _currentLanguage = languageCode == 'fr' ? 'fr-FR' : 'en-US';
      await _tts.setLanguage(_currentLanguage);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() {
        _onCompletion?.call();
      });
      _tts.setCancelHandler(() {
        _onCompletion?.call();
      });
      _tts.setErrorHandler((_) {
        _onCompletion?.call();
      });

      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[TtsService] init error: $e');
    }
  }

  /// Change la langue de la synthèse vocale.
  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode == 'fr' ? 'fr-FR' : 'en-US';
    try {
      await _tts.setLanguage(_currentLanguage);
    } catch (e) {
      debugPrint('[TtsService] setLanguage error: $e');
    }
  }

  /// Énonce un message vocalement.
  Future<void> speak(String text) async {
    if (!_isEnabled || text.trim().isEmpty) return;
    try {
      if (!_isInitialized) {
        await init();
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] speak error: $e');
    }
  }

  /// Interrompt l'énoncé en cours.
  Future<void> stop() async {
    try {
      await _tts.stop();
      _onCompletion?.call();
    } catch (e) {
      debugPrint('[TtsService] stop error: $e');
    }
  }
}
