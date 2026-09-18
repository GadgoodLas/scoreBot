import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:score_bot/data/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('score_bot_storage_test_');
    storageService = StorageService();
    await storageService.init(tempDir.path);
  });

  tearDown(() async {
    await storageService.dispose();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageService Settings Tests', () {
    test('initial state has no api key and default model', () {
      expect(storageService.getApiKey(), isNull);
      expect(storageService.getAiModel(), 'gemini-2.5-flash');
      expect(storageService.isAiConfigured(), isFalse);
      expect(storageService.hasSeenAiOnboarding(), isFalse);
    });

    test('saving and retrieving api key works correctly', () async {
      await storageService.saveApiKey('AIzaSyTestKey123');
      expect(storageService.getApiKey(), 'AIzaSyTestKey123');
      expect(storageService.isAiConfigured(), isTrue);
    });

    test('saving and retrieving custom AI model works correctly', () async {
      await storageService.saveAiModel('gemini-2.0-flash');
      expect(storageService.getAiModel(), 'gemini-2.0-flash');
    });

    test('onboarding seen flag persists correctly', () async {
      expect(storageService.hasSeenAiOnboarding(), isFalse);
      await storageService.setAiOnboardingSeen(true);
      expect(storageService.hasSeenAiOnboarding(), isTrue);
    });

    test('clearAiConfig removes key and model', () async {
      await storageService.saveApiKey('key_to_delete');
      await storageService.saveAiModel('gemini-1.5-pro');

      expect(storageService.isAiConfigured(), isTrue);

      await storageService.clearAiConfig();

      expect(storageService.getApiKey(), isNull);
      expect(storageService.getAiModel(), 'gemini-2.5-flash');
      expect(storageService.isAiConfigured(), isFalse);
    });

    test('voice engine defaults to local when no API key is configured', () {
      expect(storageService.getVoiceEngine(), 'local');
      expect(storageService.isLocalVoiceMode, isTrue);
    });

    test('saving and retrieving voice engine works correctly', () async {
      await storageService.saveVoiceEngine('gemini');
      expect(storageService.getVoiceEngine(), 'gemini');
      expect(storageService.isLocalVoiceMode, isFalse);

      await storageService.saveVoiceEngine('local');
      expect(storageService.getVoiceEngine(), 'local');
      expect(storageService.isLocalVoiceMode, isTrue);
    });
  });
}
