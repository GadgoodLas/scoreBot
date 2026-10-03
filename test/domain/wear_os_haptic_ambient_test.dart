import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/data/services/haptic_service.dart';
import 'package:score_bot/data/services/tts_service.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/live/view_models/live_view_model.dart';

class _FakeTtsService extends TtsService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

class _FakeMatchRepository implements MatchRepository {
  _FakeMatchRepository();

  @override
  String get languageCode => 'fr';

  @override
  bool get isVoiceReady => true;

  @override
  bool get isAiConfigured => true;

  @override
  bool get isLocalVoiceMode => false;

  @override
  List<GameEvent> getEvents(String matchId) => [];

  @override
  Future<void> startVoiceCommand() async {}

  @override
  Future<void> cancelVoiceCommand() async {}

  @override
  Future<GameMatch> addPoint(
    GameMatch match,
    String teamId, {
    int points = 1,
    String? scorerName,
    String? assistName,
  }) async {
    return teamId == match.teamA.id
        ? match.copyWith(scoreA: match.scoreA + points)
        : match.copyWith(scoreB: match.scoreB + points);
  }

  @override
  Future<GameMatch> removePoint(GameMatch match, String teamId) async {
    return teamId == match.teamA.id
        ? match.copyWith(scoreA: match.scoreA > 0 ? match.scoreA - 1 : 0)
        : match.copyWith(scoreB: match.scoreB > 0 ? match.scoreB - 1 : 0);
  }

  @override
  Future<GameMatch> togglePause(GameMatch match) async => match.copyWith(
    status:
        match.status == GameMatchStatus.paused
            ? GameMatchStatus.live
            : GameMatchStatus.paused,
  );

  @override
  Future<GameMatch> pauseMatch(GameMatch match) async =>
      match.copyWith(status: GameMatchStatus.paused);

  @override
  Future<GameMatch> resumeMatch(GameMatch match) async =>
      match.copyWith(status: GameMatchStatus.live);

  @override
  Future<GameMatch> startHalftime(GameMatch match) async =>
      match.copyWith(status: GameMatchStatus.halftime);

  @override
  Future<GameMatch> endMatch(GameMatch match) async =>
      match.copyWith(status: GameMatchStatus.finished);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticService Patterns', () {
    test('goal triggers double heavy vibration pattern', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(
        customRunner: (type) async {
          calls.add(type);
        },
      );

      await haptic.goal();
      expect(
        calls,
        equals([HapticFeedbackType.heavy, HapticFeedbackType.heavy]),
      );
    });

    test('yellowCard triggers single medium vibration', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(
        customRunner: (type) async => calls.add(type),
      );

      await haptic.yellowCard();
      expect(calls, equals([HapticFeedbackType.medium]));
    });

    test('redCard triggers triple heavy vibration pattern', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(
        customRunner: (type) async => calls.add(type),
      );

      await haptic.redCard();
      expect(
        calls,
        equals([
          HapticFeedbackType.heavy,
          HapticFeedbackType.heavy,
          HapticFeedbackType.heavy,
        ]),
      );
    });

    test('foul triggers light vibration', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(
        customRunner: (type) async => calls.add(type),
      );

      await haptic.foul();
      expect(calls, equals([HapticFeedbackType.light]));
    });

    test('correction triggers double selection click pattern', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(
        customRunner: (type) async => calls.add(type),
      );

      await haptic.correction();
      expect(
        calls,
        equals([HapticFeedbackType.selection, HapticFeedbackType.selection]),
      );
    });

    test('periodEnd triggers vibrate then heavy impact', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(
        customRunner: (type) async => calls.add(type),
      );

      await haptic.periodEnd();
      expect(
        calls,
        equals([HapticFeedbackType.vibrate, HapticFeedbackType.heavy]),
      );
    });

    test('error triggers medium then light vibration', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(
        customRunner: (type) async => calls.add(type),
      );

      await haptic.error();
      expect(
        calls,
        equals([HapticFeedbackType.medium, HapticFeedbackType.light]),
      );
    });
  });

  group('LiveViewModel Wear OS & Ambient Mode', () {
    late GameMatch testMatch;
    late _FakeMatchRepository fakeRepo;

    setUp(() {
      fakeRepo = _FakeMatchRepository();
      testMatch = GameMatch(
        id: 'wear-test-1',
        sport: SportType.football,
        teamA: const Team(id: 'a', name: 'Équipe A', color: '#FF0000'),
        teamB: const Team(id: 'b', name: 'Équipe B', color: '#0000FF'),
        status: GameMatchStatus.live,
        scoreA: 0,
        scoreB: 0,
        durationMinutes: 90,
        startTime: DateTime.now(),
      );
    });

    test('ambient mode toggling and exit', () {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(customRunner: (t) async => calls.add(t));
      final vm = LiveViewModel(
        matchRepository: fakeRepo,
        initialMatch: testMatch,
        ttsService: _FakeTtsService(),
        hapticService: haptic,
      );

      expect(vm.isAmbientMode, isFalse);

      vm.toggleAmbientMode();
      expect(vm.isAmbientMode, isTrue);
      expect(calls, contains(HapticFeedbackType.selection));

      vm.exitAmbientMode();
      expect(vm.isAmbientMode, isFalse);

      vm.dispose();
    });

    test(
      'startListening exits ambient mode automatically and triggers haptic',
      () async {
        final calls = <HapticFeedbackType>[];
        final haptic = HapticService(customRunner: (t) async => calls.add(t));
        final vm = LiveViewModel(
          matchRepository: fakeRepo,
          initialMatch: testMatch,
          ttsService: _FakeTtsService(),
          hapticService: haptic,
        );

        vm.toggleAmbientMode(value: true);
        expect(vm.isAmbientMode, isTrue);

        await vm.startListening();
        // Le mode ambiant doit être quitté pour afficher le retour visuel vocal
        expect(vm.isAmbientMode, isFalse);
        expect(calls, contains(HapticFeedbackType.selection));

        vm.dispose();
      },
    );

    test('score manual buttons trigger appropriate haptic patterns', () async {
      final calls = <HapticFeedbackType>[];
      final haptic = HapticService(customRunner: (t) async => calls.add(t));
      final vm = LiveViewModel(
        matchRepository: fakeRepo,
        initialMatch: testMatch,
        ttsService: _FakeTtsService(),
        hapticService: haptic,
      );

      await vm.incrementScoreA();
      expect(vm.scoreA, equals(1));
      expect(calls, contains(HapticFeedbackType.heavy)); // goal pattern

      calls.clear();
      await vm.decrementScoreA();
      expect(vm.scoreA, equals(0));
      expect(
        calls,
        contains(HapticFeedbackType.selection),
      ); // correction pattern

      calls.clear();
      await vm.togglePause();
      expect(
        calls,
        contains(HapticFeedbackType.medium),
      ); // matchControl pattern

      vm.dispose();
    });
  });
}
