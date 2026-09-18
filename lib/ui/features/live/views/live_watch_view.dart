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
          final isVoiceActive = viewModel.voiceState != VoiceState.idle;

          return GestureDetector(
            // Tap n'importe où pour démarrer / arrêter la dictée vocale
            onTap: () => viewModel.toggleListening(),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // ─── Vue standard du match ───
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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

                        const SizedBox(height: 4),

                        // Bouton micro indicateur
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic, size: 14, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text(
                                'Tap pour parler',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
              VoiceState.processing => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Analyse Gemini...',
                      style: TextStyle(
                        color: Colors.orangeAccent,
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
