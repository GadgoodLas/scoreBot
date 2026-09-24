import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/game_event.dart';

/// Noms des boites Hive.
class _BoxNames {
  static const matches = 'matches';
  static const events = 'events';
  static const settings = 'settings';
}

/// Clés utilisées dans la boîte settings.
class _SettingKeys {
  static const apiKey = 'gemini_api_key';
  static const aiModel = 'gemini_ai_model';
  static const hasSeenOnboarding = 'has_seen_ai_onboarding';
  static const voiceEngine = 'voice_engine'; // 'local' ou 'gemini'
  static const language = 'app_language'; // 'en' ou 'fr'
}

/// Service de persistance locale utilisant Hive.
class StorageService {
  late Box<String> _matchesBox;
  late Box<String> _eventsBox;
  late Box<String> _settingsBox;

  bool _initialized = false;

  /// Initialise Hive et ouvre les boîtes de stockage.
  Future<void> init([String? customPath]) async {
    if (_initialized) return;
    if (customPath != null) {
      Hive.init(customPath);
    } else {
      await Hive.initFlutter();
    }
    _matchesBox = await Hive.openBox<String>(_BoxNames.matches);
    _eventsBox = await Hive.openBox<String>(_BoxNames.events);
    _settingsBox = await Hive.openBox<String>(_BoxNames.settings);
    _initialized = true;
  }

  // ─────────────── MATCHES ───────────────

  /// Sauvegarde un match (création ou mise à jour).
  Future<void> saveMatch(GameMatch match) async {
    _assertInitialized();
    final json = jsonEncode(match.toMap());
    await _matchesBox.put(match.id, json);
  }

  /// Récupère un match par son ID.
  GameMatch? getMatch(String id) {
    _assertInitialized();
    final json = _matchesBox.get(id);
    if (json == null) return null;
    return GameMatch.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Liste tous les matchs stockés, du plus récent au plus ancien.
  List<GameMatch> listMatches() {
    _assertInitialized();
    return _matchesBox.values
        .map(
          (json) => GameMatch.fromMap(jsonDecode(json) as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Supprime un match et tous ses événements associés.
  Future<void> deleteMatch(String matchId) async {
    _assertInitialized();
    await _matchesBox.delete(matchId);
    final eventsToDelete =
        _eventsBox.keys
            .where((key) => (key as String).startsWith('${matchId}_'))
            .toList();
    await _eventsBox.deleteAll(eventsToDelete);
  }

  // ─────────────── EVENTS ───────────────

  /// Sauvegarde un événement de match.
  Future<void> saveEvent(String matchId, GameEvent event) async {
    _assertInitialized();
    final key = '${matchId}_${event.id}';
    final json = jsonEncode(event.toMap());
    await _eventsBox.put(key, json);
  }

  /// Récupère tous les événements d'un match, triés chronologiquement.
  List<GameEvent> getEventsForMatch(String matchId) {
    _assertInitialized();
    final prefix = '${matchId}_';
    return _eventsBox.keys
        .where((key) => (key as String).startsWith(prefix))
        .map((key) {
          final json = _eventsBox.get(key)!;
          return GameEvent.fromMap(jsonDecode(json) as Map<String, dynamic>);
        })
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Supprime un événement spécifique.
  Future<void> deleteEvent(String matchId, String eventId) async {
    _assertInitialized();
    await _eventsBox.delete('${matchId}_$eventId');
  }

  // ─────────────── SETTINGS (IA & CONFIG) ───────────────

  /// Récupère la clé API Gemini configurée par l'utilisateur.
  String? getApiKey() {
    _assertInitialized();
    final key = _settingsBox.get(_SettingKeys.apiKey);
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  /// Sauvegarde la clé API Gemini de l'utilisateur.
  Future<void> saveApiKey(String key) async {
    _assertInitialized();
    await _settingsBox.put(_SettingKeys.apiKey, key.trim());
  }

  /// Récupère le modèle IA sélectionné par l'utilisateur (défaut : gemini-2.5-flash).
  String getAiModel() {
    _assertInitialized();
    final model = _settingsBox.get(_SettingKeys.aiModel);
    if (model == null || model.trim().isEmpty) return 'gemini-2.5-flash';
    return model.trim();
  }

  /// Sauvegarde le modèle IA préféré de l'utilisateur.
  Future<void> saveAiModel(String model) async {
    _assertInitialized();
    await _settingsBox.put(_SettingKeys.aiModel, model.trim());
  }

  /// Indique si l'utilisateur a déjà vu le dialogue d'onboarding IA.
  bool hasSeenAiOnboarding() {
    _assertInitialized();
    return _settingsBox.get(_SettingKeys.hasSeenOnboarding) == 'true';
  }

  /// Marque l'onboarding IA comme vu.
  Future<void> setAiOnboardingSeen([bool seen = true]) async {
    _assertInitialized();
    await _settingsBox.put(
      _SettingKeys.hasSeenOnboarding,
      seen ? 'true' : 'false',
    );
  }

  /// Vérifie si l'IA est configurée avec une clé valide.
  bool isAiConfigured() {
    final key = getApiKey();
    return key != null &&
        key.isNotEmpty &&
        !key.contains('your_gemini_api_key');
  }

  /// Récupère le moteur vocal actif : 'local' ou 'gemini'.
  /// Si non spécifié, utilise 'gemini' si une clé est configurée, sinon 'local'.
  String getVoiceEngine() {
    _assertInitialized();
    final engine = _settingsBox.get(_SettingKeys.voiceEngine);
    if (engine != null && engine.isNotEmpty) {
      return engine;
    }
    return isAiConfigured() ? 'gemini' : 'local';
  }

  /// Enregistre le moteur vocal choisi ('local' ou 'gemini').
  Future<void> saveVoiceEngine(String engine) async {
    _assertInitialized();
    await _settingsBox.put(
      _SettingKeys.voiceEngine,
      engine.trim().toLowerCase(),
    );
  }

  /// Indique si le mode vocal actif est le mode local (sans IA).
  bool get isLocalVoiceMode => getVoiceEngine() == 'local';

  /// Récupère la langue active de l'application ('en' par défaut).
  String getLanguageCode() {
    _assertInitialized();
    final lang = _settingsBox.get(_SettingKeys.language);
    if (lang != null && (lang == 'en' || lang == 'fr')) {
      return lang;
    }
    return 'en'; // Anglais par défaut
  }

  /// Sauvegarde la langue sélectionnée ('en' ou 'fr').
  Future<void> saveLanguageCode(String languageCode) async {
    _assertInitialized();
    final code = languageCode.trim().toLowerCase();
    if (code == 'en' || code == 'fr') {
      await _settingsBox.put(_SettingKeys.language, code);
    }
  }

  /// Efface la configuration IA (pour tests ou réinitialisation).
  Future<void> clearAiConfig() async {
    _assertInitialized();
    await _settingsBox.delete(_SettingKeys.apiKey);
    await _settingsBox.delete(_SettingKeys.aiModel);
    await _settingsBox.delete(_SettingKeys.voiceEngine);
  }

  // ─────────────── HELPERS ───────────────

  void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'StorageService non initialisé. Appelez init() en premier.',
      );
    }
  }

  /// Ferme les boîtes Hive.
  Future<void> dispose() async {
    await _matchesBox.close();
    await _eventsBox.close();
    await _settingsBox.close();
    _initialized = false;
  }
}
