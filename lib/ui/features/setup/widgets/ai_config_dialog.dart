import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bot/l10n/generated/app_localizations.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';

/// Modèles prédéfinis recommandés pour ScoreBot.
class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

const List<AiModelOption> kRecommendedAiModels = [
  AiModelOption(
    id: 'gemini-2.5-flash',
    name: 'Gemini 2.5 Flash',
    description: '⭐ Recommandé — Le plus rapide et réactif pour la voix',
  ),
  AiModelOption(
    id: 'gemini-2.0-flash',
    name: 'Gemini 2.0 Flash',
    description: 'Équilibré et polyvalent',
  ),
  AiModelOption(
    id: 'gemini-1.5-flash',
    name: 'Gemini 1.5 Flash',
    description: 'Très stable et léger',
  ),
  AiModelOption(
    id: 'gemini-1.5-pro',
    name: 'Gemini 1.5 Pro',
    description: 'Haute précision de raisonnement',
  ),
  AiModelOption(
    id: 'custom',
    name: 'Modèle personnalisé...',
    description: 'Saisir un identifiant de modèle Gemini spécifique',
  ),
];

/// Boîte de dialogue de configuration du mode vocal (Sans IA ou avec Gemini).
class AiConfigDialog extends StatefulWidget {
  const AiConfigDialog({
    super.key,
    required this.initialApiKey,
    required this.initialModel,
    this.initialVoiceEngine = 'local',
    required this.onSave,
    required this.onTestConnection,
    this.isOnboarding = false,
    this.onDismissOnboarding,
  });

  final String initialApiKey;
  final String initialModel;
  final String initialVoiceEngine;
  final Future<void> Function(String apiKey, String model, String voiceEngine)
  onSave;
  final Future<bool> Function(String apiKey, String model) onTestConnection;
  final bool isOnboarding;
  final VoidCallback? onDismissOnboarding;

  static Future<void> show({
    required BuildContext context,
    required String initialApiKey,
    required String initialModel,
    String initialVoiceEngine = 'local',
    required Future<void> Function(
      String apiKey,
      String model,
      String voiceEngine,
    )
    onSave,
    required Future<bool> Function(String apiKey, String model)
    onTestConnection,
    bool isOnboarding = false,
    VoidCallback? onDismissOnboarding,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isOnboarding,
      builder:
          (ctx) => AiConfigDialog(
            initialApiKey: initialApiKey,
            initialModel: initialModel,
            initialVoiceEngine: initialVoiceEngine,
            onSave: onSave,
            onTestConnection: onTestConnection,
            isOnboarding: isOnboarding,
            onDismissOnboarding: onDismissOnboarding,
          ),
    );
  }

  @override
  State<AiConfigDialog> createState() => _AiConfigDialogState();
}

class _AiConfigDialogState extends State<AiConfigDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _customModelController;

  late String _selectedEngine; // 'local' ou 'gemini'
  bool _obscureKey = true;
  String _selectedModelId = 'gemini-2.5-flash';
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testSuccessMessage;
  String? _testErrorMessage;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
    _selectedEngine = widget.initialVoiceEngine;

    final knownModel = kRecommendedAiModels.any(
      (m) => m.id == widget.initialModel && m.id != 'custom',
    );

    if (knownModel) {
      _selectedModelId = widget.initialModel;
      _customModelController = TextEditingController();
    } else if (widget.initialModel.isNotEmpty) {
      _selectedModelId = 'custom';
      _customModelController = TextEditingController(text: widget.initialModel);
    } else {
      _selectedModelId = 'gemini-2.5-flash';
      _customModelController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  String get _effectiveModel =>
      _selectedModelId == 'custom'
          ? _customModelController.text.trim()
          : _selectedModelId;

  Future<void> _handleTest() async {
    final key = _apiKeyController.text.trim();
    final model = _effectiveModel;

    if (key.isEmpty) {
      setState(() {
        _testErrorMessage = 'Veuillez d\'abord saisir votre clé API.';
        _testSuccessMessage = null;
      });
      return;
    }

    if (model.isEmpty) {
      setState(() {
        _testErrorMessage = 'Veuillez spécifier un nom de modèle valide.';
        _testSuccessMessage = null;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testErrorMessage = null;
      _testSuccessMessage = null;
    });

    try {
      final success = await widget.onTestConnection(key, model);
      if (mounted) {
        setState(() {
          _isTesting = false;
          if (success) {
            _testSuccessMessage = '✅ Connexion réussie ! Modèle "$model" prêt.';
          } else {
            _testErrorMessage = '❌ Échec du test. Vérifiez votre clé.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testErrorMessage = '❌ $e';
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final key = _apiKeyController.text.trim();
    final model = _effectiveModel;
    final engine = _selectedEngine;

    if (engine == 'gemini' && key.isEmpty && !widget.isOnboarding) {
      setState(() {
        _testErrorMessage = 'La clé API Gemini est requise pour le mode IA.';
      });
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.onSave(key, model, engine);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(
              engine == 'local'
                  ? '⚡ Mode vocal local (sans IA) activé avec succès !'
                  : '🧠 Mode IA ($model) activé avec succès !',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _testErrorMessage = 'Erreur lors de la sauvegarde : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLocal = _selectedEngine == 'local';

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── En-tête ───
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLocal ? Icons.offline_bolt : Icons.auto_awesome,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isOnboarding
                              ? l10n.voiceModeOnboardingTitle
                              : l10n.voiceModeConfigTitle,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLocal
                              ? l10n.modeNoAiSubtitle
                              : l10n.modeGeminiSubtitle,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isOnboarding)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Sélecteur de Mode (Local vs Gemini) ───
              Text(
                l10n.voiceEngine,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _EngineCard(
                      title: l10n.modeNoAiTitle,
                      subtitle: l10n.modeNoAiSubtitle,
                      isSelected: isLocal,
                      onTap: () => setState(() => _selectedEngine = 'local'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EngineCard(
                      title: l10n.modeGeminiTitle,
                      subtitle: l10n.modeGeminiSubtitle,
                      isSelected: !isLocal,
                      onTap: () => setState(() => _selectedEngine = 'gemini'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Détails selon le mode choisi ───
              if (isLocal) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.howLocalWorksTitle,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.howLocalWorksContent,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ─── Mode Gemini : Clé API & Modèle ───
                Text(
                  l10n.apiKeyLabel,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: AppTheme.background,
                    prefixIcon: const Icon(
                      Icons.key,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed:
                              () => setState(() => _obscureKey = !_obscureKey),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.paste,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          tooltip: 'Coller depuis le presse-papier',
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null && mounted) {
                              setState(() {
                                _apiKeyController.text = data!.text!.trim();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Clé gratuite sur aistudio.google.com (Google AI Studio)',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 16),

                // Modèle Gemini
                const Text(
                  'Modèle Gemini',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedModelId,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      items:
                          kRecommendedAiModels.map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    opt.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    opt.description,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedModelId = val);
                        }
                      },
                    ),
                  ),
                ),

                if (_selectedModelId == 'custom') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customModelController,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ex: gemini-2.5-pro, gemini-exp-1206...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppTheme.background,
                      prefixIcon: const Icon(
                        Icons.code,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Message résultat du test
                if (_testSuccessMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _testSuccessMessage!,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_testErrorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _testErrorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Bouton Tester
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _handleTest,
                  icon:
                      _isTesting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.network_check, size: 18),
                  label: Text(
                    _isTesting ? l10n.testingConnection : l10n.testConnection,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ─── Actions principales ───
              Row(
                children: [
                  if (widget.isOnboarding)
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          widget.onDismissOnboarding?.call();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          l10n.skip,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                              : Text(
                                isLocal
                                    ? '⚡ ${l10n.activateNoAi}'
                                    : '🧠 ${l10n.saveAndActivateAi}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
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
    );
  }
}
