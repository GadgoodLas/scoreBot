import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/data/services/tts_service.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/live/view_models/live_view_model.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';

class _FakeTtsService extends TtsService {
  final List<String> spokenMessages = [];
  bool stopCalled = false;

  @override
  Future<void> setLanguage(String languageCode) async {}

  @override
  Future<void> speak(String text) async {
    spokenMessages.add(text);
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }
}

class _FakeMatchRepository implements MatchRepository {
  _FakeMatchRepository({this.languageCode = 'fr'});

  @override
  final String languageCode;

  @override
  List<GameEvent> getEvents(String matchId) => [];

  @override
  Future<GameMatch> pauseMatch(GameMatch match) async =>
      match.copyWith(status: GameMatchStatus.paused);

  @override
  Future<GameMatch> endMatch(GameMatch match) async =>
      match.copyWith(status: GameMatchStatus.finished);

  @override
  Future<GameMatch> createMatch({
    required SportType sport,
    required Team teamA,
    required Team teamB,
    int? durationMinutes,
    int? breakDurationMinutes,
  }) async {
    return GameMatch(
      id: 'test-m',
      sport: sport,
      teamA: teamA,
      teamB: teamB,
      status: GameMatchStatus.live,
      scoreA: 0,
      scoreB: 0,
      startTime: DateTime.now(),
      durationMinutes: durationMinutes ?? 90,
      breakDurationMinutes: breakDurationMinutes,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SetupViewModel Duration & Break Configuration', () {
    test('initializes default duration and break according to sport', () {
      final repo = _FakeMatchRepository();
      final vm = SetupViewModel(matchRepository: repo);

      // Default sport is football
      expect(vm.durationMinutes, 90);
      expect(vm.breakDurationMinutes, 45);

      // Select basketball (40 min duration, has halftime)
      vm.selectSport(SportType.basketball);
      expect(vm.durationMinutes, 40);
      expect(vm.breakDurationMinutes, 20);

      // Select volleyball (no halftime, sets)
      vm.selectSport(SportType.volleyball);
      expect(vm.durationMinutes, 90);
      expect(vm.breakDurationMinutes, isNull);
    });

    test('setting duration adjusts break if break exceeds new duration', () {
      final repo = _FakeMatchRepository();
      final vm = SetupViewModel(matchRepository: repo);

      vm.setDuration(90);
      vm.setBreakDuration(45);
      expect(vm.breakDurationMinutes, 45);

      // Reduce total duration below break duration
      vm.setDuration(30);
      expect(vm.durationMinutes, 30);
      expect(vm.breakDurationMinutes, 15); // clamped to half
    });

    test('creates match with configured duration and break duration', () async {
      final repo = _FakeMatchRepository();
      final vm = SetupViewModel(matchRepository: repo);

      vm.setTeamAName('Red');
      vm.setTeamBName('Blue');
      vm.setDuration(60);
      vm.setBreakDuration(25);

      final match = await vm.startMatch();
      expect(match, isNotNull);
      expect(match!.durationMinutes, 60);
      expect(match.breakDurationMinutes, 25);
    });
  });

  group('LiveViewModel Timer Alerts & Vocal TTS Notifications', () {
    test('triggers break vocal notification when elapsed exceeds break duration', () async {
      final repo = _FakeMatchRepository(languageCode: 'fr');
      final tts = _FakeTtsService();

      // Match started 30 minutes ago, with break configured at 25 minutes
      final match = GameMatch(
        id: 'm-live-1',
        sport: SportType.football,
        teamA: const Team(id: 'a', name: 'A'),
        teamB: const Team(id: 'b', name: 'B'),
        status: GameMatchStatus.live,
        scoreA: 0,
        scoreB: 0,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        durationMinutes: 90,
        breakDurationMinutes: 25,
      );

      final vm = LiveViewModel(
        matchRepository: repo,
        initialMatch: match,
        ttsService: tts,
      );

      // Allow timer loop or call internal check
      expect(vm.pendingAlert, LiveAlertType.breakSuggested);
      expect(tts.spokenMessages, contains("C'est l'heure de la pause ! Prenez une pause."));

      // Accepting break pauses the match
      await vm.acceptBreakAlert();
      expect(vm.pendingAlert, isNull);
      expect(vm.match.status, GameMatchStatus.paused);

      vm.dispose();
    });

    test('triggers match end vocal notification when elapsed exceeds duration', () async {
      final repo = _FakeMatchRepository(languageCode: 'en');
      final tts = _FakeTtsService();

      // Match started 95 minutes ago, total duration 90 minutes
      final match = GameMatch(
        id: 'm-live-2',
        sport: SportType.football,
        teamA: const Team(id: 'a', name: 'A'),
        teamB: const Team(id: 'b', name: 'B'),
        status: GameMatchStatus.live,
        scoreA: 1,
        scoreB: 1,
        startTime: DateTime.now().subtract(const Duration(minutes: 95)),
        durationMinutes: 90,
        breakDurationMinutes: 45,
      );

      final vm = LiveViewModel(
        matchRepository: repo,
        initialMatch: match,
        ttsService: tts,
      );

      expect(vm.pendingAlert, LiveAlertType.matchEndReached);
      expect(tts.spokenMessages, contains('Full time! Match finished.'));

      // Accepting end closes match
      await vm.acceptEndMatchAlert();
      expect(vm.pendingAlert, isNull);
      expect(vm.match.status, GameMatchStatus.finished);

      vm.dispose();
    });
  });

  group('SetupViewModel Lineup Vocal Announcement', () {
    test('generateLineupAnnouncement in French with and without players', () {
      final repo = _FakeMatchRepository();
      final vm = SetupViewModel(matchRepository: repo);
      vm.setTeamAName('Paris');
      vm.setTeamBName('Marseille');

      final announcementNoPlayers = vm.generateLineupAnnouncement(
        sportLabel: 'Football',
        languageCode: 'fr',
      );
      expect(announcementNoPlayers, 'Match de Football. Paris contre Marseille. Bon match à tous !');

      vm.addPlayerToTeamA('Kylian, Achraf');
      vm.addPlayerToTeamB('Pierre, Amine');

      final announcementWithPlayers = vm.generateLineupAnnouncement(
        sportLabel: 'Football',
        languageCode: 'fr',
      );
      expect(
        announcementWithPlayers,
        'Match de Football. Paris contre Marseille. Composition de Paris : Kylian, Achraf. Composition de Marseille : Pierre, Amine. Bon match à tous !',
      );
    });

    test('generateLineupAnnouncement in English', () {
      final repo = _FakeMatchRepository();
      final vm = SetupViewModel(matchRepository: repo);
      vm.setTeamAName('Arsenal');
      vm.setTeamBName('Chelsea');
      vm.addPlayerToTeamA('Saka');
      vm.addPlayerToTeamB('Palmer');

      final announcement = vm.generateLineupAnnouncement(
        sportLabel: 'Football',
        languageCode: 'en',
      );
      expect(
        announcement,
        'Football match. Arsenal versus Chelsea. Team Arsenal lineup: Saka. Team Chelsea lineup: Palmer. Good luck everyone!',
      );
    });

    test('toggleLineupAnnouncement speaks message and can be stopped', () async {
      final repo = _FakeMatchRepository();
      final tts = _FakeTtsService();
      final vm = SetupViewModel(matchRepository: repo, ttsService: tts);
      vm.setTeamAName('Lions');
      vm.setTeamBName('Tigers');

      expect(vm.isAnnouncingLineup, isFalse);

      await vm.toggleLineupAnnouncement(sportLabel: 'Rugby', languageCode: 'fr');
      expect(vm.isAnnouncingLineup, isTrue);
      expect(tts.spokenMessages.length, 1);
      expect(tts.spokenMessages.first, contains('Match de Rugby. Lions contre Tigers.'));

      // Toggling again stops announcement
      await vm.toggleLineupAnnouncement(sportLabel: 'Rugby', languageCode: 'fr');
      expect(vm.isAnnouncingLineup, isFalse);
      expect(tts.stopCalled, isTrue);
    });

    test('startMatch stops any active lineup announcement', () async {
      final repo = _FakeMatchRepository();
      final tts = _FakeTtsService();
      final vm = SetupViewModel(matchRepository: repo, ttsService: tts);
      vm.setTeamAName('Alpha');
      vm.setTeamBName('Beta');

      await vm.toggleLineupAnnouncement(sportLabel: 'Football', languageCode: 'fr');
      expect(vm.isAnnouncingLineup, isTrue);

      final match = await vm.startMatch();
      expect(match, isNotNull);
      expect(vm.isAnnouncingLineup, isFalse);
      expect(tts.stopCalled, isTrue);
    });
  });
}


