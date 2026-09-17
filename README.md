# ⚽ ScoreBot

Application mobile de scoring sportif en temps réel avec commandes vocales et intelligence artificielle.

> Enregistrez les scores, buts, cartons et statistiques d'un match simplement en parlant.  
> **"But pour l'équipe rouge par Cédric assisté par Nabil"** → Score mis à jour instantanément.

---

## 🎯 Fonctionnalités

- **Commandes vocales** : Appuyez sur le micro, parlez, relâchez — Gemini transcrit et comprend votre commande
- **Multi-sports** : Football, Basketball, Handball, Rugby, Volleyball, Personnalisé
- **Chronomètre live** : Démarre automatiquement avec le match
- **Score en temps réel** : Mis à jour instantanément après chaque but
- **Feed d'événements** : Historique chronologique de tous les événements
- **Statistiques** : Buts, assists, cartons, fautes par équipe et par joueur
- **Support montre** : Vue compacte automatique sur Wear OS (petits écrans)
- **Correction vocale** : "Annule le dernier but" → annulation automatique
- **Stockage local** : Matchs persistés avec Hive (fonctionne hors ligne)

---

## 🏗️ Architecture

```
lib/
├── data/
│   ├── repositories/   # MatchRepository — orchestre les services
│   └── services/
│       ├── audio_service.dart    # Enregistrement micro (record)
│       ├── gemini_service.dart   # Transcription + NLP (Gemini API)
│       └── storage_service.dart # Persistance locale (Hive)
├── domain/
│   └── models/
│       ├── match.dart            # Match, Team, Player
│       ├── game_event.dart       # Événements (GoalEvent, CardEvent...)
│       └── sport_type.dart       # SportType enum
└── ui/
    ├── core/theme/               # Thème sombre AppTheme
    └── features/
        ├── setup/                # Écran de configuration du match
        ├── live/                 # Écran match en cours + vue montre
        └── summary/              # Résumé et statistiques
```

Pattern **MVVM** + **Clean Architecture** :
- **Views** : Widgets Flutter purs, reçoivent le ViewModel
- **ViewModels** : Étendent `ChangeNotifier`, gèrent l'état UI
- **Repositories** : Source unique de vérité, orchestrent les services
- **Services** : Wrappers stateless des APIs externes

---

## 🚀 Démarrage

### Prérequis

- Flutter SDK ≥ 3.7.0
- Clé API Gemini (obtenez-la sur [Google AI Studio](https://aistudio.google.com/))
- Android SDK (pour Android) ou Xcode (pour iOS)

### Installation

```bash
git clone <url-du-repo>
cd score_bot

# Configurer la clé API
cp .env.example .env
# Éditez .env et remplacez your_gemini_api_key_here par votre clé

# Installer les dépendances
flutter pub get

# Lancer l'app
flutter run
```

### Permissions requises

| Plateforme | Permission | Raison |
|---|---|---|
| Android | `RECORD_AUDIO` | Enregistrement des commandes vocales |
| Android | `INTERNET` | Appels à l'API Gemini |
| iOS | `NSMicrophoneUsageDescription` | Enregistrement des commandes vocales |

---

## 🎙️ Exemples de commandes vocales

| Commande | Action |
|---|---|
| "But pour l'équipe rouge par Cédric" | ⚽ Goal : Cédric (Équipe Rouge) |
| "But pour l'équipe rouge par Cédric assisté par Nabil" | ⚽ Goal + Assist |
| "Carton jaune pour le joueur 10 de l'équipe bleue" | 🟨 Carton jaune |
| "Carton rouge pour l'équipe rouge" | 🟥 Carton rouge |
| "Faute pour l'équipe bleue par Karim" | ⚠️ Faute |
| "Temps mort équipe rouge" | ⏸️ Timeout |
| "Remplacement équipe bleue, Samir sort, Mehdi entre" | 🔄 Substitution |
| "Annule le dernier but" | ↩️ Correction |

---

## 🔧 Stack Technique

| Composant | Technologie |
|---|---|
| Framework | Flutter (Dart) |
| Transcription vocale | Gemini `gemini-3.5-transcribe` |
| NLP / Parsing | Gemini `gemini-3.8-flash` (structured output) |
| State management | `provider` + `ChangeNotifier` |
| Injection dépendances | `get_it` |
| Stockage local | `hive_flutter` |
| Enregistrement audio | `record` |
| Variables d'env | `flutter_dotenv` |

---

## 🖥️ Écrans

### 1. Configuration du match
- Sélection du sport (Football, Basketball, Handball...)
- Noms des deux équipes
- Durée du match (slider 10–120 min)

### 2. Match en direct
- Chronomètre + score en grand format
- Bouton microphone (push-to-talk)
- Feed d'événements en temps réel
- Contrôles : Pause / Mi-temps / Fin de match

### 3. Résumé / Statistiques
- Score final + vainqueur
- Stats par équipe (buts, cartons, fautes)
- Top buteurs et passeurs
- Timeline chronologique de tous les événements
- Export texte pour partage

---

## 📱 Support Wear OS

L'app détecte automatiquement si elle tourne sur une petite surface (< 250dp de largeur) et affiche la vue compacte :
- Score en grands chiffres
- Chronomètre
- Tap n'importe où pour enregistrer une commande vocale

---

## 🔐 Sécurité

> ⚠️ La clé API Gemini est stockée dans `.env` (gitignored). Ne commitez jamais votre clé API.

Pour un usage en production, préférez un backend intermédiaire qui effectue les appels Gemini côté serveur.

---

## 📄 Licence

MIT License — Libre d'utilisation et de modification.
