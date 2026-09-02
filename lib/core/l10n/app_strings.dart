/// All user-visible text in the app, centralized here as named constants.
///
/// Hoopmap ships in English only (no flutter_localizations, no .arb files):
/// this class exists purely to keep strings out of widget bodies and easy to
/// audit, not to support multiple languages.
abstract final class AppStrings {
  // Onboarding
  static const onboardingSkip = 'Skip';
  static const onboardingNext = 'Next';
  static const onboardingGetStarted = 'See courts near me';
  static const onboardingBrowseInstead = 'Browse without location';
  static const onboardingSlide1Title = 'Find a court, wherever you are';
  static const onboardingSlide1Description =
      'Hoopmap finds basketball courts around you and shows them in a list '
      'or on a map, sorted by distance.';
  static const onboardingSlide2Title = 'Open, community-driven data';
  static const onboardingSlide2Description =
      "Courts come from OpenStreetMap, complemented by contributions from "
      'other Hoopmap users who add missing courts.';
  static const onboardingSlide3Title = 'Courts near you, in one tap';
  static const onboardingSlide3Description =
      'Hoopmap uses your location only to sort courts by how far away they '
      "are. Nothing leaves your phone, and you can browse without it.";

  // Navigation (bottom nav bar destinations)
  static const navList = 'List';
  static const navMap = 'Map';

  // Not found page
  static const notFoundTitle = 'Page not found';
  static const notFoundMessage = "This page doesn't exist anymore.";
  static const notFoundAction = 'Back to home';

  // Generic message views
  static const retry = 'Retry';
  // Recovery actions for the failures the user can only fix outside the app.
  static const openAppSettings = 'Open settings';
  static const openLocationSettings = 'Turn on location';
  static const refresh = 'Refresh';
  static const close = 'Close';

  // Location not asked for yet (the app never prompts on its own)
  static const locationNotRequestedTitle = 'See the courts around you';
  static const locationNotRequestedMessage =
      'Hoopmap needs your location to find nearby courts and sort them by '
      'distance. It only uses it while you have the app open.';
  static const locationNotRequestedShort =
      "Hoopmap isn't using your location yet.";
  static const useMyLocation = 'See courts near me';

  // Pre-permission rationale (core/location/pages/)
  static const locationRationaleTitle = 'Find the courts around you';
  static const locationRationaleIntro =
      'Hoopmap can use your location to show the courts closest to you '
      'first.';
  static const locationRationaleReasonDistance =
      'Courts are sorted by how far away they are, so the nearest one is at '
      'the top.';
  static const locationRationaleReasonWhileOpen =
      'Your location is read only while you have Hoopmap open, never in the '
      'background.';
  static const locationRationaleReasonPrivate =
      'It stays on your phone: Hoopmap never stores it or sends it anywhere.';
  static const locationRationaleNextStep =
      'Android will ask you to confirm on the next screen. You can change '
      'your mind at any time in the app settings.';
  static const locationRationaleAllow = 'Allow location';
  static const locationRationaleNotNow = 'Not now';

  // Browsing from a city instead of a position
  static const pickCityTitle = 'Choose a city';
  static const pickCitySearchLabel = 'Search a city or country';
  static const pickCityUseMyLocation = 'Use my location';
  static const pickCityNoMatch =
      "No city matches that. Try a country name, or pan the map to look "
      'anywhere.';
  static const pickCityPanTheMapHint =
      'Not on the list? Open the Map tab and pan to anywhere in the world.';
  static const browseACity = 'Choose a city';
  static String browsingCity(String city) => 'Courts near $city';
  static const browsingMyLocation = 'Courts near you';

  // Court errors (core/court_error_messages.dart)
  static const errorLocationPermissionDenied =
      'Location access was denied. Allow it to see courts near you.';
  static const errorLocationPermissionPermanentlyDenied =
      'Location access is turned off for Hoopmap. Allow it in the app '
      'settings to see courts near you.';
  static const errorLocationServiceDisabled =
      'Location is turned off on this device. Turn it on to see courts '
      'near you.';
  static const errorLocationTimeout =
      "Couldn't get your location in time. Move somewhere with a clearer "
      'view of the sky and try again.';
  static const errorOverpassRateLimited =
      'The OpenStreetMap service is under heavy load right now. Try again '
      'in a moment.';
  static const errorAreaTooLarge = 'The area to search is too large to query.';
  static const errorOffline =
      "You appear to be offline. Check your connection and try again.";
  static const errorOverpass =
      "OpenStreetMap's court service isn't responding right now. Try again "
      'in a moment.';
  static const errorCourtNotFound =
      "This court can't be found. It may have been removed.";
  static const errorUnexpected = 'Something went wrong. Try again.';

  // Court facts shared across cards, preview and detail
  static const outdoor = 'Outdoor';
  static const indoor = 'Indoor';
  static const outdoorCourt = 'Outdoor court';
  static const indoorCourt = 'Indoor court';
  static String hoopCount(int count) => count == 1 ? '1 hoop' : '$count hoops';

  // Courts list page
  static const courtsListTitle = 'Nearby courts';
  static const addCourtTooltip = 'Add a court';
  static const noCourtsNearbyTitle = 'No courts here yet';
  // The radius is a setting, so the message has to say the one in force
  // rather than the one the app happened to ship with.
  static String noCourtsNearbyListMessage(String radius) =>
      'Nothing within $radius of you. Be the first to put a court on the map '
      '— it takes a name, a pin and about a minute.';
  static String noCourtsAroundListMessage(String place, String radius) =>
      'Nothing within $radius of $place. Be the first to put a court on the '
      'map — it takes a name, a pin and about a minute.';
  static String noCourtsInAreaListMessage(String radius) =>
      'Nothing within $radius of the area you are looking at. Be the first '
      'to put a court on the map — it takes a name, a pin and about a '
      'minute.';
  static const addFirstCourt = 'Add the first court';

  // Courts map page
  static const mapTitle = 'Map';
  static const locationUnavailableSnackBar = "Couldn't access your location.";
  static const noCourtsNearbyMapMessage = 'No courts in this area yet.';
  static const addACourt = 'Add a court';
  static const openStreetMapContributors = 'OpenStreetMap contributors';
  static const openStreetMapAttribution = '© OpenStreetMap contributors';
  static String courtClusterLabel(int count) =>
      '$count courts here. Zoom in to see them.';
  static const recenterOnMyLocation = 'Recenter on my location';
  static const mapLocatingYou = 'Finding courts near you…';

  // Court detail page
  static const courtDetailTitle = 'Court details';
  static const addedByHoopmapUser = 'Added by a Hoopmap user';
  static const courtNotFoundTitle = 'Court not found';
  static const backToList = 'Back to list';
  static const directions = 'Directions';
  static String source(String value) => 'Source: $value';

  // Add court page
  static const addCourtTitle = 'Add a court';
  static const informationSectionTitle = 'Information';
  static const courtNameLabel = 'Court name';
  static const courtNameHint = 'E.g. Riverside Park Court';
  static const courtNameValidation = 'Name must be between 3 and 60 characters';
  static const hoopCountLabel = 'Number of hoops';
  static const hoopCountValidation = 'Between 1 and 20 hoops';
  static const outdoorSubtitle = 'The court is outdoors';
  static const indoorSubtitle = 'The court is indoors';
  static const locationSectionTitle = 'Location';
  static const locationHelperText =
      'Move the map to place the pin on the court.';
  static const locationToChoose = 'Choose a location';
  static String locationChosen(String latitude, String longitude) =>
      'Selected location: $latitude, $longitude';
  static const useCurrentLocation = 'My current location';
  static const enterCoordinates = 'Enter coordinates';
  static const latitudeLabel = 'Latitude';
  static const longitudeLabel = 'Longitude';
  static const latitudeValidation = 'Between -90 and 90';
  static const longitudeValidation = 'Between -180 and 180';
  static const courtAddedSnackBar = 'Court added successfully';
  static const submitAddCourt = 'Add court';

  // Court photo attribution
  static String photoAttribution(String author, String? licenseShortName) =>
      licenseShortName != null
      ? 'Photo: $author · Wikimedia Commons ($licenseShortName)'
      : 'Photo: $author · Wikimedia Commons';

  // Settings
  static const settingsTitle = 'Settings';
  static const settingsTooltip = 'Settings';
  static const settingsAppearanceSection = 'Appearance';
  static const settingsThemeSystem = 'Follow the system';
  static const settingsThemeLight = 'Light';
  static const settingsThemeDark = 'Dark';
  static const settingsSearchSection = 'Search';
  static const settingsSearchRadiusTitle = 'Search radius';
  static const settingsSearchRadiusSubtitle =
      'How far around you (or the city you picked) Hoopmap looks for courts.';
  static String settingsRadiusLabel(double meters) {
    final km = meters / 1000;
    return km == km.roundToDouble() ? '${km.round()} km' : '$km km';
  }

  static const settingsLanguageSection = 'Language';
  static const settingsLanguageTitle = 'English';
  static const settingsLanguageSubtitle =
      'Hoopmap ships in English only for now. Court names come from '
      'OpenStreetMap in whatever language they were mapped.';
  static const settingsLegalSection = 'Legal';
  static const settingsTermsTitle = 'Terms of Use';
  static const settingsTermsSubtitle =
      'The rules for adding courts and reporting content.';
  static const settingsAttributionTitle = 'Map data and attribution';
  static const settingsAttributionSubtitle =
      'Court data and map tiles © OpenStreetMap contributors, available '
      'under the Open Database License (ODbL). Court photos come from '
      'Wikimedia Commons, credited to their authors.';
  static const settingsAboutSection = 'About';
  static String settingsVersion(String version) => 'Version $version';
  static const settingsAboutSubtitle =
      'Find basketball courts wherever you are, from OpenStreetMap and '
      'contributions by other players.';

  // Terms of Use
  static const termsOfUseTitle = 'Terms of Use';
  static String termsOfUseEffectiveDate(String date) => 'Effective date: $date';
  static const termsGateIntro =
      'Please review and accept the Terms of Use before adding a court.';
  static const termsAccept = 'Accept';
  static const termsDecline = 'Decline';

  // Report this court
  static const reportThisCourt = 'Report this court';
  static const reportDialogTitle = 'Report this court';
  static const reportDialogDescription =
      "Let us know what's wrong. Our team reviews reports and removes "
      'content that violates the Terms of Use.';
  static const reportReasonInaccurate = 'Inaccurate information';
  static const reportReasonOffensive = 'Offensive content';
  static const reportReasonSpam = 'Spam';
  static const reportReasonDoesNotExist = "Court doesn't exist";
  static const reportReasonOther = 'Other';
  static const reportCommentLabel = 'Additional details (optional)';
  static const reportSubmit = 'Submit report';
  static const reportCancel = 'Cancel';
  static const reportSuccessSnackBar =
      "Thanks — your report was received and will be reviewed.";
  static const reportAlreadySubmitted = "You've already reported this court.";
  static const reportError = "Couldn't submit your report. Try again.";
}
