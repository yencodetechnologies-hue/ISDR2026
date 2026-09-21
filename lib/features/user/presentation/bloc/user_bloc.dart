import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/complaint_model.dart';
import '../../../../core/models/visitor_model.dart';
import '../../../../core/models/monthly_visitor_pass_model.dart';
import '../../../../core/services/api_service.dart';

// Events
abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserDataEvent extends UserEvent {}

class AddVisitorEvent extends UserEvent {
  final String userId;
  final String name;
  final String mobileNumber;
  final VisitorCategory category;
  final RelativeType? relativeType;
  final VisitorType? type;
  final String? typeDetail;
  final String? block;
  final String? homeNumber;
  final String reasonForVisit;
  final DateTime visitDateTime;
  final File? image;

  const AddVisitorEvent({
    required this.userId,
    required this.name,
    required this.mobileNumber,
    required this.category,
    this.relativeType,
    this.type,
    this.typeDetail,
    this.block,
    this.homeNumber,
    required this.reasonForVisit,
    required this.visitDateTime,
    this.image,
  });

  @override
  List<Object?> get props => [
        userId,
        name,
        mobileNumber,
        category,
        relativeType,
        type,
        typeDetail,
        block,
        homeNumber,
        reasonForVisit,
        visitDateTime,
        image,
      ];
}

class RaiseComplaintEvent extends UserEvent {
  final String userId;
  final ComplaintType type;
  final String description;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final DateTime? preferredRepairDateTime;
  final bool isUrgent;

  const RaiseComplaintEvent({
    required this.userId,
    required this.type,
    required this.description,
    this.block,
    this.floor,
    this.roomNumber,
    this.preferredRepairDateTime,
    this.isUrgent = false,
  });

  @override
  List<Object?> get props => [
        userId,
        type,
        description,
        block,
        floor,
        roomNumber,
        preferredRepairDateTime,
        isUrgent,
      ];
}

class LoadMyUnitVisitorsEvent extends UserEvent {}

class UpdateVisitorApprovalEvent extends UserEvent {
  final String visitorId;
  final String status; // 'approved' | 'rejected'

  const UpdateVisitorApprovalEvent({required this.visitorId, required this.status});

  @override
  List<Object?> get props => [visitorId, status];
}

class LoadMyMonthlyVisitorPassesEvent extends UserEvent {}

class CreateMonthlyVisitorPassEvent extends UserEvent {
  final VisitorType visitorType;
  final String personName;
  final String mobileNumber;
  final String? reasonForPass;

  const CreateMonthlyVisitorPassEvent({
    required this.visitorType,
    required this.personName,
    required this.mobileNumber,
    this.reasonForPass,
  });

  @override
  List<Object?> get props => [visitorType, personName, mobileNumber, reasonForPass];
}

class ToggleMonthlyVisitorPassEvent extends UserEvent {
  final String passId;
  final bool enabled;

  const ToggleMonthlyVisitorPassEvent({required this.passId, required this.enabled});

  @override
  List<Object?> get props => [passId, enabled];
}

// States
abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  final List<VisitorModel> visitors;
  final List<ComplaintModel> complaints;
  final List<VisitorModel> myUnitVisitors;
  final List<MonthlyVisitorPassModel> monthlyVisitorPasses;

  const UserLoaded({
    required this.visitors,
    required this.complaints,
    this.myUnitVisitors = const [],
    this.monthlyVisitorPasses = const [],
  });

  @override
  List<Object?> get props => [visitors, complaints, myUnitVisitors, monthlyVisitorPasses];
}

// BLoC
class UserBloc extends Bloc<UserEvent, UserState> {
  static const String _visitorsKey = 'visitors_list';
  final ApiService _apiService = ApiService();

  UserBloc() : super(UserInitial()) {
    on<LoadUserDataEvent>(_onLoadUserData);
    on<AddVisitorEvent>(_onAddVisitor);
    on<RaiseComplaintEvent>(_onRaiseComplaint);
    on<LoadMyUnitVisitorsEvent>(_onLoadMyUnitVisitors);
    on<UpdateVisitorApprovalEvent>(_onUpdateVisitorApproval);
    on<LoadMyMonthlyVisitorPassesEvent>(_onLoadMyMonthlyVisitorPasses);
    on<CreateMonthlyVisitorPassEvent>(_onCreateMonthlyVisitorPass);
    on<ToggleMonthlyVisitorPassEvent>(_onToggleMonthlyVisitorPass);
  }

  Future<void> _onLoadUserData(
    LoadUserDataEvent event,
    Emitter<UserState> emit,
  ) async {
    final current = state;
    if (current is! UserLoaded) {
      emit(UserLoading());
    }
    try {
      // Prefer visitors from backend so list matches security dashboard and today's visitors
      List<VisitorModel> visitors = [];
      final response = await _apiService.getUserVisitors();
      if (response['success'] == true && response['visitors'] != null) {
        final list = response['visitors'] as List;
        visitors = list
            .map((v) => VisitorModel.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList();
        await _saveVisitors(visitors);
      } else {
        visitors = await _getVisitors();
      }
      var complaints = await _fetchComplaintsFromApi();
      emit(UserLoaded(
        visitors: visitors,
        complaints: complaints,
        myUnitVisitors: current is UserLoaded ? current.myUnitVisitors : const [],
        monthlyVisitorPasses: current is UserLoaded ? current.monthlyVisitorPasses : const [],
      ));
    } catch (e) {
      try {
        final visitors = await _getVisitors();
        final complaints = await _fetchComplaintsFromApi();
        emit(UserLoaded(
          visitors: visitors,
          complaints: complaints,
          myUnitVisitors: current is UserLoaded ? current.myUnitVisitors : const [],
          monthlyVisitorPasses: current is UserLoaded ? current.monthlyVisitorPasses : const [],
        ));
      } catch (_) {
        emit(UserLoaded(visitors: [], complaints: []));
      }
    }
  }

  Future<void> _onLoadMyUnitVisitors(
    LoadMyUnitVisitorsEvent event,
    Emitter<UserState> emit,
  ) async {
    final current = state;
    if (current is! UserLoaded) return;
    try {
      final response = await _apiService.getVisitorsForMyUnit();
      if (response['success'] == true && response['visitors'] != null) {
        final list = (response['visitors'] as List)
            .map((v) => VisitorModel.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList();
        emit(UserLoaded(
          visitors: current.visitors,
          complaints: current.complaints,
          myUnitVisitors: list,
          monthlyVisitorPasses: current.monthlyVisitorPasses,
        ));
      } else {
        emit(UserLoaded(
          visitors: current.visitors,
          complaints: current.complaints,
          myUnitVisitors: current.myUnitVisitors,
          monthlyVisitorPasses: current.monthlyVisitorPasses,
        ));
      }
    } catch (e) {
      emit(UserLoaded(
        visitors: current.visitors,
        complaints: current.complaints,
        myUnitVisitors: current.myUnitVisitors,
        monthlyVisitorPasses: current.monthlyVisitorPasses,
      ));
    }
  }

  Future<void> _onUpdateVisitorApproval(
    UpdateVisitorApprovalEvent event,
    Emitter<UserState> emit,
  ) async {
    final current = state;
    if (current is! UserLoaded) return;
    try {
      final response = await _apiService.updateVisitorApproval(event.visitorId, event.status);
      if (response['success'] == true) {
        final updated = response['visitor'] != null
            ? VisitorModel.fromJson(Map<String, dynamic>.from(response['visitor'] as Map))
            : null;
        List<VisitorModel> newList = List.from(current.myUnitVisitors);
        final idx = newList.indexWhere((v) => v.id == event.visitorId);
        if (idx >= 0 && updated != null) {
          newList[idx] = updated;
        } else if (idx >= 0 && event.status == 'rejected') {
          newList.removeAt(idx);
        }
        emit(UserLoaded(
          visitors: current.visitors,
          complaints: current.complaints,
          myUnitVisitors: newList,
          monthlyVisitorPasses: current.monthlyVisitorPasses,
        ));
      }
    } catch (e) {
      // Keep state unchanged on error
    }
  }

  Future<void> _onAddVisitor(
    AddVisitorEvent event,
    Emitter<UserState> emit,
  ) async {
    try {
      // Normalize mobile to 10 digits for backend schema
      final digits = event.mobileNumber.replaceAll(RegExp(r'\D'), '');
      final mobileNumber = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      if (mobileNumber.length != 10) {
        final complaints = await _fetchComplaintsFromApi();
        final visitors = await _getVisitors();
        emit(UserLoaded(visitors: visitors, complaints: complaints));
        return;
      }

      // Build body for backend POST /api/visitors (resident create)
      final typeStr = event.category == VisitorCategory.relative
          ? 'guest'
          : (event.type ?? VisitorType.other).name;
      final body = <String, dynamic>{
        'name': event.name,
        'mobileNumber': mobileNumber,
        'category': event.category.name,
        'reasonForVisit': event.reasonForVisit,
        'visitTime': event.visitDateTime.toUtc().toIso8601String(),
        'type': typeStr,
      };
      if (event.block != null && event.block!.trim().isNotEmpty) {
        body['block'] = event.block!.trim();
      }
      if (event.homeNumber != null && event.homeNumber!.trim().isNotEmpty) {
        body['homeNumber'] = event.homeNumber!.trim();
      }
      if (event.category == VisitorCategory.relative && event.relativeType != null) {
        body['relativeType'] = event.relativeType!.name;
      }
      if (event.category == VisitorCategory.outsider && event.type != null) {
        body['type'] = event.type!.name;
      }
      if (event.typeDetail != null && event.typeDetail!.trim().isNotEmpty) {
        body['typeDetail'] = event.typeDetail!.trim();
      }
      final response = await _apiService.createVisitor(body, image: event.image);
      if (response['success'] != true) {
        // Optionally show error to user (e.g. via a snackbar in UI)
        final complaints = await _fetchComplaintsFromApi();
        final visitors = await _getVisitors();
        emit(UserLoaded(visitors: visitors, complaints: complaints));
        return;
      }

      // Refresh visitor list from backend so security dashboard and app stay in sync
      final listResponse = await _apiService.getUserVisitors();
      List<VisitorModel> visitors = [];
      if (listResponse['success'] == true && listResponse['visitors'] != null) {
        final list = listResponse['visitors'] as List;
        visitors = list
            .map((v) => VisitorModel.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList();
        await _saveVisitors(visitors);
      } else {
        // Fallback: add the created visitor from response to current list
        final created = response['visitor'];
        if (created != null) {
          visitors = await _getVisitors();
          visitors.insert(0, VisitorModel.fromJson(Map<String, dynamic>.from(created as Map)));
          await _saveVisitors(visitors);
        }
      }

      final complaints = await _fetchComplaintsFromApi();
      emit(UserLoaded(
        visitors: visitors,
        complaints: complaints,
        monthlyVisitorPasses: state is UserLoaded
            ? (state as UserLoaded).monthlyVisitorPasses
            : const <MonthlyVisitorPassModel>[],
      ));
    } catch (e) {
      // On error keep current state; optionally emit error state for UI
      try {
        final visitors = await _getVisitors();
        final complaints = await _fetchComplaintsFromApi();
        emit(UserLoaded(
          visitors: visitors,
          complaints: complaints,
          monthlyVisitorPasses: state is UserLoaded
              ? (state as UserLoaded).monthlyVisitorPasses
              : const <MonthlyVisitorPassModel>[],
        ));
      } catch (_) {}
    }
  }

  Future<void> _onRaiseComplaint(
    RaiseComplaintEvent event,
    Emitter<UserState> emit,
  ) async {
    try {
      final response = await _apiService.createComplaint(
        type: event.type.name,
        description: event.description,
        block: event.block,
        floor: event.floor,
        roomNumber: event.roomNumber,
        preferredRepairDateTime: event.preferredRepairDateTime,
        isUrgent: event.isUrgent,
      );
      if (response['success'] == true) {
        final visitors = await _getVisitors();
        final complaints = await _fetchComplaintsFromApi();
        emit(UserLoaded(
          visitors: visitors,
          complaints: complaints,
          monthlyVisitorPasses: state is UserLoaded
              ? (state as UserLoaded).monthlyVisitorPasses
              : const <MonthlyVisitorPassModel>[],
        ));
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<List<ComplaintModel>> _fetchComplaintsFromApi() async {
    try {
      final response = await _apiService.getComplaints();
      if (response['success'] == true && response['complaints'] != null) {
        final list = response['complaints'] as List;
        return list
            .map((c) => ComplaintModel.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<VisitorModel>> _getVisitors() async {
    final prefs = await SharedPreferences.getInstance();
    final visitorsJson = prefs.getString(_visitorsKey);
    if (visitorsJson != null) {
      final List<dynamic> visitorsList = jsonDecode(visitorsJson);
      return visitorsList.map((v) => VisitorModel.fromJson(v)).toList();
    }
    return [];
  }

  Future<void> _saveVisitors(List<VisitorModel> visitors) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _visitorsKey,
      jsonEncode(visitors.map((v) => v.toJson()).toList()),
    );
  }

  Future<List<UserModel>> _getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('users_list');
    if (usersJson != null) {
      final List<dynamic> usersList = jsonDecode(usersJson);
      return usersList.map((u) => UserModel.fromJson(u)).toList();
    }
    return [];
  }
 
  Future<void> _onLoadMyMonthlyVisitorPasses(
    LoadMyMonthlyVisitorPassesEvent event,
    Emitter<UserState> emit,
  ) async {
    final current = state;
    if (current is! UserLoaded) {
      // If user hasn't loaded yet, just emit empty and let UI retry.
      final response = await _apiService.getMyMonthlyVisitorPasses();
      final passesJson = response['passes'] as List<dynamic>? ?? [];
      final passes = passesJson
          .map((p) => MonthlyVisitorPassModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
      emit(UserLoaded(
        visitors: const <VisitorModel>[],
        complaints: const <ComplaintModel>[],
        monthlyVisitorPasses: passes,
      ));
      return;
    }

    try {
      final response = await _apiService.getMyMonthlyVisitorPasses();
      if (response['success'] == true) {
        final passesJson = response['passes'] as List<dynamic>? ?? [];
        final passes = passesJson
            .map((p) => MonthlyVisitorPassModel.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();

        emit(UserLoaded(
          visitors: current.visitors,
          complaints: current.complaints,
          myUnitVisitors: current.myUnitVisitors,
          monthlyVisitorPasses: passes,
        ));
      }
    } catch (_) {
      // keep current state
    }
  }

  Future<void> _onCreateMonthlyVisitorPass(
    CreateMonthlyVisitorPassEvent event,
    Emitter<UserState> emit,
  ) async {
    final current = state;
    if (current is! UserLoaded) return;

    try {
      final response = await _apiService.createMonthlyVisitorPass(
        visitorType: event.visitorType.name,
        personName: event.personName.trim(),
        mobileNumber: event.mobileNumber.trim(),
        reasonForPass: event.reasonForPass,
      );
      if (response['success'] == true && response['pass'] != null) {
        final pass = MonthlyVisitorPassModel.fromJson(
          Map<String, dynamic>.from(response['pass'] as Map),
        );
        final updated = List<MonthlyVisitorPassModel>.from(current.monthlyVisitorPasses);
        final idx = updated.indexWhere((p) => p.id == pass.id);
        if (idx >= 0) {
          updated[idx] = pass;
        } else {
          updated.insert(0, pass);
        }
        emit(UserLoaded(
          visitors: current.visitors,
          complaints: current.complaints,
          myUnitVisitors: current.myUnitVisitors,
          monthlyVisitorPasses: updated,
        ));
      }
    } catch (_) {
      // keep current state
    }
  }

  Future<void> _onToggleMonthlyVisitorPass(
    ToggleMonthlyVisitorPassEvent event,
    Emitter<UserState> emit,
  ) async {
    final current = state;
    if (current is! UserLoaded) return;

    try {
      final response = await _apiService.toggleMonthlyVisitorPass(
        passId: event.passId,
        enabled: event.enabled,
      );
      if (response['success'] == true && response['pass'] != null) {
        final passJson = response['pass'];
        final pass = MonthlyVisitorPassModel.fromJson(
          Map<String, dynamic>.from(passJson as Map),
        );
        final updated = List<MonthlyVisitorPassModel>.from(current.monthlyVisitorPasses);
        final idx = updated.indexWhere((p) => p.id == pass.id);
        if (idx >= 0) {
          updated[idx] = pass;
        } else {
          updated.insert(0, pass);
        }
        emit(UserLoaded(
          visitors: current.visitors,
          complaints: current.complaints,
          myUnitVisitors: current.myUnitVisitors,
          monthlyVisitorPasses: updated,
        ));
      }
    } catch (_) {
      // keep current state
    }
  }

}
