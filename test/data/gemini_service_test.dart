import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/data/services/gemini_service.dart';
import 'package:score_bot/domain/models/sport_type.dart';

void main() {
  group('ParsedVoiceCommand Tests', () {
    test('fromJson parses match_control correctly', () {
      final json = {
        'transcription': 'Pause',
        'type': 'unknown',
        'team': 'Équipe A',
        'match_control': 'pause',
      };

      final cmd = ParsedVoiceCommand.fromJson(json);
      expect(cmd.matchControl, 'pause');
      expect(cmd.transcription, 'Pause');
      expect(cmd.type, GameEventType.unknown);
    });

    test('fromJson parses goal event with all fields', () {
      final json = {
        'transcription': 'But pour les bleus par Cédric assisté par Nabil',
        'type': 'goal',
        'team': 'bleu',
        'player': 'Cédric',
        'secondary_player': 'Nabil',
        'points': 1,
      };

      final cmd = ParsedVoiceCommand.fromJson(json);
      expect(cmd.type, GameEventType.goal);
      expect(cmd.playerName, 'Cédric');
      expect(cmd.secondaryPlayerName, 'Nabil');
      expect(cmd.points, 1);
    });
  });
}

