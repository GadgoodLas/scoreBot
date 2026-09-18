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
    );
  }

  @override
  String toString() =>
      'ParsedVoiceCommand(transcription: "$transcription", type: $type, team: $teamName, player: $playerName)';
}

/// Service d'intégration avec la Gemini API.
/// Traite l'audio directement en une seule passe multimodale intelligente.
class GeminiService {
  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  final String _apiKey;

  // Modèles avec fallback automatique (gemini-3.6-flash et gemini-3.5-flash)
  static const List<String> _models = [
    'gemini-3.6-flash',
    'gemini-3.5-flash',
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

    Exception? lastException;

    for (final model in _models) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/models/$model:generateContent?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
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
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final jsonText = _extractText(data);
          final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
          return ParsedVoiceCommand.fromJson(parsed);
        } else if (response.statusCode == 404) {
          // Essayer le modèle suivant
          lastException = GeminiException('Modèle $model indisponible (404)');
          continue;
        } else {
          final errorBody = response.body;
          throw GeminiException(
            'Erreur API ($model: ${response.statusCode}) : $errorBody',
          );
        }
      } catch (e) {
        if (e is GeminiException && !e.message.contains('404')) {
          rethrow;
        }
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    throw lastException ?? const GeminiException('Échec du traitement IA');
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

    for (final model in _models) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/models/$model:generateContent?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
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
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final jsonText = _extractText(data);
          final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
          return ParsedVoiceCommand.fromJson(parsed);
        } else if (response.statusCode == 404) {
          continue;
        } else {
          throw GeminiException(
            'Erreur API ($model: ${response.statusCode}) : ${response.body}',
          );
        }
      } catch (e) {
        if (e is GeminiException && !e.message.contains('404')) {
          rethrow;
        }
      }
    }

    throw const GeminiException('Échec de l\'analyse texte');
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
Tu es un assistant arbitre/scoreur sportif intelligent en direct pour un match.
Tu reçois des commandes vocales ou textuelles d'un joueur ou arbitre et tu dois extraire l'événement de jeu sous forme de JSON strict.

## Contexte du match en cours
- Sport : ${match.sport.label}
- Équipe A : "${match.teamA.name}" (couleur: ${match.teamA.color ?? 'non spécifiée'})${teamAPlayers.isNotEmpty ? ', joueurs: $teamAPlayers' : ''}
- Équipe B : "${match.teamB.name}" (couleur: ${match.teamB.color ?? 'non spécifiée'})${teamBPlayers.isNotEmpty ? ', joueurs: $teamBPlayers' : ''}
- Minute actuelle du match : ${match.currentMinute}'

## Types d'événements autorisés pour ce sport (${match.sport.label})
${match.sport.availableEvents.map((e) => '- "${e.name}": ${e.label}').join('\n')}
- "correction": Pour annuler le dernier événement ou corriger une erreur
- "unknown": Si aucune parole claire ou aucun événement sportif n'est reconnu

## Règles de parsing
1. "transcription" : Contient la transcription exacte du texte prononcé en français.
2. "type" : Le type d'événement parmi la liste autorisée. Si rien n'a été dit ou si c'est inaudible, mets "unknown".
3. "team" : Le nom ou la couleur de l'équipe concernée (ex: "${match.teamA.name}" ou "${match.teamA.color ?? 'A'}").
4. "player" : Nom du joueur principal (buteur, fautif, joueur recevant un carton...).
5. "secondary_player" : Nom du passeur décisif ("assisté par X") ou joueur entrant lors d'un changement.
6. "is_penalty" : true si la voix mentionne un penalty ou coup franc direct transformé.
7. "points" : Pour basket (2 ou 3 points), rugby (5 pour essai, 2 pour transformation), hand/foot (1 par défaut).
8. "correction_action" : "undo_last" si l'utilisateur demande d'annuler ou supprimer le dernier but/événement.

## Exemples
Audio: "But pour l'équipe rouge par Cedric assisté par Nabil"
→ transcription="But pour l'équipe rouge par Cedric assisté par Nabil", type="goal", team="rouge", player="Cedric", secondary_player="Nabil", points=1

Audio: "Carton jaune pour le joueur numéro 10 de l'équipe bleue"  
→ transcription="Carton jaune pour le joueur numéro 10 de l'équipe bleue", type="yellowCard", team="bleue", player="#10"

Audio: "Annule le dernier but"
→ transcription="Annule le dernier but", type="correction", team="${match.teamA.name}", correction_action="undo_last"
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
