import 'package:uuid/uuid.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/services/audio_service.dart';
import 'package:score_bot/data/services/gemini_service.dart';
import 'package:score_bot/data/services/storage_service.dart';

/// Résultat d'une commande vocale traitée.
class VoiceCommandResult {
  const VoiceCommandResult({
    required this.transcription,
    this.event,
    this.errorMessage,
  });

  /// Texte transcrit par Gemini.
  final String transcription;

  /// Événement créé (null si parsing échoué ou commande inconnue).
  final GameEvent? event;

  /// Message d'erreur si quelque chose s'est mal passé.
  final String? errorMessage;

  bool get isSuccess => event != null;
}

/// Repository central de ScoreBot.
/// Orchestre les services Audio, Gemini et Storage pour gérer un match en direct.
class MatchRepository {
  MatchRepository({
    required AudioService audioService,
    required GeminiService geminiService,
    required StorageService storageService,
  })  : _audio = audioService,
        _gemini = geminiService,
        _storage = storageService;

  final AudioService _audio;
  final GeminiService _gemini;
  final StorageService _storage;
  final _uuid = const Uuid();

  // ─────────────── MATCH LIFECYCLE ───────────────

  /// Crée et démarre un nouveau match.
  Future<GameMatch> createMatch({
    required SportType sport,
    required Team teamA,
    required Team teamB,
    int? durationMinutes,
  }) async {
    final match = GameMatch(
      id: _uuid.v4(),
      sport: sport,
      teamA: teamA,
      teamB: teamB,
      status: GameMatchStatus.live,
      scoreA: 0,
      scoreB: 0,
      startTime: DateTime.now(),
      durationMinutes: durationMinutes ?? sport.matchDurationMinutes,
    );

    await _storage.saveMatch(match);
    return match;
  }

  /// Pause / reprend le match.
  Future<GameMatch> togglePause(GameMatch match) async {
    final newStatus = match.status == GameMatchStatus.live
        ? GameMatchStatus.paused
        : GameMatchStatus.live;
    final updated = match.copyWith(status: newStatus);
    await _storage.saveMatch(updated);
    return updated;
  }

  /// Passe le match en mi-temps.
  Future<GameMatch> startHalftime(GameMatch match) async {
    final updated = match.copyWith(status: GameMatchStatus.halftime);
    await _storage.saveMatch(updated);
    return updated;
  }

  /// Termine le match.
  Future<GameMatch> endMatch(GameMatch match) async {
    final updated = match.copyWith(
      status: GameMatchStatus.finished,
      endTime: DateTime.now(),
    );
    await _storage.saveMatch(updated);
    return updated;
  }

  // ─────────────── VOICE COMMANDS ───────────────

  /// Démarre l'enregistrement d'une commande vocale.
  Future<void> startVoiceCommand() => _audio.startRecording();

  /// Arrête l'enregistrement, traite l'audio via Gemini en une seule passe,
  /// crée et persiste l'événement de match.
  ///
  /// Retourne un [VoiceCommandResult] avec l'événement créé ou l'erreur.
  Future<VoiceCommandResult> stopAndProcessVoiceCommand(GameMatch match) async {
    try {
      // 1. Arrêter l'enregistrement et récupérer l'audio
      final audioBytes = await _audio.stopRecording();

      // 2. Traiter directement l'audio avec Gemini en une seule passe
      final parsed = await _gemini.processAudioCommand(
        audioBytes: audioBytes,
        mimeType: _audio.mimeType,
        match: match,
      );

      final transcription = parsed.transcription.isNotEmpty
          ? parsed.transcription
          : 'Commande vocale';

      if (parsed.type == GameEventType.unknown) {
        return VoiceCommandResult(
          transcription: transcription,
          errorMessage: parsed.transcription.isNotEmpty
              ? 'Événement non reconnu : "${parsed.transcription}"'
              : 'Aucune parole claire détectée. Réessayez.',
        );
      }

      // 3. Résoudre l'équipe (correspondance par nom ou couleur)
      final resolvedTeam = _resolveTeam(parsed.teamName, match);

      // 4. Créer l'événement de domaine
      final minute = parsed.minute ?? match.currentMinute;
      final eventId = _uuid.v4();
      final now = DateTime.now();

      final event = _buildEvent(
        id: eventId,
        parsed: parsed,
        teamId: resolvedTeam?.id ?? match.teamA.id,
        minute: minute,
        timestamp: now,
      );

      // 5. Persister l'événement
      await _storage.saveEvent(match.id, event);

      return VoiceCommandResult(
        transcription: transcription,
        event: event,
      );
    } on AudioException catch (e) {
      return VoiceCommandResult(
        transcription: '',
        errorMessage: e.message,
      );
    } on GeminiException catch (e) {
      return VoiceCommandResult(
        transcription: '',
        errorMessage: e.message,
      );
    } catch (e) {
      return VoiceCommandResult(
        transcription: '',
        errorMessage: 'Erreur inattendue : $e',
      );
    }
  }

  /// Traite une commande saisie sous forme de texte (fallback pratique).
  Future<VoiceCommandResult> processTextCommand(
    String text,
    GameMatch match,
  ) async {
    try {
      final parsed = await _gemini.parseTextCommand(
        text: text,
        match: match,
      );

      if (parsed.type == GameEventType.unknown) {
        return VoiceCommandResult(
          transcription: text,
          errorMessage: 'Commande non reconnue : "$text"',
        );
      }

      final resolvedTeam = _resolveTeam(parsed.teamName, match);
      final minute = parsed.minute ?? match.currentMinute;
      final eventId = _uuid.v4();
      final now = DateTime.now();

      final event = _buildEvent(
        id: eventId,
        parsed: parsed,
        teamId: resolvedTeam?.id ?? match.teamA.id,
        minute: minute,
        timestamp: now,
      );

      await _storage.saveEvent(match.id, event);

      return VoiceCommandResult(
        transcription: text,
        event: event,
      );
    } on GeminiException catch (e) {
      return VoiceCommandResult(
        transcription: text,
        errorMessage: e.message,
      );
    } catch (e) {
      return VoiceCommandResult(
        transcription: text,
        errorMessage: 'Erreur : $e',
      );
    }
  }

  /// Annule l'enregistrement en cours sans traiter.
  Future<void> cancelVoiceCommand() => _audio.cancelRecording();

  // ─────────────── EVENTS ───────────────

  /// Ajoute un événement manuel (sans commande vocale).
  Future<GameEvent> addEvent(GameMatch match, GameEvent event) async {
    await _storage.saveEvent(match.id, event);
    return event;
  }

  /// Supprime le dernier événement d'un match (annulation vocale).
  Future<GameEvent?> undoLastEvent(GameMatch match) async {
    final events = _storage.getEventsForMatch(match.id);
    if (events.isEmpty) return null;
    final last = events.last;
    await _storage.deleteEvent(match.id, last.id);
    return last;
  }

  /// Récupère tous les événements d'un match.
  List<GameEvent> getEvents(String matchId) =>
      _storage.getEventsForMatch(matchId);

  // ─────────────── SCORE ───────────────

  /// Recalcule et met à jour le score d'un match à partir de ses événements.
  Future<GameMatch> recalculateScore(GameMatch match) async {
    final events = _storage.getEventsForMatch(match.id);
    int scoreA = 0;
    int scoreB = 0;

    for (final event in events) {
      if (event is GoalEvent) {
        final points = event.points;
        if (event.teamId == match.teamA.id) {
          scoreA += points;
        } else if (event.teamId == match.teamB.id) {
          scoreB += points;
        }
      }
    }

    final updated = match.copyWith(scoreA: scoreA, scoreB: scoreB);
    await _storage.saveMatch(updated);
    return updated;
  }

  // ─────────────── HISTORY ───────────────

  /// Liste tous les matchs sauvegardés.
  List<GameMatch> listMatches() => _storage.listMatches();

  // ─────────────── PRIVATE HELPERS ───────────────

  /// Résout l'équipe à partir d'un nom partiel ou d'une couleur.
  Team? _resolveTeam(String teamName, GameMatch match) {
    if (teamName.isEmpty) return match.teamA;

    final normalized = teamName.toLowerCase().trim();

    // Correspondance exacte ou partielle sur le nom ou la couleur
    for (final team in [match.teamA, match.teamB]) {
      if (team.name.toLowerCase().contains(normalized) ||
          normalized.contains(team.name.toLowerCase())) {
        return team;
      }
      if (team.color != null &&
          (team.color!.toLowerCase().contains(normalized) ||
              normalized.contains(team.color!.toLowerCase()))) {
        return team;
      }
    }

    return match.teamA; // Fallback sur l'équipe A
  }

  /// Crée un [GameEvent] concret à partir d'une commande parsée.
  GameEvent _buildEvent({
    required String id,
    required ParsedVoiceCommand parsed,
    required String teamId,
    required int minute,
    required DateTime timestamp,
  }) {
    return switch (parsed.type) {
      GameEventType.goal => GoalEvent(
          id: id,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          scorerName: parsed.playerName,
          assistName: parsed.secondaryPlayerName,
          isPenalty: parsed.isPenalty,
          points: parsed.points ?? 1,
        ),
      GameEventType.yellowCard || GameEventType.redCard => CardEvent(
          id: id,
          type: parsed.type,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          playerName: parsed.playerName,
        ),
      GameEventType.foul => FoulEvent(
          id: id,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          playerName: parsed.playerName,
        ),
      GameEventType.timeout => TimeoutEvent(
          id: id,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
        ),
      GameEventType.substitution => SubstitutionEvent(
          id: id,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          playerOutName: parsed.playerName,
          playerInName: parsed.secondaryPlayerName,
        ),
      GameEventType.correction => CorrectionEvent(
          id: id,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          action: parsed.correctionAction ?? 'undo_last',
        ),
      _ => GenericEvent(
          id: id,
          type: parsed.type,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          notes: parsed.notes,
        ),
    };
  }
}
