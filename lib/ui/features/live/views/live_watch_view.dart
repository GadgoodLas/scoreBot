import 'package:flutter/material.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/ui/features/live/view_models/live_view_model.dart';

/// Vue compacte et optimisée du match en cours pour Pixel Watch (Wear OS).
/// Offre un affichage clair du score, un retour visuel textuel complet sur les commandes vocales,
/// et des animations adaptées aux écrans ronds.
class LiveWatchView extends StatelessWidget {
  const LiveWatchView({super.key, required this.viewModel});

  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // Navigation automatique vers le résumé dès la fin du match
          if (viewModel.isMatchFinished) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  '/summary',
                  arguments: viewModel.match,
                );
              }
            });
          }

          final isVoiceActive = viewModel.voiceState != VoiceState.idle;

          // ─── Mode Ambiant (OLED Éco) ───
          if (viewModel.isAmbientMode && !isVoiceActive) {
            return GestureDetector(
              onTap: () => viewModel.exitAmbientMode(),
              behavior: HitTestBehavior.opaque,
              child: _WatchAmbientView(viewModel: viewModel),
            );
          }

          return GestureDetector(
            // Tap pour démarrer / arrêter la dictée vocale, appui long pour mode ambiant
            onTap: () => viewModel.toggleListening(),
            onLongPress: () => viewModel.toggleAmbientMode(),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // ─── Vue standard du match ───
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Alerte vocale / pause / fin de match
                              if (viewModel.pendingAlert != null) ...[
                                _WatchAlertBadge(viewModel: viewModel),
                                const SizedBox(height: 3),
                              ],

                              // Statut match si non live
                              if (viewModel.match.status !=
                                  GameMatchStatus.live) ...[
                                _WatchStatusBadge(
                                  status: viewModel.match.status,
                                ),
                                const SizedBox(height: 2),
                              ],

                              // Chronomètre & bouton mode ambiant
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    viewModel.elapsedFormatted,
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => viewModel.toggleAmbientMode(),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.nightlight_outlined,
                                        size: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),

                              // Score
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _WatchScore(
                                    score: viewModel.scoreA,
                                    color: Colors.redAccent,
                                    teamName: viewModel.match.teamA.name,
                                    onTap: () => viewModel.incrementScoreA(),
                                    onDoubleTap:
                                        () => viewModel.decrementScoreA(),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      ':',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w200,
                                      ),
                                    ),
                                  ),
                                  _WatchScore(
                                    score: viewModel.scoreB,
                                    color: Colors.blueAccent,
                                    teamName: viewModel.match.teamB.name,
                                    onTap: () => viewModel.incrementScoreB(),
                                    onDoubleTap:
                                        () => viewModel.decrementScoreB(),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 3),

                              // Bouton micro indicateur
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      viewModel.isVoiceReady
                                          ? (viewModel.isLocalVoiceMode
                                              ? Colors.tealAccent.withValues(
                                                alpha: 0.15,
                                              )
                                              : AppTheme.primary.withValues(
                                                alpha: 0.15,
                                              ))
                                          : Colors.amber.withValues(
                                            alpha: 0.15,
                                          ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        viewModel.isVoiceReady
                                            ? (viewModel.isLocalVoiceMode
                                                ? Colors.tealAccent.withValues(
                                                  alpha: 0.4,
                                                )
                                                : AppTheme.primary.withValues(
                                                  alpha: 0.4,
                                                ))
                                            : Colors.amber.withValues(
                                              alpha: 0.4,
                                            ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      viewModel.isVoiceReady
                                          ? (viewModel.isLocalVoiceMode
                                              ? Icons.offline_bolt
                                              : Icons.mic)
                                          : Icons.mic_off,
                                      size: 12,
                                      color:
                                          viewModel.isVoiceReady
                                              ? (viewModel.isLocalVoiceMode
                                                  ? Colors.tealAccent
                                                  : AppTheme.primary)
                                              : Colors.amberAccent,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      viewModel.isVoiceReady
                                          ? (viewModel.isLocalVoiceMode
                                              ? '⚡ ${AppLocalizations.of(context)!.localVoiceModeBadge}'
                                              : AppLocalizations.of(
                                                context,
                                              )!.tapToSpeak)
                                          : 'IA non configurée',
                                      style: TextStyle(
                                        color:
                                            viewModel.isVoiceReady
                                                ? (viewModel.isLocalVoiceMode
                                                    ? Colors.tealAccent
                                                    : AppTheme.primary)
                                                : Colors.amberAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 4),

                              // ─── Boutons de contrôle du match ───
                              _WatchMatchControls(
                                viewModel: viewModel,
                                context: context,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ─── Overlay Vocal Dynamique (Enregistrement / Analyse / Résultat) ───
                if (isVoiceActive)
                  Positioned.fill(
                    child: _WatchVoiceOverlay(viewModel: viewModel),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Boutons Pause/Reprendre et Terminer le match sur la montre.
class _WatchMatchControls extends StatelessWidget {
  const _WatchMatchControls({required this.viewModel, required this.context});

  final LiveViewModel viewModel;
  final BuildContext context;

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.grey[900],
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.white12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag, color: Colors.redAccent, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    l10n.endMatchDialogTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Bouton Annuler / Non (croix grise)
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(false),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Bouton Confirmer / Oui (validation rouge)
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(true),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirmed == true) {
      await viewModel.endMatch();
      // La navigation est gérée automatiquement via isMatchFinished
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPaused = viewModel.match.status == GameMatchStatus.paused;

    return GestureDetector(
      // Absorbe le tap ici pour ne pas déclencher le toggleListening parent
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pause / Reprendre
          _WatchIconButton(
            icon: isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.orangeAccent,
            tooltip: isPaused ? l10n.resume : l10n.pause,
            onTap: () => viewModel.togglePause(),
          ),
          const SizedBox(width: 12),
          // Terminer le match
          _WatchIconButton(
            icon: Icons.flag,
            color: Colors.redAccent,
            tooltip: l10n.endMatch,
            onTap: _confirmEnd,
          ),
        ],
      ),
    );
  }
}

/// Bouton icône compact pour la montre.
class _WatchIconButton extends StatelessWidget {
  const _WatchIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _WatchScore extends StatelessWidget {
  const _WatchScore({
    required this.score,
    required this.color,
    required this.teamName,
    required this.onTap,
    required this.onDoubleTap,
  });

  final int score;
  final Color color;
  final String teamName;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: TextStyle(
                color: color,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 64),
              child: Text(
                teamName,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay plein écran qui affiche l'état vocal et le texte transcrit sur la montre
class _WatchVoiceOverlay extends StatelessWidget {
  const _WatchVoiceOverlay({required this.viewModel});

  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.voiceState;

    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (state) {
              VoiceState.recording => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.redAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Écoute (${viewModel.recordingSeconds}s)...',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap pour envoyer',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
              VoiceState.processing => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color:
                          viewModel.isLocalVoiceMode
                              ? Colors.tealAccent
                              : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewModel.isLocalVoiceMode
                        ? 'Analyse Locale...'
                        : 'Analyse Gemini...',
                    style: TextStyle(
                      color:
                          viewModel.isLocalVoiceMode
                              ? Colors.tealAccent
                              : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              VoiceState.success => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    viewModel.lastTranscription?.isNotEmpty == true
                        ? viewModel.lastTranscription!
                        : 'Validé !',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              VoiceState.error => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    viewModel.lastError ?? 'Non reconnu',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              VoiceState.idle => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}

class _WatchStatusBadge extends StatelessWidget {
  const _WatchStatusBadge({required this.status});
  final GameMatchStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (text, color) = switch (status) {
      GameMatchStatus.paused => ('⏸ ${l10n.matchPaused}', Colors.orangeAccent),
      GameMatchStatus.halftime => (
        '⏱ ${l10n.matchHalftime}',
        Colors.amberAccent,
      ),
      GameMatchStatus.finished => (
        '🏁 ${l10n.matchFinished}',
        Colors.greenAccent,
      ),
      _ => ('', Colors.transparent),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _WatchAlertBadge extends StatelessWidget {
  const _WatchAlertBadge({required this.viewModel});
  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final alert = viewModel.pendingAlert;
    if (alert == null) return const SizedBox.shrink();

    final isBreak = alert == LiveAlertType.breakSuggested;
    final color = isBreak ? Colors.tealAccent : Colors.amberAccent;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBreak ? Icons.pause_circle : Icons.sports_score,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              if (isBreak) {
                await viewModel.acceptBreakAlert();
              } else {
                await viewModel.acceptEndMatchAlert();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(
                    '/summary',
                    arguments: viewModel.match,
                  );
                }
              }
            },
            child: Text(
              isBreak ? '${l10n.takeBreak} ✔️' : '${l10n.finishMatch} ✔️',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: viewModel.dismissPendingAlert,
            child: const Icon(Icons.close, size: 10, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

/// Vue Ambiante (Always-On Display) pour Wear OS.
/// Conçue pour maximiser l'autonomie de batterie sur écran OLED (fond 100% noir pur)
/// tout en gardant le chrono et le score immédiatement lisibles d'un coup d'œil par l'arbitre.
class _WatchAmbientView extends StatelessWidget {
  const _WatchAmbientView({required this.viewModel});

  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Indicateur Éco
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.nightlight_round,
                    size: 9,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.ambientMode.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),

              // Chronomètre épuré
              Text(
                viewModel.elapsedFormatted,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 1),

              // Score géant monochrome à fort contraste
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${viewModel.scoreA}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 36,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ),
                  Text(
                    '${viewModel.scoreB}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              // Noms d'équipe discrets
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      viewModel.match.teamA.name,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'vs',
                      style: TextStyle(color: Colors.white24, fontSize: 8),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      viewModel.match.teamB.name,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Indication de réveil
              Text(
                l10n.ambientModeHint,
                style: const TextStyle(color: Colors.white38, fontSize: 7.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
