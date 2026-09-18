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
    this.matchControl,
    this.errorMessage,
  });

  /// Texte transcrit par Gemini.
  final String transcription;

  /// Événement créé (null si parsing échoué ou commande de contrôle match).
  final GameEvent? event;

  /// Contrôle match demandé ('pause', 'resume', 'halftime', 'end_match').
  final String? matchControl;

  /// Message d'erreur si quelque chose s'est mal passé.
  final String? errorMessage;

  bool get isSuccess => event != null || matchControl != null;
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

  /// Reprend le match.
  Future<GameMatch> resumeMatch(GameMatch match) async {
    final updated = match.copyWith(status: GameMatchStatus.live);
    await _storage.saveMatch(updated);
    return updated;
  }

  /// Met le match en pause.
  Future<GameMatch> pauseMatch(GameMatch match) async {
    final updated = match.copyWith(status: GameMatchStatus.paused);
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
  /// crée et persiste l'événement de match ou exécute l'action de contrôle.
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

      // 3. Gestion d'un contrôle de match vocal (pause, reprise, mi-temps, fin)
      if (parsed.matchControl != null) {
        return VoiceCommandResult(
          transcription: transcription,
          matchControl: parsed.matchControl,
        );
      }

      if (parsed.type == GameEventType.unknown) {
        return VoiceCommandResult(
          transcription: transcription,
          errorMessage: parsed.transcription.isNotEmpty
              ? 'Événement non reconnu : "${parsed.transcription}"'
              : 'Aucune parole claire détectée. Réessayez.',
        );
      }

      // 4. Résoudre l'équipe (correspondance par nom, joueur ou couleur)
      final resolvedTeam = _resolveTeam(
        parsed.teamName,
        match,
        playerName: parsed.playerName,
        secondaryPlayerName: parsed.secondaryPlayerName,
      );

      // 5. Créer l'événement de domaine
      final minute = parsed.minute ?? match.currentMinute;
      final eventId = _uuid.v4();
      final now = DateTime.now();

      final event = _buildEvent(
        id: eventId,
        parsed: parsed,
        teamId: resolvedTeam?.id ?? match.teamA.id,
        minute: minute,
        timestamp: now,
        match: match,
      );

      // 6. Persister l'événement
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

      final transcription = parsed.transcription.isNotEmpty ? parsed.transcription : text;

      if (parsed.matchControl != null) {
        return VoiceCommandResult(
          transcription: transcription,
          matchControl: parsed.matchControl,
        );
      }

      if (parsed.type == GameEventType.unknown) {
        return VoiceCommandResult(
          transcription: transcription,
          errorMessage: 'Commande non reconnue : "$text"',
        );
      }

      final resolvedTeam = _resolveTeam(
        parsed.teamName,
        match,
        playerName: parsed.playerName,
        secondaryPlayerName: parsed.secondaryPlayerName,
      );
      final minute = parsed.minute ?? match.currentMinute;
      final eventId = _uuid.v4();
      final now = DateTime.now();

      final event = _buildEvent(
        id: eventId,
        parsed: parsed,
        teamId: resolvedTeam?.id ?? match.teamA.id,
        minute: minute,
        timestamp: now,
        match: match,
      );

      await _storage.saveEvent(match.id, event);

      return VoiceCommandResult(
        transcription: transcription,
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

  /// Ajoute 1 point (ou n points) au score d'une équipe via un GoalEvent.
  Future<GameMatch> addPoint(GameMatch match, String teamId, {int points = 1}) async {
    final event = GoalEvent(
      id: _uuid.v4(),
      teamId: teamId,
      minute: match.currentMinute,
      timestamp: DateTime.now(),
      points: points,
    );
    await _storage.saveEvent(match.id, event);
    return recalculateScore(match);
  }

  /// Retire 1 point (ou le dernier but) d'une équipe.
  Future<GameMatch> removePoint(GameMatch match, String teamId) async {
    final events = _storage.getEventsForMatch(match.id);
    // Trouve le dernier événement de score de cette équipe
    final lastGoalIndex = events.lastIndexWhere(
      (e) => e is GoalEvent && e.teamId == teamId,
    );

    if (lastGoalIndex != -1) {
      final goalToRemove = events[lastGoalIndex];
      await _storage.deleteEvent(match.id, goalToRemove.id);
    }
    return recalculateScore(match);
  }

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

  /// Résout l'équipe à partir d'un nom partiel, d'une couleur, d'un mot-clé ou d'un joueur.
  Team? _resolveTeam(
    String teamName,
    GameMatch match, {
    String? playerName,
    String? secondaryPlayerName,
  }) {
    // 1. Recherche via les joueurs du match si précisés
    final playerQuery = playerName?.toLowerCase().trim() ?? '';
    final secPlayerQuery = secondaryPlayerName?.toLowerCase().trim() ?? '';

    if (playerQuery.isNotEmpty || secPlayerQuery.isNotEmpty) {
      for (final p in match.teamB.players) {
        final pName = p.name.toLowerCase();
        if ((playerQuery.isNotEmpty && pName.contains(playerQuery)) ||
            (secPlayerQuery.isNotEmpty && pName.contains(secPlayerQuery))) {
          return match.teamB;
        }
      }
      for (final p in match.teamA.players) {
        final pName = p.name.toLowerCase();
        if ((playerQuery.isNotEmpty && pName.contains(playerQuery)) ||
            (secPlayerQuery.isNotEmpty && pName.contains(secPlayerQuery))) {
          return match.teamA;
        }
      }
    }

    if (teamName.isEmpty) return match.teamA;

    final normalized = teamName.toLowerCase().trim();

    // 2. Correspondance exacte ou partielle avec le nom officiel de l'équipe
    if (match.teamB.name.toLowerCase().contains(normalized) ||
        normalized.contains(match.teamB.name.toLowerCase())) {
      return match.teamB;
    }
    if (match.teamA.name.toLowerCase().contains(normalized) ||
        normalized.contains(match.teamA.name.toLowerCase())) {
      return match.teamA;
    }

    // 3. Correspondance par couleur
    if (match.teamB.color != null &&
        (match.teamB.color!.toLowerCase().contains(normalized) ||
            normalized.contains(match.teamB.color!.toLowerCase()))) {
      return match.teamB;
    }
    if (match.teamA.color != null &&
        (match.teamA.color!.toLowerCase().contains(normalized) ||
            normalized.contains(match.teamA.color!.toLowerCase()))) {
      return match.teamA;
    }

    // 4. Mots-clés relatifs (Équipe 2, Bleu, Extérieur, Eux...)
    const teamBKeywords = [
      'b',
      '2',
      'deux',
      'deuxième',
      'deuxieme',
      'bleu',
      'bleue',
      'bleus',
      'bleues',
      'extérieur',
      'exterieur',
      'visiteur',
      'visiteurs',
      'eux',
      'les autres',
      'droite',
    ];
    for (final kw in teamBKeywords) {
      if (normalized == kw ||
          normalized.contains('équipe $kw') ||
          normalized.contains('equipe $kw')) {
        return match.teamB;
      }
    }

    // 5. Mots-clés relatifs (Équipe 1, Rouge, Domicile, Nous...)
    const teamAKeywords = [
      'a',
      '1',
      'un',
      'première',
      'premiere',
      'premier',
      'rouge',
      'rouges',
      'domicile',
      'nous',
      'les nôtres',
      'les notres',
      'gauche',
    ];
    for (final kw in teamAKeywords) {
      if (normalized == kw ||
          normalized.contains('équipe $kw') ||
          normalized.contains('equipe $kw')) {
        return match.teamA;
      }
    }

    return match.teamA; // Fallback par défaut sur l'équipe A
  }

  /// Crée un [GameEvent] concret à partir d'une commande parsée.
  GameEvent _buildEvent({
    required String id,
    required ParsedVoiceCommand parsed,
    required String teamId,
    required int minute,
    required DateTime timestamp,
    required GameMatch match,
  }) {
    final normScorer = _normalizePlayerName(parsed.playerName, teamId, match);
    final normAssist = _normalizePlayerName(parsed.secondaryPlayerName, teamId, match);

    return switch (parsed.type) {
      GameEventType.goal => GoalEvent(
          id: id,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          scorerName: normScorer,
          assistName: normAssist,
          isPenalty: parsed.isPenalty,
          points: parsed.points ?? 1,
        ),
      GameEventType.yellowCard || GameEventType.redCard => CardEvent(
          id: id,
          type: parsed.type,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          playerName: normScorer,
        ),
      GameEventType.foul => FoulEvent(
          id: id,
          teamId: teamId,
          minute: minute,
          timestamp: timestamp,
          playerName: normScorer,
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
          playerOutName: normScorer,
          playerInName: normAssist,
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

  /// Normalise le nom d'un joueur en le rattachant au nom exact enregistré dans le match si trouvé.
  String? _normalizePlayerName(String? name, String teamId, GameMatch match) {
    if (name == null || name.trim().isEmpty) return null;
    final clean = name.trim().toLowerCase();

    // Recherche d'abord dans l'équipe concernée
    final team = match.teamById(teamId);
    if (team != null) {
      for (final p in team.players) {
        if (p.name.toLowerCase() == clean ||
            p.name.toLowerCase().contains(clean) ||
            clean.contains(p.name.toLowerCase())) {
          return p.name;
        }
      }
    }

    // Recherche dans l'autre équipe
    final otherTeam = teamId == match.teamA.id ? match.teamB : match.teamA;
    for (final p in otherTeam.players) {
      if (p.name.toLowerCase() == clean ||
          p.name.toLowerCase().contains(clean) ||
          clean.contains(p.name.toLowerCase())) {
        return p.name;
      }
    }

    return name.trim();
  }
}
