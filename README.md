# ⚽ ScoreBot

Application mobile et montre connectée de scoring sportif en temps réel avec commandes vocales et intelligence artificielle.

> Enregistrez les scores, buteurs, passeurs, cartons et statistiques d'un match simplement en parlant.  
> **"But équipe A Stéphane assist Nabil"** → Score et statistiques mis à jour instantanément.

---

## 🎯 Fonctionnalités

- **🎙️ Commandes vocales intelligentes** : Appuyez ou dictez — Gemini transcrit et extrait l'événement en une seule passe multimodale.
- **👆 Scoring tactile rapide** :
  - **1 tap sur le score d'une équipe** 👉 **+1 point**
  - **2 taps (double-tap) sur le score d'une équipe** 👉 **-1 point** *(protection contre les scores négatifs)*
- **👥 Gestion des effectifs & joueurs** :
  - Saisie des noms des joueurs pour chaque équipe avant le coup d'envoi.
  - Attribution automatique des buts et des passes décisives aux joueurs.
- **📊 Statistiques complètes par équipe et par joueur** :
  - Cartes individuelles par équipe : Buts ⚽, Passes décisives 🅰️, Cartons jaunes 🟨, Cartons rouges 🟥.
  - Classement des meilleurs buteurs et meilleurs passeurs.
  - Chronologie complète et export texte pour partage (WhatsApp, SMS, etc.).
- **⌚ Optimisé Pixel Watch (Wear OS)** :
  - Interface compacte AMOLED à fort contraste.
  - Retour textuel et visuel immédiat sur la transcription vocale.
  - Retours haptiques (vibrations) à l'ouverture du micro et à la validation.
- **⏱️ Contrôle vocal du match** :
  - Commandes vocales d'arbitrage : *"Pause"*, *"Reprends"*, *"Mi-temps"*, *"Fin du match"*, *"Annule le but"*.
- **🛡️ Résilience API Gemini (Multi-Model Fallback)** :
  - Bascule automatique en cascade (`gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-3.8-flash`...).
  - Gestion automatique des erreurs 429 (*Rate Limit*) et 503 (*Surchargé*) avec retry et backoff exponentiel.
- **Multi-sports** : Football, Basketball, Handball, Rugby, Volleyball, Personnalisé.
- **Stockage local persistant** : Matchs et événements sauvegardés localement avec Hive (fonctionne hors ligne).

---

## 🏗️ Architecture

```
lib/
├── data/
│   ├── repositories/
│   │   └── match_repository.dart    # Orchestre Audio, Gemini et Persistance
│   └── services/
│       ├── audio_service.dart       # Capture micro (record, autoGain, noiseSuppress)
│       ├── gemini_service.dart      # Transcription + NLP structuré avec fallback
│       └── storage_service.dart     # Stockage local NoSQL (Hive)
├── domain/
│   └── models/
│       ├── match.dart               # GameMatch, Team, Player
│       ├── game_event.dart          # GoalEvent, CardEvent, FoulEvent, etc.
│       └── sport_type.dart          # SportType enum et règles
└── ui/
    ├── core/theme/                  # Thème sombre AMOLED AppTheme
    └── features/
        ├── setup/                   # Configuration du match et saisie des joueurs
        ├── live/                    # Match en direct (vue smartphone + vue montre)
        └── summary/                 # Résumé, podiums et stats détaillées
```

Pattern **MVVM** + **Clean Architecture** :
- **Views** : Widgets Flutter purs, réactifs et découplés.
- **ViewModels** : Étendent `ChangeNotifier`, gèrent l'état UI et les retours haptiques.
- **Repositories** : Source unique de vérité et résolution intelligente des entités.
- **Services** : Wrappers stateless des services natifs et API Gemini.

---

## 🚀 Démarrage

### Prérequis

- Flutter SDK ≥ 3.7.0
- Clé API Gemini ([Google AI Studio](https://aistudio.google.com/))
- Android SDK (pour smartphone ou Pixel Watch) ou Xcode (pour iOS)

### Installation

```bash
git clone https://github.com/GadgoodLas/scoreBot.git
cd scoreBot

# Configurer la clé API
cp .env.example .env
# Éditez .env et renseignez votre clé GEMINI_API_KEY

# Installer les dépendances
flutter pub get

# Lancer sur smartphone ou desktop
flutter run
```

---

## ⌚ Déploiement sur Pixel Watch (Wear OS)

1. **Activer le mode Développeur sur la Pixel Watch** :
   - Allez dans **Paramètres** > **Système** > **À propos**.
   - Tapotez **7 fois** sur **Version** / **Numéro de build**.
2. **Activer le Débogage Wi-Fi** :
   - Dans **Paramètres** > **Options pour les développeurs** : activez **Débogage ADB** et **Débogage sans fil**.
   - Cliquez sur **Associer un appareil** (*Pair device*) et notez l'IP, le port et le code à 6 chiffres.
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

## 🔐 Sécurité

> ⚠️ Le fichier `.env` est exclu du contrôle de version (`.gitignore`). Ne commitez jamais votre clé API Gemini.

---

## 📄 Licence

MIT License — Libre d'utilisation et de modification.
