import 'package:flutter/material.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/ui/features/summary/views/summary_view.dart';

/// Vue résumé adaptée aux montres connectées Wear OS (Pixel Watch).
class SummaryWatchView extends StatelessWidget {
  const SummaryWatchView({super.key, required this.viewModel});

  final SummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final isAi = viewModel.isAiReport;
          final isGenerating = viewModel.isGeneratingReport;
          final report = viewModel.generatedReport;

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                // ─── Statut ───
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    '🏁 MATCH TERMINÉ',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // ─── Vainqueur ───
                Text(
                  viewModel.winner == 'Égalité'
                      ? '🤝 Égalité'
                      : '🏆 ${viewModel.winner}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // ─── Score ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${viewModel.scoreA}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        ':',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 24,
                          fontWeight: FontWeight.w200,
                        ),
                      ),
                    ),
                    Text(
                      '${viewModel.scoreB}',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${viewModel.match.teamA.name} vs ${viewModel.match.teamB.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
                const SizedBox(height: 12),

                // ─── Compte-rendu automatique ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAi
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
                            isAi ? Icons.auto_awesome : Icons.description,
                            size: 13,
                            color: isAi ? AppTheme.primary : Colors.tealAccent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isAi ? 'Compte-rendu IA' : 'Compte-rendu auto',
                              style: TextStyle(
                                color: isAi ? AppTheme.primary : Colors.tealAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (isGenerating) ...[
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Génération...',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ] else if (report != null && report.isNotEmpty) ...[
                        Text(
                          report,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Aucun rapport.',
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ─── Buteurs clés ───
                if (viewModel.topScorers.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '⚽ Meilleur buteur : ${viewModel.topScorers.first.key} (${viewModel.topScorers.first.value})',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ─── Bouton Nouveau match ───
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    icon: const Icon(Icons.sports_soccer, size: 14),
                    label: const Text(
                      'Nouveau match',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

