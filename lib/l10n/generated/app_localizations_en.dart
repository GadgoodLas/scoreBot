// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ScoreBot';

  @override
  String get sport => 'Sport';

  @override
  String get teamsAndPlayers => 'Teams & Players';

  @override
  String get teamA => 'Team A';

  @override
  String get teamB => 'Team B';

  @override
  String get addPlayerHint => 'Add player(s) (e.g. Stephen, Kevin...)';

  @override
  String get matchDuration => 'Match duration';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get startMatch => 'Start match';

  @override
  String get aiStatusLocal => 'Offline voice mode active (no AI)';

  @override
  String get aiStatusLocalSub =>
      '100% offline speech recognition — Tap to switch to AI';

  @override
  String get aiStatusGemini => 'AI voice mode active (Gemini)';

  @override
  String aiStatusGeminiSub(String model) {
    return 'Model: $model — Tap to change';
  }

  @override
  String get aiStatusUnconfigured => 'Voice mode not configured';

  @override
  String get aiStatusUnconfiguredSub =>
      'Enable offline mode or configure a Gemini API key';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get tapToSpeak => 'Tap to speak';

  @override
  String get localVoiceModeBadge => 'Offline';

  @override
  String get listening => 'Listening...';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get matchPaused => 'PAUSED';

  @override
  String get matchHalftime => 'HALF-TIME';

  @override
  String get matchLive => 'LIVE';

  @override
  String get matchFinished => 'MATCH FINISHED';

  @override
  String get endMatchDialogTitle => 'End match?';

  @override
  String get endMatchDialogContent => 'This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'End';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get halftime => 'Half-time';

  @override
  String get endMatch => 'End match';

  @override
  String get summaryTitle => 'Match Summary';

  @override
  String get matchReport => 'Match Report';

  @override
  String get aiReportBadge => 'AI Report';

  @override
  String get localReportBadge => 'Auto Report';

  @override
  String get generatingReport => 'Generating report...';

  @override
  String get noReportAvailable => 'No report available.';

  @override
  String get copyReport => 'Copy report';

  @override
  String get reportCopied => 'Report copied to clipboard!';

  @override
  String get shareReport => 'Share Report';

  @override
  String get downloadReport => 'Download (.txt)';

  @override
  String reportDownloaded(String filename) {
    return 'Report saved: $filename';
  }

  @override
  String get regenerateReport => 'Regenerate';

  @override
  String topScorer(String player, int points) {
    return 'Top scorer: $player ($points)';
  }

  @override
  String get stats => 'Statistics';

  @override
  String get teamStats => 'Team Statistics';

  @override
  String get playerStats => 'Player Statistics';

  @override
  String get newMatch => 'New match';

  @override
  String get draw => 'Draw';

  @override
  String winner(String name) {
    return '$name wins!';
  }

  @override
  String get goals => 'Goals';

  @override
  String get assists => 'Assists';

  @override
  String get yellowCards => 'Yellow cards';

  @override
  String get redCards => 'Red cards';

  @override
  String get voiceModeConfigTitle => 'Voice Mode Settings';

  @override
  String get voiceModeOnboardingTitle => 'Enable Voice Mode';

  @override
  String get voiceEngine => 'Voice engine';

  @override
  String get modeNoAiTitle => 'Offline Mode (No AI)';

  @override
  String get modeNoAiSubtitle => '100% offline, zero quota, instant';

  @override
  String get modeGeminiTitle => 'Gemini AI Mode';

  @override
  String get modeGeminiSubtitle => 'Natural speech, assists, cards and fouls';

  @override
  String get howLocalWorksTitle => 'How does offline mode work?';

  @override
  String get howLocalWorksContent =>
      'ScoreBot uses the speech recognition engine built into your device without any network requests.\nCommon commands are instantly recognized:\n• \"Goal Team A\" or \"Goal Red Team\"\n• \"Goal by [Player Name]\"\n• \"Pause\" / \"Resume\" / \"Half-time\" / \"End match\"\n• \"Cancel last goal\"';

  @override
  String get apiKeyLabel => 'Google Gemini API Key';

  @override
  String get apiKeyHint => 'AIzaSy...';

  @override
  String get apiKeyHelp => 'Free API key from aistudio.google.com';

  @override
  String get geminiModelLabel => 'Gemini Model';

  @override
  String get customModelHint => 'e.g. gemini-2.5-pro...';

  @override
  String get testConnection => 'Test Gemini Connection';

  @override
  String get testingConnection => 'Testing connection...';

  @override
  String testSuccess(String model) {
    return 'Connection successful! Model \"$model\" is ready.';
  }

  @override
  String get testFailed => 'Connection test failed. Please check your API key.';

  @override
  String get activateNoAi => 'Activate Offline Mode';

  @override
  String get saveAndActivateAi => 'Save & Activate AI';

  @override
  String get skip => 'Skip';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get save => 'Save';

  @override
  String get breakDuration => 'Break / Halftime after';

  @override
  String get noBreak => 'No break';

  @override
  String get breakNotificationVocal => 'Break time! Take a break.';

  @override
  String get matchEndNotificationVocal => 'Full time! Match finished.';

  @override
  String get breakAlertTitle => 'Break suggested';

  @override
  String get breakAlertMessage =>
      'Break time reached. Would you like to pause the match?';

  @override
  String get matchEndAlertTitle => 'Full time reached';

  @override
  String get matchEndAlertMessage =>
      'Match duration completed. Would you like to end the match?';

  @override
  String get takeBreak => 'Take a break';

  @override
  String get finishMatch => 'Finish match';

  @override
  String get continuePlaying => 'Keep playing';
}
