import 'package:flutter/material.dart';
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
  }) : _match = match {
    _events = matchRepository.getEvents(match.id);
  }

  final GameMatch _match;
  GameMatch get match => _match;

  late final List<GameEvent> _events;

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

  int yellowCardsForTeam(String teamId) => _events
      .whereType<CardEvent>()
      .where((e) =>
          e.teamId == teamId && e.type == GameEventType.yellowCard)
      .length;

  int redCardsForTeam(String teamId) => _events
      .whereType<CardEvent>()
      .where((e) =>
          e.teamId == teamId && e.type == GameEventType.redCard)
      .length;

  int foulsForTeam(String teamId) => _events
      .whereType<FoulEvent>()
      .where((e) => e.teamId == teamId)
      .length;

  // ─────────────── Stats par joueur ───────────────

  /// Top buteurs toutes équipes confondues.
  List<MapEntry<String, int>> get topScorers {
    final map = <String, int>{};
    for (final e in _events.whereType<GoalEvent>()) {
      if (e.scorerName != null && e.scorerName!.trim().isNotEmpty) {
        map[e.scorerName!] = (map[e.scorerName!] ?? 0) + e.points;
      }
    }
    return map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Top passeurs.
  List<MapEntry<String, int>> get topAssists {
    final map = <String, int>{};
    for (final e in _events.whereType<GoalEvent>()) {
      if (e.assistName != null && e.assistName!.trim().isNotEmpty) {
        map[e.assistName!] = (map[e.assistName!] ?? 0) + 1;
      }
    }
    return map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Statistiques détaillées de chaque joueur pour une équipe donnée.
  List<PlayerMatchStats> playerStatsForTeam(String teamId) {
    final team = _match.teamById(teamId);
    final knownPlayerNames = <String>{};

    if (team != null) {
      for (final p in team.players) {
        if (p.name.trim().isNotEmpty) {
          knownPlayerNames.add(p.name.trim());
        }
      }
    }

    // Ajoute les joueurs mentionnés lors des événements pour cette équipe
    for (final e in _events.where((e) => e.teamId == teamId)) {
      if (e is GoalEvent) {
        if (e.scorerName != null && e.scorerName!.trim().isNotEmpty) {
          knownPlayerNames.add(e.scorerName!.trim());
        }
        if (e.assistName != null && e.assistName!.trim().isNotEmpty) {
          knownPlayerNames.add(e.assistName!.trim());
        }
      } else if (e is CardEvent && e.playerName != null && e.playerName!.trim().isNotEmpty) {
        knownPlayerNames.add(e.playerName!.trim());
      } else if (e is FoulEvent && e.playerName != null && e.playerName!.trim().isNotEmpty) {
        knownPlayerNames.add(e.playerName!.trim());
      }
    }

    final stats = <PlayerMatchStats>[];
    for (final name in knownPlayerNames) {
      final norm = name.toLowerCase();
      int goals = 0;
      int assists = 0;
      int yellows = 0;
      int reds = 0;

      for (final e in _events.where((e) => e.teamId == teamId)) {
        if (e is GoalEvent) {
          if (e.scorerName?.toLowerCase() == norm) {
            goals += e.points;
          }
          if (e.assistName?.toLowerCase() == norm) {
            assists += 1;
          }
        } else if (e is CardEvent) {
          if (e.playerName?.toLowerCase() == norm) {
            if (e.type == GameEventType.yellowCard) yellows++;
            if (e.type == GameEventType.redCard) reds++;
          }
        }
      }

      stats.add(PlayerMatchStats(
        playerName: name,
        teamId: teamId,
        goals: goals,
        assists: assists,
        yellowCards: yellows,
        redCards: reds,
      ));
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
    buf.writeln(
        '${_match.teamA.name} $scoreA — $scoreB ${_match.teamB.name}');
    buf.writeln('');

    for (final event in _events) {
      final teamName = event.teamId == _match.teamA.id
          ? _match.teamA.name
          : _match.teamB.name;

      final desc = switch (event) {
        GoalEvent(:final scorerName, :final assistName) =>
          '${event.type.emoji} ${event.minute}\' ${scorerName ?? "But"}${assistName != null ? ' (assist: $assistName)' : ''} — $teamName',
        CardEvent(:final playerName) =>
          '${event.type.emoji} ${event.minute}\' ${playerName ?? '?'} — $teamName',
        _ => '${event.type.emoji} ${event.minute}\' ${event.type.label} — $teamName',
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
        buf.writeln('- ${p.playerName}${details.isNotEmpty ? " (${details.join(', ')})" : ''}');
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
        buf.writeln('- ${p.playerName}${details.isNotEmpty ? " (${details.join(', ')})" : ''}');
      }
    }

    if (topScorers.isNotEmpty) {
      buf.writeln('\n🏅 Meilleur buteur : ${topScorers.first.key} (${topScorers.first.value} but(s))');
    }

    buf.writeln('\nGénéré par ScoreBot 🤖');
    return buf.toString();
  }
}

/// Modèle pour les statistiques individuelles d'un joueur pendant un match.
class PlayerMatchStats {
  const PlayerMatchStats({
    required this.playerName,
    required this.teamId,
    this.goals = 0,
    this.assists = 0,
    this.yellowCards = 0,
    this.redCards = 0,
  });

  final String playerName;
  final String teamId;
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '🏆 Résumé du match',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primary),
            onPressed: () => _shareResult(context),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Score final ───
            _FinalScoreCard(viewModel: viewModel),
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
          ],
        ),
      ),
    );
  }

  Future<void> _shareResult(BuildContext context) async {
    final text = viewModel.generateShareText();
    // Sur un vrai appareil, utiliser share_plus
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
}

class _FinalScoreCard extends StatelessWidget {
  const _FinalScoreCard({required this.viewModel});
  final SummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
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
            viewModel.winner == 'Égalité'
                ? '🤝 Égalité !'
                : '🏆 ${viewModel.winner}',
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
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
          ...entries.take(5).map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('👤 ${entry.key}',
                          style: const TextStyle(color: AppTheme.textPrimary)),
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
    final team = event.teamId == match.teamA.id
        ? match.teamA.name
        : match.teamB.name;
    return switch (event) {
      GoalEvent(:final scorerName, :final assistName) =>
        '${scorerName ?? 'But'} ${assistName != null ? '(assist: $assistName)' : ''} — $team',
      CardEvent(:final playerName) =>
        '${playerName ?? '?'} — $team',
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
                badges.add(_StatBadge(
                  label: '⚽ ${p.goals} but${p.goals > 1 ? "s" : ""}',
                  color: Colors.greenAccent,
                ));
              }
              if (p.assists > 0) {
                badges.add(_StatBadge(
                  label: '🅰️ ${p.assists} assist${p.assists > 1 ? "s" : ""}',
                  color: Colors.cyanAccent,
                ));
              }
              if (p.yellowCards > 0) {
                badges.add(_StatBadge(
                  label: '🟨 ${p.yellowCards}',
                  color: Colors.amberAccent,
                ));
              }
              if (p.redCards > 0) {
                badges.add(_StatBadge(
                  label: '🟥 ${p.redCards}',
                  color: Colors.redAccent,
                ));
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
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
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
