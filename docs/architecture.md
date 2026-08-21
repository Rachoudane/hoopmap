# Architecture

Ce document décrit l'organisation du code de Hoopmap telle qu'elle existe aujourd'hui, la raison d'être de ses principales abstractions, la stratégie de test, et les limites connues du projet.

## Couches et règle de dépendance

Le code de la feature `courts` (`lib/features/courts/`) est organisé en trois couches, avec une règle de dépendance à sens unique : `presentation` dépend de `data` et `domain`, `data` dépend de `domain`, et `domain` ne dépend de rien d'autre dans le projet.

- **`domain/`** : les types métier (`Court`, `CourtWithDistance`, `GeoBounds`), les fonctions pures (`distance.dart`), et l'interface abstraite `CourtRepository` (avec l'exception `CourtNotFoundException`). Aucun fichier de ce dossier n'importe Flutter, `http` ou `cloud_firestore`.
- **`data/`** : les implémentations concrètes de `CourtRepository` — `OverpassCourtRepository` (HTTP vers l'API Overpass), `FirestoreCourtRepository` (Firestore), `CompositeCourtRepository` (combine les deux) — ainsi que leurs mappers (`overpass_mapper.dart`, `court_mapper.dart`) et le câblage Riverpod (`court_repository_provider.dart`).
- **`presentation/`** : les notifiers/providers Riverpod qui exposent l'état à l'UI (`NearbyCourtsNotifier`, `courtDetailProvider`, `AddCourtController`) et les pages (`pages/`).

`lib/core/` regroupe les préoccupations transverses utilisées par plusieurs features : l'authentification (`core/auth/auth_providers.dart`), l'accès à Firebase (`core/firebase/firebase_providers.dart`), la géolocalisation (`core/location/`, avec l'interface `LocationService` et son implémentation `GeolocatorLocationService`), le routeur (`core/router/`), l'onboarding (`core/onboarding/`) et le système de design (`core/theme/`).

## Navigation

Le routeur (`core/router/app_router.dart`) a deux particularités :

- **Portail d'onboarding** : sa fonction `redirect` lit `onboardingCompletedProvider` (synchrone, adossé à `shared_preferences`) et renvoie systématiquement vers `/onboarding` tant qu'il n'a pas été complété, quelle que soit la route demandée.
- **Navigation par onglets** : Liste et Carte sont les deux branches d'un `StatefulShellRoute.indexedStack` (chacune garde sa pile de navigation et sa position de défilement en changeant d'onglet), affichées dans `AppShell` avec une `NavigationBar`. La fiche terrain et le formulaire d'ajout sont des routes de haut niveau, ouvertes par `push` (jamais `go`) pour toujours laisser un onglet sous-jacent dans la pile.

Comme une fiche terrain peut aussi être ouverte directement par un deep link à froid (sans pile de navigation existante), `core/router/back_to_home_scope.dart` intercepte le retour (bouton ou geste système) via `PopScope` : s'il y a quelque chose à dépiler, il dépile normalement ; sinon, il navigue explicitement vers l'accueil.

## Gestion des erreurs

Aucune page n'affiche un type d'exception brut. `features/courts/presentation/court_error_messages.dart` traduit chaque exception métier (échec Overpass, limitation de débit 429, permission ou service de localisation refusé/désactivé, terrain introuvable) en un message français actionnable, affiché par `AppErrorView`/`AppEmptyView` (`core/presentation/widgets/`) avec un bouton Réessayer qui invalide le provider concerné.

## Le pattern repository et le repository composite

`CourtRepository` est l'unique abstraction que voit la couche `presentation` : `watchCourtsInBounds(GeoBounds)`, `watchCourt(String id)` et `addCourt(Court court)`. Trois classes l'implémentent :

- `OverpassCourtRepository` traduit ces appels en requêtes vers l'API Overpass et lève `UnsupportedError` sur `addCourt` (on n'écrit pas dans OpenStreetMap).
- `FirestoreCourtRepository` lit et écrit dans la collection Firestore `courts`.
- `CompositeCourtRepository` reçoit une `List<CourtRepository>` (Overpass puis Firestore, câblés dans `court_repository_provider.dart`) et implémente elle-même `CourtRepository` :
  - `watchCourtsInBounds` et `watchCourt` interrogent toutes les sources en parallèle, fusionnent les résultats (dédupliqués par identifiant) et tolèrent qu'une source échoue tant qu'au moins une répond ;
  - `addCourt` délègue à la première source dont l'appel ne lève pas `UnsupportedError` — en pratique, Firestore.

Grâce à cette composition, la couche `presentation` (et les tests) ne manipulent qu'un seul type, `CourtRepository`, sans jamais savoir si une donnée vient d'OpenStreetMap ou de Firestore.

## Pourquoi des interfaces de domaine

`CourtRepository` (Firestore, Overpass) et `LocationService` (géolocalisation) sont toutes deux définies comme des interfaces abstraites dans le domaine/core, avec une seule implémentation concrète adossée au SDK réel (`cloud_firestore`/`http`, `geolocator`). Cela sert deux objectifs :

1. La couche `presentation` dépend d'une abstraction stable, pas d'un SDK tiers — remplacer ou faire évoluer une source de données n'impacte pas les notifiers ni les pages.
2. Les tests peuvent substituer une implémentation entièrement contrôlée (un faux `CourtRepository`, un faux `LocationService`) sans jamais toucher un SDK réel, ce qui rend possible la stratégie de test décrite ci-dessous.

## Stratégie de test

Aucun test du projet n'effectue d'appel réseau ou d'appel Firebase réel :

- **`OverpassCourtRepository`** est testé avec un faux `http.Client` écrit à la main (une classe qui étend `http.BaseClient` et redéfinit `send()` pour retourner une réponse simulée).
- **`CompositeCourtRepository`**, **`NearbyCourtsNotifier`**, **`courtDetailProvider`** et **`AddCourtController`** sont testés avec de faux `CourtRepository` (et, pour la géolocalisation, un faux `LocationService`) écrits à la main dans chaque fichier de test.
- **`FirestoreCourtRepository`** est testé avec `FakeFirebaseFirestore`, du package `fake_cloud_firestore` : une implémentation en mémoire de `cloud_firestore`, pas une instance réelle.
- **`FirebaseAuth`** n'est jamais invoqué réellement dans les tests : `anonymousSessionProvider` est surchargé au niveau du `ProviderContainer`, et `FirestoreCourtRepository` accepte un paramètre optionnel `currentUserId` pour injecter l'identifiant utilisateur sans passer par `FirebaseAuth.instance`.
- **`SharedPreferences`** utilise `SharedPreferences.setMockInitialValues(...)` (une implémentation en mémoire fournie par le package) avant `sharedPreferencesProvider.overrideWithValue(...)`, jamais le stockage réel de l'appareil.

## Limites connues

- **Dépendance à Overpass** : l'app s'appuie entièrement sur l'instance publique `overpass-api.de` et sa politique d'usage (délai de 30 s, taille de zone interrogée plafonnée). Si ce service est indisponible, lent ou limite les requêtes, la recherche de terrains OpenStreetMap échoue, sans repli sur une autre instance.
- **Pas de cache disque** : chaque recherche relance une requête Overpass et une requête Firestore ; aucune réponse n'est persistée localement d'une session à l'autre.
- **Rayon de recherche fixe** : `NearbyCourtsNotifier` interroge toujours un rayon de 5 000 mètres autour de la position de l'utilisateur ; ce rayon n'est ni configurable par l'utilisateur, ni ajusté selon la densité de terrains.
- **Pas de modération** : `AddCourtController` écrit directement dans Firestore dès que le formulaire est valide. Rien ne filtre, ne signale ni ne vérifie une contribution avant qu'elle soit visible par tous les utilisateurs.
