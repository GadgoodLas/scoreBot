import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/game_event.dart';

/// Noms des boites Hive.
class _BoxNames {
  static const matches = 'matches';
  static const events = 'events';
}

/// Service de persistance locale utilisant Hive.
class StorageService {
  late Box<String> _matchesBox;
  late Box<String> _eventsBox;

  bool _initialized = false;

  /// Initialise Hive et ouvre les boîtes de stockage.
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _matchesBox = await Hive.openBox<String>(_BoxNames.matches);
    _eventsBox = await Hive.openBox<String>(_BoxNames.events);
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
        .map((json) =>
            GameMatch.fromMap(jsonDecode(json) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Supprime un match et tous ses événements associés.
  Future<void> deleteMatch(String matchId) async {
    _assertInitialized();
    await _matchesBox.delete(matchId);
    final eventsToDelete = _eventsBox.keys
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
          return GameEvent.fromMap(
            jsonDecode(json) as Map<String, dynamic>,
          );
        })
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Supprime un événement spécifique.
  Future<void> deleteEvent(String matchId, String eventId) async {
    _assertInitialized();
    await _eventsBox.delete('${matchId}_$eventId');
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
    _initialized = false;
  }
}
