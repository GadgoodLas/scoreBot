import 'package:flutter/material.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';

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
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Sélection du sport ───
                _SectionTitle(title: 'Sport'),
                const SizedBox(height: 12),
                _SportSelector(viewModel: widget.viewModel),
                const SizedBox(height: 28),

                // ─── Équipes ───
                _SectionTitle(title: 'Équipes'),
                const SizedBox(height: 12),
                _TeamInput(
                  label: 'Équipe A',
                  controller: _teamAController,
                  color: Colors.redAccent,
                  onChanged: widget.viewModel.setTeamAName,
                ),
                const SizedBox(height: 12),
                _TeamInput(
                  label: 'Équipe B',
                  controller: _teamBController,
                  color: Colors.blueAccent,
                  onChanged: widget.viewModel.setTeamBName,
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

