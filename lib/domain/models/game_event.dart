import 'package:equatable/equatable.dart';
import 'sport_type.dart';

/// Événement sportif enregistré pendant un match.
/// Utilise un sealed class pour garantir l'exhaustivité du pattern matching.
sealed class GameEvent extends Equatable {
  const GameEvent({
    required this.id,
    required this.type,
    required this.teamId,
    required this.minute,
    required this.timestamp,
  });

  final String id;
  final GameEventType type;
  final String teamId; // ID de l'équipe concernée
  final int minute; // Minute du match
  final DateTime timestamp;

  @override
  List<Object?> get props => [id, type, teamId, minute, timestamp];

  Map<String, dynamic> toMap();

  factory GameEvent.fromMap(Map<String, dynamic> map) {
    final type = GameEventType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => GameEventType.unknown,
    );

    return switch (type) {
      GameEventType.goal => GoalEvent.fromMap(map),
      GameEventType.yellowCard => CardEvent.fromMap(map),
      GameEventType.redCard => CardEvent.fromMap(map),
      GameEventType.foul => FoulEvent.fromMap(map),
      GameEventType.timeout => TimeoutEvent.fromMap(map),
      GameEventType.substitution => SubstitutionEvent.fromMap(map),
      GameEventType.correction => CorrectionEvent.fromMap(map),
      _ => GenericEvent.fromMap(map),
    };
  }
}

/// But / Panier / Essai — événement de score principal.
class GoalEvent extends GameEvent {
  const GoalEvent({
    required super.id,
    required super.teamId,
    required super.minute,
    required super.timestamp,
    this.scorerName,
    this.assistName,
    this.isPenalty = false,
    this.points = 1,
  }) : super(type: GameEventType.goal);

  final String? scorerName;
  final String? assistName;
  final bool isPenalty;
  final int points; // 1 but foot, 2 ou 3 points basket, 5 essai rugby...

  @override
  List<Object?> get props => [
    ...super.props,
    scorerName,
    assistName,
    isPenalty,
    points,
  ];

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'teamId': teamId,
    'minute': minute,
    'timestamp': timestamp.toIso8601String(),
    'scorerName': scorerName,
    'assistName': assistName,
    'isPenalty': isPenalty,
    'points': points,
  };

  factory GoalEvent.fromMap(Map<String, dynamic> map) => GoalEvent(
    id: map['id'] as String,
    teamId: map['teamId'] as String,
    minute: map['minute'] as int,
    timestamp: DateTime.parse(map['timestamp'] as String),
    scorerName: map['scorerName'] as String?,
    assistName: map['assistName'] as String?,
    isPenalty: map['isPenalty'] as bool? ?? false,
    points: map['points'] as int? ?? 1,
  );
}

/// Carton jaune ou rouge.
class CardEvent extends GameEvent {
  const CardEvent({
    required super.id,
    required super.type,
    required super.teamId,
    required super.minute,
    required super.timestamp,
    this.playerName,
    this.reason,
  }) : assert(
         type == GameEventType.yellowCard || type == GameEventType.redCard,
       );

  final String? playerName;
  final String? reason;

  @override
  List<Object?> get props => [...super.props, playerName, reason];

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'teamId': teamId,
    'minute': minute,
    'timestamp': timestamp.toIso8601String(),
    'playerName': playerName,
    'reason': reason,
  };

  factory CardEvent.fromMap(Map<String, dynamic> map) => CardEvent(
    id: map['id'] as String,
    type: GameEventType.values.firstWhere((t) => t.name == map['type']),
    teamId: map['teamId'] as String,
    minute: map['minute'] as int,
    timestamp: DateTime.parse(map['timestamp'] as String),
    playerName: map['playerName'] as String?,
    reason: map['reason'] as String?,
  );
}

/// Faute.
class FoulEvent extends GameEvent {
  const FoulEvent({
    required super.id,
    required super.teamId,
    required super.minute,
    required super.timestamp,
    this.playerName,
  }) : super(type: GameEventType.foul);

  final String? playerName;

  @override
  List<Object?> get props => [...super.props, playerName];

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'teamId': teamId,
    'minute': minute,
    'timestamp': timestamp.toIso8601String(),
    'playerName': playerName,
  };

  factory FoulEvent.fromMap(Map<String, dynamic> map) => FoulEvent(
    id: map['id'] as String,
    teamId: map['teamId'] as String,
    minute: map['minute'] as int,
    timestamp: DateTime.parse(map['timestamp'] as String),
    playerName: map['playerName'] as String?,
  );
}

/// Temps mort.
class TimeoutEvent extends GameEvent {
  const TimeoutEvent({
    required super.id,
    required super.teamId,
    required super.minute,
    required super.timestamp,
  }) : super(type: GameEventType.timeout);

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'teamId': teamId,
    'minute': minute,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TimeoutEvent.fromMap(Map<String, dynamic> map) => TimeoutEvent(
    id: map['id'] as String,
    teamId: map['teamId'] as String,
    minute: map['minute'] as int,
    timestamp: DateTime.parse(map['timestamp'] as String),
  );
}

/// Remplacement de joueur.
class SubstitutionEvent extends GameEvent {
  const SubstitutionEvent({
    required super.id,
    required super.teamId,
    required super.minute,
    required super.timestamp,
    this.playerOutName,
    this.playerInName,
  }) : super(type: GameEventType.substitution);

  final String? playerOutName;
  final String? playerInName;

  @override
  List<Object?> get props => [...super.props, playerOutName, playerInName];

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'teamId': teamId,
    'minute': minute,
    'timestamp': timestamp.toIso8601String(),
    'playerOutName': playerOutName,
    'playerInName': playerInName,
  };

  factory SubstitutionEvent.fromMap(Map<String, dynamic> map) =>
      SubstitutionEvent(
        id: map['id'] as String,
        teamId: map['teamId'] as String,
        minute: map['minute'] as int,
        timestamp: DateTime.parse(map['timestamp'] as String),
        playerOutName: map['playerOutName'] as String?,
        playerInName: map['playerInName'] as String?,
      );
}

/// Correction / annulation d'un événement précédent.
class CorrectionEvent extends GameEvent {
  const CorrectionEvent({
    required super.id,
    required super.teamId,
    required super.minute,
    required super.timestamp,
    required this.action,
    this.targetEventId,
  }) : super(type: GameEventType.correction);

  /// 'undo_last' ou ID d'un événement spécifique à annuler.
  final String action;
  final String? targetEventId;

  @override
  List<Object?> get props => [...super.props, action, targetEventId];

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'teamId': teamId,
    'minute': minute,
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'targetEventId': targetEventId,
  };

  factory CorrectionEvent.fromMap(Map<String, dynamic> map) => CorrectionEvent(
    id: map['id'] as String,
    teamId: map['teamId'] as String,
    minute: map['minute'] as int,
    timestamp: DateTime.parse(map['timestamp'] as String),
    action: map['action'] as String? ?? 'undo_last',
    targetEventId: map['targetEventId'] as String?,
  );
}

/// Événement générique pour les types non structurés.
class GenericEvent extends GameEvent {
  const GenericEvent({
    required super.id,
    required super.type,
    required super.teamId,
    required super.minute,
    required super.timestamp,
    this.notes,
  });

  final String? notes;

  @override
  List<Object?> get props => [...super.props, notes];

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'teamId': teamId,
    'minute': minute,
    'timestamp': timestamp.toIso8601String(),
    'notes': notes,
  };

  factory GenericEvent.fromMap(Map<String, dynamic> map) => GenericEvent(
    id: map['id'] as String,
    type: GameEventType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => GameEventType.unknown,
    ),
    teamId: map['teamId'] as String,
    minute: map['minute'] as int,
    timestamp: DateTime.parse(map['timestamp'] as String),
    notes: map['notes'] as String?,
  );
}
