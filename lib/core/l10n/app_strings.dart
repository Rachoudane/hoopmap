/// All user-visible text in the app, centralized here as named constants.
///
/// Hoopmap ships in English only (no flutter_localizations, no .arb files):
/// this class exists purely to keep strings out of widget bodies and easy to
/// audit, not to support multiple languages.
abstract final class AppStrings {
  // Onboarding
  static const onboardingSkip = 'Skip';
  static const onboardingNext = 'Next';
  static const onboardingGetStarted = 'Get started';
  static const onboardingSlide1Title = 'Find a court, wherever you are';
  static const onboardingSlide1Description =
      'Hoopmap finds basketball courts around you and shows them in a list '
      'or on a map, sorted by distance.';
  static const onboardingSlide2Title = 'Open, community-driven data';
  static const onboardingSlide2Description =
      "Courts come from OpenStreetMap, complemented by contributions from "
      'other Hoopmap users who add missing courts.';
  static const onboardingSlide3Title = 'Your location, and nothing else';
  static const onboardingSlide3Description =
      "On the next screen, Android will ask for permission to access your "
      "location. It's used only to show courts near you.";

  // Navigation (bottom nav bar destinations)
  static const navList = 'List';
  static const navMap = 'Map';

  // Not found page
  static const notFoundTitle = 'Page not found';
  static const notFoundMessage = "This page doesn't exist anymore.";
  static const notFoundAction = 'Back to home';

  // Generic message views
  static const retry = 'Retry';
  static const refresh = 'Refresh';
  static const close = 'Close';

  // Court errors (core/court_error_messages.dart)
  static const errorLocationPermissionDenied =
      'Location access was denied. Allow it in the app settings to see '
      'courts near you.';
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
  static const errorOverpass =
      "Couldn't reach OpenStreetMap. Check your connection and try again.";
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
  static const noCourtsNearbyTitle = 'No courts nearby';
  static const noCourtsNearbyListMessage =
      'No courts were found within 5 km. You can add one yourself.';

  // Courts map page
  static const mapTitle = 'Map';
  static const locationUnavailableSnackBar = "Couldn't access your location.";
  static const noCourtsNearbyMapMessage =
      'No courts were found within 5 km of you.';
  static const openStreetMapContributors = 'OpenStreetMap contributors';
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

  // Terms of Use
  static const termsOfUseTooltip = 'Terms of Use';
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
