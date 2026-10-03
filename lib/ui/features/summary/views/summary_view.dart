import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/repositories/match_repository.dart';

/// ViewModel de l'écran de résumé et statistiques.
class SummaryViewModel extends ChangeNotifier {
  SummaryViewModel({
    required MatchRepository matchRepository,
    required GameMatch match,
  }) : _matchRepository = matchRepository,
       _match = match {
    _events = matchRepository.getEvents(match.id);
    _generateAutomaticReport();
  }

  final MatchRepository _matchRepository;
  final GameMatch _match;
  GameMatch get match => _match;

  late final List<GameEvent> _events;

  // ─────────────── Rapport de match ───────────────

  String? _generatedReport;
  String? get generatedReport => _generatedReport;

  bool _isGeneratingReport = false;
  bool get isGeneratingReport => _isGeneratingReport;

  bool _isAiReport = false;
  bool get isAiReport => _isAiReport;

  Future<void> _generateAutomaticReport() async {
    _isGeneratingReport = true;
    notifyListeners();
    try {
      _generatedReport = await _matchRepository.generateMatchReport(_match);
      _isAiReport =
          !_matchRepository.isLocalVoiceMode && _matchRepository.isAiConfigured;
    } catch (_) {
      _generatedReport = generateShareText();
      _isAiReport = false;
    } finally {
      _isGeneratingReport = false;
      notifyListeners();
    }
  }

  Future<void> regenerateReport() async {
    await _generateAutomaticReport();
  }

  // ─────────────── Stats globales ───────────────

  int get scoreA => _match.scoreA;
  int get scoreB => _match.scoreB;

  String get winner {
    if (scoreA > scoreB) return _match.teamA.name;
    if (scoreB > scoreA) return _match.teamB.name;
    return 'Égalité';
  }

  // ─────────────── Stats par équipe ───────────────

  int goalsForTeam(String teamId) => _events
      .whereType<GoalEvent>()
      .where((e) => e.teamId == teamId)
      .fold(0, (sum, e) => sum + e.points);

  int yellowCardsForTeam(String teamId) =>
      _events
          .whereType<CardEvent>()
          .where(
            (e) => e.teamId == teamId && e.type == GameEventType.yellowCard,
          )
          .length;

  int redCardsForTeam(String teamId) =>
      _events
          .whereType<CardEvent>()
          .where((e) => e.teamId == teamId && e.type == GameEventType.redCard)
          .length;

  int foulsForTeam(String teamId) =>
      _events.whereType<FoulEvent>().where((e) => e.teamId == teamId).length;

  // ─────────────── Stats par joueur ───────────────

  /// Top buteurs toutes équipes confondues.
  List<MapEntry<String, int>> get topScorers {
    final map = <String, int>{};
    for (final e in _events.whereType<GoalEvent>()) {
      if (e.scorerName != null && e.scorerName!.trim().isNotEmpty) {
        map[e.scorerName!] = (map[e.scorerName!] ?? 0) + e.points;
      }
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Top passeurs.
  List<MapEntry<String, int>> get topAssists {
    final map = <String, int>{};
    for (final e in _events.whereType<GoalEvent>()) {
      if (e.assistName != null && e.assistName!.trim().isNotEmpty) {
        map[e.assistName!] = (map[e.assistName!] ?? 0) + 1;
      }
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Statistiques détaillées de chaque joueur pour une équipe donnée.
  List<PlayerMatchStats> playerStatsForTeam(String teamId) {
    final team = _match.teamById(teamId);
    final knownPlayerNames = <String>{};
    final playerNumberMap = <String, int?>{};

    if (team != null) {
      for (final p in team.players) {
        if (p.name.trim().isNotEmpty) {
          final clean = p.name.trim();
          knownPlayerNames.add(clean);
          playerNumberMap[clean.toLowerCase()] = p.number;
        }
      }
    }

    // Ajoute les joueurs mentionnés lors des événements pour cette équipe s'ils ne sont pas déjà dans l'effectif
    for (final e in _events.where((e) => e.teamId == teamId)) {
      if (e is GoalEvent) {
        if (e.scorerName != null && e.scorerName!.trim().isNotEmpty) {
          final raw = e.scorerName!.trim();
          // Si le buteur correspond à un numéro enregistré dans l'équipe, on associe au joueur
          final matchingPlayer =
              team?.players
                  .where(
                    (p) =>
                        p.name.toLowerCase() == raw.toLowerCase() ||
                        (p.number != null && raw == '#${p.number}'),
                  )
                  .firstOrNull;
          knownPlayerNames.add(matchingPlayer?.name ?? raw);
        }
        if (e.assistName != null && e.assistName!.trim().isNotEmpty) {
          final raw = e.assistName!.trim();
          final matchingPlayer =
              team?.players
                  .where(
                    (p) =>
                        p.name.toLowerCase() == raw.toLowerCase() ||
                        (p.number != null && raw == '#${p.number}'),
                  )
                  .firstOrNull;
          knownPlayerNames.add(matchingPlayer?.name ?? raw);
        }
      } else if (e is CardEvent &&
          e.playerName != null &&
          e.playerName!.trim().isNotEmpty) {
        final raw = e.playerName!.trim();
        final matchingPlayer =
            team?.players
                .where(
                  (p) =>
                      p.name.toLowerCase() == raw.toLowerCase() ||
                      (p.number != null && raw == '#${p.number}'),
                )
                .firstOrNull;
        knownPlayerNames.add(matchingPlayer?.name ?? raw);
      } else if (e is FoulEvent &&
          e.playerName != null &&
          e.playerName!.trim().isNotEmpty) {
        final raw = e.playerName!.trim();
        final matchingPlayer =
            team?.players
                .where(
                  (p) =>
                      p.name.toLowerCase() == raw.toLowerCase() ||
                      (p.number != null && raw == '#${p.number}'),
                )
                .firstOrNull;
        knownPlayerNames.add(matchingPlayer?.name ?? raw);
      }
    }

    final stats = <PlayerMatchStats>[];
    for (final name in knownPlayerNames) {
      final norm = name.toLowerCase();
      final pNumber = playerNumberMap[norm];
      int goals = 0;
      int assists = 0;
      int yellows = 0;
      int reds = 0;

      for (final e in _events.where((e) => e.teamId == teamId)) {
        if (e is GoalEvent) {
          final scorer = e.scorerName?.toLowerCase();
          if (scorer == norm ||
              (pNumber != null &&
                  (scorer == '#$pNumber' || scorer == '$pNumber'))) {
            goals += e.points;
          }
          final assister = e.assistName?.toLowerCase();
          if (assister == norm ||
              (pNumber != null &&
                  (assister == '#$pNumber' || assister == '$pNumber'))) {
            assists += 1;
          }
        } else if (e is CardEvent) {
          final player = e.playerName?.toLowerCase();
          if (player == norm ||
              (pNumber != null &&
                  (player == '#$pNumber' || player == '$pNumber'))) {
            if (e.type == GameEventType.yellowCard) yellows++;
            if (e.type == GameEventType.redCard) reds++;
          }
        }
      }

      stats.add(
        PlayerMatchStats(
          playerName: name,
          playerNumber: pNumber,
          teamId: teamId,
          goals: goals,
          assists: assists,
          yellowCards: yellows,
          redCards: reds,
        ),
      );
    }

    stats.sort((a, b) {
      final g = b.goals.compareTo(a.goals);
      if (g != 0) return g;
      final ast = b.assists.compareTo(a.assists);
      if (ast != 0) return ast;
      return a.playerName.compareTo(b.playerName);
    });

    return stats;
  }

  // ─────────────── Timeline ───────────────

  List<GameEvent> get allEvents => List.unmodifiable(_events);

  /// Génère un résumé texte du match pour le partage.
  String generateShareText() {
    final buf = StringBuffer();
    buf.writeln('⚽ ScoreBot — Résumé du match');
    buf.writeln('${_match.sport.emoji} ${_match.sport.label}');
    buf.writeln('${_match.teamA.name} $scoreA — $scoreB ${_match.teamB.name}');
    buf.writeln('');

    for (final event in _events) {
      final teamName =
          event.teamId == _match.teamA.id
              ? _match.teamA.name
              : _match.teamB.name;

      final desc = switch (event) {
        GoalEvent(:final scorerName, :final assistName) =>
          '${event.type.emoji} ${event.minute}\' ${scorerName ?? "But"}${assistName != null ? ' (assist: $assistName)' : ''} — $teamName',
        CardEvent(:final playerName) =>
          '${event.type.emoji} ${event.minute}\' ${playerName ?? '?'} — $teamName',
        _ =>
          '${event.type.emoji} ${event.minute}\' ${event.type.label} — $teamName',
      };

      buf.writeln(desc);
    }

    final statsA = playerStatsForTeam(_match.teamA.id);
    if (statsA.isNotEmpty) {
      buf.writeln('\n👥 Joueurs ${_match.teamA.name} :');
      for (final p in statsA) {
        final details = [
          if (p.goals > 0) '${p.goals} ⚽',
          if (p.assists > 0) '${p.assists} 🅰️',
          if (p.yellowCards > 0) '${p.yellowCards} 🟨',
          if (p.redCards > 0) '${p.redCards} 🟥',
        ];
        buf.writeln(
          '- ${p.playerName}${details.isNotEmpty ? " (${details.join(', ')})" : ''}',
        );
      }
    }

    final statsB = playerStatsForTeam(_match.teamB.id);
    if (statsB.isNotEmpty) {
      buf.writeln('\n👥 Joueurs ${_match.teamB.name} :');
      for (final p in statsB) {
        final details = [
          if (p.goals > 0) '${p.goals} ⚽',
          if (p.assists > 0) '${p.assists} 🅰️',
          if (p.yellowCards > 0) '${p.yellowCards} 🟨',
          if (p.redCards > 0) '${p.redCards} 🟥',
        ];
        buf.writeln(
          '- ${p.playerName}${details.isNotEmpty ? " (${details.join(', ')})" : ''}',
        );
      }
    }

    if (topScorers.isNotEmpty) {
      buf.writeln(
        '\n🏅 Meilleur buteur : ${topScorers.first.key} (${topScorers.first.value} but(s))',
      );
    }

    buf.writeln('\nGénéré par ScoreBot 🤖');
    return buf.toString();
  }

  /// Génère une feuille de match ultra-complète optimisée pour WhatsApp
  /// avec mise en forme markdown (*gras*, _italique_), emojis et séparateurs.
  String generateWhatsAppReport() {
    final buf = StringBuffer();
    buf.writeln('🏆 *SCOREBOT — FEUILLE DE MATCH*');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('${_match.sport.emoji} *Sport :* ${_match.sport.label}');
    final d = _match.startTime;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
    buf.writeln('📅 *Date :* $dateStr à $timeStr');
    if (_match.durationMinutes > 0) {
      buf.writeln('⏱️ *Durée :* ${_match.durationMinutes} min');
    }
    buf.writeln('');
    buf.writeln(
      '🔴 *${_match.teamA.name}*  *$scoreA — $scoreB*  *${_match.teamB.name}* 🔵',
    );
    if (scoreA == scoreB) {
      buf.writeln('🤝 *Résultat :* Match nul');
    } else {
      buf.writeln('🎉 *Vainqueur :* $winner');
    }
    buf.writeln('━━━━━━━━━━━━━━━━━━━━');

    if (_events.isNotEmpty) {
      buf.writeln('⏱️ *FIL DU MATCH :*');
      for (final event in _events) {
        final teamName =
            event.teamId == _match.teamA.id
                ? _match.teamA.name
                : _match.teamB.name;

        final desc = switch (event) {
          GoalEvent(:final scorerName, :final assistName) =>
            '${event.type.emoji} ${event.minute}\' *${scorerName ?? "But"}*${assistName != null ? " _(passe: $assistName)_" : ""} — $teamName',
          CardEvent(:final playerName) =>
            '${event.type.emoji} ${event.minute}\' *${playerName ?? "?"}* — $teamName',
          _ =>
            '${event.type.emoji} ${event.minute}\' *${event.type.label}* — $teamName',
        };

        buf.writeln(desc);
      }
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    }

    final statsA = playerStatsForTeam(_match.teamA.id);
    final statsB = playerStatsForTeam(_match.teamB.id);

    if (statsA.isNotEmpty || statsB.isNotEmpty) {
      buf.writeln('👥 *STATISTIQUES DES JOUEURS :*');
      if (statsA.isNotEmpty) {
        buf.writeln('\n🔴 *${_match.teamA.name} :*');
        for (final p in statsA) {
          final numStr = p.playerNumber != null ? '#${p.playerNumber} ' : '';
          final details = [
            if (p.goals > 0) '${p.goals} ⚽',
            if (p.assists > 0) '${p.assists} 🅰️',
            if (p.yellowCards > 0) '${p.yellowCards} 🟨',
            if (p.redCards > 0) '${p.redCards} 🟥',
          ];
          buf.writeln(
            '• $numStr*${p.playerName}*${details.isNotEmpty ? " : ${details.join(', ')}" : ""}',
          );
        }
      }

      if (statsB.isNotEmpty) {
        buf.writeln('\n🔵 *${_match.teamB.name} :*');
        for (final p in statsB) {
          final numStr = p.playerNumber != null ? '#${p.playerNumber} ' : '';
          final details = [
            if (p.goals > 0) '${p.goals} ⚽',
            if (p.assists > 0) '${p.assists} 🅰️',
            if (p.yellowCards > 0) '${p.yellowCards} 🟨',
            if (p.redCards > 0) '${p.redCards} 🟥',
          ];
          buf.writeln(
            '• $numStr*${p.playerName}*${details.isNotEmpty ? " : ${details.join(', ')}" : ""}',
          );
        }
      }
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    }

    if (topScorers.isNotEmpty) {
      buf.writeln(
        '🏅 *Meilleur buteur :* *${topScorers.first.key}* (${topScorers.first.value} but(s))',
      );
    }

    buf.writeln('\n🤖 _Feuille de match officielle générée par ScoreBot_');
    return buf.toString();
  }

  /// Partage directement la feuille de match formatée pour WhatsApp.
  Future<void> shareOnWhatsApp() async {
    final text = generateWhatsAppReport();
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject:
            '🏆 Feuille de match : ${_match.teamA.name} vs ${_match.teamB.name}',
      ),
    );
  }

  /// Enregistre le rapport sous forme de fichier texte (.txt) et retourne le fichier créé.
  Future<File> saveReportToFile() async {
    final text = generatedReport ?? generateShareText();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedA = _match.teamA.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final sanitizedB = _match.teamB.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final filename = 'scorebot_${sanitizedA}_vs_${sanitizedB}_$timestamp.txt';

    if (Platform.isAndroid) {
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/$filename');
          await file.writeAsString(text);
          return file;
        }
      } catch (_) {
        // Fallback si permission refusée sur scoped storage
      }
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null && await downloadsDir.exists()) {
        final file = File('${downloadsDir.path}/$filename');
        await file.writeAsString(text);
        return file;
      }
    } catch (_) {}

    final docsDir = await getApplicationDocumentsDirectory();
    final fallbackFile = File('${docsDir.path}/$filename');
    await fallbackFile.writeAsString(text);
    return fallbackFile;
  }
}

/// Modèle pour les statistiques individuelles d'un joueur pendant un match.
class PlayerMatchStats {
  const PlayerMatchStats({
    required this.playerName,
    required this.teamId,
    this.playerNumber,
    this.goals = 0,
    this.assists = 0,
    this.yellowCards = 0,
    this.redCards = 0,
  });

  final String playerName;
  final String teamId;
  final int? playerNumber;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
}

/// Écran de résumé et statistiques de fin de match.
class SummaryView extends StatelessWidget {
  const SummaryView({super.key, required this.viewModel});

  final SummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final match = viewModel.match;
    final statsA = viewModel.playerStatsForTeam(match.teamA.id);
    final statsB = viewModel.playerStatsForTeam(match.teamB.id);

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          '🏆 ${l10n.summaryTitle}',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
            onPressed: () => _shareOnWhatsApp(context),
            tooltip: l10n.shareWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppTheme.primary),
            onPressed: () => _downloadReport(context),
            tooltip: l10n.downloadReport,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primary),
            onPressed: () => _shareResult(context),
            tooltip: l10n.shareReport,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Score final ───
                _FinalScoreCard(viewModel: viewModel),
                const SizedBox(height: 16),

                // ─── Compte-rendu automatique ───
                _MatchReportCard(
                  viewModel: viewModel,
                  onShare: () => _shareResult(context),
                  onWhatsAppShare: () => _shareOnWhatsApp(context),
                  onDownload: () => _downloadReport(context),
                ),
                const SizedBox(height: 16),

                // ─── Stats équipes ───
                _TeamStatsCard(viewModel: viewModel, match: match),
                const SizedBox(height: 16),

                // ─── Stats par joueur (Équipe A et Équipe B) ───
                if (statsA.isNotEmpty || statsB.isNotEmpty) ...[
                  _TeamPlayersStatsCard(
                    team: match.teamA,
                    color: Colors.redAccent,
                    stats: statsA,
                  ),
                  const SizedBox(height: 12),
                  _TeamPlayersStatsCard(
                    team: match.teamB,
                    color: Colors.blueAccent,
                    stats: statsB,
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── Top buteurs ───
                if (viewModel.topScorers.isNotEmpty) ...[
                  _StatsList(
                    title: '⚽ Top Buteurs',
                    entries: viewModel.topScorers,
                    unit: 'but(s)',
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── Top passeurs ───
                if (viewModel.topAssists.isNotEmpty) ...[
                  _StatsList(
                    title: '🅰️ Top Passeurs',
                    entries: viewModel.topAssists,
                    unit: 'passe(s)',
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── Timeline des événements ───
                _EventTimeline(viewModel: viewModel),
                const SizedBox(height: 24),

                // ─── Bouton Nouveau match ───
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text(
                    'Commencer un nouveau match',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _shareResult(BuildContext context) async {
    final text = viewModel.generatedReport ?? viewModel.generateShareText();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject:
              'ScoreBot — ${viewModel.match.teamA.name} vs ${viewModel.match.teamB.name}',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reportCopied),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    }
  }

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    final text = viewModel.generateWhatsAppReport();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject:
              '🏆 Feuille de match : ${viewModel.match.teamA.name} vs ${viewModel.match.teamB.name}',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reportCopied),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    }
  }

  Future<void> _downloadReport(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final file = await viewModel.saveReportToFile();
      final filename = file.path.split(Platform.pathSeparator).last;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reportDownloaded(filename)),
          backgroundColor: AppTheme.surface,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l10n.shareReport,
            textColor: AppTheme.primary,
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  files: [XFile(file.path)],
                  text:
                      viewModel.generatedReport ??
                      viewModel.generateShareText(),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class _FinalScoreCard extends StatelessWidget {
  const _FinalScoreCard({required this.viewModel});
  final SummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDraw = viewModel.scoreA == viewModel.scoreB;
    final winnerTitle =
        isDraw ? '🤝 ${l10n.draw} !' : '🏆 ${l10n.winner(viewModel.winner)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            winnerTitle,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreBlock(
                name: viewModel.match.teamA.name,
                score: viewModel.scoreA,
                color: Colors.redAccent,
              ),
              const Text(
                '—',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 28),
              ),
              _ScoreBlock(
                name: viewModel.match.teamB.name,
                score: viewModel.scoreB,
                color: Colors.blueAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${viewModel.match.sport.emoji} ${viewModel.match.sport.label}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({
    required this.name,
    required this.score,
    required this.color,
  });

  final String name;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          name,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MatchReportCard extends StatelessWidget {
  const _MatchReportCard({
    required this.viewModel,
    required this.onShare,
    required this.onWhatsAppShare,
    required this.onDownload,
  });

  final SummaryViewModel viewModel;
  final VoidCallback onShare;
  final VoidCallback onWhatsAppShare;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final report = viewModel.generatedReport;
    final isGenerating = viewModel.isGeneratingReport;
    final isAi = viewModel.isAiReport;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isAi
                  ? AppTheme.primary.withValues(alpha: 0.4)
                  : Colors.tealAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAi ? Icons.auto_awesome : Icons.article_outlined,
                color: isAi ? AppTheme.primary : Colors.tealAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.matchReport,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAi ? AppTheme.primary : Colors.tealAccent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isAi ? AppTheme.primary : Colors.tealAccent)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAi ? Icons.auto_awesome : Icons.offline_bolt,
                      size: 12,
                      color: isAi ? AppTheme.primary : Colors.tealAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAi ? l10n.aiReportBadge : l10n.localReportBadge,
                      style: TextStyle(
                        color: isAi ? AppTheme.primary : Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isGenerating)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.generatingReport,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (report != null && report.isNotEmpty) ...[
            Text(
              report,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => viewModel.regenerateReport(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.regenerateReport),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: report));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.reportCopied),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppTheme.surface,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 15),
                  label: Text(l10n.copyReport),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download, size: 15),
                  label: Text(l10n.downloadReport),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: BorderSide(
                      color: Colors.tealAccent.withValues(alpha: 0.4),
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onWhatsAppShare,
                  icon: const Icon(Icons.chat, size: 15),
                  label: Text(l10n.shareWhatsApp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share, size: 15),
                  label: Text(l10n.shareReport),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Aucun rapport disponible.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamStatsCard extends StatelessWidget {
  const _TeamStatsCard({required this.viewModel, required this.match});
  final SummaryViewModel viewModel;
  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'STATISTIQUES PAR ÉQUIPE',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Buts',
            valueA: viewModel.goalsForTeam(match.teamA.id),
            valueB: viewModel.goalsForTeam(match.teamB.id),
            match: match,
          ),
          _StatRow(
            label: '🟨 Cartons jaunes',
            valueA: viewModel.yellowCardsForTeam(match.teamA.id),
            valueB: viewModel.yellowCardsForTeam(match.teamB.id),
            match: match,
          ),
          _StatRow(
            label: '🟥 Cartons rouges',
            valueA: viewModel.redCardsForTeam(match.teamA.id),
            valueB: viewModel.redCardsForTeam(match.teamB.id),
            match: match,
          ),
          _StatRow(
            label: '⚠️ Fautes',
            valueA: viewModel.foulsForTeam(match.teamA.id),
            valueB: viewModel.foulsForTeam(match.teamB.id),
            match: match,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.valueA,
    required this.valueB,
    required this.match,
  });

  final String label;
  final int valueA;
  final int valueB;
  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$valueA',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$valueB',
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsList extends StatelessWidget {
  const _StatsList({
    required this.title,
    required this.entries,
    required this.unit,
  });

  final String title;
  final List<MapEntry<String, int>> entries;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...entries
              .take(5)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        '👤 ${entry.key}',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.value} $unit',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _EventTimeline extends StatelessWidget {
  const _EventTimeline({required this.viewModel});
  final SummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final events = viewModel.allEvents;
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHRONOLOGIE',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    "${event.minute}'",
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(width: 10),
                  Text(event.type.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _describeEvent(event, viewModel.match),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _describeEvent(GameEvent event, GameMatch match) {
    final team =
        event.teamId == match.teamA.id ? match.teamA.name : match.teamB.name;
    return switch (event) {
      GoalEvent(:final scorerName, :final assistName) =>
        '${scorerName ?? 'But'} ${assistName != null ? '(assist: $assistName)' : ''} — $team',
      CardEvent(:final playerName) => '${playerName ?? '?'} — $team',
      SubstitutionEvent(:final playerOutName, :final playerInName) =>
        '${playerOutName ?? '?'} → ${playerInName ?? '?'} — $team',
      _ => '${event.type.label} — $team',
    };
  }
}

class _TeamPlayersStatsCard extends StatelessWidget {
  const _TeamPlayersStatsCard({
    required this.team,
    required this.color,
    required this.stats,
  });

  final Team team;
  final Color color;
  final List<PlayerMatchStats> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'STATS JOUEURS — ${team.name.toUpperCase()}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.isEmpty)
            const Text(
              'Aucun joueur enregistré',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            )
          else
            ...stats.map((p) {
              final badges = <Widget>[];
              if (p.goals > 0) {
                badges.add(
                  _StatBadge(
                    label: '⚽ ${p.goals} but${p.goals > 1 ? "s" : ""}',
                    color: Colors.greenAccent,
                  ),
                );
              }
              if (p.assists > 0) {
                badges.add(
                  _StatBadge(
                    label: '🅰️ ${p.assists} assist${p.assists > 1 ? "s" : ""}',
                    color: Colors.cyanAccent,
                  ),
                );
              }
              if (p.yellowCards > 0) {
                badges.add(
                  _StatBadge(
                    label: '🟨 ${p.yellowCards}',
                    color: Colors.amberAccent,
                  ),
                );
              }
              if (p.redCards > 0) {
                badges.add(
                  _StatBadge(
                    label: '🟥 ${p.redCards}',
                    color: Colors.redAccent,
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    if (p.playerNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: color.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          '#${p.playerNumber}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      )
                    else ...[
                      const Icon(
                        Icons.person,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        p.playerName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (badges.isNotEmpty)
                      Wrap(spacing: 6, children: badges)
                    else
                      const Text(
                        '0 but',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
