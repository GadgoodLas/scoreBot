import 'package:flutter/material.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/ui/features/live/view_models/live_view_model.dart';

/// Vue compacte du match en cours pour montre connectée (Wear OS).
/// Design minimaliste adapté aux petits écrans ronds.
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
          return GestureDetector(
            // Tap pour démarrer / arrêter l'enregistrement
            onTapDown: (_) => viewModel.startListening(),
            onTapUp: (_) => viewModel.stopListening(),
            child: Stack(
              children: [
                // Score central
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chrono
                      Text(
                        viewModel.elapsedFormatted,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          letterSpacing: 2,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Score
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WatchScore(
                            score: viewModel.scoreA,
                            color: Colors.redAccent,
                            teamName: viewModel.match.teamA.name,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              ':',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 32,
                                fontWeight: FontWeight.w200,
                              ),
                            ),
                          ),
                          _WatchScore(
                            score: viewModel.scoreB,
                            color: Colors.blueAccent,
                            teamName: viewModel.match.teamB.name,
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      // Sport
                      Text(
                        viewModel.match.sport.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // Indicateur de l'état vocal
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _WatchVoiceIndicator(state: viewModel.voiceState),
                  ),
                ),

                // Statut match (pause, mi-temps...)
                if (viewModel.match.status != GameMatchStatus.live)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _WatchStatusBadge(
                        status: viewModel.match.status,
                      ),
                    ),
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
  });

  final int score;
  final Color color;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 40,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          teamName.length > 6
              ? teamName.substring(0, 6)
              : teamName,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _WatchVoiceIndicator extends StatelessWidget {
  const _WatchVoiceIndicator({required this.state});
  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      VoiceState.idle => const Icon(
          Icons.mic_none,
          color: Colors.white30,
          size: 16,
        ),
      VoiceState.recording => const Icon(
          Icons.mic,
          color: Colors.redAccent,
          size: 20,
        ),
      VoiceState.processing => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orangeAccent,
          ),
        ),
      VoiceState.success => const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 16,
        ),
      VoiceState.error => const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
          size: 16,
        ),
    };
  }
}

class _WatchStatusBadge extends StatelessWidget {
  const _WatchStatusBadge({required this.status});
  final GameMatchStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      GameMatchStatus.paused => ('⏸ PAUSE', Colors.orangeAccent),
      GameMatchStatus.halftime => ('MI-TEMPS', Colors.amberAccent),
      GameMatchStatus.finished => ('FIN', Colors.greenAccent),
      _ => ('', Colors.transparent),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
