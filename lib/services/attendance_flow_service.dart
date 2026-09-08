/// Remembers which event the user chose to time in before opening the scanner.
class AttendanceFlowService {
  int? pendingTimeInEventId;

  void beginTimeIn(int eventId) {
    pendingTimeInEventId = eventId;
  }

  void clearPendingTimeIn() {
    pendingTimeInEventId = null;
  }

  void clear() {
    clearPendingTimeIn();
  }
}
