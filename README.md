# hoopmap

Application Flutter qui aide à trouver des terrains de basket où que l'on soit dans le monde, en combinant les données OpenStreetMap et les terrains ajoutés par les utilisateurs.

[![CI](https://github.com/Rachoudane/hoopmap/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rachoudane/hoopmap/actions/workflows/ci.yml)

## Ce que fait l'app

- Localise l'utilisateur et affiche les terrains de basket à proximité, triés par distance, sous forme de liste ou de carte.
- Recherche les terrains OpenStreetMap à la volée dans la zone géographique concernée plutôt que dans une base préchargée, pour fonctionner n'importe où dans le monde.
- Fusionne ces résultats avec les terrains ajoutés par les utilisateurs, stockés dans Firestore.
- Affiche une fiche par terrain (nom, nombre de paniers, intérieur/extérieur, coordonnées), accessible aussi par deep link.
- Propose un bouton "Itinéraire" qui ouvre l'application de cartographie du téléphone sur les coordonnées du terrain.
- Permet d'ajouter un terrain (nom, nombre de paniers, intérieur/extérieur, position) via un formulaire, après une authentification anonyme automatique.

## Sources de données

Les terrains affichés viennent de deux sources distinctes, interrogées puis fusionnées par un repository composite :

- **OpenStreetMap, via l'API Overpass** : à chaque recherche, l'app interroge `https://overpass-api.de/api/interpreter` pour les éléments `leisure=pitch` avec un tag `sport` contenant `basketball`, dans une boîte englobante calculée autour du point de recherche. Rien n'est préchargé ni mis en cache : comme la couverture est mondiale, stocker ou embarquer l'ensemble des terrains OpenStreetMap n'est pas envisageable, donc chaque zone consultée déclenche sa propre requête.
- **Firestore** : uniquement les terrains ajoutés par les utilisateurs depuis l'app. La recherche s'y fait par une requête de plage sur la latitude, puis un filtre sur la longitude côté client.

Le repository composite fusionne les deux listes en dédupliquant par identifiant, et continue de fonctionner si une seule des deux sources répond.

## Stack

- Flutter / Dart
- Riverpod (`flutter_riverpod`) pour la gestion d'état et l'injection de dépendances
- GoRouter (`go_router`) pour la navigation et les deep links
- Firebase : `firebase_core`, `cloud_firestore` (terrains ajoutés par les utilisateurs), `firebase_auth` (authentification anonyme)
- `http` pour interroger l'API Overpass
- `geolocator` pour la position de l'utilisateur
- `flutter_map` + `latlong2` pour l'affichage cartographique (tuiles OpenStreetMap)
- `url_launcher` pour ouvrir l'application de cartographie du téléphone
- Tests : `flutter_test`, `fake_cloud_firestore`, et des faux clients HTTP / repositories écrits à la main

## Démarrer

Prérequis :

- Flutter (channel stable ; la CI utilise la version définie dans `.github/workflows/ci.yml`)
- Un projet Firebase avec Firestore et l'authentification anonyme activée, et votre propre fichier `lib/firebase_options.dart` généré pour ce projet (celui du dépôt pointe vers le projet Firebase original et ne fonctionnera pas pour un autre compte) — générez le vôtre avec la CLI FlutterFire, pointée vers votre projet

Commandes :

```bash
flutter pub get
flutter run
flutter test
```

## Deep links

Une fiche terrain est accessible via le lien `hoopmap://courts/<id>`, où `<id>` est soit un identifiant OpenStreetMap (`osm:<type>-<id>`), soit l'identifiant d'un document Firestore. Pour l'ouvrir sur un appareil ou un émulateur Android connecté :

```bash
adb shell am start -a android.intent.action.VIEW -d "hoopmap://courts/osm:way-123456"
```

## Attribution

- Les données des terrains OpenStreetMap ainsi que les tuiles de la carte proviennent d'OpenStreetMap : © les contributeurs d'OpenStreetMap, disponibles sous licence ODbL (https://www.openstreetmap.org/copyright).
- Les requêtes de recherche de terrains sont envoyées à l'API Overpass (service communautaire de l'infrastructure OpenStreetMap) avec un User-Agent identifiant l'application et une limite de taille de zone interrogée, conformément à sa politique d'usage.

## Architecture

Le détail de l'architecture (couches, pattern repository, stratégie de test, limites connues) est documenté dans [docs/architecture.md](docs/architecture.md).
