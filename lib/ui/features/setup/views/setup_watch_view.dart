import 'package:flutter/material.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';

/// Vue d'accueil / configuration du match optimisée pour Wear OS (Pixel Watch).
/// Affiche le contenu en 3 étapes courtes défilables verticalement.
class SetupWatchView extends StatefulWidget {
  const SetupWatchView({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  @override
  State<SetupWatchView> createState() => _SetupWatchViewState();
}

class _SetupWatchViewState extends State<SetupWatchView> {
  final _pageController = PageController();
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
    _pageController.dispose();
    _teamAController.dispose();
    _teamBController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          return PageView(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            children: [
              // ─── Page 1 : Sport ───
              _WatchPage(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '⚽ SPORT',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _WatchSportGrid(
                      selectedSport: widget.viewModel.selectedSport,
                      onSelect: (s) {
                        widget.viewModel.selectSport(s);
                        _nextPage();
                      },
                    ),
                    const SizedBox(height: 6),
                    _WatchPageIndicator(current: 0, total: 3),
                  ],
                ),
              ),

              // ─── Page 2 : Équipes ───
              _WatchPage(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ÉQUIPES',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _WatchTextField(
                      controller: _teamAController,
                      hint: 'Équipe A',
                      color: Colors.redAccent,
                      onChanged: widget.viewModel.setTeamAName,
                    ),
                    const SizedBox(height: 6),
                    _WatchTextField(
                      controller: _teamBController,
                      hint: 'Équipe B',
                      color: Colors.blueAccent,
                      onChanged: widget.viewModel.setTeamBName,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _WatchNavButton(
                          icon: Icons.arrow_upward,
                          onTap: _prevPage,
                        ),
                        const SizedBox(width: 12),
                        _WatchNavButton(
                          icon: Icons.arrow_downward,
                          onTap: _nextPage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _WatchPageIndicator(current: 1, total: 3),
                  ],
                ),
              ),

              // ─── Page 3 : Démarrer ───
              _WatchPage(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mode vocal actif
                    _WatchVoiceBadge(isLocal: widget.viewModel.isLocalVoiceMode),
                    const SizedBox(height: 8),

                    // Résumé
                    Text(
                      '${widget.viewModel.selectedSport.emoji} ${widget.viewModel.selectedSport.label}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.viewModel.teamAName.isEmpty
                              ? 'Équipe A'
                              : widget.viewModel.teamAName,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          ' vs ',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                        Text(
                          widget.viewModel.teamBName.isEmpty
                              ? 'Équipe B'
                              : widget.viewModel.teamBName,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.viewModel.durationMinutes} min',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 10),

                    // Erreur
                    if (widget.viewModel.errorMessage != null) ...[
                      Text(
                        widget.viewModel.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Bouton démarrer
                    GestureDetector(
                      onTap: widget.viewModel.isCreating
                          ? null
                          : () => _startMatch(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.viewModel.isCreating
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: widget.viewModel.isCreating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                '🚀 Démarrer',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _WatchNavButton(icon: Icons.arrow_upward, onTap: _prevPage),
                    const SizedBox(height: 2),
                    _WatchPageIndicator(current: 2, total: 3),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Widgets internes ────────────────────────────────────────────────────────

class _WatchPage extends StatelessWidget {
  const _WatchPage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: child,
      ),
    );
  }
}

/// Indicateurs de page (petits points).
class _WatchPageIndicator extends StatelessWidget {
  const _WatchPageIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        return Container(
          width: i == current ? 12 : 6,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i == current
                ? AppTheme.primary
                : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// Grille de sports compacte pour la montre.
class _WatchSportGrid extends StatelessWidget {
  const _WatchSportGrid({
    required this.selectedSport,
    required this.onSelect,
  });

  final SportType selectedSport;
  final void Function(SportType) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: SportType.values.map((sport) {
        final isSelected = selectedSport == sport;
        return GestureDetector(
          onTap: () => onSelect(sport),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(sport.emoji, style: const TextStyle(fontSize: 14)),
                Text(
                  sport.label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : Colors.white60,
                    fontSize: 8,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Champ de texte compact pour la montre.
class _WatchTextField extends StatelessWidget {
  const _WatchTextField({
    required this.controller,
    required this.hint,
    required this.color,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final Color color;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: color, fontSize: 12),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: color.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
      ),
    );
  }
}

/// Bouton navigation compact (haut/bas).
class _WatchNavButton extends StatelessWidget {
  const _WatchNavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, size: 14, color: Colors.white60),
      ),
    );
  }
}

/// Badge indiquant le mode vocal actif.
class _WatchVoiceBadge extends StatelessWidget {
  const _WatchVoiceBadge({required this.isLocal});
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final color = isLocal ? Colors.tealAccent : AppTheme.primary;
    final label = isLocal ? '⚡ Local' : '🧠 Gemini';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
