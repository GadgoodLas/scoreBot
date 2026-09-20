import 'package:score_bot/data/services/gemini_service.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';

/// Parseur de commandes vocales hors-ligne et sans IA.
/// Utilise des règles déterministes et des expressions régulières pour analyser
/// instantanément (< 1 ms) le texte produit par la reconnaissance vocale locale.
class OfflineVoiceCommandParser {
  const OfflineVoiceCommandParser();

  /// Parse un texte de commande vocale en un `ParsedVoiceCommand` structuré.
  ParsedVoiceCommand parse({
    required String rawText,
    required GameMatch match,
  }) {
    final text = rawText.trim();
    final norm = _normalize(text);

    if (norm.isEmpty) {
      return ParsedVoiceCommand(
        transcription: text,
        type: GameEventType.unknown,
        teamName: '',
      );
    }

    // 1. ─── CONTRÔLE DU MATCH (Chrono & Périodes) ───
    final matchControl = _detectMatchControl(norm);
    if (matchControl != null) {
      return ParsedVoiceCommand(
        transcription: text,
        type: GameEventType.unknown,
        teamName: '',
        matchControl: matchControl,
      );
    }

    // 2. ─── CORRECTION / ANNULATION ───
    if (_isCorrection(norm)) {
      return ParsedVoiceCommand(
        transcription: text,
        type: GameEventType.correction,
        teamName: '',
        correctionAction: 'undo_last',
      );
    }

    // 3. ─── CARTONS ───
    final cardEvent = _detectCardEvent(text, norm, match);
    if (cardEvent != null) {
      return cardEvent;
    }

    // 4. ─── FAUTES ───
    final foulEvent = _detectFoulEvent(text, norm, match);
    if (foulEvent != null) {
      return foulEvent;
    }

    // 5. ─── BUTS & POINTS ───
    final goalEvent = _detectGoalEvent(text, norm, match);
    if (goalEvent != null) {
      return goalEvent;
    }

    // 6. Aucun événement reconnu
    return ParsedVoiceCommand(
      transcription: text,
      type: GameEventType.unknown,
      teamName: '',
    );
  }

  // ─────────────── DÉTECTION CONTRÔLE ───────────────

  String? _detectMatchControl(String norm) {
    // Pause
    if (norm == 'pause' ||
        norm.contains('en pause') ||
        norm.contains('temps mort') ||
        norm.contains('timeout') ||
        norm.contains('time out') ||
        norm.contains('arrete le chrono') ||
        norm.contains('stop the clock') ||
        norm.contains('arret de jeu') ||
        norm == 'stop') {
      return 'pause';
    }

    // Reprise
    if (norm == 'reprends' ||
        norm == 'reprendre' ||
        norm == 'resume' ||
        norm == 'play' ||
        norm == 'relance' ||
        norm.contains('c est reparti') ||
        norm.contains('reparti') ||
        norm.contains('start again') ||
        norm == 'continue') {
      return 'resume';
    }

    // Mi-temps
    if (norm.contains('mi temps') ||
        norm.contains('mitemps') ||
        norm.contains('half time') ||
        norm.contains('halftime')) {
      return 'halftime';
    }

    // Fin du match
    if (norm.contains('fin du match') ||
        norm.contains('fin de match') ||
        norm.contains('end match') ||
        norm.contains('end game') ||
        norm.contains('finish match') ||
        norm.contains('game over') ||
        norm.contains('termine') ||
        norm.contains('sifflet final') ||
        norm.contains('final whistle')) {
      return 'end_match';
    }

    return null;
  }

  // ─────────────── DÉTECTION CORRECTION ───────────────

  bool _isCorrection(String norm) {
    return norm.contains('annule') ||
        norm.contains('annuler') ||
        norm.contains('undo') ||
        norm.contains('cancel') ||
        norm.contains('pas but') ||
        norm.contains('no goal') ||
        norm.contains('erreur') ||
        norm.contains('mistake') ||
        norm.contains('retour en arriere') ||
        norm.contains('take back');
  }

  // ─────────────── DÉTECTION CARTONS ───────────────

  ParsedVoiceCommand? _detectCardEvent(String text, String norm, GameMatch match) {
    final isYellow = norm.contains('jaune') || norm.contains('yellow');
    final isRed = (norm.contains('rouge') || norm.contains('red card') || norm.contains('red')) &&
        !norm.contains('equipe rouge') &&
        !norm.contains('les rouges') &&
        !norm.contains('red team');

    if (!isYellow && !isRed) return null;

    final type = isYellow ? GameEventType.yellowCard : GameEventType.redCard;
    // Ignorer les couleurs pour l'équipe car "jaune"/"rouge" désigne le carton
    final (team, player) = _resolveTeamAndPlayer(
      norm,
      match,
      ignoreColors: true,
      allowGenericCandidate: true,
    );

    return ParsedVoiceCommand(
      transcription: text,
      type: type,
      teamName: team ?? match.teamA.name,
      playerName: player,
    );
  }

  // ─────────────── DÉTECTION FAUTES ───────────────

  ParsedVoiceCommand? _detectFoulEvent(String text, String norm, GameMatch match) {
    final isFoul = norm.contains('faute') || norm.contains('foul');
    final isPenalty = norm.contains('penalty') || norm.contains('penaltie');

    if (!isFoul && !isPenalty) return null;

    final (team, player) = _resolveTeamAndPlayer(
      norm,
      match,
      allowGenericCandidate: true,
    );

    return ParsedVoiceCommand(
      transcription: text,
      type: GameEventType.foul,
      teamName: team ?? match.teamA.name,
      playerName: player,
      isPenalty: isPenalty,
    );
  }

  // ─────────────── DÉTECTION BUTS & POINTS ───────────────

  ParsedVoiceCommand? _detectGoalEvent(String text, String norm, GameMatch match) {
    final isGoalKeyword = norm.contains('but') ||
        norm.contains('goal') ||
        norm.contains('panier') ||
        norm.contains('basket') ||
        norm.contains('essai') ||
        norm.contains('try') ||
        norm.contains('touchdown') ||
        norm.contains('point') ||
        norm.contains('score') ||
        norm.contains('scores') ||
        norm.contains('scored') ||
        norm.contains('marque') ||
        norm.contains('marquer') ||
        norm.contains('plus un') ||
        norm.contains('plus one') ||
        norm.contains('+1') ||
        norm.contains('un zero') ||
        norm.contains('1-0') ||
        norm.contains('deux un') ||
        norm.contains('2-1');

    // N'extraire un candidat générique ("par X" ou "de X" ou "by X") que si un mot clé de but est présent
    final (team, scorer) = _resolveTeamAndPlayer(
      norm,
      match,
      allowGenericCandidate: isGoalKeyword,
    );
    final assist = _detectAssist(norm, match, excludePlayer: scorer);
    final points = _detectPoints(norm);

    // Si un buteur ou un mot-clé de but/point est présent
    if (isGoalKeyword || scorer != null) {
      final finalTeam = team ?? (scorer != null ? _findTeamForPlayer(scorer, match) : null) ?? match.teamA.name;

      return ParsedVoiceCommand(
        transcription: text,
        type: GameEventType.goal,
        teamName: finalTeam,
        playerName: scorer,
        secondaryPlayerName: assist,
        points: points,
      );
    }

    return null;
  }

  // ─────────────── EXTRACTION PASSEUR ───────────────

  String? _detectAssist(String norm, GameMatch match, {String? excludePlayer}) {
    // Patterns : "assist [nom]", "assisted by [nom]", "pass from [nom]", "passe de [nom]", "passe [nom]"
    final assistRegex = RegExp(r'(?:assisted by|assiste par|assist by|assist|pass from|passe de|passeur|passe)\s+([a-z0-9à-ÿ]+)');
    final matchRegex = assistRegex.firstMatch(norm);

    if (matchRegex != null) {
      final rawCandidate = matchRegex.group(1);
      if (rawCandidate != null) {
        // Chercher parmi les joueurs enregistrés
        for (final p in [...match.teamA.players, ...match.teamB.players]) {
          if (_normalize(p.name) == rawCandidate || _normalize(p.name).contains(rawCandidate)) {
            if (p.name != excludePlayer) return p.name;
          }
        }
        return rawCandidate;
      }
    }

    return null;
  }

  // ─────────────── DÉTECTION DU NOMBRE DE POINTS ───────────────

  int _detectPoints(String norm) {
    if (norm.contains('3 points') || norm.contains('trois points') || norm.contains('three points')) return 3;
    if (norm.contains('2 points') || norm.contains('deux points') || norm.contains('two points')) return 2;
    return 1;
  }

  // ─────────────── RÉSOLUTION ÉQUIPE & JOUEUR ───────────────

  (String?, String?) _resolveTeamAndPlayer(
    String norm,
    GameMatch match, {
    bool ignoreColors = false,
    bool allowGenericCandidate = false,
  }) {
    String? matchedTeam;
    String? matchedPlayer;

    // 1. Chercher un joueur enregistré dans Team A
    for (final p in match.teamA.players) {
      final pNorm = _normalize(p.name);
      if (pNorm.isNotEmpty && _containsWord(norm, pNorm)) {
        matchedPlayer = p.name;
        matchedTeam = match.teamA.name;
        break;
      }
    }

    // 2. Chercher un joueur enregistré dans Team B
    if (matchedPlayer == null) {
      for (final p in match.teamB.players) {
        final pNorm = _normalize(p.name);
        if (pNorm.isNotEmpty && _containsWord(norm, pNorm)) {
          matchedPlayer = p.name;
          matchedTeam = match.teamB.name;
          break;
        }
      }
    }

    // 3. Détection d'équipe explicite si non déjà déduite
    if (matchedTeam == null) {
      final teamANorm = _normalize(match.teamA.name);
      final teamBNorm = _normalize(match.teamB.name);

      final isExplicitTeamA = _containsWord(norm, 'equipe a') ||
          _containsWord(norm, 'team a') ||
          _containsWord(norm, 'equipe 1') ||
          _containsWord(norm, 'team 1') ||
          (teamANorm.isNotEmpty && _containsWord(norm, teamANorm));

      final isExplicitTeamB = _containsWord(norm, 'equipe b') ||
          _containsWord(norm, 'team b') ||
          _containsWord(norm, 'equipe 2') ||
          _containsWord(norm, 'team 2') ||
          (teamBNorm.isNotEmpty && _containsWord(norm, teamBNorm));

      if (isExplicitTeamA && !isExplicitTeamB) {
        matchedTeam = match.teamA.name;
      } else if (isExplicitTeamB && !isExplicitTeamA) {
        matchedTeam = match.teamB.name;
      } else if (!ignoreColors) {
        final colorANorm = _normalize(match.teamA.color ?? '');
        final colorBNorm = _normalize(match.teamB.color ?? '');

        final isColorA = _containsColor(norm, colorANorm);
        final isColorB = _containsColor(norm, colorBNorm);

        if (isColorA && !isColorB) {
          matchedTeam = match.teamA.name;
        } else if (isColorB && !isColorA) {
          matchedTeam = match.teamB.name;
        }
      }
    }

    // 4. Si pas de joueur de l'effectif trouvé, chercher un nom générique après "par", "de", "by", "from", "for"
    if (matchedPlayer == null && allowGenericCandidate) {
      final byRegex = RegExp(r'(?:par|de|pour|by|from|for)\s+([a-zà-ÿ]+)');
      final byMatch = byRegex.firstMatch(norm);
      if (byMatch != null) {
        final candidate = byMatch.group(1);
        // Ne pas prendre les mots de liaison / stopwords
        const stopWords = [
          'equipe', 'team', 'les', 'le', 'la', 'un', 'une', 'des', 'the', 'a', 'an',
          'ce', 'mon', 'son', 'qui', 'est', 'il', 'elle', 'nous', 'vous', 'ils', 'elles',
          'match', 'game'
        ];
        if (candidate != null && !stopWords.contains(candidate)) {
          matchedPlayer = candidate[0].toUpperCase() + candidate.substring(1);
        }
      }
    }

    return (matchedTeam, matchedPlayer);
  }

  bool _containsColor(String text, String color) {
    if (color.isEmpty) return false;
    if (_containsWord(text, color)) return true;
    final plural = color.endsWith('s') ? color : '${color}s';
    if (_containsWord(text, plural)) return true;
    return false;
  }

  String? _findTeamForPlayer(String playerName, GameMatch match) {
    final norm = _normalize(playerName);
    for (final p in match.teamA.players) {
      if (_normalize(p.name) == norm) return match.teamA.name;
    }
    for (final p in match.teamB.players) {
      if (_normalize(p.name) == norm) return match.teamB.name;
    }
    return null;
  }

  // ─────────────── UTILITAIRES DE TEXTE ───────────────

  /// Vérifie si la phrase contient le mot ou l'expression comme mot entier.
  bool _containsWord(String text, String word) {
    if (text == word) return true;
    final regex = RegExp('(^|\\s)${RegExp.escape(word)}(\\s|\$|[.,;!?])');
    return regex.hasMatch(text);
  }

  /// Nettoie et normalise une chaîne : minuscules, suppression des accents et ponctuation.
  static String _normalize(String input) {
    var str = input.toLowerCase();

    const withAccents = 'àáâãäåèéêëìíîïòóôõöùúûüýçñ';
    const withoutAccents = 'aaaaaaeeeeiiiiooooouuuuycn';

    for (int i = 0; i < withAccents.length; i++) {
      str = str.replaceAll(withAccents[i], withoutAccents[i]);
    }

    // Remplacer la ponctuation par des espaces
    str = str.replaceAll(RegExp(r"['\-_.,;:!?\(\)\[\]]"), ' ');
    // Nettoyer les espaces multiples
    str = str.replaceAll(RegExp(r'\s+'), ' ').trim();

    return str;
  }
}
