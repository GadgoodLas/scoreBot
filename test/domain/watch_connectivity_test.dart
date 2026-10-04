import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/data/services/watch_connectivity_service.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> log;
  late WatchConnectivityService service;

  final sampleMatch = GameMatch(
    id: 'match-123',
    sport: SportType.football,
    teamA: const Team(id: 'team-a', name: 'FC Barcelone'),
    teamB: const Team(id: 'team-b', name: 'Real Madrid'),
    status: GameMatchStatus.live,
    scoreA: 1,
    scoreB: 0,
    startTime: DateTime(2026, 10, 4, 18, 0),
    durationMinutes: 90,
  );

  setUp(() {
    log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.scorebot.score_bot/wearable'),
          (MethodCall methodCall) async {
            log.add(methodCall);
            if (methodCall.method == 'sendMessage') {
              return {'delivered': true, 'nodeCount': 1};
            }
            if (methodCall.method == 'checkConnectedNodes') {
              return [
                {'id': 'watch-node-1', 'displayName': 'Pixel Watch'},
              ];
            }
            return null;
          },
        );

    service = WatchConnectivityService();
  });

  tearDown(() {
    service.dispose();
  });

  test('checkConnectedNodes returns list of remote devices', () async {
    final nodes = await service.checkConnectedNodes();
    expect(nodes.length, 1);
    expect(nodes.first['displayName'], 'Pixel Watch');
    expect(service.hasConnectedNodes, isTrue);
  });

  test('sendMatchState serializes match and invokes native sendMessage', () async {
    final sent = await service.sendMatchState(sampleMatch);
    expect(sent, isTrue);
    expect(log.length, 1);
    expect(log.first.method, 'sendMessage');

    final args = log.first.arguments as Map;
    expect(args['path'], '/match/sync');
    expect(args['data'], contains('match-123'));
    expect(args['data'], contains('FC Barcelone'));
  });

  test('sendScoreUpdate sends concise score update payload', () async {
    final sent = await service.sendScoreUpdate(
      matchId: 'match-123',
      scoreA: 2,
      scoreB: 1,
    );
    expect(sent, isTrue);
    expect(log.first.method, 'sendMessage');

    final args = log.first.arguments as Map;
    expect(args['data'], contains('"scoreA":2'));
    expect(args['data'], contains('"scoreB":1'));
  });

  test('sendMatchControl sends action control payload', () async {
    final sent = await service.sendMatchControl(
      matchId: 'match-123',
      action: 'pause',
    );
    expect(sent, isTrue);
    expect(log.first.method, 'sendMessage');

    final args = log.first.arguments as Map;
    expect(args['data'], contains('"action":"pause"'));
  });

  test('incoming onMessageReceived parses matchState and emits to stream', () async {
    GameMatch? receivedMatch;
    service.onMatchStateReceived.listen((m) {
      receivedMatch = m;
    });

    // Format JSON standard
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'com.scorebot.score_bot/wearable',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onMessageReceived', {
              'path': '/match/sync',
              'data':
                  '{"type":"matchState","match":{"id":"match-123","sport":"football","teamA":{"id":"team-a","name":"Equipe A","players":[]},"teamB":{"id":"team-b","name":"Equipe B","players":[]},"status":"live","scoreA":3,"scoreB":2,"startTime":"2026-10-04T18:00:00.000","durationMinutes":90}}',
            }),
          ),
          (_) {},
        );

    await Future.delayed(const Duration(milliseconds: 50));
    expect(receivedMatch, isNotNull);
    expect(receivedMatch?.id, 'match-123');
    expect(receivedMatch?.scoreA, 3);
    expect(receivedMatch?.scoreB, 2);
  });
}
