import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/complaint_model.dart';
import '../../../../core/services/api_service.dart';

// Events
abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserDataEvent extends UserEvent {}

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

// States
abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  final List<ComplaintModel> complaints;

  const UserLoaded({required this.complaints});

  @override
  List<Object?> get props => [complaints];
}

// BLoC
class UserBloc extends Bloc<UserEvent, UserState> {
  final ApiService _apiService = ApiService();

  UserBloc() : super(UserInitial()) {
    on<LoadUserDataEvent>(_onLoadUserData);
    on<RaiseComplaintEvent>(_onRaiseComplaint);
  }

  Future<void> _onLoadUserData(
    LoadUserDataEvent event,
    Emitter<UserState> emit,
  ) async {
    if (state is! UserLoaded) {
      emit(UserLoading());
    }
    try {
      final complaints = await _fetchComplaintsFromApi();
      emit(UserLoaded(complaints: complaints));
    } catch (_) {
      emit(const UserLoaded(complaints: []));
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
        final complaints = await _fetchComplaintsFromApi();
        emit(UserLoaded(complaints: complaints));
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
}
