import '../../../../core/models/visitor_model.dart';
import '../bloc/security_bloc.dart';

/// Visitor list filter for the security dashboard Visitors tab and Operations shortcuts.
enum SecurityVisitorSection {
  waitingApproval,
  approved,
  inside,
  exited,
  today,
  upcoming,
  viewAll,
  monthlyVisitors,
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<VisitorModel> filteredVisitorsForSection(
  SecurityLoaded state,
  SecurityVisitorSection section,
) {
  final now = DateTime.now();
  switch (section) {
    case SecurityVisitorSection.waitingApproval:
      return state.pendingApprovalVisitors;
    case SecurityVisitorSection.approved:
      return state.approvedVisitors;
    case SecurityVisitorSection.inside:
      return state.activeVisitors;
    case SecurityVisitorSection.exited:
      return state.completedVisitors;
    case SecurityVisitorSection.today:
      return state.visitors
          .where((v) => _isSameDay(v.visitTime.toLocal(), now))
          .toList();
    case SecurityVisitorSection.upcoming:
      return state.visitors.where((v) => v.visitTime.isAfter(now)).toList();
    case SecurityVisitorSection.viewAll:
      return state.visitors;
    case SecurityVisitorSection.monthlyVisitors:
      return [];
  }
}

String emptyMessageForSection(SecurityVisitorSection section) {
  switch (section) {
    case SecurityVisitorSection.waitingApproval:
      return 'No visitors waiting for approval';
    case SecurityVisitorSection.approved:
      return 'No approved visitors waiting for entry';
    case SecurityVisitorSection.inside:
      return 'No visitors currently inside';
    case SecurityVisitorSection.exited:
      return 'No completed exits yet';
    case SecurityVisitorSection.today:
      return 'No visitors today';
    case SecurityVisitorSection.upcoming:
      return 'No upcoming visitors';
    case SecurityVisitorSection.viewAll:
      return 'No visitors registered';
    case SecurityVisitorSection.monthlyVisitors:
      return 'No monthly visitors registered for this apartment';
  }
}
