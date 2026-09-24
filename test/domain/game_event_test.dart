import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/sport_type.dart';

void main() {
  group('GoalEvent', () {
    test('toMap and fromMap are symmetric', () {
      final event = GoalEvent(
        id: 'evt-1',
        teamId: 'team-a',
        minute: 34,
        timestamp: DateTime(2025, 9, 17, 15, 30),
        scorerName: 'Cédric',
        assistName: 'Nabil',
        isPenalty: false,
        points: 1,
      );

      final map = event.toMap();
      final restored = GameEvent.fromMap(map) as GoalEvent;

      expect(restored.id, event.id);
      expect(restored.scorerName, 'Cédric');
      expect(restored.assistName, 'Nabil');
      expect(restored.isPenalty, false);
      expect(restored.points, 1);
      expect(restored.type, GameEventType.goal);
    });

    test('default points is 1', () {
      final event = GoalEvent(
        id: 'g1',
        teamId: 'ta',
        minute: 1,
        timestamp: DateTime.now(),
      );
      expect(event.points, 1);
    });
  });

  group('CardEvent', () {
    test('yellow card serialization', () {
      final event = CardEvent(
        id: 'c1',
        type: GameEventType.yellowCard,
        teamId: 'tb',
        minute: 22,
        timestamp: DateTime.now(),
        playerName: 'Karim',
      );

      final map = event.toMap();
      final restored = GameEvent.fromMap(map) as CardEvent;
      expect(restored.type, GameEventType.yellowCard);
      expect(restored.playerName, 'Karim');
    });

    test('assert fails for non-card type', () {
      expect(
        () => CardEvent(
          id: 'bad',
          type: GameEventType.goal, // Invalid!
          teamId: 'ta',
          minute: 1,
          timestamp: DateTime.now(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('CorrectionEvent', () {
    test('toMap and fromMap are symmetric', () {
      final event = CorrectionEvent(
        id: 'corr-1',
        teamId: 'ta',
        minute: 55,
        timestamp: DateTime.now(),
        action: 'undo_last',
      );

      final map = event.toMap();
      final restored = GameEvent.fromMap(map) as CorrectionEvent;
      expect(restored.action, 'undo_last');
    });
  });

  group('GameEvent.fromMap', () {
    test('unknown type falls back to GenericEvent', () {
      final map = {
        'id': 'gen-1',
        'type': 'cornerKick',
        'teamId': 'ta',
        'minute': 10,
        'timestamp': DateTime.now().toIso8601String(),
        'notes': 'Corner droit',
      };

      final event = GameEvent.fromMap(map) as GenericEvent;
      expect(event.type, GameEventType.cornerKick);
      expect(event.notes, 'Corner droit');
    });
  });
}
