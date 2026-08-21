# Publier une release

## Prérequis

- Flutter (channel stable ; la CI utilise la version définie dans `.github/workflows/ci.yml`).
- Un keystore Android de production. **Aucun keystore n'est fourni avec ce dépôt** — il n'en existe pas encore pour hoopmap au moment où ce document est écrit. Voir [Générer le keystore](#générer-le-keystore-une-seule-fois) ci-dessous.
- Les quatre variables d'environnement listées ci-dessous, positionnées dans le terminal qui lance le build (jamais committées).

## Variables d'environnement attendues

| Variable | Contenu |
|---|---|
| `HOOPMAP_KEYSTORE_PATH` | Chemin absolu vers le fichier `.jks` du keystore |
| `HOOPMAP_KEYSTORE_PASSWORD` | Mot de passe du keystore |
| `HOOPMAP_KEY_ALIAS` | Alias de la clé de signature à l'intérieur du keystore |
| `HOOPMAP_KEY_PASSWORD` | Mot de passe de cette clé (souvent identique au mot de passe du keystore) |

`tool/build_release.ps1` lit ces quatre variables et génère `android/key.properties` à partir d'elles avant de lancer le build. Ce fichier (comme le keystore lui-même) est ignoré par git (`.gitignore` et `android/.gitignore`) — ne le committez jamais.

Pour les positionner dans une session PowerShell :

```powershell
$env:HOOPMAP_KEYSTORE_PATH = "C:\chemin\vers\hoopmap-upload.jks"
$env:HOOPMAP_KEYSTORE_PASSWORD = "..."
$env:HOOPMAP_KEY_ALIAS = "upload"
$env:HOOPMAP_KEY_PASSWORD = "..."
```

## Générer le keystore (une seule fois)

Si aucun keystore n'existe encore pour hoopmap :

```bash
keytool -genkey -v -keystore hoopmap-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Répondez aux questions (nom, organisation, etc.) et choisissez un mot de passe robuste. **Conservez ce fichier et ce mot de passe en lieu sûr et sauvegardé** (par exemple un gestionnaire de secrets) : sans lui, il est impossible de publier une mise à jour de l'application déjà en ligne sur le Play Store, il faudrait republier sous un nouvel identifiant d'application.

## Lancer le build

```powershell
.\tool\build_release.ps1
```

Le script s'arrête à la première erreur et enchaîne dans l'ordre :

1. génération de `android/key.properties` depuis les variables d'environnement (si elles sont toutes positionnées — sinon le fichier existant, s'il y en a un, est laissé tel quel) ;
2. `dart format --output=none --set-exit-if-changed .` ;
3. `flutter analyze --fatal-infos` ;
4. `flutter test` (suite complète) ;
5. `flutter build appbundle --release` — le format attendu par le Play Store ;
6. `flutter build apk --release` — pour une installation directe (tests internes, distribution hors Play Store).

Sans keystore valide, les étapes 1 à 4 réussissent normalement mais les étapes 5 et 6 échouent au moment de la signature — vérifié en lançant le script sans les variables d'environnement positionnées :

- `flutter build appbundle --release` échoue sur `signReleaseBundle` avec une `NullPointerException` sans message (bug connu de l'outil bundletool quand les propriétés de signature sont nulles) ;
- `flutter build apk --release` échoue plus clairement sur `packageRelease` : `SigningConfig "release" is missing required property "storeFile"`.

Dans les deux cas, c'est attendu, pas un bug du script.

## Résultats

- App Bundle : `build/app/outputs/bundle/release/app-release.aab`
- APK : `build/app/outputs/flutter-apk/app-release.apk`

## Ce qui reste à faire manuellement pour publier sur le Play Store

Ce dépôt et ce script produisent l'App Bundle signé ; la suite se passe dans la Play Console, hors de ce dépôt :

1. Créer l'application dans la [Play Console](https://play.google.com/console) si ce n'est pas déjà fait, avec l'identifiant d'application `com.rachoucorp.hoopmap`.
2. Remplir la fiche du Play Store : description courte/longue, catégorie, icône 512×512 (dérivable de `assets/icon/icon.png`), captures d'écran (au moins 2, format téléphone), politique de confidentialité (obligatoire : l'app demande la position et écrit dans Firestore).
3. Répondre au questionnaire de contenu (classification d'âge) et à la déclaration de sécurité des données (Data safety) — notamment mentionner la collecte de position et son usage (afficher les terrains proches, jamais partagée).
4. Envoyer `app-release.aab` dans une piste de test interne, valider l'installation et le parcours complet sur au moins un appareil réel, puis promouvoir vers la production.
5. Pour chaque release suivante : incrémenter `version` dans `pubspec.yaml` (le `+N` doit toujours augmenter, c'est le `versionCode` Android) avant de relancer `tool/build_release.ps1`.
