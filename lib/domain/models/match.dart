import 'package:equatable/equatable.dart';
import 'package:score_bot/domain/models/sport_type.dart';

/// Représente un joueur d'une équipe.
class Player extends Equatable {
  const Player({
    required this.id,
    required this.name,
    this.number,
    this.position,
  });

  final String id;
  final String name;
  final int? number;
  final String? position;

  @override
  List<Object?> get props => [id, name, number, position];

  Player copyWith({
    String? id,
    String? name,
    int? number,
    String? position,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'number': number,
        'position': position,
      };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
        id: map['id'] as String,
        name: map['name'] as String,
        number: map['number'] as int?,
        position: map['position'] as String?,
      );

  /// Représentation courte pour les prompts Gemini.
  String get shortLabel =>
      number != null ? '#$number $name' : name;
}

/// Représente une équipe dans un match.
class Team extends Equatable {
  const Team({
    required this.id,
    required this.name,
    this.color,
    this.players = const [],
  });

  final String id;
  final String name;
  final String? color; // ex: 'rouge', 'bleue'
  final List<Player> players;

  @override
  List<Object?> get props => [id, name, color, players];

  Team copyWith({
    String? id,
    String? name,
    String? color,
    List<Player>? players,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      players: players ?? this.players,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'players': players.map((p) => p.toMap()).toList(),
      };

  factory Team.fromMap(Map<String, dynamic> map) => Team(
        id: map['id'] as String,
        name: map['name'] as String,
        color: map['color'] as String?,
        players: (map['players'] as List<dynamic>? ?? [])
            .map((p) => Player.fromMap(p as Map<String, dynamic>))
            .toList(),
      );
}

/// Statut d'un match.
enum GameMatchStatus {
  setup, // En cours de configuration
  live, // Match en cours
  halftime, // Mi-temps
  paused, // Pause
  finished, // Match terminé
}

/// Représente un match complet avec ses deux équipes.
class GameMatch extends Equatable {
  const GameMatch({
    required this.id,
    required this.sport,
    required this.teamA,
    required this.teamB,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    required this.startTime,
    this.endTime,
    this.durationMinutes = 90,
    this.breakDurationMinutes,
  });

  final String id;
  final SportType sport;
  final Team teamA;
  final Team teamB;
  final GameMatchStatus status;
  final int scoreA;
  final int scoreB;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final int? breakDurationMinutes;

  @override
  List<Object?> get props => [
        id, sport, teamA, teamB, status,
        scoreA, scoreB, startTime, endTime, durationMinutes, breakDurationMinutes,
      ];

  /// Retourne l'équipe correspondant à l'id donné.
  Team? teamById(String teamId) {
    if (teamA.id == teamId) return teamA;
    if (teamB.id == teamId) return teamB;
    return null;
  }

  /// Durée écoulée depuis le début du match.
  Duration get elapsed {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Minute actuelle du match (pour les événements).
  int get currentMinute => elapsed.inMinutes.clamp(0, durationMinutes);

  GameMatch copyWith({
    String? id,
    SportType? sport,
    Team? teamA,
    Team? teamB,
    GameMatchStatus? status,
    int? scoreA,
    int? scoreB,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    int? breakDurationMinutes,
    bool clearBreakDuration = false,
  }) {
    return GameMatch(
      id: id ?? this.id,
      sport: sport ?? this.sport,
      teamA: teamA ?? this.teamA,
      teamB: teamB ?? this.teamB,
      status: status ?? this.status,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      breakDurationMinutes: clearBreakDuration
          ? null
          : (breakDurationMinutes ?? this.breakDurationMinutes),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sport': sport.name,
        'teamA': teamA.toMap(),
        'teamB': teamB.toMap(),
        'status': status.name,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'breakDurationMinutes': breakDurationMinutes,
      };

  factory GameMatch.fromMap(Map<String, dynamic> map) => GameMatch(
        id: map['id'] as String,
        sport: SportType.values.firstWhere((s) => s.name == map['sport']),
        teamA: Team.fromMap(map['teamA'] as Map<String, dynamic>),
        teamB: Team.fromMap(map['teamB'] as Map<String, dynamic>),
        status: GameMatchStatus.values.firstWhere((s) => s.name == map['status']),
        scoreA: map['scoreA'] as int,
        scoreB: map['scoreB'] as int,
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: map['endTime'] != null
            ? DateTime.parse(map['endTime'] as String)
            : null,
        durationMinutes: map['durationMinutes'] as int? ?? 90,
        breakDurationMinutes: map['breakDurationMinutes'] as int?,
      );
}
