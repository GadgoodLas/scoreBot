import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/ui/features/summary/views/summary_view.dart';

class _FakeMatchRepository implements MatchRepository {
  _FakeMatchRepository(this._events);

  final List<GameEvent> _events;

  @override
  List<GameEvent> getEvents(String matchId) => _events;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Player Stats in SummaryViewModel', () {
    test('computes goals, assists, and cards per player correctly', () {
      final events = <GameEvent>[];
      final repo = _FakeMatchRepository(events);

      const teamA = Team(
        id: 'team-a',
        name: 'Équipe A',
        color: 'rouge',
        players: [
          Player(id: 'p1', name: 'Stéphane'),
          Player(id: 'p2', name: 'Nabil'),
        ],
      );
      const teamB = Team(
        id: 'team-b',
        name: 'Équipe B',
        color: 'bleu',
        players: [
          Player(id: 'p3', name: 'Karim'),
        ],
      );

      final match = GameMatch(
        id: 'match-1',
        sport: SportType.football,
        teamA: teamA,
        teamB: teamB,
        status: GameMatchStatus.finished,
        scoreA: 2,
        scoreB: 0,
        startTime: DateTime.now().subtract(const Duration(minutes: 90)),
        durationMinutes: 90,
      );

      // Event 1: But Stéphane assist Nabil
      events.add(
        GoalEvent(
          id: 'e1',
          teamId: teamA.id,
          minute: 12,
          timestamp: DateTime.now(),
          scorerName: 'Stéphane',
          assistName: 'Nabil',
        ),
      );

      // Event 2: But Stéphane sans assist
      events.add(
        GoalEvent(
          id: 'e2',
          teamId: teamA.id,
          minute: 34,
          timestamp: DateTime.now(),
          scorerName: 'Stéphane',
        ),
      );

      // Event 3: Carton jaune pour Nabil
      events.add(
        CardEvent(
          id: 'e3',
          type: GameEventType.yellowCard,
          teamId: teamA.id,
          minute: 50,
          timestamp: DateTime.now(),
          playerName: 'Nabil',
        ),
      );

      final vm = SummaryViewModel(matchRepository: repo, match: match);
      final statsA = vm.playerStatsForTeam(teamA.id);

      expect(statsA.length, 2);

      final stephane = statsA.firstWhere((p) => p.playerName == 'Stéphane');
      expect(stephane.goals, 2);
      expect(stephane.assists, 0);

      final nabil = statsA.firstWhere((p) => p.playerName == 'Nabil');
      expect(nabil.goals, 0);
      expect(nabil.assists, 1);
      expect(nabil.yellowCards, 1);
    });

    test('generateShareText produces expected summary format', () {
      final events = <GameEvent>[];
      final repo = _FakeMatchRepository(events);

      const teamA = Team(id: 'tA', name: 'Lions', color: 'rouge');
      const teamB = Team(id: 'tB', name: 'Tigers', color: 'bleu');

      final match = GameMatch(
        id: 'm1',
        sport: SportType.football,
        teamA: teamA,
        teamB: teamB,
        status: GameMatchStatus.finished,
        scoreA: 2,
        scoreB: 1,
        startTime: DateTime.now(),
        durationMinutes: 90,
      );

      events.add(
        GoalEvent(
          id: 'g1',
          teamId: teamA.id,
          minute: 10,
          timestamp: DateTime.now(),
          scorerName: 'Alex',
        ),
      );

      final vm = SummaryViewModel(matchRepository: repo, match: match);
      final text = vm.generateShareText();

      expect(text, contains('ScoreBot — Résumé du match'));
      expect(text, contains('Lions 2 — 1 Tigers'));
      expect(text, contains('Alex'));
    });

    test('saveReportToFile writes report to file successfully', () async {
      final events = <GameEvent>[];
      final repo = _FakeMatchRepository(events);

      const teamA = Team(id: 'tA', name: 'FC Alpha', color: 'rouge');
      const teamB = Team(id: 'tB', name: 'FC Beta', color: 'bleu');

      final match = GameMatch(
        id: 'm2',
        sport: SportType.football,
        teamA: teamA,
        teamB: teamB,
        status: GameMatchStatus.finished,
        scoreA: 1,
        scoreB: 0,
        startTime: DateTime.now(),
        durationMinutes: 90,
      );

      final tempDir = await Directory.systemTemp.createTemp('scorebot_report_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => tempDir.path,
      );

      try {
        final vm = SummaryViewModel(matchRepository: repo, match: match);
        final file = await vm.saveReportToFile();

        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content, contains('FC Alpha 1 — 0 FC Beta'));
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
