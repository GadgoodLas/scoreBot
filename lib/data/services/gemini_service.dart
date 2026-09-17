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
    this.playerName,
    this.secondaryPlayerName,
    this.minute,
    this.notes,
    this.correctionAction,
    this.isPenalty = false,
    this.points,
  });

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
      'ParsedVoiceCommand(type: $type, team: $teamName, player: $playerName)';
}

/// Service d'intégration avec la Gemini API.
/// Gère la transcription audio et le parsing NLP des commandes vocales.
class GeminiService {
  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  final String _apiKey;

  static const _transcribeModel = 'gemini-3.5-transcribe';
  static const _nlpModel = 'gemini-3.8-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Transcrit un fichier audio en texte.
  ///
  /// [audioBytes] : Données audio brutes (WAV, M4A, OGG).
  /// [mimeType] : Type MIME du fichier audio (ex: 'audio/wav').
  Future<String> transcribeAudio(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
  }) async {
    final base64Audio = base64Encode(audioBytes);

    final response = await http.post(
      Uri.parse('$_baseUrl/models/$_transcribeModel:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
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
                    'Transcris exactement ce qui est dit en français. '
                    'Retourne uniquement la transcription, sans ponctuation superflue.',
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiException(
        'Erreur transcription audio: ${response.statusCode} — ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(data);
    return text.trim();
  }

  /// Parse une commande vocale transcrite en événement structuré.
  ///
  /// [transcription] : Texte transcrit (ex: "But pour l'équipe rouge par Cedric")
  /// [match] : Contexte du match en cours pour aider le NLP.
  Future<ParsedVoiceCommand> parseVoiceCommand(
    String transcription,
    GameMatch match,
  ) async {
    final systemPrompt = _buildSystemPrompt(match);
    final responseSchema = _buildResponseSchema();

    final response = await http.post(
      Uri.parse('$_baseUrl/models/$_nlpModel:generateContent?key=$_apiKey'),
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
              {'text': transcription},
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

    if (response.statusCode != 200) {
      throw GeminiException(
        'Erreur NLP parsing: ${response.statusCode} — ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final jsonText = _extractText(data);
    final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    return ParsedVoiceCommand.fromJson(parsed);
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
Tu es un assistant de scoring sportif intelligent. 
Tu dois analyser les commandes vocales d'un utilisateur et les transformer en événements structurés JSON.

## Contexte du match
- Sport : ${match.sport.label}
- Équipe A : "${match.teamA.name}"${teamAPlayers.isNotEmpty ? ' (joueurs: $teamAPlayers)' : ''}
- Équipe B : "${match.teamB.name}"${teamBPlayers.isNotEmpty ? ' (joueurs: $teamBPlayers)' : ''}
- Minute actuelle : ${match.currentMinute}

## Types d'événements disponibles
${match.sport.availableEvents.map((e) => '- ${e.name}: ${e.label}').join('\n')}

## Règles
1. Identifie quel type d'événement est décrit dans la commande vocale.
2. Détermine l'équipe concernée en faisant correspondre les noms (même partiellement, ex: "rouge" → "${match.teamA.name}").
3. Extrais les noms des joueurs mentionnés.
4. Pour un "but assisté par X", X va dans "secondary_player".
5. Pour une correction/annulation, utilise type="correction" et action="undo_last".
6. Si la commande est incompréhensible, utilise type="unknown".
7. Réponds UNIQUEMENT avec le JSON demandé, aucun texte autour.

## Exemples
Commande: "But pour l'équipe rouge par Cedric assisté par Nabil"
→ type=goal, team="rouge", player="Cedric", secondary_player="Nabil"

Commande: "Carton jaune pour le joueur numéro 10 de l'équipe bleue"  
→ type=yellow_card, team="bleue", player="#10"

Commande: "Annule le dernier but"
→ type=correction, correction_action="undo_last"
''';
  }

  /// Schéma JSON pour la sortie structurée de Gemini.
  Map<String, dynamic> _buildResponseSchema() {
    return {
      'type': 'OBJECT',
      'properties': {
        'type': {
          'type': 'STRING',
          'enum': GameEventType.values.map((e) => e.name).toList(),
          'description': 'Type d\'événement sportif',
        },
        'team': {
          'type': 'STRING',
          'description': 'Nom ou identifiant de l\'équipe concernée',
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
          'description': 'Nombre de points (basket: 2 ou 3, rugby: 5 pour essai...)',
        },
        'correction_action': {
          'type': 'STRING',
          'description': 'Action de correction: "undo_last"',
        },
        'notes': {
          'type': 'STRING',
          'description': 'Informations libres non structurées',
        },
      },
      'required': ['type', 'team'],
    };
  }

  /// Extrait le texte de la réponse Gemini.
  String _extractText(Map<String, dynamic> data) {
    final candidates =
        data['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) {
      throw GeminiException('Aucun candidat dans la réponse Gemini');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>? ?? {};
    final parts = content['parts'] as List<dynamic>? ?? [];
    if (parts.isEmpty) {
      throw GeminiException('Aucune partie dans la réponse Gemini');
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
