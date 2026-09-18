/// Officer and Attendee login identifiers stay as created (Student ID + Gmail).
/// Flip to true to restore self-serve username changes for those roles.
abstract final class AuthConstants {
  static const memberLoginIdentifierChangeEnabled = false;
  static const memberLoginIdentifierLockedMessage =
      'Login username cannot be changed. Sign in with the Student ID and Gmail assigned to this account.';
}
