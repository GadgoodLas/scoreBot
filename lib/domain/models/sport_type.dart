/// Types de sports supportés par ScoreBot.
enum SportType {
  football(
    label: 'Football',
    emoji: '⚽',
    matchDurationMinutes: 90,
    hasHalftime: true,
  ),
  basketball(
    label: 'Basketball',
    emoji: '🏀',
    matchDurationMinutes: 40,
    hasHalftime: true,
  ),
  handball(
    label: 'Handball',
    emoji: '🤾',
    matchDurationMinutes: 60,
    hasHalftime: true,
  ),
  rugby(
    label: 'Rugby',
    emoji: '🏉',
    matchDurationMinutes: 80,
    hasHalftime: true,
  ),
  volleyball(
    label: 'Volleyball',
    emoji: '🏐',
    matchDurationMinutes: 0, // Par sets
    hasHalftime: false,
  ),
  custom(
    label: 'Personnalisé',
    emoji: '🏆',
    matchDurationMinutes: 90,
    hasHalftime: true,
  );

  const SportType({
    required this.label,
    required this.emoji,
    required this.matchDurationMinutes,
    required this.hasHalftime,
  });

  /// Nom affiché dans l'interface.
  final String label;

  /// Emoji représentant le sport.
  final String emoji;

  /// Durée standard d'un match en minutes (0 = par sets/manches).
  final int matchDurationMinutes;

  /// Indique si le match comporte une mi-temps.
  final bool hasHalftime;

  /// Liste des événements disponibles pour ce sport.
  List<GameEventType> get availableEvents {
    switch (this) {
      case SportType.football:
        return [
          GameEventType.goal,
          GameEventType.assist,
          GameEventType.yellowCard,
          GameEventType.redCard,
          GameEventType.foul,
          GameEventType.substitution,
          GameEventType.cornerKick,
          GameEventType.penalty,
        ];
      case SportType.basketball:
        return [
          GameEventType.goal, // Panier
          GameEventType.freeThrow,
          GameEventType.foul,
          GameEventType.timeout,
          GameEventType.substitution,
        ];
      case SportType.handball:
        return [
          GameEventType.goal,
          GameEventType.assist,
          GameEventType.yellowCard,
          GameEventType.redCard,
          GameEventType.foul,
          GameEventType.timeout,
          GameEventType.penalty,
          GameEventType.substitution,
        ];
      case SportType.rugby:
        return [
          GameEventType.goal, // Essai
          GameEventType.assist,
          GameEventType.yellowCard,
          GameEventType.redCard,
          GameEventType.foul,
          GameEventType.penalty,
        ];
      case SportType.volleyball:
      case SportType.custom:
        return GameEventType.values;
    }
  }
}

/// Tous les types d'événements possibles dans un match.
enum GameEventType {
  goal(label: 'But', emoji: '⚽'),
  assist(label: 'Passe décisive', emoji: '🅰️'),
  yellowCard(label: 'Carton jaune', emoji: '🟨'),
  redCard(label: 'Carton rouge', emoji: '🟥'),
  foul(label: 'Faute', emoji: '⚠️'),
  timeout(label: 'Temps mort', emoji: '⏸️'),
  substitution(label: 'Remplacement', emoji: '🔄'),
  cornerKick(label: 'Corner', emoji: '🚩'),
  penalty(label: 'Pénalty', emoji: '🎯'),
  freeThrow(label: 'Lancer franc', emoji: '🏀'),
  correction(label: 'Correction', emoji: '↩️'),
  unknown(label: 'Inconnu', emoji: '❓');

  const GameEventType({required this.label, required this.emoji});

  final String label;
  final String emoji;
}

