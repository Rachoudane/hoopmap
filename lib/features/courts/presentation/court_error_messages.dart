import '../../../core/location/location_service.dart';
import '../data/overpass_court_repository.dart';
import '../domain/court_repository.dart';

/// Translates the exceptions that can surface from the courts data layer
/// into a message a user can act on, so no screen ever shows a raw
/// exception type or message.
String courtErrorMessage(Object error) {
  if (error is LocationPermissionDeniedException) {
    return "L'accès à votre position a été refusé. Autorisez-le dans les "
        "paramètres de l'application pour voir les terrains proches de "
        'vous.';
  }
  if (error is LocationServiceDisabledException) {
    return 'La localisation est désactivée sur cet appareil. Activez-la '
        'pour voir les terrains proches de vous.';
  }
  if (error is OverpassRateLimitedException) {
    return 'Le service OpenStreetMap est très sollicité en ce moment. '
        'Réessayez dans quelques instants.';
  }
  if (error is AreaTooLargeException) {
    return 'La zone à explorer est trop grande pour être interrogée.';
  }
  if (error is OverpassException) {
    return 'Impossible de contacter OpenStreetMap. Vérifiez votre connexion '
        'et réessayez.';
  }
  if (error is CourtNotFoundException) {
    return "Ce terrain est introuvable. Il a peut-être été supprimé.";
  }
  return 'Une erreur inattendue est survenue. Réessayez.';
}
