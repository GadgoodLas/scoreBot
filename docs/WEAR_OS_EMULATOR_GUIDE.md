# ⌚ Guide de Test sur Émulateur Wear OS (Android Studio)

Ce guide détaille les étapes simples pour exécuter et tester **ScoreBot** sur un émulateur de montre connectée **Wear OS** depuis **Android Studio** ou directement en ligne de commande.

---

## 📋 Prérequis

1. **Android Studio** installé avec le **SDK Android** et les composants d'émulation.
2. Un émulateur Wear OS configuré (un émulateur `Wear_OS_Small_Round` est déjà configuré sur votre machine).
3. Flutter SDK opérationnel.

---

## 🚀 Étape 1 : Démarrer l'émulateur Wear OS

### Option A — En ligne de commande (Le plus rapide)
Ouvrez un terminal PowerShell à la racine du projet et exécutez :
```powershell
flutter emulators --launch Wear_OS_Small_Round
```
> L'émulateur de la montre ronde démarre alors sur votre bureau.

### Option B — Depuis Android Studio
1. Ouvrez Android Studio.
2. Allez dans le menu : **Tools** > **Device Manager** (ou cliquez sur l'icône de téléphone/montre dans la barre d'outils droite).
3. Dans l'onglet **Virtual**, repérez la montre **Wear OS Small Round**.
4. Cliquez sur le bouton **Play (▶️)** pour la lancer.

*(Si vous n'avez pas encore d'émulateur Wear OS : cliquez sur **Create Device** > catégorie **Wear OS** > choisissez **Wear OS Small Round** ou **Pixel Watch** > téléchargez l'image système Wear OS 4 ou 5 > Terminer).*

---

## 🔍 Étape 2 : Vérifier la détection de la montre

Une fois l'émulateur allumé et arrivé sur l'écran d'accueil de la montre, tapez dans le terminal :
```powershell
flutter devices
```
Vous devez voir apparaître l'émulateur dans la liste, par exemple :
```text
Wear OS Small Round (mobile) • emulator-5554 • android-x86 • Android ... (Wear OS)
```

---

## 🏃 Étape 3 : Lancer ScoreBot sur la montre

Le projet ScoreBot dispose d'une flavor dédiée aux montres : `watch`.

### En ligne de commande :
```powershell
flutter run --flavor watch -d emulator-5554
```
*(Remplacez `emulator-5554` par l'ID affiché lors de l'étape 2 ou par `Wear_OS_Small_Round`).*

### Depuis l'interface Android Studio :
1. Dans la liste déroulante des appareils (en haut d'Android Studio), sélectionnez **Wear OS Small Round**.
2. Dans le menu de configuration d'exécution :
   - Cliquez sur **Edit Configurations...** (à côté du bouton vert Run).
   - Dans le champ **Additional run args**, ajoutez :
     ```text
     --flavor watch
     ```
3. Cliquez sur le bouton vert **Run (Shift+F10)** ou **Debug (Shift+F9)**.

---

## 🎙️ Étape 4 : Activer le Microphone de l'ordinateur pour les tests vocaux

Pour tester la dictée vocale des compositions d'équipe et les commandes en match :
1. Dans la barre latérale de l'émulateur Wear OS, cliquez sur les trois petits points `...` (**Extended Controls**).
2. Allez dans l'onglet **Microphone**.
3. Assurez-vous que l'option **"Virtual microphone uses host audio input"** est activée.
4. Autorisez l'accès au microphone sur la montre lorsque l'application vous le demande au premier clic sur le micro.

---

## 🧪 Parcours de test recommandé

### 1. Écran de Configuration (`SetupWatchView`)
- L'interface s'adapte automatiquement à la forme circulaire de l'écran.
- **Sélection du sport** : Football, Futsal, Basket, etc.
- **Durée & Mi-temps** : Ajustez le temps de jeu et de pause.
- **Compositions d'équipe & Numéros** :
  - Cliquez sur une équipe pour ouvrir le panneau de dictée `LineupDictationSheet`.
  - Dictez ou saisissez des joueurs avec numéro : *"numéro 10 Messi numéro 7 Mbappé"*.
  - Vérifiez la présence des pastilles de numéros `#N`.
- Cliquez sur **Démarrer le match**.

### 2. Écran de Match en Direct (`LiveWatchView`)
- **Score tactile grand format** :
  - **1 tap** sur le score d'une équipe = **+1 point**.
  - **Double-tap rapide** sur le score = **-1 point**.
- **Commandes vocales (Bouton Micro)** :
  - *"but équipe A numéro 5 assit numéro 3"* $\rightarrow$ attribue le but au #5 et la passe décisive au #3.
  - *"carton jaune équipe A numéro 9"*.
  - *"pause"* / *"reprends"*.
- **Gestion du temps** :
  - Le chronomètre tourne et alerte à la mi-temps et à la fin du temps réglementaire.
  - Bouton **Pause/Play** et bouton **Drapeau 🏁** pour terminer le match.

### 3. Écran Résumé & Statistiques (`SummaryWatchView`)
- Défilement optimisé pour l'écran de montre.
- Tableau récapitulatif avec les statistiques de chaque joueur par numéro : **Buts (B)**, **Passes décisives (PD)**, **Cartons jaunes (CJ)**, **Cartons rouges (CR)** et **Fautes (F)**.

---

## 🛠️ Commandes utiles de dépannage

| Action | Commande |
| :--- | :--- |
| **Compiler l'APK Watch en Debug** | `flutter build apk --flavor watch --debug` |
| **Installer manuellement l'APK sur l'émulateur** | `adb install build/app/outputs/flutter-apk/app-watch-debug.apk` |
| **Voir les logs de l'application en direct** | `adb logcat \| grep -i flutter` |
| **Redémarrer le serveur ADB si non détecté** | `adb kill-server; adb start-server` |
