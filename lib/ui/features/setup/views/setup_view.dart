import 'package:flutter/material.dart';
import 'package:score_bot/main.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';
import 'package:score_bot/ui/features/setup/widgets/ai_config_dialog.dart';
import 'package:score_bot/ui/features/setup/widgets/lineup_dictation_sheet.dart';

/// Écran de configuration du match avant son démarrage.
class SetupView extends StatefulWidget {
  const SetupView({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final _teamAController = TextEditingController();
  final _teamBController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _teamAController.text = widget.viewModel.teamAName;
    _teamBController.text = widget.viewModel.teamBName;

    // Détecte au premier lancement si l'utilisateur doit être invité à configurer l'IA
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.viewModel.shouldPromptAiOnboarding && mounted) {
        _openAiSettings(context, isOnboarding: true);
      }
    });
  }

  void _openAiSettings(BuildContext context, {bool isOnboarding = false}) {
    AiConfigDialog.show(
      context: context,
      initialApiKey: widget.viewModel.currentApiKey,
      initialModel: widget.viewModel.currentAiModel,
      initialVoiceEngine: widget.viewModel.voiceEngine,
      isOnboarding: isOnboarding,
      onDismissOnboarding: () => widget.viewModel.dismissAiOnboarding(),
      onSave:
          (apiKey, model, voiceEngine) => widget.viewModel.saveAiConfig(
            apiKey: apiKey,
            model: model,
            voiceEngine: voiceEngine,
          ),
      onTestConnection:
          (apiKey, model) =>
              widget.viewModel.testAiConnection(apiKey: apiKey, model: model),
    );
  }

  @override
  void dispose() {
    _teamAController.dispose();
    _teamBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          '⚽ ${l10n.appTitle}',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          // ─── Sélecteur de langue EN / FR ───
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: PopupMenuButton<String>(
              initialValue: currentLang,
              tooltip: l10n.language,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: AppTheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentLang == 'fr' ? '🇫🇷 FR' : '🇬🇧 EN',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white60,
                      size: 16,
                    ),
                  ],
                ),
              ),
              onSelected: (lang) {
                ScoreBotApp.setLocale(context, Locale(lang));
                widget.viewModel.setLanguageCode(lang);
              },
              itemBuilder:
                  (ctx) => [
                    const PopupMenuItem(
                      value: 'en',
                      child: Row(
                        children: [
                          Text('🇬🇧'),
                          SizedBox(width: 8),
                          Text(
                            'English',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'fr',
                      child: Row(
                        children: [
                          Text('🇫🇷'),
                          SizedBox(width: 8),
                          Text(
                            'Français',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                final isConfigured = widget.viewModel.isAiConfigured;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color:
                          isConfigured ? AppTheme.primary : Colors.amberAccent,
                    ),
                    if (!isConfigured)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            tooltip: l10n.voiceModeConfigTitle,
            onPressed: () => _openAiSettings(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Statut IA / Mode vocal ───
                _AiStatusCard(
                  viewModel: widget.viewModel,
                  onConfigure: () => _openAiSettings(context),
                ),
                const SizedBox(height: 20),

                // ─── Sélection du sport ───
                _SectionTitle(title: l10n.sport),
                const SizedBox(height: 12),
                _SportSelector(viewModel: widget.viewModel),
                const SizedBox(height: 28),

                // ─── Équipes & Joueurs ───
                _SectionTitle(title: l10n.teamsAndPlayers),
                const SizedBox(height: 12),
                _TeamInput(
                  label: l10n.teamA,
                  controller: _teamAController,
                  color: Colors.redAccent,
                  onChanged: widget.viewModel.setTeamAName,
                ),
                const SizedBox(height: 8),
                _PlayersSection(
                  teamName: widget.viewModel.teamAName,
                  color: Colors.redAccent,
                  players: widget.viewModel.teamAPlayers,
                  onAddPlayer: widget.viewModel.addPlayerToTeamA,
                  onRemovePlayer: widget.viewModel.removePlayerFromTeamA,
                  onSetPlayers: widget.viewModel.setTeamAPlayers,
                  startDictation: widget.viewModel.startLineupDictation,
                  stopDictation: widget.viewModel.stopLineupDictation,
                ),
                const SizedBox(height: 20),
                _TeamInput(
                  label: l10n.teamB,
                  controller: _teamBController,
                  color: Colors.blueAccent,
                  onChanged: widget.viewModel.setTeamBName,
                ),
                const SizedBox(height: 8),
                _PlayersSection(
                  teamName: widget.viewModel.teamBName,
                  color: Colors.blueAccent,
                  players: widget.viewModel.teamBPlayers,
                  onAddPlayer: widget.viewModel.addPlayerToTeamB,
                  onRemovePlayer: widget.viewModel.removePlayerFromTeamB,
                  onSetPlayers: widget.viewModel.setTeamBPlayers,
                  startDictation: widget.viewModel.startLineupDictation,
                  stopDictation: widget.viewModel.stopLineupDictation,
                ),
                const SizedBox(height: 12),
                _LineupAnnouncementButton(
                  viewModel: widget.viewModel,
                  sportLabel: widget.viewModel.selectedSport.label,
                ),
                const SizedBox(height: 28),

                // ─── Durée ───
                _SectionTitle(title: l10n.matchDuration),
                const SizedBox(height: 12),
                _DurationSlider(viewModel: widget.viewModel),
                const SizedBox(height: 32),

                // ─── Erreur ───
                if (widget.viewModel.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      widget.viewModel.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── Bouton démarrer ───
                ElevatedButton(
                  onPressed:
                      widget.viewModel.isCreating
                          ? null
                          : () => _startMatch(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child:
                      widget.viewModel.isCreating
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(
                            '🚀 ${l10n.startMatch}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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

  Future<void> _startMatch(BuildContext context) async {
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    final match = await widget.viewModel.startMatch();
    if (match != null && mounted) {
      navigator.pushReplacementNamed('/live', arguments: match);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SportSelector extends StatelessWidget {
  const _SportSelector({required this.viewModel});
  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          SportType.values.map((sport) {
            final isSelected = viewModel.selectedSport == sport;
            return GestureDetector(
              onTap: () => viewModel.selectSport(sport),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppTheme.primary.withValues(alpha: 0.2)
                          : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${sport.emoji} ${sport.label}',
                  style: TextStyle(
                    color:
                        isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _TeamInput extends StatelessWidget {
  const _TeamInput({
    required this.label,
    required this.controller,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Color color;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.surface,
        prefixIcon: Icon(Icons.group, color: color),
      ),
    );
  }
}

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({required this.viewModel});
  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxBreak = (viewModel.durationMinutes - 1).clamp(5, 180);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Durée totale ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.matchDuration,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            Text(
              l10n.durationMinutes(viewModel.durationMinutes),
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Slider(
          value: viewModel.durationMinutes.toDouble().clamp(5.0, 180.0),
          min: 5,
          max: 180,
          divisions: 35,
          activeColor: AppTheme.primary,
          inactiveColor: AppTheme.divider,
          onChanged: (v) => viewModel.setDuration(v.round()),
        ),
        const SizedBox(height: 8),

        // ─── Durée avant pause / mi-temps ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.breakDuration,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            Text(
              viewModel.breakDurationMinutes != null
                  ? l10n.durationMinutes(viewModel.breakDurationMinutes!)
                  : l10n.noBreak,
              style: TextStyle(
                color:
                    viewModel.breakDurationMinutes != null
                        ? Colors.tealAccent
                        : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        if (viewModel.breakDurationMinutes != null)
          Slider(
            value: viewModel.breakDurationMinutes!.toDouble().clamp(
              5.0,
              maxBreak.toDouble(),
            ),
            min: 5,
            max: maxBreak.toDouble(),
            divisions: (maxBreak - 5).clamp(1, 50),
            activeColor: Colors.tealAccent,
            inactiveColor: AppTheme.divider,
            onChanged: (v) => viewModel.setBreakDuration(v.round()),
          ),
        const SizedBox(height: 4),

        // Puces rapides de configuration
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text(l10n.noBreak, style: const TextStyle(fontSize: 11)),
                selected: viewModel.breakDurationMinutes == null,
                onSelected: (selected) {
                  if (selected) viewModel.setBreakDuration(null);
                },
                selectedColor: Colors.white24,
                backgroundColor: AppTheme.surface,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(
                  'Mi-temps (${(viewModel.durationMinutes / 2).round()} min)',
                  style: const TextStyle(fontSize: 11),
                ),
                selected:
                    viewModel.breakDurationMinutes ==
                    (viewModel.durationMinutes / 2).round(),
                onSelected: (selected) {
                  if (selected) {
                    viewModel.setBreakDuration(
                      (viewModel.durationMinutes / 2).round(),
                    );
                  }
                },
                selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
                backgroundColor: AppTheme.surface,
              ),
              if (viewModel.durationMinutes > 30) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('15 min', style: TextStyle(fontSize: 11)),
                  selected: viewModel.breakDurationMinutes == 15,
                  onSelected: (selected) {
                    if (selected) viewModel.setBreakDuration(15);
                  },
                  selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
                  backgroundColor: AppTheme.surface,
                ),
              ],
              if (viewModel.durationMinutes > 45) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('20 min', style: TextStyle(fontSize: 11)),
                  selected: viewModel.breakDurationMinutes == 20,
                  onSelected: (selected) {
                    if (selected) viewModel.setBreakDuration(20);
                  },
                  selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
                  backgroundColor: AppTheme.surface,
                ),
              ],
              if (viewModel.durationMinutes > 90) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('45 min', style: TextStyle(fontSize: 11)),
                  selected: viewModel.breakDurationMinutes == 45,
                  onSelected: (selected) {
                    if (selected) viewModel.setBreakDuration(45);
                  },
                  selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
                  backgroundColor: AppTheme.surface,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            Icon(Icons.volume_up, size: 14, color: AppTheme.primary),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Annonces vocales automatiques à la pause et à la fin du match',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayersSection extends StatefulWidget {
  const _PlayersSection({
    required this.teamName,
    required this.color,
    required this.players,
    required this.onAddPlayer,
    required this.onRemovePlayer,
    required this.onSetPlayers,
    required this.startDictation,
    required this.stopDictation,
  });

  final String teamName;
  final Color color;
  final List<Player> players;
  final void Function(String) onAddPlayer;
  final void Function(int) onRemovePlayer;
  final void Function(List<Player>) onSetPlayers;
  final Future<void> Function({
    required void Function(String text, bool isFinal) onResult,
  })
  startDictation;
  final Future<void> Function() stopDictation;

  @override
  State<_PlayersSection> createState() => _PlayersSectionState();
}

class _PlayersSectionState extends State<_PlayersSection> {
  final _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onAddPlayer(text);
      _controller.clear();
    }
  }

  void _openDictation(BuildContext context) {
    LineupDictationSheet.show(
      context,
      teamName: widget.teamName,
      color: widget.color,
      initialPlayers: widget.players,
      startDictation: widget.startDictation,
      stopDictation: widget.stopDictation,
      onSavePlayers: widget.onSetPlayers,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: '${l10n.addPlayerHint} (ex: 10 Messi)',
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
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.person_add, color: widget.color, size: 20),
                onPressed: _submit,
                tooltip: l10n.addPlayerHint,
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                icon: const Icon(Icons.mic, size: 20),
                onPressed: () => _openDictation(context),
                tooltip: l10n.dictateLineup,
                style: IconButton.styleFrom(
                  backgroundColor: widget.color.withValues(alpha: 0.2),
                  foregroundColor: widget.color,
                ),
              ),
            ],
          ),
          if (widget.players.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(widget.players.length, (index) {
                final player = widget.players[index];
                return InputChip(
                  avatar:
                      player.number != null
                          ? CircleAvatar(
                            backgroundColor: widget.color,
                            radius: 10,
                            child: Text(
                              '${player.number}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          : null,
                  label: Text(
                    player.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: widget.color.withValues(alpha: 0.15),
                  side: BorderSide(color: widget.color.withValues(alpha: 0.4)),
                  onDeleted: () => widget.onRemovePlayer(index),
                  deleteIconColor: Colors.white70,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte indiquant l'état d'activation du modèle IA et du mode vocal.
class _AiStatusCard extends StatelessWidget {
  const _AiStatusCard({required this.viewModel, required this.onConfigure});

  final SetupViewModel viewModel;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLocal = viewModel.isLocalVoiceMode;
    final isConfigured = viewModel.isAiConfigured;
    final modelName = viewModel.currentAiModel;

    final (icon, title, subtitle, color) =
        isLocal
            ? (
              Icons.offline_bolt,
              l10n.aiStatusLocal,
              l10n.aiStatusLocalSub,
              AppTheme.primary,
            )
            : isConfigured
            ? (
              Icons.auto_awesome,
              l10n.aiStatusGemini,
              l10n.aiStatusGeminiSub(modelName),
              AppTheme.primary,
            )
            : (
              Icons.mic_off_outlined,
              l10n.aiStatusUnconfigured,
              l10n.aiStatusUnconfiguredSub,
              Colors.amberAccent,
            );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onConfigure,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              foregroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: color.withValues(alpha: 0.5)),
              ),
            ),
            child: Text(
              l10n.settings,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton pour déclencher ou interrompre l'annonce vocale des compositions d'équipes.
class _LineupAnnouncementButton extends StatelessWidget {
  const _LineupAnnouncementButton({
    required this.viewModel,
    required this.sportLabel,
  });

  final SetupViewModel viewModel;
  final String sportLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAnnouncing = viewModel.isAnnouncingLineup;
    final primaryColor = isAnnouncing ? Colors.amberAccent : AppTheme.primary;

    return OutlinedButton.icon(
      onPressed:
          () => viewModel.toggleLineupAnnouncement(
            sportLabel: sportLabel,
            languageCode: Localizations.localeOf(context).languageCode,
          ),
      icon: Icon(
        isAnnouncing ? Icons.stop_circle_outlined : Icons.campaign_outlined,
        color: primaryColor,
        size: 20,
      ),
      label: Text(
        isAnnouncing ? l10n.stopAnnouncement : l10n.announceLineups,
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: primaryColor.withValues(
          alpha: isAnnouncing ? 0.15 : 0.06,
        ),
        side: BorderSide(
          color: primaryColor.withValues(alpha: isAnnouncing ? 0.8 : 0.35),
          width: isAnnouncing ? 1.5 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
