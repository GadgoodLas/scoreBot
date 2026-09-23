// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ScoreBot';

  @override
  String get sport => 'Sport';

  @override
  String get teamsAndPlayers => 'Équipes & Joueurs';

  @override
  String get teamA => 'Équipe A';

  @override
  String get teamB => 'Équipe B';

  @override
  String get addPlayerHint => 'Ajouter joueur(s) (ex: Stéphane, Nabil...)';

  @override
  String get matchDuration => 'Durée du match';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get startMatch => 'Démarrer le match';

  @override
  String get aiStatusLocal => 'Mode vocal local actif (sans IA)';

  @override
  String get aiStatusLocalSub =>
      'Reconnaissance 100% hors-ligne — Cliquez pour passer en mode IA';

  @override
  String get aiStatusGemini => 'Mode vocal IA actif (Gemini)';

  @override
  String aiStatusGeminiSub(String model) {
    return 'Modèle : $model — Cliquez pour modifier';
  }

  @override
  String get aiStatusUnconfigured => 'Mode vocal non configuré';

  @override
  String get aiStatusUnconfiguredSub =>
      'Activez le mode local ou configurez une clé Gemini';

  @override
  String get settings => 'Réglages';

  @override
  String get language => 'Langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get tapToSpeak => 'Tap pour parler';

  @override
  String get localVoiceModeBadge => 'Local';

  @override
  String get listening => 'Écoute en cours...';

  @override
  String get analyzing => 'Analyse en cours...';

  @override
  String get matchPaused => 'PAUSE';

  @override
  String get matchHalftime => 'MI-TEMPS';

  @override
  String get matchLive => 'EN COURS';

  @override
  String get matchFinished => 'MATCH TERMINÉ';

  @override
  String get endMatchDialogTitle => 'Terminer le match ?';

  @override
  String get endMatchDialogContent => 'Cette action ne peut pas être annulée.';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Terminer';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get halftime => 'Mi-temps';

  @override
  String get endMatch => 'Fin du match';

  @override
  String get summaryTitle => 'Résumé du match';

  @override
  String get matchReport => 'Compte-rendu du match';

  @override
  String get aiReportBadge => 'Compte-rendu IA';

  @override
  String get localReportBadge => 'Compte-rendu auto';

  @override
  String get generatingReport => 'Génération...';

  @override
  String get noReportAvailable => 'Aucun rapport disponible.';

  @override
  String get copyReport => 'Copier le rapport';

  @override
  String get reportCopied => 'Rapport copié dans le presse-papier !';

  @override
  String get shareReport => 'Partager le rapport';

  @override
  String get downloadReport => 'Télécharger (.txt)';

  @override
  String reportDownloaded(String filename) {
    return 'Rapport enregistré : $filename';
  }

  @override
  String get regenerateReport => 'Régénérer';

  @override
  String topScorer(String player, int points) {
    return 'Meilleur buteur : $player ($points)';
  }

  @override
  String get stats => 'Statistiques';

  @override
  String get teamStats => 'Statistiques d\'équipe';

  @override
  String get playerStats => 'Statistiques par joueur';

  @override
  String get newMatch => 'Nouveau match';

  @override
  String get draw => 'Égalité';

  @override
  String winner(String name) {
    return '$name remporte le match !';
  }

  @override
  String get goals => 'Buts';

  @override
  String get assists => 'Passes décisives';

  @override
  String get yellowCards => 'Cartons jaunes';

  @override
  String get redCards => 'Cartons rouges';

  @override
  String get voiceModeConfigTitle => 'Configuration du Mode Vocal';

  @override
  String get voiceModeOnboardingTitle => 'Activer le mode vocal';

  @override
  String get voiceEngine => 'Moteur vocal';

  @override
  String get modeNoAiTitle => 'Mode Sans IA';

  @override
  String get modeNoAiSubtitle => '100% hors-ligne, zéro quota, instantané';

  @override
  String get modeGeminiTitle => 'Mode IA Gemini';

  @override
  String get modeGeminiSubtitle => 'Langage naturel, passes décisives, cartons';

  @override
  String get howLocalWorksTitle => 'Comment ça fonctionne en mode sans IA ?';

  @override
  String get howLocalWorksContent =>
      'ScoreBot utilise le moteur vocal intégré à votre smartphone/montre sans aucun appel réseau.\nLes commandes courantes sont reconnues immédiatement :\n• \"But équipe A\" ou \"But équipe rouge\"\n• \"But de [Nom du joueur]\"\n• \"Pause\" / \"Reprends\" / \"Mi-temps\" / \"Fin du match\"\n• \"Annule le dernier but\"';

  @override
  String get apiKeyLabel => 'Clé API Google Gemini';

  @override
  String get apiKeyHint => 'AIzaSy...';

  @override
  String get apiKeyHelp => 'Clé gratuite sur aistudio.google.com';

  @override
  String get geminiModelLabel => 'Modèle Gemini';

  @override
  String get customModelHint => 'ex: gemini-2.5-pro, gemini-exp-1206...';

  @override
  String get testConnection => 'Tester la connexion Gemini';

  @override
  String get testingConnection => 'Test en cours...';

  @override
  String testSuccess(String model) {
    return 'Connexion réussie ! Modèle \"$model\" prêt.';
  }

  @override
  String get testFailed => 'Échec du test. Vérifiez votre clé API.';

  @override
  String get activateNoAi => 'Activer le mode sans IA';

  @override
  String get saveAndActivateAi => 'Enregistrer et activer l\'IA';

  @override
  String get skip => 'Passer';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get save => 'Enregistrer';

  @override
  String get breakDuration => 'Pause / Mi-temps après';

  @override
  String get noBreak => 'Sans pause';

  @override
  String get breakNotificationVocal =>
      'Cest lheure de la pause ! Prenez une pause.';

  @override
  String get matchEndNotificationVocal =>
      'Fin du match ! Le temps réglementaire est écoulé.';

  @override
  String get breakAlertTitle => 'Pause conseillée';

  @override
  String get breakAlertMessage =>
      'La durée avant la pause est atteinte. Voulez-vous suspendre le match ?';

  @override
  String get matchEndAlertTitle => 'Temps réglementaire écoulé';

  @override
  String get matchEndAlertMessage =>
      'La durée du match est terminée. Voulez-vous terminer le match ?';

  @override
  String get takeBreak => 'Faire la pause';

  @override
  String get finishMatch => 'Terminer le match';

  @override
  String get continuePlaying => 'Continuer à jouer';
}
