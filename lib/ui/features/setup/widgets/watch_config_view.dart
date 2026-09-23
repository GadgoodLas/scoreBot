import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/main.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';

/// Vue de configuration complète adaptée aux écrans circulaires Wear OS.
/// Permet de basculer le moteur vocal (Local vs Gemini), de saisir ou coller la clé API,
/// de choisir le modèle IA et de basculer la langue.
class WatchConfigView extends StatefulWidget {
  const WatchConfigView({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  static Future<void> show(BuildContext context, SetupViewModel viewModel) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => WatchConfigView(viewModel: viewModel),
      ),
    );
  }

  @override
  State<WatchConfigView> createState() => _WatchConfigViewState();
}

class _WatchConfigViewState extends State<WatchConfigView> {
  late final TextEditingController _apiKeyController;
  late String _selectedEngine;
  late String _selectedModel;
  bool _isTesting = false;
  String? _testMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.viewModel.currentApiKey);
    _selectedEngine = widget.viewModel.voiceEngine;
    _selectedModel = widget.viewModel.currentAiModel;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _apiKeyController.text = data.text!.trim();
      });
    }
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = 'Clé API vide';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testSuccess = null;
    });

    final success = await widget.viewModel.testAiConnection(
      apiKey: key,
      model: _selectedModel,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = success;
        _testMessage = success ? '✅ Connecté !' : '❌ Erreur clé';
      });
    }
  }

  Future<void> _save() async {
    await widget.viewModel.saveAiConfig(
      apiKey: _apiKeyController.text.trim(),
      model: _selectedModel,
      voiceEngine: _selectedEngine,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── En-tête ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 14, color: Colors.white70),
                    ),
                  ),
                  Text(
                    '⚙️ ${l10n.settings.toUpperCase()}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
              const SizedBox(height: 10),

              // ─── Moteur Vocal : Local vs Gemini ───
              Text(
                l10n.voiceModeConfigTitle,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _WatchChoiceButton(
                      selected: _selectedEngine == 'local',
                      icon: Icons.offline_bolt,
                      label: '⚡ Local',
                      color: Colors.tealAccent,
                      onTap: () => setState(() => _selectedEngine = 'local'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _WatchChoiceButton(
                      selected: _selectedEngine == 'gemini',
                      icon: Icons.auto_awesome,
                      label: '🧠 Gemini',
                      color: AppTheme.primary,
                      onTap: () => setState(() => _selectedEngine = 'gemini'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── Section Clé & Modèle si Gemini ───
              if (_selectedEngine == 'gemini') ...[
                Text(
                  l10n.apiKeyLabel,
                  style: const TextStyle(color: Colors.white60, fontSize: 9),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TextField(
                          controller: _apiKeyController,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          decoration: const InputDecoration(
                            hintText: 'AIzaSy...',
                            hintStyle: TextStyle(color: Colors.white30, fontSize: 10),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _pasteFromClipboard,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                        ),
                        child: const Center(
                          child: Icon(Icons.paste, size: 12, color: AppTheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Sélection du modèle
                Text(
                  l10n.geminiModelLabel,
                  style: const TextStyle(color: Colors.white60, fontSize: 9),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    'gemini-2.5-flash',
                    'gemini-2.0-flash',
                    'gemini-1.5-flash',
                  ].map((m) {
                    final isSel = _selectedModel == m;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedModel = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primary : Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.replaceAll('gemini-', ''),
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),

                // Bouton Tester la connexion
                GestureDetector(
                  onTap: _isTesting ? null : _testConnection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Center(
                      child: _isTesting
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                            )
                          : Text(
                              _testMessage ?? '🧪 ${l10n.testConnection}',
                              style: TextStyle(
                                color: _testSuccess == true
                                    ? Colors.greenAccent
                                    : _testSuccess == false
                                        ? Colors.redAccent
                                        : Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ─── Langue ───
              Text(
                l10n.language,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _WatchChoiceButton(
                      selected: currentLang == 'en',
                      icon: Icons.language,
                      label: '🇬🇧 EN',
                      color: Colors.white,
                      onTap: () {
                        ScoreBotApp.setLocale(context, const Locale('en'));
                        widget.viewModel.setLanguageCode('en');
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _WatchChoiceButton(
                      selected: currentLang == 'fr',
                      icon: Icons.language,
                      label: '🇫🇷 FR',
                      color: Colors.white,
                      onTap: () {
                        ScoreBotApp.setLocale(context, const Locale('fr'));
                        widget.viewModel.setLanguageCode('fr');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ─── Bouton Enregistrer ───
              GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '💾 ${l10n.save}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchChoiceButton extends StatelessWidget {
  const _WatchChoiceButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 11, color: selected ? color : Colors.white60),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.white70,
                fontSize: 9,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

