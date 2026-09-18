import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:score_bot/data/services/storage_service.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/domain/models/game_event.dart';

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
  GeminiService({
    StorageService? storageService,
    String? apiKey,
    String? preferredModel,
  })  : _storageService = storageService,
        _explicitApiKey = apiKey,
        _preferredModel = preferredModel ?? '';

  final StorageService? _storageService;
  String? _explicitApiKey;
  String _preferredModel;

  /// Clé API effective : clé explicite en mémoire > clé Hive > clé .env
  String get apiKey {
    if (_explicitApiKey != null && _explicitApiKey!.trim().isNotEmpty) {
      return _explicitApiKey!.trim();
    }
    final savedKey = _storageService?.getApiKey();
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      return savedKey.trim();
    }
    if (dotenv.isInitialized) {
      return (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    }
    return '';
  }

  /// Modèle préféré effectif : modèle en mémoire > modèle Hive > défaut (gemini-2.5-flash)
  String get preferredModel {
    if (_preferredModel.trim().isNotEmpty) {
      return _preferredModel.trim();
    }
    final savedModel = _storageService?.getAiModel();
    if (savedModel != null && savedModel.trim().isNotEmpty) {
      return savedModel.trim();
    }
    return 'gemini-2.5-flash';
  }

  /// Indique si une clé API valide est configurée.
  bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.contains('your_gemini_api_key');

  /// Met à jour la configuration en mémoire (prise d'effet immédiate).
  void updateConfig({String? apiKey, String? preferredModel}) {
    if (apiKey != null) _explicitApiKey = apiKey.trim();
    if (preferredModel != null) _preferredModel = preferredModel.trim();
  }

  // Modèles par défaut avec fallback automatique en cascade
  static const List<String> _defaultFallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-1.5-flash',
  ];

  /// Liste ordonnée des modèles à essayer, en commençant par le modèle choisi.
  List<String> get candidateModels {
    final list = <String>[];
    final pref = preferredModel.trim();
    if (pref.isNotEmpty) {
      list.add(pref);
    }
    for (final m in _defaultFallbackModels) {
      if (!list.contains(m)) {
        list.add(m);
      }
    }
    return list;
  }

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Valide une clé API et un modèle en effectuant une requête de test légère.
  static Future<bool> validateApiKey({
    required String apiKey,
    required String model,
  }) async {
    final cleanKey = apiKey.trim();
    final cleanModel = model.trim();

    if (cleanKey.isEmpty || cleanKey.contains('your_gemini_api_key')) {
      throw const GeminiException('La clé API fournie est vide ou invalide.');
    }

    final uri = Uri.parse(
      '$_baseUrl/models/$cleanModel:generateContent?key=$cleanKey',
    );

    final testBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': 'ping'},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 5,
      },
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: testBody,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 400) {
        throw const GeminiException('Clé API ou modèle invalide (Erreur 400).');
      } else if (response.statusCode == 403) {
        throw const GeminiException('Accès refusé. Vérifiez votre clé API (Erreur 403).');
      } else if (response.statusCode == 404) {
        throw GeminiException('Le modèle "$cleanModel" est introuvable (Erreur 404).');
      } else if (response.statusCode == 429) {
        // En cas de 429, la clé est reconnue même si le quota instantané est atteint
        return true;
      } else {
        throw GeminiException('Erreur de validation (${response.statusCode}) : ${response.body}');
      }
    } on TimeoutException {
      throw const GeminiException('Délai d\'attente dépassé (Timeout). Vérifiez votre connexion.');
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Impossible de contacter Gemini : $e');
    }
  }

  /// Traite directement un fichier audio et extrait l'événement structuré.
  Future<ParsedVoiceCommand> processAudioCommand({
    required Uint8List audioBytes,
    required String mimeType,
    required GameMatch match,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(
        'Clé API Gemini non configurée. Veuillez renseigner votre clé API dans les paramètres.',
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
    if (!isConfigured) {
      throw const GeminiException(
        'Clé API Gemini non configurée. Veuillez renseigner votre clé API dans les paramètres.',
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

  /// Génère un compte-rendu journalistique du match en français.
  Future<String> generateMatchReport({
    required GameMatch match,
    required List<GameEvent> events,
  }) async {
    if (!isConfigured) {
      throw const GeminiException('Clé API Gemini non configurée');
    }

    final eventsSummary = StringBuffer();
    for (final e in events) {
      final team = e.teamId == match.teamA.id ? match.teamA.name : match.teamB.name;
      final desc = switch (e) {
        GoalEvent(:final scorerName, :final assistName, :final points) =>
          '${e.minute}\' : But/Point ($points pts) de $scorerName'
              '${assistName != null ? " (passe: $assistName)" : ""} pour $team',
        CardEvent(:final playerName) =>
          '${e.minute}\' : ${e.type.label} pour $playerName ($team)',
        FoulEvent(:final playerName) =>
          '${e.minute}\' : Faute de $playerName ($team)',
        _ => '${e.minute}\' : ${e.type.label} ($team)',
      };
      eventsSummary.writeln('- $desc');
    }

    final prompt = '''
Tu es un journaliste sportif passionné et rigoureux.
Rédige un compte-rendu vivant, fluide et captivant du match suivant en français (entre 120 et 200 mots).
Structure le texte avec :
1. Un titre dynamique avec des émojis
2. Une introduction percutante résumant l'issue de la rencontre
3. Les tournants majeurs et actions décisives
4. Une mise en lumière du joueur du match et de l'état d'esprit des équipes

Détails du match :
- Sport : ${match.sport.label}
- Affiche : ${match.teamA.name} contre ${match.teamB.name}
- Score final : ${match.teamA.name} ${match.scoreA} — ${match.scoreB} ${match.teamB.name}
- Événements marquants chronologiques :
${eventsSummary.isNotEmpty ? eventsSummary.toString() : "- Aucun événement majeur enregistré"}

Rédige directement le compte-rendu en texte brut soigné avec quelques sauts de ligne et émojis adaptés.
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
      },
    });

    final currentKey = apiKey;
    for (final model in candidateModels) {
      final uri = Uri.parse('$_baseUrl/models/$model:generateContent?key=$currentKey');
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final text = _extractText(data);
            if (text.trim().isNotEmpty) {
              return text.trim();
            }
          }

          if (response.statusCode == 429 || response.statusCode == 503) {
            if (attempt == 1) {
              await Future.delayed(const Duration(milliseconds: 800));
              continue;
            }
            break;
          }

          if (response.statusCode == 404 || response.statusCode >= 500) {
            break;
          }
        } catch (_) {
          // Continuer avec le modèle suivant
        }
      }
    }

    throw const GeminiException('Impossible de générer le rapport avec les modèles disponibles');
  }

  /// Exécute l'appel API avec retry exponentiel sur 429/503 et bascule de modèle.
  Future<ParsedVoiceCommand> _executeWithFallback(String requestBody) async {
    Exception? lastException;
    bool hitRateLimit = false;
    final currentKey = apiKey;

    for (final model in candidateModels) {
      final uri = Uri.parse('$_baseUrl/models/$model:generateContent?key=$currentKey');

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
