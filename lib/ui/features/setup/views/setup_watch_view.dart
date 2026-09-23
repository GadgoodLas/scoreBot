import 'package:flutter/material.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';
import 'package:score_bot/ui/features/setup/widgets/watch_config_view.dart';

/// Vue d'accueil / configuration du match optimisée pour Wear OS (Pixel Watch).
/// Utilise un PageView vertical en 3 étapes. Chaque page utilise un
/// LayoutBuilder + SingleChildScrollView pour éviter tout overflow.
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
    final l10n = AppLocalizations.of(context)!;

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
              _WatchScrollPage(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '⚽ ${l10n.sport.toUpperCase()}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => WatchConfigView.show(context, widget.viewModel),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings,
                            size: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _WatchSportGrid(
                    selectedSport: widget.viewModel.selectedSport,
                    onSelect: (s) {
                      widget.viewModel.selectSport(s);
                      _nextPage();
                    },
                  ),
                  const SizedBox(height: 4),
                  _WatchPageIndicator(current: 0, total: 3),
                ],
              ),

              // ─── Page 2 : Équipes ───
              _WatchScrollPage(
                children: [
                  Text(
                    l10n.teamsAndPlayers.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _WatchTextField(
                    controller: _teamAController,
                    hint: l10n.teamA,
                    color: Colors.redAccent,
                    onChanged: widget.viewModel.setTeamAName,
                  ),
                  const SizedBox(height: 4),
                  _WatchTextField(
                    controller: _teamBController,
                    hint: l10n.teamB,
                    color: Colors.blueAccent,
                    onChanged: widget.viewModel.setTeamBName,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WatchNavButton(icon: Icons.arrow_upward, onTap: _prevPage),
                      const SizedBox(width: 10),
                      _WatchNavButton(icon: Icons.arrow_downward, onTap: _nextPage),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _WatchPageIndicator(current: 1, total: 3),
                ],
              ),

              // ─── Page 3 : Démarrer ───
              _WatchScrollPage(
                children: [
                  _WatchVoiceBadge(
                    isLocal: widget.viewModel.isLocalVoiceMode,
                    localLabel: l10n.localVoiceModeBadge,
                    onTap: () => WatchConfigView.show(context, widget.viewModel),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.viewModel.selectedSport.emoji} ${widget.viewModel.selectedSport.label}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  _WatchTeamRow(
                    teamA: widget.viewModel.teamAName.isEmpty
                        ? 'A'
                        : widget.viewModel.teamAName,
                    teamB: widget.viewModel.teamBName.isEmpty
                        ? 'B'
                        : widget.viewModel.teamBName,
                  ),
                  Text(
                    l10n.durationMinutes(widget.viewModel.durationMinutes),
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                  const SizedBox(height: 8),
                  if (widget.viewModel.errorMessage != null) ...[
                    Text(
                      widget.viewModel.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                  ],
                  _WatchStartButton(
                    isCreating: widget.viewModel.isCreating,
                    label: l10n.startMatch,
                    onTap: () => _startMatch(context),
                  ),
                  const SizedBox(height: 4),
                  _WatchNavButton(icon: Icons.arrow_upward, onTap: _prevPage),
                  const SizedBox(height: 2),
                  _WatchPageIndicator(current: 2, total: 3),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Widgets internes ────────────────────────────────────────────────────────

/// Conteneur de page qui s'adapte à l'espace disponible sans déborder.
/// Utilise LayoutBuilder pour contraindre le contenu à la hauteur réelle.
class _WatchScrollPage extends StatelessWidget {
  const _WatchScrollPage({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Indicateurs de page (petits traits).
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
          width: i == current ? 10 : 5,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i == current ? AppTheme.primary : Colors.white24,
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
      spacing: 5,
      runSpacing: 5,
      alignment: WrapAlignment.center,
      children: SportType.values.map((sport) {
        final isSelected = selectedSport == sport;
        return GestureDetector(
          onTap: () => onSelect(sport),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.white12,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(sport.emoji, style: const TextStyle(fontSize: 13)),
                Text(
                  sport.label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : Colors.white60,
                    fontSize: 7,
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
      style: TextStyle(color: color, fontSize: 11),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 10),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, size: 13, color: Colors.white60),
      ),
    );
  }
}

/// Affichage compact des deux équipes sur une ligne.
class _WatchTeamRow extends StatelessWidget {
  const _WatchTeamRow({required this.teamA, required this.teamB});
  final String teamA;
  final String teamB;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            teamA,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'vs',
            style: TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ),
        Flexible(
          child: Text(
            teamB,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Bouton démarrer compact.
class _WatchStartButton extends StatelessWidget {
  const _WatchStartButton({
    required this.isCreating,
    required this.label,
    required this.onTap,
  });
  final bool isCreating;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCreating ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: isCreating
              ? AppTheme.primary.withValues(alpha: 0.4)
              : AppTheme.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: isCreating
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                '🚀 $label',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
      ),
    );
  }
}

/// Badge indiquant le mode vocal actif.
class _WatchVoiceBadge extends StatelessWidget {
  const _WatchVoiceBadge({
    required this.isLocal,
    this.localLabel = 'Local',
    this.onTap,
  });
  final bool isLocal;
  final String localLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isLocal ? Colors.tealAccent : AppTheme.primary;
    final label = isLocal ? '⚡ $localLabel' : '🧠 Gemini';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.settings, size: 8, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
