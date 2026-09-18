import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';

/// Réponse parsée de Gemini NLP.
class ParsedVoiceCommand {
  const ParsedVoiceCommand({
    required this.type,
    required this.teamName,
    this.transcription = '',
    this.playerName,
    this.secondaryPlayerName,
    this.minute,
    this.notes,
    this.correctionAction,
    this.isPenalty = false,
    this.points,
    this.matchControl,
  });

  final String transcription;
  final GameEventType type;
  final String teamName; // Nom de l'équipe (tel que détecté)
  final String? playerName;
  final String? secondaryPlayerName; // Passeur, remplaçant entrant...
  final int? minute;
  final String? notes;
  final String? correctionAction; // 'undo_last' etc.
  final bool isPenalty;
  final int? points;
  final String? matchControl; // 'pause', 'resume', 'halftime', 'end_match'

  factory ParsedVoiceCommand.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'unknown';
    final type = GameEventType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => GameEventType.unknown,
    );

    return ParsedVoiceCommand(
      transcription: json['transcription'] as String? ?? '',
      type: type,
      teamName: json['team'] as String? ?? '',
      playerName: json['player'] as String?,
      secondaryPlayerName: json['secondary_player'] as String?,
      minute: json['minute'] as int?,
      notes: json['notes'] as String?,
      correctionAction: json['correction_action'] as String?,
      isPenalty: json['is_penalty'] as bool? ?? false,
      points: json['points'] as int?,
      matchControl: json['match_control'] as String?,
    );
  }

  @override
  String toString() =>
      'ParsedVoiceCommand(transcription: "$transcription", type: $type, team: $teamName, player: $playerName, control: $matchControl)';
}

/// Service d'intégration avec la Gemini API.
/// Traite l'audio directement en une seule passe multimodale intelligente.
class GeminiService {
  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  final String _apiKey;

  // Modèles avec fallback automatique en cascade (par ordre de rapidité et stabilité)
  static const List<String> _models = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-1.5-flash',
  ];
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Traite directement un fichier audio et extrait l'événement structuré.
  Future<ParsedVoiceCommand> processAudioCommand({
    required Uint8List audioBytes,
    required String mimeType,
    required GameMatch match,
  }) async {
    if (_apiKey.isEmpty || _apiKey.contains('your_gemini_api_key')) {
      throw const GeminiException(
        'Clé API Gemini manquante. Veuillez renseigner GEMINI_API_KEY dans le fichier .env',
      );
    }

    final base64Audio = base64Encode(audioBytes);
    final systemPrompt = _buildSystemPrompt(match);
    final responseSchema = _buildResponseSchema();

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Audio,
              }
            },
            {
              'text':
                  'Écoute attentivement cet enregistrement audio en français. '
                  'Transcris exactement ce qui est dit dans le champ "transcription", '
                  'puis analyse l\'événement de match pour remplir les champs structurés JSON.',
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
      },
    });

    return _executeWithFallback(body);
  }

  /// Parse une commande textuelle directe (pour le fallback ou test sans micro).
  Future<ParsedVoiceCommand> parseTextCommand({
    required String text,
    required GameMatch match,
  }) async {
    if (_apiKey.isEmpty || _apiKey.contains('your_gemini_api_key')) {
      throw const GeminiException(
        'Clé API Gemini manquante. Veuillez renseigner GEMINI_API_KEY dans le fichier .env',
      );
    }

    final systemPrompt = _buildSystemPrompt(match);
    final responseSchema = _buildResponseSchema();

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Analyse cette commande : "$text". '
                  'Remplis "transcription" avec ce texte et remplis les champs structurés JSON.',
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
      },
    });

    return _executeWithFallback(body);
  }

  /// Exécute l'appel API avec retry exponentiel sur 429/503 et bascule de modèle.
  Future<ParsedVoiceCommand> _executeWithFallback(String requestBody) async {
    Exception? lastException;
    bool hitRateLimit = false;

    for (final model in _models) {
      final uri = Uri.parse('$_baseUrl/models/$model:generateContent?key=$_apiKey');

      // Jusqu'à 2 essais par modèle (retry après 800ms en cas de 429/503)
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final jsonText = _extractText(data);
            final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
            return ParsedVoiceCommand.fromJson(parsed);
          }

          // Si 429 (Quota/Rate Limit) ou 503 (Serveur saturé)
          if (response.statusCode == 429 || response.statusCode == 503) {
            hitRateLimit = true;
            if (attempt == 1) {
              await Future.delayed(const Duration(milliseconds: 800));
              continue; // Réessayer une 2e fois ce même modèle
            }
            // Passer au modèle suivant
            lastException = GeminiException(
              'Modèle $model surchargé (${response.statusCode})',
            );
            break;
          }

          // Si 404 (Modèle non disponible) ou 500/502/504 (Erreur temporaire)
          if (response.statusCode == 404 || response.statusCode >= 500) {
            lastException = GeminiException('Modèle $model indisponible (${response.statusCode})');
            break; // Passer au modèle suivant
          }

          // Autre erreur client (ex: 400 mauvaise requête)
          final errorBody = response.body;
          throw GeminiException(
            'Erreur API ($model: ${response.statusCode}) : $errorBody',
          );
        } catch (e) {
          if (e is GeminiException && e.message.contains('Erreur API ($model: 400)')) {
            rethrow;
          }
          lastException = e is Exception ? e : Exception(e.toString());
          if (attempt == 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
    }

    if (hitRateLimit) {
      throw const GeminiException(
        '⚠️ Quota Gemini saturé (429/503). Veuillez patienter quelques secondes avant de reparler.',
      );
    }

    throw lastException ?? const GeminiException('Échec du traitement IA');
  }

  /// Construit le prompt système avec le contexte du match.
  String _buildSystemPrompt(GameMatch match) {
    final teamAPlayers = match.teamA.players
        .map((p) => p.shortLabel)
        .join(', ');
    final teamBPlayers = match.teamB.players
        .map((p) => p.shortLabel)
        .join(', ');

    return '''
Tu es un arbitre et scoreur sportif intelligent assistant en direct pendant un match.
Tu reçois des commandes vocales ou textuelles courtes en français d'un joueur, arbitre ou coach (souvent depuis une montre Pixel Watch ou un smartphone au bord du terrain).
Tu dois comprendre l'intention et extraire l'événement ou le contrôle du match sous forme de JSON strict.

## Contexte du match en cours
- Sport : ${match.sport.label}
- Équipe A (Équipe 1 / Domicile / Rouge / Nous) : "${match.teamA.name}" (couleur: ${match.teamA.color ?? 'rouge'})${teamAPlayers.isNotEmpty ? ', joueurs: $teamAPlayers' : ''}
- Équipe B (Équipe 2 / Extérieur / Bleu / Eux) : "${match.teamB.name}" (couleur: ${match.teamB.color ?? 'bleu'})${teamBPlayers.isNotEmpty ? ', joueurs: $teamBPlayers' : ''}
- Minute actuelle du match : ${match.currentMinute}'

## Types d'événements autorisés (${match.sport.label})
${match.sport.availableEvents.map((e) => '- "${e.name}": ${e.label}').join('\n')}
- "correction": Pour annuler le dernier événement ou corriger une erreur (ex: "annule", "pas but", "enlève le point")
- "unknown": Si aucun son ou aucune parole compréhensible n'est détectée.

## Contrôles du match (match_control)
Si la commande demande de gérer le chronomètre ou l'état du match :
- "pause" : "pause", "mets en pause", "stop le chrono", "temps mort"
- "resume" : "reprends", "play", "relance", "reprise"
- "halftime" : "mi-temps", "c'est la mi-temps"
- "end_match" : "fin du match", "match terminé", "coup de sifflet final"

## Règles de compréhension
1. "transcription" : Transcription exacte du français parlé. Sois fidèle même si c'est très court (ex: "But !", "1-0", "Pause").
2. "type" : Type d'événement ("goal", "yellowCard", "redCard", "foul", "substitution", "timeout", "correction", "unknown").
3. "team" : Résous l'équipe avec bon sens :
   - "nous", "pour nous", "les nôtres", "équipe 1", "équipe A", "rouge" → "${match.teamA.name}"
   - "eux", "les autres", "équipe 2", "équipe B", "bleu" → "${match.teamB.name}"
   - Si un joueur est nommé, associe à son équipe si connue parmi les effectifs.
   - Si l'équipe n'est pas précisée (ex: "But de Karim" ou juste "But !"), mets "${match.teamA.name}".
4. "player" : Nom du joueur principal (buteur, fautif, carton...).
   Ex: "but équipe A stéphane" → player="stéphane".
5. "secondary_player" : Nom du passeur décisif ("assisté par X", "assist X", "passe de X") ou remplaçant entrant.
   Ex: "assist nabil" ou "assisté par nabil" → secondary_player="nabil".
6. "points" : Valeur des points (Foot/Hand=1, Basket=2 ou 3 si tir à 3 points, Rugby essai=5, transfo=2).
7. "correction_action" : "undo_last" pour annuler le dernier événement.

## Exemples d'interprétation
- "but équipe A stéphane assist nabil" → transcription="but équipe A stéphane assist nabil", type="goal", team="${match.teamA.name}", player="stéphane", secondary_player="nabil", points=1
- "but pour les rouges par Stéphane assisté de Nabil" → transcription="but pour les rouges par Stéphane assisté de Nabil", type="goal", team="${match.teamA.name}", player="Stéphane", secondary_player="Nabil", points=1
- "But de Thomas" → transcription="But de Thomas", type="goal", team="${match.teamA.name}", player="Thomas", points=1
- "But !" → transcription="But !", type="goal", team="${match.teamA.name}", points=1
- "1-0" ou "On a marqué" → transcription="1-0", type="goal", team="${match.teamA.name}", points=1
- "But pour les bleus par Cédric" → transcription="But pour les bleus par Cédric", type="goal", team="${match.teamB.name}", player="Cédric", points=1
- "Panier à trois points de Lucas" → transcription="Panier à trois points de Lucas", type="goal", team="${match.teamA.name}", player="Lucas", points=3
- "Carton jaune pour le numéro 7" → transcription="Carton jaune pour le numéro 7", type="yellowCard", team="${match.teamA.name}", player="#7"
- "Faute" → transcription="Faute", type="foul", team="${match.teamA.name}"
- "Annule le but" ou "Pas but" → transcription="Annule le but", type="correction", team="${match.teamA.name}", correction_action="undo_last"
- "Pause" ou "Mets sur pause" → transcription="Pause", type="unknown", team="${match.teamA.name}", match_control="pause"
- "Mi-temps" → transcription="Mi-temps", type="unknown", team="${match.teamA.name}", match_control="halftime"
- "Fin du match" → transcription="Fin du match", type="unknown", team="${match.teamA.name}", match_control="end_match"
''';
  }

  /// Schéma JSON pour la sortie structurée de Gemini.
  Map<String, dynamic> _buildResponseSchema() {
    return {
      'type': 'OBJECT',
      'properties': {
        'transcription': {
          'type': 'STRING',
          'description': 'Transcription textuelle exacte de la voix en français',
        },
        'type': {
          'type': 'STRING',
          'enum': GameEventType.values.map((e) => e.name).toList(),
          'description': 'Type d\'événement sportif',
        },
        'team': {
          'type': 'STRING',
          'description': 'Nom ou couleur de l\'équipe concernée',
        },
        'player': {
          'type': 'STRING',
          'description': 'Nom du joueur principal (buteur, fautif...)',
        },
        'secondary_player': {
          'type': 'STRING',
          'description': 'Nom du joueur secondaire (passeur, remplaçant entrant...)',
        },
        'minute': {
          'type': 'INTEGER',
          'description': 'Minute du match si mentionnée',
        },
        'is_penalty': {
          'type': 'BOOLEAN',
          'description': 'Vrai si c\'est un penalty/lancer franc',
        },
        'points': {
          'type': 'INTEGER',
          'description': 'Nombre de points marqués',
        },
        'correction_action': {
          'type': 'STRING',
          'description': 'Action de correction: "undo_last"',
        },
        'match_control': {
          'type': 'STRING',
          'description': 'Contrôle match : "pause", "resume", "halftime", "end_match"',
        },
        'notes': {
          'type': 'STRING',
          'description': 'Informations supplémentaires éventuelles',
        },
      },
      'required': ['transcription', 'type', 'team'],
    };
  }

  /// Extrait le texte de la réponse Gemini.
  String _extractText(Map<String, dynamic> data) {
    final candidates =
        data['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) {
      throw const GeminiException('Aucune réponse générée par l\'IA');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>? ?? {};
    final parts = content['parts'] as List<dynamic>? ?? [];
    if (parts.isEmpty) {
      throw const GeminiException('Réponse vide de l\'IA');
    }
    return parts[0]['text'] as String? ?? '';
  }
}

/// Exception spécifique au service Gemini.
class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;

  @override
  String toString() => 'GeminiException: $message';
}
