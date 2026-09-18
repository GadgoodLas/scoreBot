import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/data/services/audio_service.dart';

/// États de la reconnaissance vocale sur l'écran live.
enum VoiceState {
  idle,
  recording,
  processing,
  success,
  error,
}

/// ViewModel de l'écran de match en direct.
class LiveViewModel extends ChangeNotifier {
  LiveViewModel({
    required MatchRepository matchRepository,
    required GameMatch initialMatch,
  })  : _repository = matchRepository,
        _match = initialMatch {
    _loadEvents();
    _startChronometer();
  }

  final MatchRepository _repository;
  GameMatch _match;
  GameMatch get match => _match;

  // ─────────────── Chronomètre ───────────────

  Timer? _chronoTimer;
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  /// Formaté "MM:SS" ou "HH:MM:SS" si > 1h.
  String get elapsedFormatted {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  int get currentMinute => _elapsed.inMinutes;

  void _startChronometer() {
    _elapsed = DateTime.now().difference(_match.startTime);
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_match.status == GameMatchStatus.live) {
        _elapsed = DateTime.now().difference(_match.startTime);
        notifyListeners();
      }
    });
  }

  // ─────────────── Événements ───────────────

  List<GameEvent> _events = [];
  List<GameEvent> get events => List.unmodifiable(_events);

  /// Événements triés du plus récent au plus ancien (pour le feed).
  List<GameEvent> get recentEvents =>
      _events.reversed.toList();

  void _loadEvents() {
    _events = _repository.getEvents(_match.id);
    notifyListeners();
  }

  // ─────────────── Voice Command ───────────────

  VoiceState _voiceState = VoiceState.idle;
  VoiceState get voiceState => _voiceState;

  String? _lastTranscription;
  String? get lastTranscription => _lastTranscription;

  String? _lastError;
  String? get lastError => _lastError;

  GameEvent? _lastEvent;
  GameEvent? get lastEvent => _lastEvent;

  int _recordingSeconds = 0;
  int get recordingSeconds => _recordingSeconds;
  Timer? _recordingTimer;

  bool _isTransitioning = false;

  /// Démarre l'enregistrement vocal.
  Future<void> startListening() async {
    if (_isTransitioning || _voiceState != VoiceState.recording) {
      if (_voiceState != VoiceState.idle) return;
    }
    // Permettre l'enregistrement même en pause pour dire "reprends" ou "fin"
    if (_match.status == GameMatchStatus.finished) return;

    _isTransitioning = true;
    _voiceState = VoiceState.recording;
    _lastError = null;
    _lastTranscription = null;
    _recordingSeconds = 0;
    notifyListeners();

    // Retour haptique immédiat au tap
    HapticFeedback.selectionClick();

    try {
      await _repository.startVoiceCommand();
      _isTransitioning = false;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingSeconds++;
        notifyListeners();
      });
      // Vibration distincte confirmant que le micro est ouvert
      HapticFeedback.heavyImpact();
    } catch (e) {
      _isTransitioning = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _voiceState = VoiceState.error;
      _lastError = e is AudioException ? e.message : 'Erreur micro : $e';
      notifyListeners();
      Timer(const Duration(seconds: 4), () {
        if (_voiceState == VoiceState.error) {
          _voiceState = VoiceState.idle;
          _lastError = null;
          notifyListeners();
        }
      });
    }
  }

  /// Bascule entre démarrage et arrêt (idéal pour Wear OS / Mobile).
  Future<void> toggleListening() async {
    if (_isTransitioning) return;
    if (_voiceState == VoiceState.idle) {
      await startListening();
    } else if (_voiceState == VoiceState.recording) {
      await stopListening();
    }
  }

  /// Arrête l'enregistrement et traite la commande.
  Future<void> stopListening() async {
    if (_isTransitioning || _voiceState != VoiceState.recording) return;

    _isTransitioning = true;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _voiceState = VoiceState.processing;
    notifyListeners();

    // Vibration haptique sur fin enregistrement
    HapticFeedback.mediumImpact();

    try {
      final result = await _repository.stopAndProcessVoiceCommand(_match);

      _lastTranscription = result.transcription;

      if (result.isSuccess) {
        _lastError = null;
        _voiceState = VoiceState.success;

        if (result.matchControl != null) {
          await _handleMatchControl(result.matchControl!);
        } else if (result.event != null) {
          _lastEvent = result.event!;
          if (result.event is CorrectionEvent) {
            await _handleCorrection(result.event as CorrectionEvent);
          } else {
            _events.add(result.event!);
            if (result.event is GoalEvent) {
              _match = await _repository.recalculateScore(_match);
            }
          }
        }

        // Vibration succès
        HapticFeedback.heavyImpact();

        // Retour à idle après 3 secondes
        Timer(const Duration(seconds: 3), () {
          if (_voiceState == VoiceState.success) {
            _voiceState = VoiceState.idle;
            _lastEvent = null;
            notifyListeners();
          }
        });
      } else {
        _lastError = result.errorMessage;
        _voiceState = VoiceState.error;

        Timer(const Duration(seconds: 4), () {
          if (_voiceState == VoiceState.error) {
            _voiceState = VoiceState.idle;
            _lastError = null;
            notifyListeners();
          }
        });
      }
    } catch (e) {
      _lastError = 'Erreur : $e';
      _voiceState = VoiceState.error;
      Timer(const Duration(seconds: 4), () {
        if (_voiceState == VoiceState.error) {
          _voiceState = VoiceState.idle;
          _lastError = null;
          notifyListeners();
        }
      });
    } finally {
      _isTransitioning = false;
      notifyListeners();
    }
  }

  /// Traite une commande saisie textuellement.
  Future<void> sendTextCommand(String text) async {
    if (text.trim().isEmpty) return;
    if (_voiceState == VoiceState.processing) return;

    _voiceState = VoiceState.processing;
    _lastError = null;
    _lastTranscription = text.trim();
    notifyListeners();

    final result = await _repository.processTextCommand(text.trim(), _match);

    if (result.isSuccess) {
      _lastError = null;
      _voiceState = VoiceState.success;

      if (result.matchControl != null) {
        await _handleMatchControl(result.matchControl!);
      } else if (result.event != null) {
        _lastEvent = result.event!;
        if (result.event is CorrectionEvent) {
          await _handleCorrection(result.event as CorrectionEvent);
        } else {
          _events.add(result.event!);
          if (result.event is GoalEvent) {
            _match = await _repository.recalculateScore(_match);
          }
        }
      }

      Timer(const Duration(seconds: 3), () {
        if (_voiceState == VoiceState.success) {
          _voiceState = VoiceState.idle;
          _lastEvent = null;
          notifyListeners();
        }
      });
    } else {
      _lastError = result.errorMessage;
      _voiceState = VoiceState.error;

      Timer(const Duration(seconds: 4), () {
        if (_voiceState == VoiceState.error) {
          _voiceState = VoiceState.idle;
          _lastError = null;
          notifyListeners();
        }
      });
    }

    notifyListeners();
  }

  Future<void> _handleMatchControl(String control) async {
    switch (control) {
      case 'pause':
        _match = await _repository.pauseMatch(_match);
        break;
      case 'resume':
        _match = await _repository.resumeMatch(_match);
        break;
      case 'halftime':
        _match = await _repository.startHalftime(_match);
        break;
      case 'end_match':
        _match = await _repository.endMatch(_match);
        _chronoTimer?.cancel();
        break;
    }
  }

  /// Annule l'enregistrement en cours.
  Future<void> cancelListening() async {
    if (_voiceState != VoiceState.recording) return;
    await _repository.cancelVoiceCommand();
    _voiceState = VoiceState.idle;
    notifyListeners();
  }

  Future<void> _handleCorrection(CorrectionEvent correction) async {
    final removed = await _repository.undoLastEvent(_match);
    if (removed != null) {
      _events.removeWhere((e) => e.id == removed.id);
      if (removed is GoalEvent) {
        _match = await _repository.recalculateScore(_match);
      }
    }
  }

  // ─────────────── Match Controls ───────────────

  Future<void> togglePause() async {
    _match = await _repository.togglePause(_match);
    notifyListeners();
  }

  Future<void> startHalftime() async {
    _match = await _repository.startHalftime(_match);
    notifyListeners();
  }

  Future<void> endMatch() async {
    _match = await _repository.endMatch(_match);
    _chronoTimer?.cancel();
    notifyListeners();
  }

  // ─────────────── Score Actions (+1 / -1) ───────────────

  /// Incrémente le score de l'équipe A (+1 au tap).
  Future<void> incrementScoreA() async {
    if (_match.status == GameMatchStatus.finished) return;
    HapticFeedback.lightImpact();
    _match = await _repository.addPoint(_match, _match.teamA.id);
    _loadEvents();
    notifyListeners();
  }

  /// Décrémente le score de l'équipe A (-1 au double tap).
  Future<void> decrementScoreA() async {
    if (_match.status == GameMatchStatus.finished || _match.scoreA <= 0) return;
    HapticFeedback.mediumImpact();
    _match = await _repository.removePoint(_match, _match.teamA.id);
    _loadEvents();
    notifyListeners();
  }

  /// Incrémente le score de l'équipe B (+1 au tap).
  Future<void> incrementScoreB() async {
    if (_match.status == GameMatchStatus.finished) return;
    HapticFeedback.lightImpact();
    _match = await _repository.addPoint(_match, _match.teamB.id);
    _loadEvents();
    notifyListeners();
  }

  /// Décrémente le score de l'équipe B (-1 au double tap).
  Future<void> decrementScoreB() async {
    if (_match.status == GameMatchStatus.finished || _match.scoreB <= 0) return;
    HapticFeedback.mediumImpact();
    _match = await _repository.removePoint(_match, _match.teamB.id);
    _loadEvents();
    notifyListeners();
  }

  // ─────────────── Computed Stats ───────────────

  /// Nombre de buts de l'équipe A.
  int get scoreA => _match.scoreA;

  /// Nombre de buts de l'équipe B.
  int get scoreB => _match.scoreB;

  /// Cartons jaunes par équipe.
  Map<String, int> get yellowCardsByTeam {
    final result = {_match.teamA.id: 0, _match.teamB.id: 0};
    for (final e in _events) {
      if (e is CardEvent && e.type == GameEventType.yellowCard) {
        result[e.teamId] = (result[e.teamId] ?? 0) + 1;
      }
    }
    return result;
  }

  @override
  void dispose() {
    _chronoTimer?.cancel();
    super.dispose();
  }
}
