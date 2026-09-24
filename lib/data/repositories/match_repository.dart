import 'package:uuid/uuid.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/services/audio_service.dart';
import 'package:score_bot/data/services/gemini_service.dart';
import 'package:score_bot/data/services/local_speech_service.dart';
import 'package:score_bot/data/services/offline_voice_command_parser.dart';
import 'package:score_bot/data/services/storage_service.dart';

/// Résultat d'une commande vocale traitée.
class VoiceCommandResult {
  const VoiceCommandResult({
    required this.transcription,
    this.event,
    this.matchControl,
    this.errorMessage,
  });

  /// Texte transcrit par Gemini ou la reconnaissance locale.
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
/// Orchestre les services Audio, Gemini, Local Speech et Storage.
class MatchRepository {
  MatchRepository({
    required AudioService audioService,
    required GeminiService geminiService,
    required StorageService storageService,
    LocalSpeechService? localSpeechService,
    OfflineVoiceCommandParser? offlineParser,
  }) : _audio = audioService,
       _gemini = geminiService,
       _storage = storageService,
       _localSpeech = localSpeechService ?? LocalSpeechService(),
       _offlineParser = offlineParser ?? const OfflineVoiceCommandParser();

  final AudioService _audio;
  final GeminiService _gemini;
  final StorageService _storage;
  final LocalSpeechService _localSpeech;
  final OfflineVoiceCommandParser _offlineParser;
  final _uuid = const Uuid();

  String _lastLocalTranscription = '';

  // ─────────────── AI & SETTINGS ───────────────

  String get apiKey => _gemini.apiKey;
  String get aiModel => _gemini.preferredModel;
  bool get isAiConfigured => _gemini.isConfigured;
  bool get hasSeenAiOnboarding => _storage.hasSeenAiOnboarding();
  String get voiceEngine => _storage.getVoiceEngine();
  bool get isLocalVoiceMode => _storage.isLocalVoiceMode;
  bool get isVoiceReady => isLocalVoiceMode || isAiConfigured;
  String get languageCode => _storage.getLanguageCode();

  /// Définit la langue active ('en' ou 'fr').
  Future<void> setLanguageCode(String code) async {
    await _storage.saveLanguageCode(code);
  }

  /// Définit le moteur vocal actif ('local' ou 'gemini').
  Future<void> setVoiceEngine(String engine) async {
    await _storage.saveVoiceEngine(engine);
  }

  /// Enregistre la configuration IA (clé API et modèle).
  Future<void> saveAiConfig({
    required String apiKey,
    required String model,
    String? voiceEngine,
  }) async {
    await _storage.saveApiKey(apiKey);
    await _storage.saveAiModel(model);
    if (voiceEngine != null) {
      await _storage.saveVoiceEngine(voiceEngine);
    } else if (apiKey.isNotEmpty) {
      await _storage.saveVoiceEngine('gemini');
    }
    await _storage.setAiOnboardingSeen(true);
    _gemini.updateConfig(apiKey: apiKey, preferredModel: model);
  }

  /// Marque l'invite d'onboarding IA comme vue.
  Future<void> dismissAiOnboarding() async {
    await _storage.setAiOnboardingSeen(true);
  }

  /// Teste la connexion à l'API Gemini avec la clé et le modèle donnés.
  Future<bool> testAiConnection({
    required String apiKey,
    required String model,
  }) async {
    return GeminiService.validateApiKey(apiKey: apiKey, model: model);
  }

  // ─────────────── MATCH LIFECYCLE ───────────────

  /// Crée et démarre un nouveau match.
  Future<GameMatch> createMatch({
    required SportType sport,
    required Team teamA,
    required Team teamB,
    int? durationMinutes,
    int? breakDurationMinutes,
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
      breakDurationMinutes: breakDurationMinutes,
    );

    await _storage.saveMatch(match);
    return match;
  }

  /// Pause / reprend le match.
  Future<GameMatch> togglePause(GameMatch match) async {
    final newStatus =
        match.status == GameMatchStatus.live
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

  /// Génère un compte-rendu textuel complet du match.
  /// Utilise Gemini si configuré et actif, sinon génère un rapport local soigné.
  Future<String> generateMatchReport(GameMatch match) async {
    final events = getEvents(match.id);

    if (!isLocalVoiceMode && isAiConfigured) {
      try {
        return await _gemini.generateMatchReport(
          match: match,
          events: events,
          language: languageCode,
        );
      } catch (_) {
        // Fallback transparent sur le générateur local
      }
    }

    return _generateLocalMatchReport(match, events);
  }

  /// Générateur déterministe hors-ligne d'un compte-rendu journalistique de match.
  String _generateLocalMatchReport(GameMatch match, List<GameEvent> events) {
    final isFrench = languageCode == 'fr';
    final buf = StringBuffer();

    // Titre & Épilogue
    final winnerText =
        isFrench
            ? (match.scoreA > match.scoreB
                ? '🏆 Victoire de ${match.teamA.name} face à ${match.teamB.name} !'
                : (match.scoreB > match.scoreA
                    ? '🏆 Victoire de ${match.teamB.name} face à ${match.teamA.name} !'
                    : '🤝 Match nul entre ${match.teamA.name} et ${match.teamB.name} !'))
            : (match.scoreA > match.scoreB
                ? '🏆 Victory for ${match.teamA.name} against ${match.teamB.name}!'
                : (match.scoreB > match.scoreA
                    ? '🏆 Victory for ${match.teamB.name} against ${match.teamA.name}!'
                    : '🤝 Draw between ${match.teamA.name} and ${match.teamB.name}!'));

    buf.writeln(winnerText);
    buf.writeln('');
    buf.writeln(
      isFrench
          ? 'Au terme d\'une confrontation disputée de ${match.sport.label}, '
              '${match.teamA.name} et ${match.teamB.name} se quittent sur le score final de '
              '${match.scoreA} à ${match.scoreB}.'
          : 'At the end of a hard-fought ${match.sport.label} game, '
              '${match.teamA.name} and ${match.teamB.name} finish with a final score of '
              '${match.scoreA} - ${match.scoreB}.',
    );
    buf.writeln('');

    // Faits saillants chronologiques
    final goals = events.whereType<GoalEvent>().toList();
    final cards = events.whereType<CardEvent>().toList();
    final fouls = events.whereType<FoulEvent>().toList();

    buf.writeln(
      isFrench
          ? '⏱️ Faits marquants de la rencontre :'
          : '⏱️ Match Highlights:',
    );
    if (events.isEmpty) {
      buf.writeln(
        isFrench
            ? '• Match calme sans incident ni but notable.'
            : '• Quiet match with no notable incidents.',
      );
    } else {
      for (final e in events) {
        final team =
            e.teamId == match.teamA.id ? match.teamA.name : match.teamB.name;
        if (e is GoalEvent) {
          final scorer = e.scorerName ?? (isFrench ? 'But' : 'Goal');
          final assist =
              e.assistName != null
                  ? (isFrench
                      ? ' (passe décisive : ${e.assistName})'
                      : ' (assist: ${e.assistName})')
                  : '';
          buf.writeln(
            isFrench
                ? '• ${e.minute}\' : ⚽ $scorer fait trembler les filets pour $team$assist.'
                : '• ${e.minute}\' : ⚽ $scorer scores for $team$assist.',
          );
        } else if (e is CardEvent) {
          final player = e.playerName ?? (isFrench ? 'Un joueur' : 'A player');
          final cardType =
              e.type == GameEventType.yellowCard
                  ? (isFrench ? '🟨 Carton jaune' : '🟨 Yellow card')
                  : (isFrench ? '🟥 Carton rouge' : '🟥 Red card');
          buf.writeln(
            isFrench
                ? '• ${e.minute}\' : $cardType adressé à $player ($team).'
                : '• ${e.minute}\' : $cardType given to $player ($team).',
          );
        } else if (e is FoulEvent) {
          buf.writeln(
            isFrench
                ? '• ${e.minute}\' : ⚠️ Faute signalée pour ${e.playerName ?? "un joueur"} ($team).'
                : '• ${e.minute}\' : ⚠️ Foul called on ${e.playerName ?? "a player"} ($team).',
          );
        }
      }
    }
    buf.writeln('');

    // Buteurs et performances individuelles
    final scorerCounts = <String, int>{};
    final assistCounts = <String, int>{};
    for (final g in goals) {
      if (g.scorerName != null && g.scorerName!.isNotEmpty) {
        scorerCounts[g.scorerName!] =
            (scorerCounts[g.scorerName!] ?? 0) + g.points;
      }
      if (g.assistName != null && g.assistName!.isNotEmpty) {
        assistCounts[g.assistName!] = (assistCounts[g.assistName!] ?? 0) + 1;
      }
    }

    buf.writeln(
      isFrench
          ? '⭐ Distinctions & statistiques clés :'
          : '⭐ Key Awards & Statistics:',
    );
    if (scorerCounts.isNotEmpty) {
      final bestScorer =
          (scorerCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;
      buf.writeln(
        isFrench
            ? '• Homme du match : ${bestScorer.key} avec ${bestScorer.value} réalisation(s).'
            : '• Player of the match: ${bestScorer.key} with ${bestScorer.value} point(s).',
      );
    }
    if (assistCounts.isNotEmpty) {
      final bestAssister =
          (assistCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;
      buf.writeln(
        isFrench
            ? '• Meilleur passeur : ${bestAssister.key} (${bestAssister.value} passe(s)).'
            : '• Top playmaker: ${bestAssister.key} (${bestAssister.value} assist(s)).',
      );
    }
    if (cards.isNotEmpty || fouls.isNotEmpty) {
      buf.writeln(
        isFrench
            ? '• Bilan arbitral : ${cards.length} carton(s) et ${fouls.length} faute(s) signalée(s).'
            : '• Disciplinary summary: ${cards.length} card(s) and ${fouls.length} foul(s).',
      );
    }

    return buf.toString();
  }

  // ─────────────── VOICE COMMANDS ───────────────

  /// Démarre l'enregistrement ou l'écoute d'une commande vocale.
  Future<void> startVoiceCommand() async {
    if (isLocalVoiceMode) {
      _lastLocalTranscription = '';
      await _localSpeech.startListening(
        localeId: languageCode == 'fr' ? 'fr_FR' : 'en_US',
        onResult: (words, isFinal) {
          _lastLocalTranscription = words;
        },
      );
    } else {
      await _audio.startRecording();
    }
  }

  /// Annule l'enregistrement en cours sans traiter.
  Future<void> cancelVoiceCommand() async {
    if (isLocalVoiceMode) {
      await _localSpeech.cancelListening();
      _lastLocalTranscription = '';
    } else {
      await _audio.cancelRecording();
    }
  }

  /// Arrête l'écoute/enregistrement, parse la commande (via moteur local ou Gemini)
  /// et crée l'événement de match.
  Future<VoiceCommandResult> stopAndProcessVoiceCommand(GameMatch match) async {
    // ─── Mode Local (Sans IA / Hors-ligne) ───
    if (isLocalVoiceMode) {
      try {
        await _localSpeech.stopListening();
        // Légère attente pour s'assurer de recevoir les derniers mots de l'OS
        await Future.delayed(const Duration(milliseconds: 200));

        final text = _lastLocalTranscription.trim();
        if (text.isEmpty) {
          return const VoiceCommandResult(
            transcription: '',
            errorMessage: 'Aucune parole claire détectée. Réessayez.',
          );
        }

        final parsed = _offlineParser.parse(rawText: text, match: match);
        return _processParsedCommand(
          parsed: parsed,
          match: match,
          fallbackTranscription: text,
        );
      } catch (e) {
        return VoiceCommandResult(
          transcription: _lastLocalTranscription,
          errorMessage: 'Erreur vocale locale : $e',
        );
      }
    }

    // ─── Mode Gemini (Cloud Multimodal) ───
    try {
      // 1. Arrêter l'enregistrement et récupérer l'audio
      final audioBytes = await _audio.stopRecording();

      // 2. Traiter directement l'audio avec Gemini en une seule passe
      final parsed = await _gemini.processAudioCommand(
        audioBytes: audioBytes,
        mimeType: _audio.mimeType,
        match: match,
      );

      return _processParsedCommand(
        parsed: parsed,
        match: match,
        fallbackTranscription: 'Commande vocale',
      );
    } on AudioException catch (e) {
      return VoiceCommandResult(transcription: '', errorMessage: e.message);
    } on GeminiException catch (e) {
      return VoiceCommandResult(transcription: '', errorMessage: e.message);
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
    // Mode local (sans IA)
    if (isLocalVoiceMode) {
      final parsed = _offlineParser.parse(rawText: text, match: match);
      return _processParsedCommand(
        parsed: parsed,
        match: match,
        fallbackTranscription: text,
      );
    }

    // Mode Gemini avec fallback automatique vers parseur hors-ligne si réseau/quota indisponible
    try {
      final parsed = await _gemini.parseTextCommand(text: text, match: match);
      return _processParsedCommand(
        parsed: parsed,
        match: match,
        fallbackTranscription: text,
      );
    } on GeminiException catch (e) {
      final fallbackParsed = _offlineParser.parse(rawText: text, match: match);
      if (fallbackParsed.type != GameEventType.unknown ||
          fallbackParsed.matchControl != null) {
        return _processParsedCommand(
          parsed: fallbackParsed,
          match: match,
          fallbackTranscription: text,
        );
      }
      return VoiceCommandResult(transcription: text, errorMessage: e.message);
    } catch (e) {
      return VoiceCommandResult(
        transcription: text,
        errorMessage: 'Erreur : $e',
      );
    }
  }

  /// Factorisation du traitement d'un [ParsedVoiceCommand] (commun à Local et Gemini).
  Future<VoiceCommandResult> _processParsedCommand({
    required ParsedVoiceCommand parsed,
    required GameMatch match,
    required String fallbackTranscription,
  }) async {
    final transcription =
        parsed.transcription.isNotEmpty
            ? parsed.transcription
            : (fallbackTranscription.isNotEmpty
                ? fallbackTranscription
                : 'Commande vocale');

    if (parsed.matchControl != null) {
      return VoiceCommandResult(
        transcription: transcription,
        matchControl: parsed.matchControl,
      );
    }

    if (parsed.type == GameEventType.unknown) {
      return VoiceCommandResult(
        transcription: transcription,
        errorMessage:
            parsed.transcription.isNotEmpty
                ? 'Événement non reconnu : "${parsed.transcription}"'
                : 'Aucune parole claire détectée. Réessayez.',
      );
    }

    // Résoudre l'équipe
    final resolvedTeam = _resolveTeam(
      parsed.teamName,
      match,
      playerName: parsed.playerName,
      secondaryPlayerName: parsed.secondaryPlayerName,
    );

    // Créer l'événement
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

    return VoiceCommandResult(transcription: transcription, event: event);
  }

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
  Future<GameMatch> addPoint(
    GameMatch match,
    String teamId, {
    int points = 1,
  }) async {
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
    final normAssist = _normalizePlayerName(
      parsed.secondaryPlayerName,
      teamId,
      match,
    );

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
