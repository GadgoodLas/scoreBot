# ⚽ ScoreBot

Real-time sports scoring application for Android smartphones and Wear OS smartwatches with voice commands, tap scoring, and artificial intelligence.

> Track scores, scorers, assists, cards, and match statistics simply by speaking or tapping the screen.  
> **"Team A goal Stephane assist Nabil"** → Score and statistics updated instantly.

---

## 🎯 Features

- **⚡ No-AI Mode (Local / 100% Offline)**:
  - **No API key required**: Use essential voice commands straight out of the box with zero internet connectivity or account required.
  - **Ultra-low latency (< 1 ms)**: On-device speech recognition (`speech_to_text`) combined with an ultra-fast deterministic parser.
  - Recognizes goals/points, team player roster names, assists, cards, fouls, and match control referee commands (*"Pause"*, *"Resume"*, *"Half time"*, *"Undo"*).
- **🎙️ AI Mode (Google Gemini)**:
  - Advanced natural language understanding for complex sentences and freeform conversational speech.
  - Direct multimodal audio analysis or assisted text input.
- **🌐 Full Bilingual Support (English & French)**:
  - **English by default** for all UI screens, logs, and voice recognition.
  - Full **French** support (UI + offline/AI voice commands) switchable at any time from the app bar with a single tap.
- **🤖 Voice Engine Selection & Customizable API Key**:
  - One-tap toggle between **⚡ No-AI Mode (Local)** and **🧠 AI Mode (Gemini)** in settings.
  - Select your preferred Gemini AI model (`gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro`, or custom models) and your personal Gemini API key.
  - **First-run onboarding dialog**: Guides users on initial setup while allowing immediate local usage without any configuration.
  - Real-time test button to immediately validate API key and model connectivity.
  - Secure local persistence using Hive.
- **👆 Rapid Tap Scoring**:
  - **1 tap on a team's score** 👉 **+1 point**
  - **2 quick taps (double-tap) on score** 👉 **-1 point** *(with negative score protection)*
- **👥 Squad & Player Management**:
  - Enter player names for each team before kickoff (individual entry or comma-separated bulk list).
  - Automatic attribution of goals and assists to registered players (both in local offline mode and AI mode).
- **📊 Comprehensive Post-Match Analytics**:
  - Podiums for top scorers and top assist providers.
  - Detailed player stat cards for each team: Goals ⚽, Assists 🅰️, Yellow cards 🟨, Red cards 🟥.
  - Complete chronological event timeline and formatted text export for sharing (WhatsApp, SMS, email).
- **⌚ Pixel Watch & Wear OS Optimized**:
  - Circular AMOLED high-contrast interface.
  - Real-time voice mode indicator (`⚡ Local` or `🧠 AI`) and live speech transcription overlay.
  - Distinct haptic feedback patterns (vibrations) on microphone open, recording finish, and event validation.
- **⏱️ Voice-Activated Match Controls**:
  - Referee commands: *"Pause"*, *"Resume"*, *"Half time"*, *"End match"* / *"Final whistle"*, *"Undo last goal"*.
- **🛡️ Gemini API Resilience (Auto Fallback)**:
  - Strict priority cascade starting with the user's preferred model.
  - Automatic fallback to backup models in case of transient upstream outages.
  - Quota handling for HTTP 429 (*Rate Limit*) and 503 (*Service Unavailable*) with exponential backoff and retry.
- **Multi-sport Ready**: Soccer/Football, Basketball, Handball, Rugby, Volleyball, Custom.
- **Persistent Local Storage**: Matches and events stored locally via Hive (100% offline-first).

---

## 🏗️ Architecture

```
lib/
├── data/
│   ├── repositories/
│   │   └── match_repository.dart             # Orchestrates Audio, Gemini/Local, and Persistence
│   └── services/
│       ├── audio_service.dart                # Audio mic capture (AAC/M4A) for Gemini
│       ├── gemini_service.dart               # Multimodal transcription + NLP with fallback
│       ├── local_speech_service.dart         # On-device speech recognition (speech_to_text)
│       ├── offline_voice_command_parser.dart # Offline deterministic parser (< 1 ms)
│       └── storage_service.dart              # Local NoSQL storage (Hive)
├── domain/
│   └── models/
│       ├── match.dart               # GameMatch, Team, Player
│       ├── game_event.dart          # GoalEvent, CardEvent, FoulEvent, etc.
│       └── sport_type.dart          # SportType enum and sport-specific rules
├── l10n/
│   ├── app_en.arb                   # English localization (default)
│   ├── app_fr.arb                   # French localization
│   └── generated/                   # Auto-generated localization classes
└── ui/
    ├── core/theme/                  # AMOLED dark theme AppTheme
    └── features/
        ├── setup/                   # Match configuration, rosters, and AI settings
        │   ├── view_models/
        │   ├── views/               # SetupView & SetupWatchView
        │   └── widgets/             # AiConfigDialog, SportSelector, PlayersSection
        ├── live/                    # In-match view (smartphone & smartwatch)
        └── summary/                 # Post-match summary, podiums, and stats
```

**MVVM** + **Clean Architecture** patterns:
- **Views**: Pure Flutter widgets, reactive and decoupled.
- **ViewModels**: Extend `ChangeNotifier`, handling UI state and haptic feedback.
- **Repositories**: Single source of truth and intelligent entity resolution.
- **Services**: Stateless wrappers around native platform APIs and the Gemini REST API.

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK ≥ 3.7.0
- Free Gemini API key ([Google AI Studio](https://aistudio.google.com/)) *(Optional for AI mode; not required for local mode)*
- Android SDK (for smartphone or Pixel Watch) or Xcode (for iOS)

### Installation

```bash
git clone https://github.com/GadgoodLas/scoreBot.git
cd scoreBot

# Install dependencies
flutter pub get

# Launch on connected device or emulator
flutter run
```

---

## ⚙️ AI Model & API Key Configuration

1. **On First Launch**: The app prompts you to configure your preferred speech engine. You can enter your Google Gemini API key or choose to stay in 100% offline local mode.
2. **From Setup Screen**: Tap the **AI** icon (`✨`) in the AppBar at any time to modify your key, model, or switch between local and AI engines.
3. **During a Live Match**: Tap the AI badge in the top bar to adjust settings without losing match state.
4. **Supported Models**:
   - `gemini-2.5-flash` ⭐ *(Recommended — ultra-fast and multimodal)*
   - `gemini-2.0-flash` *(Balanced)*
   - `gemini-1.5-flash` *(Stable)*
   - `gemini-1.5-pro` *(Complex reasoning)*
   - *Custom model* (e.g. `gemini-2.5-pro`, experimental endpoints)

---

## ⌚ Deployment on Pixel Watch (Wear OS)

1. **Enable Developer Options on Pixel Watch**:
   - Navigate to **Settings** > **System** > **About**.
   - Tap **Build number** **7 times**.
2. **Enable Wireless Debugging**:
   - In **Settings** > **Developer options**, enable **ADB debugging** and **Wireless debugging**.
   - Tap **Pair new device** and note the IP address, port, and 6-digit code.
3. **Pair and Connect via ADB**:
   ```powershell
   adb pair <WATCH_IP>:<PAIRING_PORT>
   adb connect <WATCH_IP>:<CONNECT_PORT>
   ```
4. **Run on Watch**:
   ```powershell
   flutter run -d "Pixel Watch"
   ```

---

## 🎙️ Voice Command Examples

The app natively parses commands in both **English** and **French**:

| Command (English / French) | Interpretation | Result |
|---|---|---|
| *"Goal Team A Stephane assist Nabil"* / *"But équipe A Stéphane assist Nabil"* | Scorer + Assist | ⚽ Goal: Stephane (Team A) + Assist: Nabil |
| *"Goal for the blues by Cedric"* / *"But pour les bleus par Cédric"* | Goal by team / color | ⚽ Goal: Cedric (Team B) |
| *"1-0"* / *"We scored"* | Direct score | ⚽ Goal (+1 for leading/Team A) |
| *"Three-pointer by Lucas"* / *"Panier à 3 points de Lucas"* | Specific points | 🏀 Basket (+3 points for Lucas) |
| *"Yellow card for number 10"* / *"Carton jaune numéro 10"* | Discipline | 🟨 Yellow card (#10) |
| *"Red card for Stephane"* / *"Carton rouge pour Stéphane"* | Discipline | 🟥 Red card (Stephane) |
| *"Foul by Karim"* / *"Faute de Karim"* | Foul | ⚠️ Foul recorded |
| *"Pause"* / *"Timeout"* | Clock control | ⏸️ Match paused |
| *"Resume"* / *"Play"* | Clock control | ▶️ Match resumed |
| *"Half time"* / *"Mi-temps"* | Match period | ⏱️ Halftime started |
| *"Full time"* / *"Final whistle"* / *"Fin du match"* | Match conclusion | 🏁 Match ended & navigated to summary |
| *"Cancel last goal"* / *"Undo"* / *"Annule le dernier but"* | Correction | ↩️ Last goal reverted, score updated |

---

## 📊 Application Screens

### 1. Match Setup ([`SetupView`](lib/ui/features/setup/views/setup_view.dart) & [`SetupWatchView`](lib/ui/features/setup/views/setup_watch_view.dart))
- Sport selection (Soccer, Basketball, Rugby, Handball, Volleyball, Custom).
- Team names, colors, and match duration (10–120 min).
- **Roster input**: Add players individually or paste comma-separated lists.
- **Language Switcher**: Toggle English 🇬🇧 and French 🇫🇷 directly in the AppBar.
- **AI / Local engine switcher**: Status badge and configuration dialog.

### 2. Live Match ([`LiveView`](lib/ui/features/live/views/live_view.dart) & [`LiveWatchView`](lib/ui/features/live/views/live_watch_view.dart))
- **Touch scoring**: 1 tap (+1), double tap (-1).
- Real-time match timer and period tracking.
- Interactive timeline feed of events (goals, assists, cards, fouls).
- **Watch Mode**: Streamlined high-contrast round display, live overlay transcription, and wrist vibration.
- Push-to-talk mic button and keyboard input fallback.

### 3. Summary & Analytics ([`SummaryView`](lib/ui/features/summary/views/summary_view.dart) & [`SummaryWatchView`](lib/ui/features/summary/views/summary_watch_view.dart))
- Final score, winner announcement, and journalistic match report.
- Overall team statistics (goals, cards, fouls).
- **Individual player breakdown** for each team (goals, assists, disciplinary cards).
- Top scorers and top playmakers podiums.
- Formatted summary text export and share button.

---

## 🔒 Security & Local Data Privacy

- Your Gemini API key is stored locally on-device using Hive and is never shared with third-party servers outside Google's official Gemini endpoint (`generativelanguage.googleapis.com`).
- Offline Local mode does not transmit any audio or telemetry data off-device.
- The `.env` and `android/key.properties` files are strictly excluded from version control via `.gitignore`.

---

## 📄 License

MIT
