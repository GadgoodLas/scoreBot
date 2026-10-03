import 'dart:async';
import 'package:flutter/services.dart';

/// Type d'action haptique pour injection ou simulation de tests.
enum HapticFeedbackType { light, medium, heavy, selection, vibrate }

/// Service dédié aux retours haptiques (vibrations) différenciés pour Wear OS et Mobile.
/// Permet à l'arbitre de ressentir instantanément au poignet la confirmation des événements
/// sans avoir à regarder l'écran.
class HapticService {
  HapticService({Future<void> Function(HapticFeedbackType type)? customRunner})
    : _runner = customRunner ?? _defaultRunner;

  final Future<void> Function(HapticFeedbackType type) _runner;

  static Future<void> _defaultRunner(HapticFeedbackType type) async {
    try {
      switch (type) {
        case HapticFeedbackType.light:
          await HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.medium:
          await HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavy:
          await HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selection:
          await HapticFeedback.selectionClick();
          break;
        case HapticFeedbackType.vibrate:
          await HapticFeedback.vibrate();
          break;
      }
    } catch (_) {
      // Ignorer les erreurs si les vibrations ne sont pas supportées par l'environnement
    }
  }

  /// Début de l'enregistrement vocal (clic net pour confirmer l'ouverture du micro).
  Future<void> recordingStart() async {
    await _runner(HapticFeedbackType.selection);
  }

  /// Fin de l'enregistrement vocal / passage en analyse (impulsion moyenne).
  Future<void> recordingStop() async {
    await _runner(HapticFeedbackType.medium);
  }

  /// Validation d'un BUT (double impulsion lourde et rapide : 2 coups nets).
  Future<void> goal() async {
    await _runner(HapticFeedbackType.heavy);
    await Future.delayed(const Duration(milliseconds: 100));
    await _runner(HapticFeedbackType.heavy);
  }

  /// Carton JAUNE (impulsion moyenne unique).
  Future<void> yellowCard() async {
    await _runner(HapticFeedbackType.medium);
  }

  /// Carton ROUGE (triple impulsion lourde d'avertissement critique).
  Future<void> redCard() async {
    await _runner(HapticFeedbackType.heavy);
    await Future.delayed(const Duration(milliseconds: 90));
    await _runner(HapticFeedbackType.heavy);
    await Future.delayed(const Duration(milliseconds: 90));
    await _runner(HapticFeedbackType.heavy);
  }

  /// Faute ou arrêt de jeu (impulsion légère).
  Future<void> foul() async {
    await _runner(HapticFeedbackType.light);
  }

  /// Correction ou annulation d'événement (double clic léger).
  Future<void> correction() async {
    await _runner(HapticFeedbackType.selection);
    await Future.delayed(const Duration(milliseconds: 90));
    await _runner(HapticFeedbackType.selection);
  }

  /// Contrôle du match (pause, reprise).
  Future<void> matchControl() async {
    await _runner(HapticFeedbackType.medium);
  }

  /// Erreur de reconnaissance ou commande non comprise (impulsion saccadée).
  Future<void> error() async {
    await _runner(HapticFeedbackType.medium);
    await Future.delayed(const Duration(milliseconds: 120));
    await _runner(HapticFeedbackType.light);
  }

  /// Alerte de mi-temps ou fin de match (vibration longue et impulsion lourde).
  Future<void> periodEnd() async {
    await _runner(HapticFeedbackType.vibrate);
    await Future.delayed(const Duration(milliseconds: 150));
    await _runner(HapticFeedbackType.heavy);
  }
}
