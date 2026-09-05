/// One thing worth knowing happened, and what qualified it.
///
/// [parameters] holds strings and numbers only, because that is all Firebase
/// Analytics stores — a bool has to be spelled out as a word by whoever logs
/// it, so the dashboard shows `outdoor`/`indoor` rather than `true`/`false`.
final class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.parameters = const {}]);

  final String name;
  final Map<String, Object> parameters;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnalyticsEvent || other.name != name) return false;
    if (other.parameters.length != parameters.length) return false;
    for (final entry in parameters.entries) {
      if (other.parameters[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    name,
    Object.hashAllUnordered(
      parameters.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => parameters.isEmpty
      ? name
      : '$name(${parameters.entries.map((e) => '${e.key}=${e.value}').join(', ')})';
}

/// How someone left onboarding, which is the first fork in the funnel.
enum OnboardingExit {
  /// "See courts near me" on the last slide — the only exit that opts in.
  getStarted,

  /// "Browse without location", on the last slide.
  browseInstead,

  /// Skip, from any slide before the last.
  skipped,
}

/// Which screen asked for the location, since the two are answered very
/// differently: onboarding explains it as part of the tour, everywhere else
/// interrupts something the user was already doing.
enum LocationEntryPoint { onboarding, inApp }

/// What the app answered the system's permission question with.
enum LocationOutcome {
  granted,
  denied,
  deniedForever,
  serviceOff,
  fixTimedOut,
  notRequested,
}

/// Where a court search was centred, which is the difference between a user
/// the app can locate and one browsing on their own terms.
enum CourtSearchArea {
  /// Around the user's own position.
  position,

  /// Around a city picked from the bundled list.
  city,

  /// Inside the box the map is showing, after a pan.
  mapBounds,
}

/// Which button opened the add-court form.
enum AddCourtEntryPoint {
  /// The floating action button on the list.
  listFab,

  /// "Add the first court", on a list that found nothing.
  listEmpty,

  /// "Add a court", on the map's empty banner.
  mapEmpty,
}

/// Where a court came from, because a court somebody added here and one
/// imported from OpenStreetMap are not the same thing to look at.
enum CourtOrigin { openStreetMap, hoopmap }
