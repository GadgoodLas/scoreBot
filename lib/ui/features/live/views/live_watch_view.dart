import 'package:flutter/material.dart';
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

          return GestureDetector(
            // Tap n'importe où pour démarrer / arrêter la dictée vocale
            onTap: () => viewModel.toggleListening(),
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
                              // Statut match si non live
                              if (viewModel.match.status != GameMatchStatus.live) ...[
                                _WatchStatusBadge(status: viewModel.match.status),
                                const SizedBox(height: 2),
                              ],

                              // Chronomètre
                              Text(
                                viewModel.elapsedFormatted,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
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
                                    onDoubleTap: () => viewModel.decrementScoreA(),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
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
                                    onDoubleTap: () => viewModel.decrementScoreB(),
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
                                  color: viewModel.isVoiceReady
                                      ? (viewModel.isLocalVoiceMode
                                          ? Colors.tealAccent.withValues(alpha: 0.15)
                                          : AppTheme.primary.withValues(alpha: 0.15))
                                      : Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: viewModel.isVoiceReady
                                        ? (viewModel.isLocalVoiceMode
                                            ? Colors.tealAccent.withValues(alpha: 0.4)
                                            : AppTheme.primary.withValues(alpha: 0.4))
                                        : Colors.amber.withValues(alpha: 0.4),
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
                                      color: viewModel.isVoiceReady
                                          ? (viewModel.isLocalVoiceMode
                                              ? Colors.tealAccent
                                              : AppTheme.primary)
                                          : Colors.amberAccent,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      viewModel.isVoiceReady
                                          ? (viewModel.isLocalVoiceMode
                                              ? '⚡ Local'
                                              : 'Tap pour parler')
                                          : 'IA non configurée',
                                      style: TextStyle(
                                        color: viewModel.isVoiceReady
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
                              _WatchMatchControls(viewModel: viewModel, context: context),
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
  const _WatchMatchControls({
    required this.viewModel,
    required this.context,
  });

  final LiveViewModel viewModel;
  final BuildContext context;

  Future<void> _confirmEnd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        title: const Text(
          'Terminer ?',
          style: TextStyle(color: Colors.white, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Non', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Oui', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.endMatch();
      // La navigation est gérée automatiquement via isMatchFinished
    }
  }

  @override
  Widget build(BuildContext context) {
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
            tooltip: isPaused ? 'Reprendre' : 'Pause',
            onTap: () => viewModel.togglePause(),
          ),
          const SizedBox(width: 12),
          // Terminer le match
          _WatchIconButton(
            icon: Icons.flag,
            color: Colors.redAccent,
            tooltip: 'Fin du match',
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
                        color: viewModel.isLocalVoiceMode
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
                        color: viewModel.isLocalVoiceMode
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
    final (text, color) = switch (status) {
      GameMatchStatus.paused => ('⏸ PAUSE', Colors.orangeAccent),
      GameMatchStatus.halftime => ('⏱ MI-TEMPS', Colors.amberAccent),
      GameMatchStatus.finished => ('🏁 FIN', Colors.greenAccent),
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
