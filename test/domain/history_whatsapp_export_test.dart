import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/history/view_models/history_view_model.dart';
import 'package:score_bot/ui/features/summary/views/summary_view.dart';

class _FakeMatchRepoForHistory implements MatchRepository {
  _FakeMatchRepoForHistory({required this.matches, required this.events});

  final List<GameMatch> matches;
  final Map<String, List<GameEvent>> events;
  bool deleteCalled = false;
  String? deletedId;

  @override
  List<GameMatch> listMatches() => List.from(matches);

  @override
  Future<void> deleteMatch(String matchId) async {
    deleteCalled = true;
    deletedId = matchId;
    matches.removeWhere((m) => m.id == matchId);
  }

  @override
  List<GameEvent> getEvents(String matchId) => events[matchId] ?? [];

  @override
  bool get isAiConfigured => false;

  @override
  bool get isLocalVoiceMode => true;

  @override
  Future<String> generateMatchReport(GameMatch match) async => 'Report auto';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameMatch match1;
  late List<GameEvent> events1;
  late _FakeMatchRepoForHistory fakeRepo;

  setUp(() {
    match1 = GameMatch(
      id: 'm-hist-1',
      sport: SportType.football,
      teamA: const Team(
        id: 'team-a',
        name: 'PSG',
        color: '#FF0000',
        players: [
          Player(id: 'p1', name: 'Mbappé', number: 7),
          Player(id: 'p2', name: 'Messi', number: 10),
        ],
      ),
      teamB: const Team(
        id: 'team-b',
        name: 'OM',
        color: '#0000FF',
        players: [Player(id: 'p3', name: 'Payet', number: 10)],
      ),
      status: GameMatchStatus.finished,
      scoreA: 2,
      scoreB: 1,
      durationMinutes: 90,
      startTime: DateTime(2026, 10, 3, 15, 30),
    );

    events1 = [
      GoalEvent(
        id: 'e1',
        teamId: 'team-a',
        minute: 14,
        scorerName: 'Mbappé',
        assistName: 'Messi',
        timestamp: DateTime(2026, 10, 3, 15, 44),
      ),
      GoalEvent(
        id: 'e2',
        teamId: 'team-b',
        minute: 40,
        scorerName: 'Payet',
        timestamp: DateTime(2026, 10, 3, 16, 10),
      ),
      GoalEvent(
        id: 'e3',
        teamId: 'team-a',
        minute: 88,
        scorerName: 'Mbappé',
        timestamp: DateTime(2026, 10, 3, 16, 58),
      ),
      CardEvent(
        id: 'e4',
        teamId: 'team-b',
        type: GameEventType.yellowCard,
        minute: 60,
        playerName: 'Payet',
        timestamp: DateTime(2026, 10, 3, 16, 30),
      ),
    ];

    fakeRepo = _FakeMatchRepoForHistory(
      matches: [match1],
      events: {'m-hist-1': events1},
    );
  });

  group('HistoryViewModel', () {
    test('loads matches from repository on init', () {
      final vm = HistoryViewModel(matchRepository: fakeRepo);
      expect(vm.matches.length, equals(1));
      expect(vm.matches.first.id, equals('m-hist-1'));
    });

    test('deletes match and updates match list', () async {
      final vm = HistoryViewModel(matchRepository: fakeRepo);
      expect(vm.matches.length, equals(1));

      await vm.deleteMatch('m-hist-1');
      expect(fakeRepo.deleteCalled, isTrue);
      expect(fakeRepo.deletedId, equals('m-hist-1'));
      expect(vm.matches.isEmpty, isTrue);
    });

    test(
      'generateWhatsAppReportForMatch includes markdown and match details',
      () {
        final vm = HistoryViewModel(matchRepository: fakeRepo);
        final report = vm.generateWhatsAppReportForMatch(match1);

        expect(report, contains('🏆 *SCOREBOT — FEUILLE DE MATCH*'));
        expect(report, contains('⚽ *Sport :* Football'));
        expect(report, contains('🔴 *PSG*  *2 — 1*  *OM* 🔵'));
        expect(report, contains('🎉 *Vainqueur :* PSG'));
        expect(report, contains("⚽ 14' *Mbappé* _(passe: Messi)_ — PSG"));
        expect(report, contains("🟨 60' *Payet* — OM"));
      },
    );
  });

  group('SummaryViewModel WhatsApp Export', () {
    test(
      'generateWhatsAppReport includes complete player stats with emojis',
      () {
        final vm = SummaryViewModel(matchRepository: fakeRepo, match: match1);
        final waReport = vm.generateWhatsAppReport();

        // Check header
        expect(waReport, contains('🏆 *SCOREBOT — FEUILLE DE MATCH*'));
        expect(waReport, contains('🔴 *PSG*  *2 — 1*  *OM* 🔵'));

        // Check timeline
        expect(waReport, contains("⚽ 14' *Mbappé* _(passe: Messi)_ — PSG"));
        expect(waReport, contains("⚽ 40' *Payet* — OM"));
        expect(waReport, contains("⚽ 88' *Mbappé* — PSG"));

        // Check individual player stats
        expect(waReport, contains('👥 *STATISTIQUES DES JOUEURS :*'));
        expect(waReport, contains('🔴 *PSG :*'));
        expect(waReport, contains('• #7 *Mbappé* : 2 ⚽'));
        expect(waReport, contains('• #10 *Messi* : 1 🅰️'));
        expect(waReport, contains('🔵 *OM :*'));
        expect(waReport, contains('• #10 *Payet* : 1 ⚽, 1 🟨'));

        // Check top scorer
        expect(
          waReport,
          contains('🏅 *Meilleur buteur :* *Mbappé* (2 but(s))'),
        );
        expect(
          waReport,
          contains('🤖 _Feuille de match officielle générée par ScoreBot_'),
        );
      },
    );
  });
}
