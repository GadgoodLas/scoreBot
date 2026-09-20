import 'package:flutter/material.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/ui/features/live/view_models/live_view_model.dart';
import 'package:score_bot/ui/features/setup/widgets/ai_config_dialog.dart';

/// Écran principal du match en cours (vue téléphone).
class LiveView extends StatelessWidget {
  const LiveView({super.key, required this.viewModel});

  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // Navigation automatique vers le résumé dès la fin du match
          // (déclenché par commande vocale ou bouton)
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

          return SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                if (isLandscape) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 360,
                        child: _MatchHeader(viewModel: viewModel),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            if (viewModel.match.status != GameMatchStatus.live)
                              _StatusBanner(status: viewModel.match.status),
                            Expanded(child: _EventFeed(viewModel: viewModel)),
                            _VoiceFeedback(viewModel: viewModel),
                            _MicButton(viewModel: viewModel),
                            _MatchControls(
                              viewModel: viewModel,
                              context: context,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _MatchHeader(viewModel: viewModel),
                    if (viewModel.match.status != GameMatchStatus.live)
                      _StatusBanner(status: viewModel.match.status),
                    Expanded(child: _EventFeed(viewModel: viewModel)),
                    _VoiceFeedback(viewModel: viewModel),
                    _MicButton(viewModel: viewModel),
                    _MatchControls(viewModel: viewModel, context: context),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

void _openAiSettings(BuildContext context, LiveViewModel viewModel) {
  AiConfigDialog.show(
    context: context,
    initialVoiceEngine: viewModel.voiceEngine,
    initialApiKey: viewModel.currentApiKey,
    initialModel: viewModel.currentAiModel,
    onSave: (apiKey, model, voiceEngine) => viewModel.saveAiConfig(
      apiKey: apiKey,
      model: model,
      voiceEngine: voiceEngine,
    ),
    onTestConnection: (apiKey, model) => viewModel.testAiConnection(
      apiKey: apiKey,
      model: model,
    ),
  );
}

// ─── Match Header ───────────────────────────────────────────────

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.viewModel});
  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final match = viewModel.match;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(
                viewModel.isLocalVoiceMode
                    ? Icons.offline_bolt
                    : (viewModel.isAiConfigured
                        ? Icons.auto_awesome
                        : Icons.warning_amber_rounded),
                size: 20,
                color: viewModel.isLocalVoiceMode
                    ? Colors.tealAccent
                    : (viewModel.isAiConfigured
                        ? AppTheme.primary
                        : Colors.amberAccent),
              ),
              tooltip: viewModel.isLocalVoiceMode
                  ? 'Mode vocal : Local (Sans IA)'
                  : (viewModel.isAiConfigured
                      ? 'Modèle IA : ${viewModel.currentAiModel}'
                      : 'Configurer l\'IA / Mode vocal'),
              onPressed: () => _openAiSettings(context, viewModel),
            ),
          ),
          Column(
            children: [
          // Chronomètre
          Text(
            viewModel.elapsedFormatted,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${match.sport.emoji} ${match.sport.label} • ${viewModel.currentMinute}\'',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Score
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => viewModel.incrementScoreA(),
                  onDoubleTap: () => viewModel.decrementScoreA(),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Text(
                        match.teamA.name,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${viewModel.scoreA}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                '—',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 32,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => viewModel.incrementScoreB(),
                  onDoubleTap: () => viewModel.decrementScoreB(),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Text(
                        match.teamB.name,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${viewModel.scoreB}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
        ],
      ),
    );
  }
}

// ─── Status Banner ───────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final GameMatchStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (text, color) = switch (status) {
      GameMatchStatus.paused => ('⏸ ${l10n.matchPaused}', Colors.orangeAccent),
      GameMatchStatus.halftime => ('⏱ ${l10n.matchHalftime}', Colors.amberAccent),
      GameMatchStatus.finished => ('🏁 ${l10n.matchFinished}', Colors.greenAccent),
      _ => ('', Colors.transparent),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: color.withValues(alpha: 0.15),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ─── Event Feed ───────────────────────────────────────────────────

class _EventFeed extends StatelessWidget {
  const _EventFeed({required this.viewModel});
  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final events = viewModel.recentEvents;

    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'Appuyez sur le micro\npour enregistrer un événement',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      reverse: false,
      itemCount: events.length,
      itemBuilder: (context, index) {
        return _EventTile(
          event: events[index],
          match: viewModel.match,
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.match});

  final GameEvent event;
  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    final teamName = event.teamId == match.teamA.id
        ? match.teamA.name
        : match.teamB.name;
    final teamColor = event.teamId == match.teamA.id
        ? Colors.redAccent
        : Colors.blueAccent;

    final description = _buildDescription();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teamColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(event.type.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  teamName,
                  style: TextStyle(color: teamColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${event.minute}\'',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _buildDescription() {
    return switch (event) {
      GoalEvent(:final scorerName, :final assistName, :final isPenalty) =>
        [
          if (scorerName != null) scorerName,
          if (assistName != null) '(assist: $assistName)',
          if (isPenalty) '⚠️ penalty',
        ].join(' '),
      CardEvent(:final playerName, :final type) =>
        playerName ?? type.label,
      FoulEvent(:final playerName) =>
        playerName ?? 'Faute',
      SubstitutionEvent(:final playerOutName, :final playerInName) =>
        '${playerOutName ?? '?'} → ${playerInName ?? '?'}',
      CorrectionEvent() => 'Correction / annulation',
      GenericEvent(:final notes) => notes ?? event.type.label,
      _ => event.type.label,
    };
  }
}

// ─── Voice Feedback ───────────────────────────────────────────────

class _VoiceFeedback extends StatelessWidget {
  const _VoiceFeedback({required this.viewModel});
  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (viewModel.voiceState) {
        VoiceState.recording => _FeedbackBanner(
            key: const ValueKey('recording'),
            message: '🎙 Enregistrement...',
            color: Colors.redAccent,
          ),
        VoiceState.processing => _FeedbackBanner(
            key: const ValueKey('processing'),
            message: '⚙️ Analyse en cours...',
            color: Colors.orangeAccent,
          ),
        VoiceState.success => _FeedbackBanner(
            key: const ValueKey('success'),
            message: '✅ ${viewModel.lastTranscription ?? 'Événement enregistré'}',
            color: Colors.greenAccent,
          ),
        VoiceState.error => _FeedbackBanner(
            key: const ValueKey('error'),
            message: '❌ ${viewModel.lastError ?? 'Erreur'}',
            color: Colors.redAccent,
          ),
        VoiceState.idle => const SizedBox.shrink(key: ValueKey('idle')),
      },
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    super.key,
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── Mic Button ───────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  const _MicButton({required this.viewModel});
  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isRecording = viewModel.voiceState == VoiceState.recording;
    final isProcessing = viewModel.voiceState == VoiceState.processing;
    final isDisabled = isProcessing ||
        viewModel.match.status != GameMatchStatus.live;

    final isReady = viewModel.isVoiceReady;
    final isLocal = viewModel.isLocalVoiceMode;
    final hintText = switch (viewModel.voiceState) {
      VoiceState.recording =>
        '🔴 Enregistrement (${viewModel.recordingSeconds}s)... Cliquez pour envoyer',
      VoiceState.processing => isLocal
          ? '⚡ Analyse locale...'
          : '⚙️ Analyse par Gemini...',
      VoiceState.success => '✅ Événement pris en compte',
      VoiceState.error => viewModel.lastError ?? '❌ Réessayez ou utilisez le clavier ⌨️',
      VoiceState.idle => isReady
          ? (isLocal
              ? '🎙️ Mode Sans IA (Local) : dictez ou ⌨️ saisissez'
              : '🎙️ Cliquez pour dicter (ou ⌨️ pour saisir)')
          : '⚠️ Mode vocal non configuré (cliquez pour activer)',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 48), // Pour centrer le micro
              GestureDetector(
                onTap: isDisabled
                    ? null
                    : () {
                        if (!isReady) {
                          _openAiSettings(context, viewModel);
                        } else {
                          viewModel.toggleListening();
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isRecording ? 84 : 70,
                  height: isRecording ? 84 : 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDisabled
                        ? AppTheme.surface
                        : isRecording
                            ? Colors.redAccent
                            : isReady
                                ? (isLocal ? Colors.tealAccent : AppTheme.primary)
                                : Colors.amber.shade700,
                    boxShadow: isRecording
                        ? [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: (isReady
                                      ? (isLocal ? Colors.tealAccent : AppTheme.primary)
                                      : Colors.amber)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                  ),
                  child: Icon(
                    isProcessing
                        ? Icons.hourglass_top
                        : isRecording
                            ? Icons.stop
                            : isReady
                                ? (isLocal ? Icons.offline_bolt : Icons.mic)
                                : Icons.mic_off,
                    color: isDisabled ? AppTheme.textSecondary : Colors.black,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bouton saisie texte (fallback pratique)
              IconButton(
                icon: const Icon(Icons.keyboard, color: AppTheme.textSecondary),
                tooltip: 'Saisir du texte',
                onPressed: isDisabled
                    ? null
                    : () {
                        if (!isReady) {
                          _openAiSettings(context, viewModel);
                        } else {
                          _showTextInputDialog(context);
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hintText,
            style: TextStyle(
              color: isRecording
                  ? Colors.redAccent
                  : isProcessing
                      ? Colors.orangeAccent
                      : isReady
                          ? (isLocal ? Colors.tealAccent : AppTheme.textSecondary)
                          : Colors.amberAccent,
              fontSize: 12,
              fontWeight: isRecording ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showTextInputDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '⌨️ Saisir un événement',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Ex: "But équipe rouge par Cédric"',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              Navigator.of(ctx).pop();
              viewModel.sendTextCommand(val);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop();
                viewModel.sendTextCommand(text);
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}

// ─── Match Controls ───────────────────────────────────────────────

class _MatchControls extends StatelessWidget {
  const _MatchControls({required this.viewModel, required this.context});

  final LiveViewModel viewModel;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final match = viewModel.match;
    final isLive = match.status == GameMatchStatus.live;
    final isPaused = match.status == GameMatchStatus.paused;
    final isFinished = match.status == GameMatchStatus.finished;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pause / Reprendre
          if (!isFinished)
            _ControlButton(
              icon: isLive ? Icons.pause : Icons.play_arrow,
              label: isLive ? l10n.pause : l10n.resume,
              onTap: viewModel.togglePause,
            ),

          // Mi-temps
          if (isLive || isPaused)
            _ControlButton(
              icon: Icons.sports,
              label: l10n.halftime,
              onTap: viewModel.startHalftime,
            ),

          // Fin du match
          if (!isFinished)
            _ControlButton(
              icon: Icons.flag,
              label: l10n.confirm,
              onTap: () => _confirmEndMatch(context),
              isDestructive: true,
            ),

          // Voir les stats
          if (isFinished)
            _ControlButton(
              icon: Icons.bar_chart,
              label: l10n.stats,
              onTap: () => Navigator.of(context).pushNamed(
                '/summary',
                arguments: viewModel.match,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmEndMatch(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          l10n.endMatchDialogTitle,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          l10n.endMatchDialogContent,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.endMatch();
    }
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

