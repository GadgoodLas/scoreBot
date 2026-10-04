import 'dart:async';
import 'package:flutter/material.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/data/services/audio_service.dart';
import 'package:score_bot/data/services/haptic_service.dart';
import 'package:score_bot/data/services/tts_service.dart';
import 'package:score_bot/data/services/watch_connectivity_service.dart';

/// États de la reconnaissance vocale sur l'écran live.
enum VoiceState { idle, recording, processing, success, error }

/// Types d'alertes automatiques en cours de match (pause, fin de temps réglementaire).
enum LiveAlertType { breakSuggested, matchEndReached }

/// ViewModel de l'écran de match en direct.
class LiveViewModel extends ChangeNotifier {
  LiveViewModel({
    required MatchRepository matchRepository,
    required GameMatch initialMatch,
    TtsService? ttsService,
    HapticService? hapticService,
    WatchConnectivityService? watchConnectivityService,
  }) : _repository = matchRepository,
       _match = initialMatch,
       _tts = ttsService ?? TtsService(),
       _haptic = hapticService ?? HapticService(),
       _connectivity = watchConnectivityService {
    _loadEvents();
    _startChronometer();
    _initConnectivityListeners();
  }

  final MatchRepository _repository;
  final TtsService _tts;
  final HapticService _haptic;
  final WatchConnectivityService? _connectivity;
  GameMatch _match;
  GameMatch get match => _match;

  LiveAlertType? _pendingAlert;
  LiveAlertType? get pendingAlert => _pendingAlert;

  bool _breakNotified = false;
  bool _endNotified = false;

  StreamSubscription<Map<String, dynamic>>? _scoreSub;
  StreamSubscription<GameEvent>? _eventSub;
  StreamSubscription<String>? _controlSub;
  StreamSubscription<GameMatch>? _matchStateSub;

  /// Indique si un appareil compagnon (téléphone ou montre) est actuellement appairé.
  bool get hasConnectedCompanion => _connectivity?.hasConnectedNodes ?? false;

  void _initConnectivityListeners() {
    if (_connectivity == null) return;

    // Diffuser l'état initial à l'ouverture du match
    _connectivity.sendMatchState(_match);
    _connectivity.checkConnectedNodes().then((_) => notifyListeners());

    // Écouter les mises à jour de score venant de l'autre appareil
    _scoreSub = _connectivity.onScoreUpdateReceived.listen((data) {
      if (data['matchId'] == _match.id) {
        final newA = data['scoreA'] as int?;
        final newB = data['scoreB'] as int?;
        if (newA != null && newB != null && (newA != _match.scoreA || newB != _match.scoreB)) {
          _match = _match.copyWith(scoreA: newA, scoreB: newB);
          _haptic.goal();
          _loadEvents();
          notifyListeners();
        }
      }
    });

    // Écouter les nouveaux événements (but, carton, faute)
    _eventSub = _connectivity.onEventReceived.listen((event) async {
      if (event.id.isNotEmpty && !_events.any((e) => e.id == event.id)) {
        _events.add(event);
        if (event is GoalEvent) {
          _match = await _repository.recalculateScore(_match);
          _haptic.goal();
        } else if (event is CardEvent) {
          if (event.type == GameEventType.redCard) {
            _haptic.redCard();
          } else {
            _haptic.yellowCard();
          }
        }
        notifyListeners();
      }
    });

    // Écouter les commandes de contrôle (pause, reprise, mi-temps, fin)
    _controlSub = _connectivity.onMatchControlReceived.listen((action) async {
      await _handleMatchControl(action);
      notifyListeners();
    });

    // Écouter un nouvel état complet de match
    _matchStateSub = _connectivity.onMatchStateReceived.listen((newMatch) {
      if (newMatch.id == _match.id) {
        _match = newMatch;
        _loadEvents();
        notifyListeners();
      }
    });
  }

  // ─────────────── Mode Ambiant (OLED Éco Wear OS) ───────────────

  bool _isAmbientMode = false;

  /// Indique si l'écran est en mode ambiant minimaliste basse consommation OLED.
  bool get isAmbientMode => _isAmbientMode;

  /// Bascule ou définit explicitement le mode ambiant.
  void toggleAmbientMode({bool? value}) {
    final next = value ?? !_isAmbientMode;
    if (_isAmbientMode != next) {
      _isAmbientMode = next;
      _haptic.recordingStart();
      notifyListeners();
    }
  }

  /// Sort du mode ambiant si actif.
  void exitAmbientMode() {
    if (_isAmbientMode) {
      _isAmbientMode = false;
      notifyListeners();
    }
  }

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
    if (_match.status == GameMatchStatus.live) {
      _checkTimersAndTriggerAlerts();
    }
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_match.status == GameMatchStatus.live) {
        _elapsed = DateTime.now().difference(_match.startTime);
        _checkTimersAndTriggerAlerts();
        notifyListeners();
      }
    });
  }

  /// Vérifie si le palier de pause ou de fin de match est atteint et diffuse les notifications vocales.
  void _checkTimersAndTriggerAlerts() {
    final breakMin = _match.breakDurationMinutes;
    if (breakMin != null && breakMin > 0 && !_breakNotified) {
      if (_elapsed.inSeconds >= breakMin * 60) {
        _breakNotified = true;
        _pendingAlert = LiveAlertType.breakSuggested;
        _haptic.periodEnd();
        _tts.speak(
          _repository.languageCode == 'fr'
              ? "C'est l'heure de la pause ! Prenez une pause."
              : "Break time! Take a break.",
        );
        notifyListeners();
      }
    }

    if (_match.durationMinutes > 0 && !_endNotified) {
      if (_elapsed.inSeconds >= _match.durationMinutes * 60) {
        _endNotified = true;
        _pendingAlert = LiveAlertType.matchEndReached;
        _haptic.periodEnd();
        _tts.speak(
          _repository.languageCode == 'fr'
              ? "Fin du match ! Le temps réglementaire est écoulé."
              : "Full time! Match finished.",
        );
        notifyListeners();
      }
    }
  }

  /// Ferme l'alerte visuelle en cours sans modifier l'état du match.
  void dismissPendingAlert() {
    _pendingAlert = null;
    notifyListeners();
  }

  /// Accepte la suggestion de pause et met le match en pause.
  Future<void> acceptBreakAlert() async {
    _pendingAlert = null;
    _match = await _repository.pauseMatch(_match);
    notifyListeners();
  }

  /// Accepte la fin de match et clôture le match.
  Future<void> acceptEndMatchAlert() async {
    _pendingAlert = null;
    _match = await _repository.endMatch(_match);
    _chronoTimer?.cancel();
    notifyListeners();
  }

  // ─────────────── Événements ───────────────

  List<GameEvent> _events = [];
  List<GameEvent> get events => List.unmodifiable(_events);

  /// Événements triés du plus récent au plus ancien (pour le feed).
  List<GameEvent> get recentEvents => _events.reversed.toList();

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

  // ─────────────── Configuration IA ───────────────

  bool get isAiConfigured => _repository.isAiConfigured;
  bool get isLocalVoiceMode => _repository.isLocalVoiceMode;
  bool get isVoiceReady => _repository.isVoiceReady;
  String get currentApiKey => _repository.apiKey;
  String get currentAiModel => _repository.aiModel;
  String get voiceEngine => _repository.voiceEngine;

  Future<void> saveAiConfig({
    required String apiKey,
    required String model,
    String? voiceEngine,
  }) async {
    await _repository.saveAiConfig(
      apiKey: apiKey,
      model: model,
      voiceEngine: voiceEngine,
    );
    notifyListeners();
  }

  Future<bool> testAiConnection({
    required String apiKey,
    required String model,
  }) {
    return _repository.testAiConnection(apiKey: apiKey, model: model);
  }

  /// Démarre l'enregistrement vocal.
  Future<void> startListening() async {
    if (_isTransitioning || _voiceState != VoiceState.recording) {
      if (_voiceState != VoiceState.idle) return;
    }
    // Permettre l'enregistrement même en pause pour dire "reprends" ou "fin"
    if (_match.status == GameMatchStatus.finished) return;

    if (!_repository.isVoiceReady) {
      _voiceState = VoiceState.error;
      _lastError = 'Mode vocal non configuré';
      _haptic.error();
      notifyListeners();
      Timer(const Duration(seconds: 4), () {
        if (_voiceState == VoiceState.error) {
          _voiceState = VoiceState.idle;
          _lastError = null;
          notifyListeners();
        }
      });
      return;
    }

    _isTransitioning = true;
    _voiceState = VoiceState.recording;
    _lastError = null;
    _lastTranscription = null;
    _recordingSeconds = 0;
    exitAmbientMode();
    notifyListeners();

    // Retour haptique immédiat au tap
    _haptic.recordingStart();

    try {
      await _repository.startVoiceCommand();
      _isTransitioning = false;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingSeconds++;
        notifyListeners();
      });
      // Vibration distincte confirmant que le micro est ouvert
      _haptic.recordingStart();
    } catch (e) {
      _isTransitioning = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _voiceState = VoiceState.error;
      _lastError = e is AudioException ? e.message : 'Erreur micro : $e';
      _haptic.error();
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
    _haptic.recordingStop();

    try {
      final result = await _repository.stopAndProcessVoiceCommand(_match);

      _lastTranscription = result.transcription;

      if (result.isSuccess) {
        _lastError = null;
        _voiceState = VoiceState.success;

        if (result.matchControl != null) {
          await _handleMatchControl(result.matchControl!);
          _haptic.matchControl();
        } else if (result.event != null) {
          _lastEvent = result.event!;
          if (result.event is CorrectionEvent) {
            await _handleCorrection(result.event as CorrectionEvent);
            _haptic.correction();
          } else {
            _events.add(result.event!);
            if (result.event is GoalEvent) {
              _match = await _repository.recalculateScore(_match);
              _haptic.goal();
            } else if (result.event is CardEvent) {
              final card = result.event as CardEvent;
              if (card.type == GameEventType.redCard) {
                _haptic.redCard();
              } else {
                _haptic.yellowCard();
              }
            } else if (result.event is FoulEvent) {
              _haptic.foul();
            } else {
              _haptic.matchControl();
            }
          }
        } else {
          _haptic.matchControl();
        }

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
        _haptic.error();

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
      _haptic.error();
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

    if (!_repository.isVoiceReady) {
      _voiceState = VoiceState.error;
      _lastError = 'Mode vocal non configuré';
      notifyListeners();
      Timer(const Duration(seconds: 4), () {
        if (_voiceState == VoiceState.error) {
          _voiceState = VoiceState.idle;
          _lastError = null;
          notifyListeners();
        }
      });
      return;
    }

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
    _haptic.matchControl();
    _match = await _repository.togglePause(_match);
    _connectivity?.sendMatchControl(
      matchId: _match.id,
      action: _match.status == GameMatchStatus.paused ? 'pause' : 'resume',
    );
    notifyListeners();
  }

  Future<void> startHalftime() async {
    _haptic.matchControl();
    _match = await _repository.startHalftime(_match);
    _connectivity?.sendMatchControl(matchId: _match.id, action: 'halftime');
    notifyListeners();
  }

  Future<void> endMatch() async {
    _haptic.periodEnd();
    _match = await _repository.endMatch(_match);
    _chronoTimer?.cancel();
    _connectivity?.sendMatchControl(matchId: _match.id, action: 'end_match');
    notifyListeners();
  }

  /// Vrai dès que le match est terminé (utilisé pour la navigation auto).
  bool get isMatchFinished => _match.status == GameMatchStatus.finished;

  // ─────────────── Score Actions (+1 / -1) ───────────────

  /// Incrémente le score de l'équipe A (+1 au tap).
  Future<void> incrementScoreA() async {
    if (_match.status == GameMatchStatus.finished) return;
    _haptic.goal();
    _match = await _repository.addPoint(_match, _match.teamA.id);
    _loadEvents();
    _connectivity?.sendScoreUpdate(
      matchId: _match.id,
      scoreA: _match.scoreA,
      scoreB: _match.scoreB,
    );
    notifyListeners();
  }

  /// Décrémente le score de l'équipe A (-1 au double tap).
  Future<void> decrementScoreA() async {
    if (_match.status == GameMatchStatus.finished || _match.scoreA <= 0) return;
    _haptic.correction();
    _match = await _repository.removePoint(_match, _match.teamA.id);
    _loadEvents();
    _connectivity?.sendScoreUpdate(
      matchId: _match.id,
      scoreA: _match.scoreA,
      scoreB: _match.scoreB,
    );
    notifyListeners();
  }

  /// Incrémente le score de l'équipe B (+1 au tap).
  Future<void> incrementScoreB() async {
    if (_match.status == GameMatchStatus.finished) return;
    _haptic.goal();
    _match = await _repository.addPoint(_match, _match.teamB.id);
    _loadEvents();
    _connectivity?.sendScoreUpdate(
      matchId: _match.id,
      scoreA: _match.scoreA,
      scoreB: _match.scoreB,
    );
    notifyListeners();
  }

  /// Décrémente le score de l'équipe B (-1 au double tap).
  Future<void> decrementScoreB() async {
    if (_match.status == GameMatchStatus.finished || _match.scoreB <= 0) return;
    _haptic.correction();
    _match = await _repository.removePoint(_match, _match.teamB.id);
    _loadEvents();
    _connectivity?.sendScoreUpdate(
      matchId: _match.id,
      scoreA: _match.scoreA,
      scoreB: _match.scoreB,
    );
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
    _scoreSub?.cancel();
    _eventSub?.cancel();
    _controlSub?.cancel();
    _matchStateSub?.cancel();
    _chronoTimer?.cancel();
    super.dispose();
  }
}
