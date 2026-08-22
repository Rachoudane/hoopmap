/// Why a user is reporting a court, matching the values accepted by
/// `firestore.rules`' `isValidNewReport`.
enum ReportReason {
  inaccurate,
  offensive,
  spam,
  doesNotExist,
  other;

  /// The value stored in Firestore for this reason.
  String get wireValue => name;
}
