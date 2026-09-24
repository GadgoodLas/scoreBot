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

  group('GeminiService Configuration Tests', () {
    test('isConfigured returns false when apiKey is empty or dummy', () {
      final service1 = GeminiService(apiKey: '');
      expect(service1.isConfigured, isFalse);

      final service2 = GeminiService(apiKey: 'your_gemini_api_key_here');
      expect(service2.isConfigured, isFalse);
    });

    test('isConfigured returns true when valid apiKey is set', () {
      final service = GeminiService(apiKey: 'AIzaSyActualKey123');
      expect(service.isConfigured, isTrue);
    });

    test('preferredModel defaults to gemini-2.5-flash', () {
      final service = GeminiService();
      expect(service.preferredModel, 'gemini-2.5-flash');
    });

    test(
      'candidateModels places custom preferredModel first without duplicates',
      () {
        final service = GeminiService(preferredModel: 'gemini-1.5-pro');
        expect(service.candidateModels.first, 'gemini-1.5-pro');
        expect(
          service.candidateModels.where((m) => m == 'gemini-1.5-pro').length,
          1,
        );
      },
    );

    test('updateConfig immediately reflects new key and model', () {
      final service = GeminiService(
        apiKey: 'initial_key',
        preferredModel: 'gemini-2.0-flash',
      );
      expect(service.preferredModel, 'gemini-2.0-flash');

      service.updateConfig(
        apiKey: 'new_key',
        preferredModel: 'gemini-3.8-flash',
      );
      expect(service.apiKey, 'new_key');
      expect(service.preferredModel, 'gemini-3.8-flash');
      expect(service.candidateModels.first, 'gemini-3.8-flash');
    });
  });
}
