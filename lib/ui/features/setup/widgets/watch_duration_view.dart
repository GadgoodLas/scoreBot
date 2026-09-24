import 'package:flutter/material.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';

/// Vue de configuration des durées (match & pause) adaptée aux écrans Wear OS.
class WatchDurationView extends StatefulWidget {
  const WatchDurationView({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  static Future<void> show(BuildContext context, SetupViewModel viewModel) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => WatchDurationView(viewModel: viewModel),
      ),
    );
  }

  @override
  State<WatchDurationView> createState() => _WatchDurationViewState();
}

class _WatchDurationViewState extends State<WatchDurationView> {
  late int _duration;
  late int? _breakDuration;

  @override
  void initState() {
    super.initState();
    _duration = widget.viewModel.durationMinutes;
    _breakDuration = widget.viewModel.breakDurationMinutes;
  }

  void _save() {
    widget.viewModel.setDuration(_duration);
    widget.viewModel.setBreakDuration(_breakDuration);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              // ─── Header Durée Match ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, size: 13, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.matchDuration,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ─── Stepper Match ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _WatchCircleButton(
                    icon: Icons.remove,
                    onTap:
                        _duration > 10
                            ? () {
                              setState(() {
                                _duration -= 5;
                                if (_breakDuration != null &&
                                    _breakDuration! >= _duration) {
                                  _breakDuration = (_duration / 2).round();
                                }
                              });
                            }
                            : null,
                  ),
                  SizedBox(
                    width: 68,
                    child: Text(
                      '$_duration min',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _WatchCircleButton(
                    icon: Icons.add,
                    onTap:
                        _duration < 180
                            ? () {
                              setState(() {
                                _duration += 5;
                              });
                            }
                            : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),

              // ─── Header Pause ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.pause_circle_outline,
                    size: 12,
                    color: Colors.tealAccent,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.breakDuration,
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ─── Stepper Pause ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _WatchCircleButton(
                    icon: Icons.remove,
                    onTap: () {
                      setState(() {
                        if (_breakDuration == null) {
                          _breakDuration = (_duration / 2).round();
                        } else if (_breakDuration! > 5) {
                          _breakDuration = _breakDuration! - 5;
                        } else {
                          _breakDuration = null;
                        }
                      });
                    },
                  ),
                  SizedBox(
                    width: 68,
                    child: Text(
                      _breakDuration != null
                          ? '$_breakDuration min'
                          : l10n.noBreak,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            _breakDuration != null
                                ? Colors.tealAccent
                                : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _WatchCircleButton(
                    icon: Icons.add,
                    onTap: () {
                      setState(() {
                        if (_breakDuration == null) {
                          _breakDuration = 5;
                        } else if (_breakDuration! < _duration - 5) {
                          _breakDuration = _breakDuration! + 5;
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ─── Raccourcis rapides ───
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  _WatchDurationChip(
                    label: l10n.noBreak,
                    selected: _breakDuration == null,
                    onTap: () {
                      setState(() {
                        _breakDuration = null;
                      });
                    },
                  ),
                  _WatchDurationChip(
                    label: '50% (${(_duration / 2).round()}m)',
                    selected: _breakDuration == (_duration / 2).round(),
                    onTap: () {
                      setState(() {
                        _breakDuration = (_duration / 2).round();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ─── Bouton Enregistrer ───
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 13),
                  label: Text(
                    l10n.save,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchCircleButton extends StatelessWidget {
  const _WatchCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color:
              onTap != null
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null ? Colors.white24 : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: onTap != null ? Colors.white : Colors.white24,
        ),
      ),
    );
  }
}

class _WatchDurationChip extends StatelessWidget {
  const _WatchDurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:
              selected
                  ? Colors.tealAccent.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.tealAccent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.tealAccent : Colors.white60,
            fontSize: 8,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
