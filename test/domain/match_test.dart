import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';

void main() {
  group('Team', () {
    test('toMap and fromMap are symmetric', () {
      const team = Team(
        id: 'team-1',
        name: 'Équipe Rouge',
        color: 'rouge',
        players: [Player(id: 'p1', name: 'Cédric', number: 10)],
      );

      final map = team.toMap();
      final restored = Team.fromMap(map);

      expect(restored.id, team.id);
      expect(restored.name, team.name);
      expect(restored.color, team.color);
      expect(restored.players.length, 1);
      expect(restored.players.first.name, 'Cédric');
    });
  });

  group('GameMatch', () {
    late GameMatch match;
    late Team teamA;
    late Team teamB;

    setUp(() {
      teamA = const Team(id: 'ta', name: 'Rouge', color: 'rouge');
      teamB = const Team(id: 'tb', name: 'Bleu', color: 'bleu');
      match = GameMatch(
        id: 'match-1',
        sport: SportType.football,
        teamA: teamA,
        teamB: teamB,
        status: GameMatchStatus.live,
        scoreA: 2,
        scoreB: 1,
        startTime: DateTime.now().subtract(const Duration(minutes: 45)),
        durationMinutes: 90,
      );
    });

    test('teamById returns correct team', () {
      expect(match.teamById('ta'), teamA);
      expect(match.teamById('tb'), teamB);
      expect(match.teamById('xx'), isNull);
    });

    test('currentMinute is within bounds', () {
      expect(match.currentMinute, greaterThanOrEqualTo(44));
      expect(match.currentMinute, lessThanOrEqualTo(90));
    });

    test('toMap and fromMap are symmetric with breakDurationMinutes', () {
      final matchWithBreak = match.copyWith(breakDurationMinutes: 45);
      final map = matchWithBreak.toMap();
      final restored = GameMatch.fromMap(map);
      expect(restored.id, matchWithBreak.id);
      expect(restored.scoreA, matchWithBreak.scoreA);
      expect(restored.scoreB, matchWithBreak.scoreB);
      expect(restored.sport, matchWithBreak.sport);
      expect(restored.durationMinutes, 90);
      expect(restored.breakDurationMinutes, 45);
    });

    test('copyWith updates only specified fields', () {
      final updated = match.copyWith(
        scoreA: 3,
        status: GameMatchStatus.finished,
        breakDurationMinutes: 40,
      );
      expect(updated.scoreA, 3);
      expect(updated.scoreB, match.scoreB);
      expect(updated.status, GameMatchStatus.finished);
      expect(updated.id, match.id);
      expect(updated.breakDurationMinutes, 40);
    });
  });

  group('SportType', () {
    test('football has correct events', () {
      final events = SportType.football.availableEvents;
      expect(events, contains(GameEventType.goal));
      expect(events, contains(GameEventType.yellowCard));
      expect(events, contains(GameEventType.redCard));
    });

    test('basketball has freeThrow', () {
      final events = SportType.basketball.availableEvents;
      expect(events, contains(GameEventType.freeThrow));
    });

    test('football duration is 90 minutes', () {
      expect(SportType.football.matchDurationMinutes, 90);
    });
  });
}
