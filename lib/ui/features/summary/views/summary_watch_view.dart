import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/ui/features/summary/views/summary_view.dart';

/// Vue résumé adaptée aux montres connectées Wear OS (Pixel Watch).
class SummaryWatchView extends StatelessWidget {
  const SummaryWatchView({super.key, required this.viewModel});

  final SummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ─── Statut ───
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.greenAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            '🏁 ${l10n.matchFinished}',
                            style: const TextStyle(
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
                          viewModel.scoreA == viewModel.scoreB
                              ? '🤝 ${l10n.draw}'
                              : '🏆 ${l10n.winner(viewModel.winner)}',
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
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
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
                              color:
                                  isAi
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : Colors.tealAccent.withValues(
                                        alpha: 0.3,
                                      ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isAi
                                        ? Icons.auto_awesome
                                        : Icons.description,
                                    size: 13,
                                    color:
                                        isAi
                                            ? AppTheme.primary
                                            : Colors.tealAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isAi
                                          ? l10n.aiReportBadge
                                          : l10n.localReportBadge,
                                      style: TextStyle(
                                        color:
                                            isAi
                                                ? AppTheme.primary
                                                : Colors.tealAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (isGenerating) ...[
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.generatingReport,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (report != null &&
                                  report.isNotEmpty) ...[
                                Text(
                                  report,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    height: 1.4,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  l10n.noReportAvailable,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '⚽ ${l10n.topScorer(viewModel.topScorers.first.key, viewModel.topScorers.first.value)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // ─── Actions Partage / Téléchargement / Copie ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => _shareOnWatch(context),
                              icon: const Icon(Icons.share, size: 16),
                              tooltip: l10n.shareReport,
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.surface,
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => _downloadOnWatch(context),
                              icon: const Icon(Icons.download, size: 16),
                              tooltip: l10n.downloadReport,
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.surface,
                                foregroundColor: Colors.tealAccent,
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () {
                                final text =
                                    viewModel.generatedReport ??
                                    viewModel.generateShareText();
                                Clipboard.setData(ClipboardData(text: text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.reportCopied,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: AppTheme.surface,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: l10n.copyReport,
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.surface,
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ─── Bouton Nouveau match ───
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamedAndRemoveUntil('/', (route) => false);
                            },
                            icon: const Icon(Icons.sports_soccer, size: 14),
                            label: Text(
                              l10n.newMatch,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
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

  Future<void> _shareOnWatch(BuildContext context) async {
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
            content: Text(
              AppLocalizations.of(context)!.reportCopied,
              style: const TextStyle(fontSize: 10),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    }
  }

  Future<void> _downloadOnWatch(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final file = await viewModel.saveReportToFile();
      final filename = file.path.split(Platform.pathSeparator).last;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.reportDownloaded(filename),
            style: const TextStyle(fontSize: 10),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppTheme.surface,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e', style: const TextStyle(fontSize: 10)),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
