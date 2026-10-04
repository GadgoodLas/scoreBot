import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';

/// Type de message échangé entre le Smartphone et la Montre Wear OS.
enum WearSyncMessageType {
  /// Synchronisation complète du match (démarrage ou rafraîchissement)
  matchState,

  /// Mise à jour rapide des scores (A / B)
  scoreUpdate,

  /// Nouvel événement enregistré (but, carton, faute...)
  eventRecorded,

  /// Commande de contrôle du match (pause, resume, halftime, finish)
  matchControl,
}

/// Service de communication bidirectionnelle entre Smartphone et Wear OS
/// via l'API native Wearable MessageClient (Bluetooth / Wi-Fi local).
class WatchConnectivityService {
  WatchConnectivityService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  static const String _channelName = 'com.scorebot.score_bot/wearable';
  static const String _pathMatchSync = '/match/sync';

  final MethodChannel _channel;

  // StreamControllers pour diffuser les événements reçus aux ViewModels
  final _matchStateController = StreamController<GameMatch>.broadcast();
  final _scoreUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _eventController = StreamController<GameEvent>.broadcast();
  final _controlController = StreamController<String>.broadcast();

  Stream<GameMatch> get onMatchStateReceived => _matchStateController.stream;
  Stream<Map<String, dynamic>> get onScoreUpdateReceived =>
      _scoreUpdateController.stream;
  Stream<GameEvent> get onEventReceived => _eventController.stream;
  Stream<String> get onMatchControlReceived => _controlController.stream;

  bool _hasConnectedNodes = false;
  bool get hasConnectedNodes => _hasConnectedNodes;

  /// Vérifie si des appareils distants (montre ou smartphone) sont actuellement appairés.
  Future<List<Map<String, String>>> checkConnectedNodes() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'checkConnectedNodes',
      );
      if (result != null) {
        final nodes =
            result.map((item) {
              final map = Map<String, dynamic>.from(item as Map);
              return {
                'id': map['id']?.toString() ?? '',
                'displayName': map['displayName']?.toString() ?? '',
              };
            }).toList();
        _hasConnectedNodes = nodes.isNotEmpty;
        return nodes;
      }
    } catch (e) {
      debugPrint('WatchConnectivityService: checkConnectedNodes error: $e');
    }
    _hasConnectedNodes = false;
    return [];
  }

  /// Diffuse l'état complet du match vers l'autre appareil.
  Future<bool> sendMatchState(GameMatch match) async {
    final payload = {
      'type': WearSyncMessageType.matchState.name,
      'match': match.toMap(),
    };
    return _sendPayload(payload);
  }

  /// Diffuse une mise à jour immédiate des scores.
  Future<bool> sendScoreUpdate({
    required String matchId,
    required int scoreA,
    required int scoreB,
  }) async {
    final payload = {
      'type': WearSyncMessageType.scoreUpdate.name,
      'matchId': matchId,
      'scoreA': scoreA,
      'scoreB': scoreB,
    };
    return _sendPayload(payload);
  }

  /// Diffuse un événement de match (but, carton, faute) vers l'autre appareil.
  Future<bool> sendEvent({
    required String matchId,
    required GameEvent event,
    required int scoreA,
    required int scoreB,
  }) async {
    final payload = {
      'type': WearSyncMessageType.eventRecorded.name,
      'matchId': matchId,
      'event': event.toMap(),
      'scoreA': scoreA,
      'scoreB': scoreB,
    };
    return _sendPayload(payload);
  }

  /// Diffuse une commande d'arbitrage (pause, reprise, mi-temps, fin).
  Future<bool> sendMatchControl({
    required String matchId,
    required String action,
  }) async {
    final payload = {
      'type': WearSyncMessageType.matchControl.name,
      'matchId': matchId,
      'action': action,
    };
    return _sendPayload(payload);
  }

  Future<bool> _sendPayload(Map<String, dynamic> payload) async {
    try {
      final jsonStr = jsonEncode(payload);
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendMessage',
        {'path': _pathMatchSync, 'data': jsonStr},
      );
      final delivered = result?['delivered'] == true;
      _hasConnectedNodes = (result?['nodeCount'] as int? ?? 0) > 0;
      return delivered;
    } catch (e) {
      debugPrint('WatchConnectivityService: sendPayload error: $e');
      return false;
    }
  }

  /// Traite les messages entrants provenant de la plateforme Android.
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onMessageReceived') {
      try {
        final arguments = Map<String, dynamic>.from(call.arguments as Map);
        final rawData = arguments['data'] as String?;
        if (rawData == null || rawData.isEmpty) return;

        final decoded = jsonDecode(rawData) as Map<String, dynamic>;
        final typeStr = decoded['type'] as String?;

        if (typeStr == WearSyncMessageType.matchState.name) {
          final matchMap = decoded['match'] as Map<String, dynamic>;
          final match = GameMatch.fromMap(matchMap);
          _matchStateController.add(match);
        } else if (typeStr == WearSyncMessageType.scoreUpdate.name) {
          _scoreUpdateController.add(decoded);
        } else if (typeStr == WearSyncMessageType.eventRecorded.name) {
          final eventMap = decoded['event'] as Map<String, dynamic>;
          final event = GameEvent.fromMap(eventMap);
          _eventController.add(event);
        } else if (typeStr == WearSyncMessageType.matchControl.name) {
          final action = decoded['action'] as String;
          _controlController.add(action);
        }
      } catch (e) {
        debugPrint(
          'WatchConnectivityService: Erreur lors du décodage du message: $e',
        );
      }
    }
  }

  void dispose() {
    _matchStateController.close();
    _scoreUpdateController.close();
    _eventController.close();
    _controlController.close();
  }
}
