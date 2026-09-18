# ⚽ ScoreBot

Application mobile et montre connectée de scoring sportif en temps réel avec commandes vocales, scoring tactile et intelligence artificielle.

> Enregistrez les scores, buteurs, passeurs, cartons et statistiques d'un match simplement en parlant ou en tapotant l'écran.  
> **"But équipe A Stéphane assist Nabil"** → Score et statistiques mis à jour instantanément.

---

## 🎯 Fonctionnalités

- **⚡ Mode Sans IA (Local / 100% Hors-ligne)** :
  - **Aucune clé API requise** : Utilisez les commandes vocales essentielles directement dès l'installation, sans compte ni connexion Internet.
  - **Latence ultra-faible (< 1 ms)** : Reconnaissance vocale locale (`speech_to_text`) associée à un analyseur déterministe ultra-rapide.
  - Reconnaît les buts/points, les noms des joueurs de l'effectif, les passes décisives, les cartons, les fautes, ainsi que toutes les commandes d'arbitrage (*"Pause"*, *"Reprends"*, *"Mi-temps"*, *"Annule"*).
- **🎙️ Mode IA (Google Gemini)** :
  - Compréhension du langage naturel avancée pour les phrases complexes et tournures libres.
  - Analyse multimodale directe ou saisie texte assistée.
- **🤖 Choix du moteur vocal & Clé API personnalisable** :
  - Bascule en un tap entre **⚡ Mode Sans IA (Local)** et **🧠 Mode IA (Gemini)** dans les paramètres.
  - Configuration de son propre modèle d'IA (`gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro` ou modèle personnalisé) et de sa propre clé API Gemini.
  - **Invite d'installation automatique** : Guide l'utilisateur au premier lancement tout en permettant d'utiliser l'app immédiatement en mode local.
  - Bouton de test en temps réel pour valider instantanément la clé et le modèle.
  - Sauvegarde locale sécurisée avec Hive.
- **👆 Scoring tactile rapide** :
  - **1 tap sur le score d'une équipe** 👉 **+1 point**
  - **2 taps rapides (double-tap) sur le score** 👉 **-1 point** *(avec protection anti-score négatif)*
- **👥 Gestion des effectifs & joueurs** :
  - Saisie des noms des joueurs pour chaque équipe avant le coup d'envoi (ajout unitaire ou liste séparée par des virgules).
  - Attribution automatique des buts et des passes décisives aux joueurs enregistrés (aussi bien en mode local qu'en mode IA).
- **📊 Statistiques complètes d'après-match** :
  - Podiums des meilleurs buteurs et meilleurs passeurs.
  - Cartes détaillées par joueur pour chaque équipe : Buts ⚽, Passes décisives 🅰️, Cartons jaunes 🟨, Cartons rouges 🟥.
  - Chronologie complète des événements et bouton d'export texte pour partage (WhatsApp, SMS, etc.).
- **⌚ Optimisé Pixel Watch (Wear OS)** :
  - Interface circulaire AMOLED à fort contraste.
  - Affichage instantané du badge d'état vocal (`⚡ Local` ou `🧠 IA`) et transcription vocale en superposition.
  - Retours haptiques distincts (vibrations) à l'ouverture du micro, sur fin d'enregistrement et sur validation.
- **⏱️ Contrôle vocal du match** :
  - Commandes d'arbitrage : *"Pause"*, *"Reprends"*, *"Mi-temps"*, *"Fin du match"*, *"Annule le dernier but"*.
- **🛡️ Résilience API Gemini (Fallback automatique)** :
  - Ordre d'exécution prioritaire commençant par le modèle choisi par l'utilisateur.
  - Bascule automatique en cascade sur d'autres modèles en cas de surcharge.
  - Gestion des quotas 429 (*Rate Limit*) et 503 (*Surchargé*) avec retry et backoff exponentiel.
- **Multi-sports** : Football, Basketball, Handball, Rugby, Volleyball, Personnalisé.
- **Stockage local persistant** : Matchs et événements sauvegardés localement avec Hive (fonctionne 100% hors ligne).

---

## 🏗️ Architecture

```
lib/
├── data/
│   ├── repositories/
│   │   └── match_repository.dart             # Orchestre Audio, Gemini/Local et Persistance
│   └── services/
│       ├── audio_service.dart                # Capture micro audio (AAC/M4A) pour Gemini
│       ├── gemini_service.dart               # Transcription + NLP multimodal avec fallback
│       ├── local_speech_service.dart         # Reconnaissance vocale locale (speech_to_text)
│       ├── offline_voice_command_parser.dart # Analyseur déterministe hors-ligne (< 1 ms)
│       └── storage_service.dart              # Stockage local NoSQL (Hive)
├── domain/
│   └── models/
│       ├── match.dart               # GameMatch, Team, Player
│       ├── game_event.dart          # GoalEvent, CardEvent, FoulEvent, etc.
│       └── sport_type.dart          # SportType enum et règles
└── ui/
    ├── core/theme/                  # Thème sombre AMOLED AppTheme
    └── features/
        ├── setup/                   # Configuration match, effectifs et réglages IA
        │   ├── view_models/
        │   ├── views/
        │   └── widgets/             # AiConfigDialog, SportSelector, PlayersSection
        ├── live/                    # Match en direct (vue smartphone + vue montre)
        └── summary/                 # Résumé, podiums et stats détaillées
```

Pattern **MVVM** + **Clean Architecture** :
- **Views** : Widgets Flutter purs, réactifs et découplés.
- **ViewModels** : Étendent `ChangeNotifier`, gèrent l'état UI et les retours haptiques.
- **Repositories** : Source unique de vérité et résolution intelligente des entités.
- **Services** : Wrappers stateless des services natifs et de l'API Gemini.

---

## 🚀 Démarrage Rapide

### Prérequis

- Flutter SDK ≥ 3.7.0
- Clé API Gemini gratuite ([Google AI Studio](https://aistudio.google.com/))
- Android SDK (pour smartphone ou Pixel Watch) ou Xcode (pour iOS)

### Installation

```bash
git clone https://github.com/GadgoodLas/scoreBot.git
cd scoreBot

# Installer les dépendances
flutter pub get

# Lancer sur smartphone ou desktop
flutter run
```

---

## ⚙️ Configuration du Modèle d'IA & Clé API

1. **Au premier lancement** : L'application vous propose automatiquement d'activer le mode vocal en renseignant votre clé API Google Gemini et votre modèle d'IA préféré.
2. **À tout moment depuis l'accueil** : Cliquez sur l'icône **IA** (`✨`) dans l'AppBar pour modifier votre clé ou votre modèle.
3. **Pendant le match** : L'icône IA dans le bandeau supérieur permet d'ajuster le modèle en cours de partie.
4. **Modèles supportés** :
   - `gemini-2.5-flash` ⭐ *(Recommandé — ultra-rapide et multimodal)*
   - `gemini-2.0-flash` *(Équilibré)*
   - `gemini-1.5-flash` *(Très stable)*
   - `gemini-1.5-pro` *(Haute précision de raisonnement)*
   - *Modèle personnalisé* (ex: `gemini-2.5-pro`, modèles expérimentaux)

---

## ⌚ Déploiement sur Pixel Watch (Wear OS)

1. **Activer le mode Développeur sur la Pixel Watch** :
   - Allez dans **Paramètres** > **Système** > **À propos**.
   - Tapotez **7 fois** sur **Version** / **Numéro de build**.
2. **Activer le Débogage Wi-Fi** :
   - Dans **Paramètres** > **Options pour les développeurs** : activez **Débogage ADB** et **Débogage sans fil**.
   - Cliquez sur **Associer un appareil** (*Pair device*) et notez l'adresse IP, le port et le code à 6 chiffres.
3. **Appairer et connecter via ADB** :
   ```powershell
   adb pair <IP_MONTRE>:<PORT_PAIRING>
   adb connect <IP_MONTRE>:<PORT_CONNECT>
   ```
4. **Lancer sur la montre** :
   ```powershell
   flutter run -d "Pixel Watch"
   ```

---

## 🎙️ Exemples de commandes vocales

| Commande | Interprétation | Résultat |
|---|---|---|
| *"But équipe A Stéphane assist Nabil"* | Buteur + Passeur | ⚽ Goal : Stéphane (Équipe A) + Passe : Nabil |
| *"But pour les bleus par Cédric"* | But par équipe/couleur | ⚽ Goal : Cédric (Équipe B) |
| *"1-0"* ou *"On a marqué"* | Score direct | ⚽ Goal (+1 pour l'équipe dominante/A) |
| *"Panier à 3 points de Lucas"* | Points spécifiques | 🏀 Panier (+3 points pour Lucas) |
| *"Carton jaune pour le numéro 10"* | Discipline | 🟨 Carton jaune (#10) |
| *"Carton rouge pour Stéphane"* | Discipline | 🟥 Carton rouge (Stéphane) |
| *"Faute de Karim"* | Faute | ⚠️ Faute enregistrée |
| *"Pause"* / *"Mets en pause"* | Contrôle chrono | ⏸️ Match mis en pause |
| *"Reprends"* / *"Play"* | Contrôle chrono | ▶️ Reprise du match |
| *"Mi-temps"* | Période | ⏱️ Passage en mi-temps |
| *"Fin du match"* | Clôture | 🏁 Fin de match et redirection stats |
| *"Annule le dernier but"* | Correction | ↩️ Dernier but annulé et score recalculé |

---

## 📊 Écrans de l'Application

### 1. Configuration du match ([`SetupView`](lib/ui/features/setup/views/setup_view.dart))
- Sélection du sport (Football, Basketball, Rugby, Handball...).
- Nom et couleur des deux équipes.
- **Saisie des joueurs** : Ajout un par un ou par liste séparée par des virgules.
- Réglage de la durée du match (slider 10–120 min).
- **Statut IA & Accès aux réglages** : Badge d'état du mode vocal et bouton de configuration.

### 2. Match en direct ([`LiveView`](lib/ui/features/live/views/live_view.dart) & [`LiveWatchView`](lib/ui/features/live/views/live_watch_view.dart))
- **Score tactile** : 1 tap (+1), double-tap (-1).
- Chronomètre temps réel.
- Feed interactif des événements (buteurs, passes, cartons).
- **Mode Montre** : Interface épurée avec grand affichage, transcription affichée en direct et vibration au poignet.
- Bouton microphone push-to-talk et fallback saisie clavier.

### 3. Résumé & Statistiques ([`SummaryView`](lib/ui/features/summary/views/summary_view.dart))
- Score final et vainqueur.
- Statistiques globales par équipe (buts, cartons, fautes).
- **Tableau détaillé par joueur** pour chaque équipe (buts, passes, cartons).
- Top buteurs et Top passeurs du match.
- Chronologie complète des événements.
- Bouton de partage / export texte.

---

##  Sécurité & Données Locales

- La clé API de l'utilisateur est stockée en local sur l'appareil via Hive et n'est jamais transmise à des serveurs tiers en dehors de l'API officielle Google Gemini (`generativelanguage.googleapis.com`).
- Le fichier `.env` est ignoré par `.gitignore` pour le développement local.

---

##  Licence

MIT
