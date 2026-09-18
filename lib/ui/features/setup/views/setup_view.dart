import 'package:flutter/material.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';
import 'package:score_bot/ui/features/setup/widgets/ai_config_dialog.dart';

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
      onSave: (apiKey, model, voiceEngine) => widget.viewModel.saveAiConfig(
        apiKey: apiKey,
        model: model,
        voiceEngine: voiceEngine,
      ),
      onTestConnection: (apiKey, model) => widget.viewModel.testAiConnection(
        apiKey: apiKey,
        model: model,
      ),
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '⚽ ScoreBot',
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
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
                      color: isConfigured ? AppTheme.primary : Colors.amberAccent,
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
            tooltip: 'Configuration Modèle IA / Clé',
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
                _SectionTitle(title: 'Sport'),
                const SizedBox(height: 12),
                _SportSelector(viewModel: widget.viewModel),
                const SizedBox(height: 28),

                // ─── Équipes & Joueurs ───
                _SectionTitle(title: 'Équipes & Joueurs'),
                const SizedBox(height: 12),
                _TeamInput(
                  label: 'Équipe A',
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
                ),
                const SizedBox(height: 20),
                _TeamInput(
                  label: 'Équipe B',
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
                ),
                const SizedBox(height: 28),

                // ─── Durée ───
                _SectionTitle(title: 'Durée du match'),
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
                      border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
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
                  onPressed: widget.viewModel.isCreating
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
                  child: widget.viewModel.isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '🚀 Démarrer le match',
                          style: TextStyle(
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
      navigator.pushReplacementNamed(
        '/live',
        arguments: match,
      );
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
      children: SportType.values.map((sport) {
        final isSelected = viewModel.selectedSport == sport;
        return GestureDetector(
          onTap: () => viewModel.selectSport(sport),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
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
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Durée',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            Text(
              '${viewModel.durationMinutes} min',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Slider(
          value: viewModel.durationMinutes.toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          activeColor: AppTheme.primary,
          inactiveColor: AppTheme.divider,
          onChanged: (v) => viewModel.setDuration(v.round()),
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
  });

  final String teamName;
  final Color color;
  final List<String> players;
  final void Function(String) onAddPlayer;
  final void Function(int) onRemovePlayer;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ajouter joueur(s) (ex: Stéphane, Nabil...)',
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
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.person_add, color: widget.color, size: 20),
                onPressed: _submit,
                tooltip: 'Ajouter',
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
                  label: Text(
                    player,
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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
  const _AiStatusCard({
    required this.viewModel,
    required this.onConfigure,
  });

  final SetupViewModel viewModel;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final isLocal = viewModel.isLocalVoiceMode;
    final isConfigured = viewModel.isAiConfigured;
    final modelName = viewModel.currentAiModel;

    final (icon, title, subtitle, color) = isLocal
        ? (
            Icons.offline_bolt,
            '⚡ Mode vocal local actif (sans IA)',
            'Reconnaissance 100% hors-ligne — Cliquez pour passer en mode IA',
            AppTheme.primary,
          )
        : isConfigured
            ? (
                Icons.auto_awesome,
                '🧠 Mode vocal IA actif (Gemini)',
                'Modèle : $modelName — Cliquez pour modifier',
                AppTheme.primary,
              )
            : (
                Icons.mic_off_outlined,
                'Mode vocal non configuré',
                'Activez le mode local ou configurez une clé Gemini',
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
            child: const Text(
              'Réglages',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
