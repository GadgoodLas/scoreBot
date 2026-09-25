import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/data/services/offline_voice_command_parser.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';

void main() {
  late OfflineVoiceCommandParser parser;
  late GameMatch testMatch;

  setUp(() {
    parser = const OfflineVoiceCommandParser();
    testMatch = GameMatch(
      id: 'test_match_1',
      sport: SportType.football,
      teamA: const Team(
        id: 'team_a',
        name: 'Équipe A',
        color: 'Rouge',
        players: [
          Player(id: 'p1', name: 'Stéphane', number: 9),
          Player(id: 'p2', name: 'Nabil', number: 10),
        ],
      ),
      teamB: const Team(
        id: 'team_b',
        name: 'Équipe B',
        color: 'Bleu',
        players: [
          Player(id: 'p3', name: 'Cedric', number: 7),
          Player(id: 'p4', name: 'Karim', number: 11),
        ],
      ),
      status: GameMatchStatus.live,
      scoreA: 0,
      scoreB: 0,
      startTime: DateTime(2026, 1, 1, 10, 0),
    );
  });

  group('OfflineVoiceCommandParser - Contrôle du match', () {
    test('detects pause keywords', () {
      for (final phrase in [
        'pause',
        'temps mort',
        'mets en pause',
        'arrete le chrono',
        'stop',
      ]) {
        final result = parser.parse(rawText: phrase, match: testMatch);
        expect(result.matchControl, 'pause', reason: 'Failed for: $phrase');
      }
    });

    test('detects resume keywords', () {
      for (final phrase in [
        'reprends',
        'reprendre',
        'play',
        'relance',
        "c'est reparti",
      ]) {
        final result = parser.parse(rawText: phrase, match: testMatch);
        expect(result.matchControl, 'resume', reason: 'Failed for: $phrase');
      }
    });

    test('detects halftime keywords', () {
      for (final phrase in ['mi-temps', 'mi temps', 'mitemps']) {
        final result = parser.parse(rawText: phrase, match: testMatch);
        expect(result.matchControl, 'halftime', reason: 'Failed for: $phrase');
      }
    });

    test('detects end match keywords', () {
      for (final phrase in ['fin du match', 'termine', 'sifflet final']) {
        final result = parser.parse(rawText: phrase, match: testMatch);
        expect(result.matchControl, 'end_match', reason: 'Failed for: $phrase');
      }
    });
  });

  group('OfflineVoiceCommandParser - Corrections / Annulations', () {
    test('detects undo / correction keywords', () {
      for (final phrase in [
        'annule',
        'annule le but',
        'pas but',
        'erreur',
        'retour en arrière',
      ]) {
        final result = parser.parse(rawText: phrase, match: testMatch);
        expect(
          result.type,
          GameEventType.correction,
          reason: 'Failed for: $phrase',
        );
        expect(
          result.correctionAction,
          'undo_last',
          reason: 'Failed for: $phrase',
        );
      }
    });
  });

  group('OfflineVoiceCommandParser - Buts et Points', () {
    test('parses basic goal for team A', () {
      final result = parser.parse(rawText: 'but équipe A', match: testMatch);
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe A');
      expect(result.points, 1);
    });

    test('parses basic goal for team B using color', () {
      final result = parser.parse(
        rawText: 'but pour les bleus',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe B');
      expect(result.points, 1);
    });

    test('automatically assigns team from registered scorer name', () {
      // Stéphane is in Team A
      final result = parser.parse(rawText: 'but de Stéphane', match: testMatch);
      expect(result.type, GameEventType.goal);
      expect(result.playerName, 'Stéphane');
      expect(result.teamName, 'Équipe A');
    });

    test('parses goal with scorer and assist from registered players', () {
      // User requested exact test case: "but équipe A stéphane assist nabil"
      final result = parser.parse(
        rawText: 'but équipe A stéphane assist nabil',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe A');
      expect(result.playerName, 'Stéphane');
      expect(result.secondaryPlayerName, 'Nabil');
    });

    test('parses goal with "passe de" assist syntax', () {
      final result = parser.parse(
        rawText: 'but pour Cedric passe de Karim',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe B');
      expect(result.playerName, 'Cedric');
      expect(result.secondaryPlayerName, 'Karim');
    });

    test('parses multiple points (e.g. basketball)', () {
      final result = parser.parse(
        rawText: 'panier 3 points équipe A',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe A');
      expect(result.points, 3);
    });

    test('parses plus un / +1 as a point', () {
      final result = parser.parse(
        rawText: '+1 pour équipe B',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe B');
      expect(result.points, 1);
    });
  });

  group('OfflineVoiceCommandParser - Cartons et Fautes', () {
    test('parses yellow card with player and team', () {
      final result = parser.parse(
        rawText: 'carton jaune pour Stéphane',
        match: testMatch,
      );
      expect(result.type, GameEventType.yellowCard);
      expect(result.playerName, 'Stéphane');
      expect(result.teamName, 'Équipe A');
    });

    test('parses red card for team B', () {
      final result = parser.parse(
        rawText: 'carton rouge équipe B',
        match: testMatch,
      );
      expect(result.type, GameEventType.redCard);
      expect(result.teamName, 'Équipe B');
    });

    test('parses foul and penalty', () {
      final foulResult = parser.parse(
        rawText: 'faute de Karim',
        match: testMatch,
      );
      expect(foulResult.type, GameEventType.foul);
      expect(foulResult.playerName, 'Karim');
      expect(foulResult.teamName, 'Équipe B');
      expect(foulResult.isPenalty, isFalse);

      final penaltyResult = parser.parse(
        rawText: 'penalty pour équipe A',
        match: testMatch,
      );
      expect(penaltyResult.type, GameEventType.foul);
      expect(penaltyResult.teamName, 'Équipe A');
      expect(penaltyResult.isPenalty, isTrue);
    });
  });

  group('OfflineVoiceCommandParser - English Commands', () {
    test('detects English match controls', () {
      expect(
        parser.parse(rawText: 'pause', match: testMatch).matchControl,
        'pause',
      );
      expect(
        parser.parse(rawText: 'timeout', match: testMatch).matchControl,
        'pause',
      );
      expect(
        parser.parse(rawText: 'stop the clock', match: testMatch).matchControl,
        'pause',
      );
      expect(
        parser.parse(rawText: 'resume', match: testMatch).matchControl,
        'resume',
      );
      expect(
        parser.parse(rawText: 'continue', match: testMatch).matchControl,
        'resume',
      );
      expect(
        parser.parse(rawText: 'half time', match: testMatch).matchControl,
        'halftime',
      );
      expect(
        parser.parse(rawText: 'halftime', match: testMatch).matchControl,
        'halftime',
      );
      expect(
        parser.parse(rawText: 'end match', match: testMatch).matchControl,
        'end_match',
      );
      expect(
        parser.parse(rawText: 'end game', match: testMatch).matchControl,
        'end_match',
      );
      expect(
        parser.parse(rawText: 'final whistle', match: testMatch).matchControl,
        'end_match',
      );
    });

    test('detects English undo and cancel keywords', () {
      expect(
        parser.parse(rawText: 'undo', match: testMatch).type,
        GameEventType.correction,
      );
      expect(
        parser.parse(rawText: 'cancel last goal', match: testMatch).type,
        GameEventType.correction,
      );
      expect(
        parser.parse(rawText: 'no goal', match: testMatch).type,
        GameEventType.correction,
      );
      expect(
        parser.parse(rawText: 'mistake', match: testMatch).type,
        GameEventType.correction,
      );
    });

    test('parses English goals and assists', () {
      final goalTeamA = parser.parse(rawText: 'goal team A', match: testMatch);
      expect(goalTeamA.type, GameEventType.goal);
      expect(goalTeamA.teamName, 'Équipe A');

      final goalByScorer = parser.parse(
        rawText: 'goal by Stephane',
        match: testMatch,
      );
      expect(goalByScorer.type, GameEventType.goal);
      expect(goalByScorer.playerName, 'Stéphane');
      expect(goalByScorer.teamName, 'Équipe A');

      final goalWithAssist = parser.parse(
        rawText: 'goal Cedric assisted by Karim',
        match: testMatch,
      );
      expect(goalWithAssist.type, GameEventType.goal);
      expect(goalWithAssist.playerName, 'Cedric');
      expect(goalWithAssist.secondaryPlayerName, 'Karim');
      expect(goalWithAssist.teamName, 'Équipe B');

      final threePointer = parser.parse(
        rawText: 'three points for team B',
        match: testMatch,
      );
      expect(threePointer.type, GameEventType.goal);
      expect(threePointer.points, 3);
    });

    test('parses English cards and fouls', () {
      final yellow = parser.parse(
        rawText: 'yellow card for Stephane',
        match: testMatch,
      );
      expect(yellow.type, GameEventType.yellowCard);
      expect(yellow.playerName, 'Stéphane');

      final red = parser.parse(rawText: 'red card Cedric', match: testMatch);
      expect(red.type, GameEventType.redCard);
      expect(red.playerName, 'Cedric');

      final foul = parser.parse(rawText: 'foul by Karim', match: testMatch);
      expect(foul.type, GameEventType.foul);
      expect(foul.playerName, 'Karim');
    });
  });

  group('OfflineVoiceCommandParser - Cas limites', () {
    test('handles empty or unrecognized input', () {
      final emptyResult = parser.parse(rawText: '', match: testMatch);
      expect(emptyResult.type, GameEventType.unknown);

      final unknownResult = parser.parse(
        rawText: 'bonjour tout le monde il fait beau',
        match: testMatch,
      );
      expect(unknownResult.type, GameEventType.unknown);
    });
  });

  group('OfflineVoiceCommandParser - Numéros de maillots & Compositions (User Request)', () {
    test('parses "but équipe A numéro 5 assit numéro 3" (unregistered numbers fallback to #N)', () {
      final result = parser.parse(
        rawText: 'but équipe A numéro 5 assit numéro 3',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe A');
      expect(result.playerName, '#5');
      expect(result.secondaryPlayerName, '#3');
      expect(result.points, 1);
    });

    test('parses goal with registered numbers and resolves player names', () {
      // Stéphane is #9 and Nabil is #10 in Team A
      final result = parser.parse(
        rawText: 'but équipe A numéro 9 assist numéro 10',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe A');
      expect(result.playerName, 'Stéphane');
      expect(result.secondaryPlayerName, 'Nabil');
    });

    test('parses goal with registered number without explicit team ("but numéro 7")', () {
      // Cedric is #7 in Team B
      final result = parser.parse(
        rawText: 'but numéro 7',
        match: testMatch,
      );
      expect(result.type, GameEventType.goal);
      expect(result.teamName, 'Équipe B');
      expect(result.playerName, 'Cedric');
    });

    test('parses yellow card by jersey number ("carton jaune équipe A numéro 9")', () {
      final result = parser.parse(
        rawText: 'carton jaune équipe A numéro 9',
        match: testMatch,
      );
      expect(result.type, GameEventType.yellowCard);
      expect(result.teamName, 'Équipe A');
      expect(result.playerName, 'Stéphane');
    });

    test('parses foul by jersey number ("faute équipe B numéro 11")', () {
      // Karim is #11 in Team B
      final result = parser.parse(
        rawText: 'faute équipe B numéro 11',
        match: testMatch,
      );
      expect(result.type, GameEventType.foul);
      expect(result.teamName, 'Équipe B');
      expect(result.playerName, 'Karim');
    });
  });
}

