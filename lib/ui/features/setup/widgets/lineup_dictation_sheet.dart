import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/data/services/lineup_parser.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';

/// Modal bottom sheet pour dicter ou composer vocalement la composition d'une équipe.
class LineupDictationSheet extends StatefulWidget {
  const LineupDictationSheet({
    super.key,
    required this.teamName,
    required this.color,
    required this.initialPlayers,
    required this.startDictation,
    required this.stopDictation,
    required this.onSavePlayers,
  });

  final String teamName;
  final Color color;
  final List<Player> initialPlayers;
  final Future<void> Function({
    required void Function(String text, bool isFinal) onResult,
  })
  startDictation;
  final Future<void> Function() stopDictation;
  final void Function(List<Player>) onSavePlayers;

  static Future<void> show(
    BuildContext context, {
    required String teamName,
    required Color color,
    required List<Player> initialPlayers,
    required Future<void> Function({
      required void Function(String text, bool isFinal) onResult,
    })
    startDictation,
    required Future<void> Function() stopDictation,
    required void Function(List<Player>) onSavePlayers,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => LineupDictationSheet(
            teamName: teamName,
            color: color,
            initialPlayers: initialPlayers,
            startDictation: startDictation,
            stopDictation: stopDictation,
            onSavePlayers: onSavePlayers,
          ),
    );
  }

  @override
  State<LineupDictationSheet> createState() => _LineupDictationSheetState();
}

class _LineupDictationSheetState extends State<LineupDictationSheet>
    with SingleTickerProviderStateMixin {
  late final List<Player> _players;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final _manualNameController = TextEditingController();
  final _manualNumberController = TextEditingController();
  final _uuid = const Uuid();

  bool _isListening = false;
  String _liveTranscription = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _players = List.from(widget.initialPlayers);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Démarrer automatiquement l'écoute vocale à l'ouverture
    _startListening();
  }

  @override
  void dispose() {
    _stopListeningSilently();
    _pulseController.dispose();
    _manualNameController.dispose();
    _manualNumberController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _errorMessage = null;
    });
    _pulseController.repeat(reverse: true);

    try {
      await widget.startDictation(
        onResult: (text, isFinal) {
          if (!mounted) return;
          setState(() {
            _liveTranscription = text;
          });

          // Extraction et mise à jour en temps réel des joueurs détectés
          final parsed = LineupParser.parse(text);
          if (parsed.isNotEmpty) {
            for (final p in parsed) {
              final exists = _players.any(
                (existing) =>
                    existing.name.toLowerCase() == p.name.toLowerCase() ||
                    (p.number != null && existing.number == p.number),
              );
              if (!exists) {
                setState(() {
                  _players.add(p);
                });
              }
            }
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _errorMessage = 'Microphone non disponible : $e';
      });
      _pulseController.stop();
    }
  }

  Future<void> _stopListening() async {
    await _stopListeningSilently();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
    }
  }

  Future<void> _stopListeningSilently() async {
    try {
      await widget.stopDictation();
    } catch (_) {}
  }

  void _addManualPlayer() {
    final name = _manualNameController.text.trim();
    if (name.isEmpty) return;

    final numText = _manualNumberController.text.trim();
    final number = int.tryParse(numText);

    final exists = _players.any(
      (existing) =>
          existing.name.toLowerCase() == name.toLowerCase() ||
          (number != null && existing.number == number),
    );

    if (!exists) {
      setState(() {
        _players.add(Player(id: _uuid.v4(), name: name, number: number));
      });
      _manualNameController.clear();
      _manualNumberController.clear();
    }
  }

  void _removePlayer(int index) {
    if (index >= 0 && index < _players.length) {
      setState(() {
        _players.removeAt(index);
      });
    }
  }

  void _confirmAndSave() {
    _stopListeningSilently();
    widget.onSavePlayers(_players);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: bottomInset + 18,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: widget.color.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poignée de glissement
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // En-tête
            Row(
              children: [
                Icon(Icons.mic, color: widget.color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.dictateLineup} — ${widget.teamName}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.dictateLineupHint,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () {
                    _stopListeningSilently();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ─── Zone d'écoute vocale interactive ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _isListening
                          ? widget.color.withValues(alpha: 0.6)
                          : AppTheme.divider,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: IconButton.filled(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                size: 28,
                              ),
                              onPressed:
                                  _isListening
                                      ? _stopListening
                                      : _startListening,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    _isListening
                                        ? widget.color
                                        : Colors.white12,
                                foregroundColor:
                                    _isListening ? Colors.black : Colors.white70,
                                padding: const EdgeInsets.all(14),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isListening
                                  ? l10n.listeningLineup
                                  : 'Micro en pause (cliquez pour parler)',
                              style: TextStyle(
                                color:
                                    _isListening
                                        ? widget.color
                                        : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _liveTranscription.isNotEmpty
                                  ? '"$_liveTranscription"'
                                  : 'ex: "numéro 10 Messi, numéro 7 Mbappé..."',
                              style: TextStyle(
                                color:
                                    _liveTranscription.isNotEmpty
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Joueurs détectés / Effectif ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.lineup.toUpperCase()} (${_players.length})',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                if (_players.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _players.clear();
                      });
                    },
                    child: const Text(
                      'Effacer tout',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            if (_players.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Aucun joueur pour le moment.\nParlez ou ajoutez manuellement ci-dessous.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_players.length, (index) {
                  final p = _players[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.number != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${p.number}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          p.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removePlayer(index),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            const SizedBox(height: 14),

            // ─── Ajout manuel rapide (N° + Nom) ───
            Row(
              children: [
                SizedBox(
                  width: 58,
                  child: TextField(
                    controller: _manualNumberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.playerNumber,
                      hintStyle: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.divider),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _manualNameController,
                    onSubmitted: (_) => _addManualPlayer(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.playerName,
                      hintStyle: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.divider),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: _addManualPlayer,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.color.withValues(alpha: 0.2),
                    foregroundColor: widget.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ─── Bouton de validation ───
            ElevatedButton(
              onPressed: _confirmAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '✅ ${l10n.validateLineup} (${_players.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
