import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// The application name
  ///
  /// In en, this message translates to:
  /// **'ScoreBot'**
  String get appTitle;

  /// No description provided for @sport.
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get sport;

  /// No description provided for @teamsAndPlayers.
  ///
  /// In en, this message translates to:
  /// **'Teams & Players'**
  String get teamsAndPlayers;

  /// No description provided for @teamA.
  ///
  /// In en, this message translates to:
  /// **'Team A'**
  String get teamA;

  /// No description provided for @teamB.
  ///
  /// In en, this message translates to:
  /// **'Team B'**
  String get teamB;

  /// No description provided for @addPlayerHint.
  ///
  /// In en, this message translates to:
  /// **'Add player(s) (e.g. Stephen, Kevin...)'**
  String get addPlayerHint;

  /// No description provided for @matchDuration.
  ///
  /// In en, this message translates to:
  /// **'Match duration'**
  String get matchDuration;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @startMatch.
  ///
  /// In en, this message translates to:
  /// **'Start match'**
  String get startMatch;

  /// No description provided for @aiStatusLocal.
  ///
  /// In en, this message translates to:
  /// **'Offline voice mode active (no AI)'**
  String get aiStatusLocal;

  /// No description provided for @aiStatusLocalSub.
  ///
  /// In en, this message translates to:
  /// **'100% offline speech recognition — Tap to switch to AI'**
  String get aiStatusLocalSub;

  /// No description provided for @aiStatusGemini.
  ///
  /// In en, this message translates to:
  /// **'AI voice mode active (Gemini)'**
  String get aiStatusGemini;

  /// No description provided for @aiStatusGeminiSub.
  ///
  /// In en, this message translates to:
  /// **'Model: {model} — Tap to change'**
  String aiStatusGeminiSub(String model);

  /// No description provided for @aiStatusUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'Voice mode not configured'**
  String get aiStatusUnconfigured;

  /// No description provided for @aiStatusUnconfiguredSub.
  ///
  /// In en, this message translates to:
  /// **'Enable offline mode or configure a Gemini API key'**
  String get aiStatusUnconfiguredSub;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @tapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get tapToSpeak;

  /// No description provided for @localVoiceModeBadge.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get localVoiceModeBadge;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @matchPaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get matchPaused;

  /// No description provided for @matchHalftime.
  ///
  /// In en, this message translates to:
  /// **'HALF-TIME'**
  String get matchHalftime;

  /// No description provided for @matchLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get matchLive;

  /// No description provided for @matchFinished.
  ///
  /// In en, this message translates to:
  /// **'MATCH FINISHED'**
  String get matchFinished;

  /// No description provided for @endMatchDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'End match?'**
  String get endMatchDialogTitle;

  /// No description provided for @endMatchDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get endMatchDialogContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get confirm;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @halftime.
  ///
  /// In en, this message translates to:
  /// **'Half-time'**
  String get halftime;

  /// No description provided for @endMatch.
  ///
  /// In en, this message translates to:
  /// **'End match'**
  String get endMatch;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Match Summary'**
  String get summaryTitle;

  /// No description provided for @matchReport.
  ///
  /// In en, this message translates to:
  /// **'Match Report'**
  String get matchReport;

  /// No description provided for @aiReportBadge.
  ///
  /// In en, this message translates to:
  /// **'AI Report'**
  String get aiReportBadge;

  /// No description provided for @localReportBadge.
  ///
  /// In en, this message translates to:
  /// **'Auto Report'**
  String get localReportBadge;

  /// No description provided for @generatingReport.
  ///
  /// In en, this message translates to:
  /// **'Generating report...'**
  String get generatingReport;

  /// No description provided for @noReportAvailable.
  ///
  /// In en, this message translates to:
  /// **'No report available.'**
  String get noReportAvailable;

  /// No description provided for @copyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get copyReport;

  /// No description provided for @reportCopied.
  ///
  /// In en, this message translates to:
  /// **'Report copied to clipboard!'**
  String get reportCopied;

  /// No description provided for @regenerateReport.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerateReport;

  /// No description provided for @topScorer.
  ///
  /// In en, this message translates to:
  /// **'Top scorer: {player} ({points})'**
  String topScorer(String player, int points);

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get stats;

  /// No description provided for @teamStats.
  ///
  /// In en, this message translates to:
  /// **'Team Statistics'**
  String get teamStats;

  /// No description provided for @playerStats.
  ///
  /// In en, this message translates to:
  /// **'Player Statistics'**
  String get playerStats;

  /// No description provided for @newMatch.
  ///
  /// In en, this message translates to:
  /// **'New match'**
  String get newMatch;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// No description provided for @winner.
  ///
  /// In en, this message translates to:
  /// **'{name} wins!'**
  String winner(String name);

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @assists.
  ///
  /// In en, this message translates to:
  /// **'Assists'**
  String get assists;

  /// No description provided for @yellowCards.
  ///
  /// In en, this message translates to:
  /// **'Yellow cards'**
  String get yellowCards;

  /// No description provided for @redCards.
  ///
  /// In en, this message translates to:
  /// **'Red cards'**
  String get redCards;

  /// No description provided for @voiceModeConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Mode Settings'**
  String get voiceModeConfigTitle;

  /// No description provided for @voiceModeOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Voice Mode'**
  String get voiceModeOnboardingTitle;

  /// No description provided for @voiceEngine.
  ///
  /// In en, this message translates to:
  /// **'Voice engine'**
  String get voiceEngine;

  /// No description provided for @modeNoAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode (No AI)'**
  String get modeNoAiTitle;

  /// No description provided for @modeNoAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'100% offline, zero quota, instant'**
  String get modeNoAiSubtitle;

  /// No description provided for @modeGeminiTitle.
  ///
  /// In en, this message translates to:
  /// **'Gemini AI Mode'**
  String get modeGeminiTitle;

  /// No description provided for @modeGeminiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Natural speech, assists, cards and fouls'**
  String get modeGeminiSubtitle;

  /// No description provided for @howLocalWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How does offline mode work?'**
  String get howLocalWorksTitle;

  /// No description provided for @howLocalWorksContent.
  ///
  /// In en, this message translates to:
  /// **'ScoreBot uses the speech recognition engine built into your device without any network requests.\nCommon commands are instantly recognized:\n• \"Goal Team A\" or \"Goal Red Team\"\n• \"Goal by [Player Name]\"\n• \"Pause\" / \"Resume\" / \"Half-time\" / \"End match\"\n• \"Cancel last goal\"'**
  String get howLocalWorksContent;

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini API Key'**
  String get apiKeyLabel;

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'AIzaSy...'**
  String get apiKeyHint;

  /// No description provided for @apiKeyHelp.
  ///
  /// In en, this message translates to:
  /// **'Free API key from aistudio.google.com'**
  String get apiKeyHelp;

  /// No description provided for @geminiModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Gemini Model'**
  String get geminiModelLabel;

  /// No description provided for @customModelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. gemini-2.5-pro...'**
  String get customModelHint;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Gemini Connection'**
  String get testConnection;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing connection...'**
  String get testingConnection;

  /// No description provided for @testSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful! Model \"{model}\" is ready.'**
  String testSuccess(String model);

  /// No description provided for @testFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed. Please check your API key.'**
  String get testFailed;

  /// No description provided for @activateNoAi.
  ///
  /// In en, this message translates to:
  /// **'Activate Offline Mode'**
  String get activateNoAi;

  /// No description provided for @saveAndActivateAi.
  ///
  /// In en, this message translates to:
  /// **'Save & Activate AI'**
  String get saveAndActivateAi;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
