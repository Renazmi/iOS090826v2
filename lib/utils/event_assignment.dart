/// Assignment Status applies only to officers who belong to an organization.
/// Attendees never receive an assignment status.
bool officerBelongsToOrganization(int? organizationId) => (organizationId ?? 0) > 0;

enum EventAssignmentStatus { assigned, unassigned }

EventAssignmentStatus? resolveEventAssignmentStatus({
  required bool assignAll,
  required List<int> assignedOfficerIds,
  required int officerId,
  required bool belongsToOrganization,
}) {
  if (!belongsToOrganization) return null;
  if (assignedOfficerIds.contains(officerId)) return EventAssignmentStatus.assigned;
  if (assignAll) return EventAssignmentStatus.assigned;
  return EventAssignmentStatus.unassigned;
}

String eventAssignmentLabel(EventAssignmentStatus status) =>
    status == EventAssignmentStatus.assigned ? 'Assigned' : 'Unassigned';
