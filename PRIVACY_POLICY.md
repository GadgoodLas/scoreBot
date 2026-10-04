# Privacy Policy for ScoreBot

**Last updated:** October 4, 2026

ScoreBot ("we", "our", or "the app") is a sports scoring and referee assistant application designed for Android smartphones and Wear OS smartwatches. We are committed to protecting your privacy.

---

## 1. Information Collection and Usage

### Audio and Voice Data (Microphone)
- **Purpose:** ScoreBot offers voice-command scoring (e.g. announcing goals, cards, fouls, and match controls).
- **Processing:**
  - **Offline / Local Mode:** Speech recognition is processed entirely on your device (`speech_to_text`). No audio recordings or transcripts are transmitted to external servers.
  - **AI Mode (Optional):** If you choose to enable the Google Gemini AI integration and supply your own API key, voice recordings are transmitted ephemerally to the Google Gemini API solely to interpret the referee command. Audio data is not stored permanently or shared with third parties for marketing purposes.
- **Permission:** Microphone permission (`RECORD_AUDIO`) is requested only when activating voice commands and is entirely optional. You can fully operate the app via manual touch controls without granting microphone access.

### Local Match Data (On-Device Storage)
- Match scores, team names, rosters, timestamps, and card statistics are stored **locally on your device** using Hive.
- We do not operate a remote user account database. We do not collect names, email addresses, or phone numbers.

### Network and Internet
- Network access is used strictly for:
  - Communicating with the Gemini API if AI mode is enabled.
  - Exporting match reports to third-party apps chosen by you (e.g. WhatsApp, SMS, clipboard).

---

## 2. Third-Party Services

When using the optional AI mode, ScoreBot interacts with:
- **Google Gemini API** ([Google Privacy Policy](https://policies.google.com/privacy))

We do not use any third-party ad networks, telemetry trackers, or data-broker SDKs.

---

## 3. Data Retention and Deletion

- All match histories and configurations remain on your device. You can delete individual matches from the History screen or erase all app data by uninstalling ScoreBot or clearing its storage in your device settings.

---

## 4. Children’s Privacy

ScoreBot does not knowingly collect personally identifiable information from children under the age of 13.

---

## 5. Contact Us

If you have any questions or feedback regarding this Privacy Policy, please contact us:
- **Developer:** Mohamed Lasram
- **GitHub Repository:** [https://github.com/GadgoodLas/scoreBot](https://github.com/GadgoodLas/scoreBot)
- **Issues:** [https://github.com/GadgoodLas/scoreBot/issues](https://github.com/GadgoodLas/scoreBot/issues)
