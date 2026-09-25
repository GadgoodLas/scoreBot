import 'package:uuid/uuid.dart';
import 'package:score_bot/domain/models/match.dart';

/// Parseur intelligent pour extraire les joueurs et leurs numéros de maillot
/// à partir d'une dictée vocale ou d'une saisie texte.
class LineupParser {
  const LineupParser();

  static const _uuid = Uuid();

  /// Parse un texte de composition en liste de [Player].
  ///
  /// Gère de multiples syntaxes vocales et textuelles, par exemple :
  /// - "numéro 10 Messi, numéro 7 Mbappé, numéro 9 Benzema"
  /// - "numéro 10 Messi numéro 7 Mbappé" (sans virgule)
  /// - "10 Messi, 7 Mbappé, 8 Paul"
  /// - "le 10 Karim et le 7 Cristiano"
  /// - "gardien 1 Lloris, 4 Varane, 10 Zidane"
  /// - "Messi, Neymar, Mbappé" (sans numéros)
  /// - "10 - Messi; 7 - Mbappé"
  static List<Player> parse(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return [];

    final players = <Player>[];
    final existingNumbers = <int>{};
    final existingNames = <String>{};

    // Nettoyage préalable : supprimer mots de remplissage initiaux comme
    // "voici la composition", "les joueurs sont", etc.
    final clean = text
        .replaceAll(
          RegExp(
            r'^(?:voici\s+(?:la\s+)?composition|les\s+joueurs\s+sont|composition\s*:?)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // 1. Essai d'extraction séquentielle avec regex pour les motifs avec numéro :
    // (dossard|gardien|numéro|numero|n°|#|le)? <chiffre> <nom>
    final pattern = RegExp(
      r"(?:(?:dossard|gardien|num[eé]ro|numero|number|n°|#|\ble\b)\s*)?(\d{1,2})\s*[:\-\.]?\s*([a-zA-ZÀ-ÿ\s'-]+?)(?=(?:,|\.|\n|;|\bet\b|\band\b|(?:dossard|gardien|num[eé]ro|number|n°|#|\ble\b)\s*\d{1,2}\b|\b\d{1,2}\s+[a-zA-ZÀ-ÿ]|$))",
      caseSensitive: false,
    );

    final matches = pattern.allMatches(clean).toList();

    if (matches.isNotEmpty) {
      for (final m in matches) {
        final numStr = m.group(1);
        final nameStr = m.group(2)?.trim();

        if (nameStr != null && nameStr.isNotEmpty) {
          final cleanName = _cleanPlayerName(nameStr);
          if (cleanName.isNotEmpty) {
            final number = numStr != null ? int.tryParse(numStr) : null;
            final normKey = cleanName.toLowerCase();

            if (!existingNames.contains(normKey)) {
              existingNames.add(normKey);
              if (number != null) existingNumbers.add(number);

              players.add(
                Player(
                  id: _uuid.v4(),
                  name: cleanName,
                  number: number,
                ),
              );
            }
          }
        }
      }
    }

    // 2. Si aucune correspondance avec numéro ou s'il reste des éléments
    // séparés par des virgules/points-virgules/retours à la ligne :
    if (players.isEmpty) {
      final segments = clean.split(RegExp(r'[,;\n]|\bet\b|\band\b'));
      for (var segment in segments) {
        segment = segment.trim();
        if (segment.isEmpty) continue;

        // Vérifier si le segment a un numéro au début : "10 Messi" ou "#10 Messi" ou "numéro 10 Messi"
        final leadingNum = RegExp(
          r'^(?:(?:dossard|gardien|num[eé]ro|number|n°|#|\ble\b)\s*)?(\d{1,2})\s*[:\-\.]?\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(segment);

        // Vérifier si le segment a un numéro à la fin : "Messi 10" ou "Messi #10"
        final trailingNum = RegExp(
          r'^(.*?)\s+(?:(?:dossard|gardien|num[eé]ro|number|n°|#|\ble\b)\s*)?(\d{1,2})$',
          caseSensitive: false,
        ).firstMatch(segment);

        if (leadingNum != null &&
            leadingNum.group(2) != null &&
            leadingNum.group(2)!.trim().isNotEmpty) {
          final numVal = int.tryParse(leadingNum.group(1)!);
          final nameVal = _cleanPlayerName(leadingNum.group(2)!);
          if (nameVal.isNotEmpty && !existingNames.contains(nameVal.toLowerCase())) {
            existingNames.add(nameVal.toLowerCase());
            players.add(
              Player(id: _uuid.v4(), name: nameVal, number: numVal),
            );
          }
        } else if (trailingNum != null &&
            trailingNum.group(1) != null &&
            trailingNum.group(1)!.trim().isNotEmpty) {
          final numVal = int.tryParse(trailingNum.group(2)!);
          final nameVal = _cleanPlayerName(trailingNum.group(1)!);
          if (nameVal.isNotEmpty && !existingNames.contains(nameVal.toLowerCase())) {
            existingNames.add(nameVal.toLowerCase());
            players.add(
              Player(id: _uuid.v4(), name: nameVal, number: numVal),
            );
          }
        } else {
          final cleanName = _cleanPlayerName(segment);
          if (cleanName.isNotEmpty && !existingNames.contains(cleanName.toLowerCase())) {
            existingNames.add(cleanName.toLowerCase());
            players.add(
              Player(id: _uuid.v4(), name: cleanName),
            );
          }
        }
      }
    }

    return players;
  }

  /// Nettoie le nom d'un joueur des mots parasites et capitalise proprement.
  static String _cleanPlayerName(String input) {
    var str = input.trim();

    // Enlever d'éventuels préfixes ou suffixes résiduels
    str = str.replaceAll(
      RegExp(r'^(?:et\s+|and\s+|le\s+|la\s+|dossard\s+|num[eé]ro\s+)', caseSensitive: false),
      '',
    );
    str = str.replaceAll(
      RegExp(r'(?:\s+et|\s+and)$', caseSensitive: false),
      '',
    );
    str = str.trim();

    if (str.isEmpty) return '';

    // Capitaliser chaque mot (ex: "kylian mbappé" -> "Kylian Mbappé")
    return str.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');
  }
}
