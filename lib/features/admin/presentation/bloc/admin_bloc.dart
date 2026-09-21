import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../../../../core/models/block_model.dart';
import '../../../../core/models/complaint_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../features/auth/data/repositories/auth_repository.dart';
import '../../../../core/services/api_service.dart';
import 'package:flutter/foundation.dart';

// Events
abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class LoadBlocksEvent extends AdminEvent {}

class SelectApartmentEvent extends AdminEvent {
  final String? apartmentId;

  const SelectApartmentEvent({this.apartmentId});

  @override
  List<Object?> get props => [apartmentId];
}

class CreateBlockEvent extends AdminEvent {
  final String blockName;
  final List<String>? floorNumbers;

  const CreateBlockEvent({
    required this.blockName,
    this.floorNumbers,
  });

  @override
  List<Object?> get props => [blockName, floorNumbers];
}

class AddFloorEvent extends AdminEvent {
  final String blockId;
  final String floorNumber;
  final List<Map<String, dynamic>>
      roomConfigurations; // [{type: '1BHK', count: 4}, {type: '2BHK', count: 2}]
  final String? roomNumber; // Optional specific room number for single room

  const AddFloorEvent({
    required this.blockId,
    required this.floorNumber,
    required this.roomConfigurations,
    this.roomNumber,
  });

  @override
  List<Object?> get props =>
      [blockId, floorNumber, roomConfigurations, roomNumber];
}

class AddRoomEvent extends AdminEvent {
  final String blockId;
  final String floorId;
  final String roomNumber;
  final String roomType;
  final int? beds;

  const AddRoomEvent({
    required this.blockId,
    required this.floorId,
    required this.roomNumber,
    required this.roomType,
    this.beds,
  });

  @override
  List<Object?> get props => [blockId, floorId, roomNumber, roomType, beds];
}

class EditBlockEvent extends AdminEvent {
  final String blockId;
  final String name;

  const EditBlockEvent({
    required this.blockId,
    required this.name,
  });

  @override
  List<Object?> get props => [blockId, name];
}

class DeleteBlockEvent extends AdminEvent {
  final String blockId;

  const DeleteBlockEvent(this.blockId);

  @override
  List<Object?> get props => [blockId];
}

class EditFloorEvent extends AdminEvent {
  final String blockId;
  final String floorId;
  final String floorNumber;

  const EditFloorEvent({
    required this.blockId,
    required this.floorId,
    required this.floorNumber,
  });

  @override
  List<Object?> get props => [blockId, floorId, floorNumber];
}

class DeleteFloorEvent extends AdminEvent {
  final String blockId;
  final String floorId;

  const DeleteFloorEvent({
    required this.blockId,
    required this.floorId,
  });

  @override
  List<Object?> get props => [blockId, floorId];
}

class LoadAllUsersEvent extends AdminEvent {}

class AddSecurityEvent extends AdminEvent {
  final String name;
  final String email;
  final String mobileNumber;
  final String password;
  final File? profilePic;
  final File? idProof;

  const AddSecurityEvent({
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.password,
    this.profilePic,
    this.idProof,
  });

  @override
  List<Object?> get props =>
      [name, email, mobileNumber, password, profilePic, idProof];
}

class UpdateSecurityEvent extends AdminEvent {
  final String securityId;
  final String? name;
  final String? email;
  final String? mobileNumber;
  final String? password;
  final File? profilePic;
  final File? idProof;

  const UpdateSecurityEvent({
    required this.securityId,
    this.name,
    this.email,
    this.mobileNumber,
    this.password,
    this.profilePic,
    this.idProof,
  });

  @override
  List<Object?> get props =>
      [securityId, name, email, mobileNumber, password, profilePic, idProof];
}

class DeleteSecurityEvent extends AdminEvent {
  final String securityId;

  const DeleteSecurityEvent({required this.securityId});

  @override
  List<Object?> get props => [securityId];
}

class AddUserEvent extends AdminEvent {
  final String name;
  final String email;
  final String mobileNumber;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final FamilyType? familyType;

  const AddUserEvent({
    required this.name,
    required this.email,
    required this.mobileNumber,
    this.block,
    this.floor,
    this.roomNumber,
    this.familyType,
  });

  @override
  List<Object?> get props =>
      [name, email, mobileNumber, block, floor, roomNumber, familyType];
}

class BlockUserEvent extends AdminEvent {
  final String userId;

  const BlockUserEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UnblockUserEvent extends AdminEvent {
  final String userId;

  const UnblockUserEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class DeleteUserEvent extends AdminEvent {
  final String userId;

  const DeleteUserEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ToggleUserActiveEvent extends AdminEvent {
  final String userId;

  const ToggleUserActiveEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UpdateUserStatusEvent extends AdminEvent {
  final String userId;
  final AccountStatus status;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final String? apartmentId;

  const UpdateUserStatusEvent({
    required this.userId,
    required this.status,
    this.block,
    this.floor,
    this.roomNumber,
    this.apartmentId,
  });

  @override
  List<Object?> get props => [userId, status, block, floor, roomNumber, apartmentId];
}

class UpdateUserDetailsEvent extends AdminEvent {
  final String userId;
  final String? name;
  final String? username;
  final String? email;
  final String? mobileNumber;
  final String? secondaryMobileNumber;
  final String? gender;
  final String? address;
  final String? familyType;
  final int? totalOccupants;
  final String? aadhaarCard;
  final String? panCard;
  final bool? isNRI;
  final String? department;
  final String? employeeId;
  final String? hostelRoom;
  final String? hostelBed;
  final String? occupationCategory;
  final String? occupationDetails;
  final String? dateOfBirth;
  final String? password;
  final File? profilePic;
  final File? aadhaarFront;
  final File? aadhaarBack;
  final File? panCardImage;

  const UpdateUserDetailsEvent({
    required this.userId,
    this.name,
    this.username,
    this.email,
    this.mobileNumber,
    this.secondaryMobileNumber,
    this.gender,
    this.address,
    this.familyType,
    this.totalOccupants,
    this.aadhaarCard,
    this.panCard,
    this.isNRI,
    this.department,
    this.employeeId,
    this.hostelRoom,
    this.hostelBed,
    this.occupationCategory,
    this.occupationDetails,
    this.dateOfBirth,
    this.password,
    this.profilePic,
    this.aadhaarFront,
    this.aadhaarBack,
    this.panCardImage,
  });

  @override
  List<Object?> get props => [
        userId,
        name,
        username,
        email,
        mobileNumber,
        secondaryMobileNumber,
        gender,
        address,
        familyType,
        totalOccupants,
        aadhaarCard,
        panCard,
        isNRI,
        department,
        employeeId,
        hostelRoom,
        hostelBed,
        occupationCategory,
        occupationDetails,
        dateOfBirth,
        password,
        profilePic,
        aadhaarFront,
        aadhaarBack,
        panCardImage,
      ];
}

class ToggleBlockActiveEvent extends AdminEvent {
  final String blockId;

  const ToggleBlockActiveEvent(this.blockId);

  @override
  List<Object?> get props => [blockId];
}

class ToggleRoomOccupiedEvent extends AdminEvent {
  final String blockId;
  final String floorId;
  final String roomId;
  final bool isOccupied;

  const ToggleRoomOccupiedEvent({
    required this.blockId,
    required this.floorId,
    required this.roomId,
    required this.isOccupied,
  });

  @override
  List<Object?> get props => [blockId, floorId, roomId, isOccupied];
}

class DeleteRoomEvent extends AdminEvent {
  final String blockId;
  final String floorId;
  final String roomId;

  const DeleteRoomEvent({
    required this.blockId,
    required this.floorId,
    required this.roomId,
  });

  @override
  List<Object?> get props => [blockId, floorId, roomId];
}

class EditRoomEvent extends AdminEvent {
  final String blockId;
  final String floorId;
  final String roomId;
  final String roomNumber;
  final String roomType;
  final int? beds;

  const EditRoomEvent({
    required this.blockId,
    required this.floorId,
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    this.beds,
  });

  @override
  List<Object?> get props => [blockId, floorId, roomId, roomNumber, roomType, beds];
}

// States
abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminLoaded extends AdminState {
  final List<BlockModel> blocks;
  final List<UserModel> allUsers;
  final List<UserModel> securityStaff;
  final List<UserModel> regularUsers;
  final List<ComplaintModel> complaints;
  final String? selectedApartmentId;

  const AdminLoaded({
    required this.blocks,
    required this.allUsers,
    List<UserModel>? securityStaff,
    required this.regularUsers,
    this.complaints = const [],
    this.selectedApartmentId,
  }) : securityStaff = securityStaff ?? const [];

  @override
  List<Object?> get props =>
      [blocks, allUsers, securityStaff, regularUsers, complaints, selectedApartmentId];
}

class AdminError extends AdminState {
  final String message;

  const AdminError({required this.message});

  @override
  List<Object?> get props => [message];
}

List<BlockModel> _parseBlocksFromApi(dynamic raw) {
  if (raw is! List) return [];
  final blocks = <BlockModel>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      blocks.add(BlockModel.fromJson(Map<String, dynamic>.from(item)));
    } catch (e) {
      debugPrint('Skipping invalid block entry: $e');
    }
  }
  return blocks;
}

String? _blockIdFromApiMap(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final id = map['id']?.toString();
  if (id != null && id.isNotEmpty) return id;
  return map['_id']?.toString();
}

// BLoC
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AuthRepository _authRepository = AuthRepository();
  final ApiService _apiService = ApiService();
  String? _selectedApartmentId;

  AdminBloc() : super(AdminInitial()) {
    on<LoadBlocksEvent>(_onLoadBlocks);
    on<SelectApartmentEvent>(_onSelectApartment);
    on<CreateBlockEvent>(_onCreateBlock);
    on<AddFloorEvent>(_onAddFloor);
    on<LoadAllUsersEvent>(_onLoadAllUsers);
    on<AddSecurityEvent>(_onAddSecurity);
    on<UpdateSecurityEvent>(_onUpdateSecurity);
    on<DeleteSecurityEvent>(_onDeleteSecurity);
    on<AddUserEvent>(_onAddUser);
    on<BlockUserEvent>(_onBlockUser);
    on<UnblockUserEvent>(_onUnblockUser);
    on<DeleteUserEvent>(_onDeleteUser);
    on<ToggleUserActiveEvent>(_onToggleUserActive);
    on<UpdateUserStatusEvent>(_onUpdateUserStatus);
    on<UpdateUserDetailsEvent>(_onUpdateUserDetails);
    on<ToggleBlockActiveEvent>(_onToggleBlockActive);
    on<AddRoomEvent>(_onAddRoom);
    on<EditBlockEvent>(_onEditBlock);
    on<DeleteBlockEvent>(_onDeleteBlock);
    on<EditFloorEvent>(_onEditFloor);
    on<DeleteFloorEvent>(_onDeleteFloor);
    on<ToggleRoomOccupiedEvent>(_onToggleRoomOccupied);
    on<DeleteRoomEvent>(_onDeleteRoom);
    on<EditRoomEvent>(_onEditRoom);
  }

  Future<
      ({
        List<UserModel> allUsers,
        List<UserModel> securityStaff,
        List<UserModel> regularUsers,
      })> _fetchUsersForApartment() async {
    final users =
        await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
    final securityStaff =
        users.where((u) => u.userType == UserType.security).toList();
    final regularUsers = users
        .where((u) =>
            u.userType == UserType.user || u.userType == UserType.tenant)
        .toList();
    return (
      allUsers: users,
      securityStaff: securityStaff,
      regularUsers: regularUsers,
    );
  }

  void _onSelectApartment(SelectApartmentEvent event, Emitter<AdminState> emit) {
    _selectedApartmentId = event.apartmentId;
    final current = state;
    if (current is AdminLoaded) {
      emit(AdminLoaded(
        blocks: current.blocks,
        allUsers: current.allUsers,
        securityStaff: current.securityStaff,
        regularUsers: current.regularUsers,
        complaints: current.complaints,
        selectedApartmentId: _selectedApartmentId,
      ));
    }
  }

  Future<void> _onLoadBlocks(
    LoadBlocksEvent event,
    Emitter<AdminState> emit,
  ) async {
    final previous = state;
    if (previous is! AdminLoaded) {
      emit(AdminLoading());
    }
    try {
      final apartmentId = _selectedApartmentId;
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: apartmentId);
      final blocks = blocksResponse['success'] == true
          ? _parseBlocksFromApi(blocksResponse['blocks'])
          : <BlockModel>[];

      final users = await _authRepository.getAllUsers(apartmentId: apartmentId);
      final securityStaff =
          users.where((u) => u.userType == UserType.security).toList();
      final regularUsers =
          users.where((u) => u.userType == UserType.user || u.userType == UserType.tenant).toList();

      List<ComplaintModel> complaints = [];
      if (apartmentId != null && apartmentId.isNotEmpty) {
        final complaintsRes = await _apiService.getComplaints(apartmentId: apartmentId);
        if (complaintsRes['success'] == true && complaintsRes['complaints'] != null) {
          final list = complaintsRes['complaints'] as List<dynamic>? ?? [];
          complaints = list
              .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: users,
        securityStaff: securityStaff,
        regularUsers: regularUsers,
        complaints: complaints,
        selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onLoadAllUsers(
    LoadAllUsersEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      print('=== AdminBloc _onLoadAllUsers CALLED ===');
      print('_selectedApartmentId: $_selectedApartmentId');
      
      final currentState = state;
      print('Fetching users (AdminLoaded: ${currentState is AdminLoaded})...');
      final users = await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
      print('Users fetched from repository: ${users.length}');

      final securityStaff =
          users.where((u) => u.userType == UserType.security).toList();
      final regularUsers = users
          .where((u) => u.userType == UserType.user || u.userType == UserType.tenant)
          .toList();

      print(
        'Filtered users - securityStaff: ${securityStaff.length}, regularUsers: ${regularUsers.length}',
      );

      if (currentState is AdminLoaded) {
        emit(AdminLoaded(
          blocks: currentState.blocks,
          allUsers: users,
          securityStaff: securityStaff,
          regularUsers: regularUsers,
          complaints: currentState.complaints,
          selectedApartmentId: _selectedApartmentId,
        ));
      } else {
        emit(AdminLoaded(
          blocks: const [],
          allUsers: users,
          securityStaff: securityStaff,
          regularUsers: regularUsers,
          complaints: const [],
          selectedApartmentId: _selectedApartmentId,
        ));
        add(LoadBlocksEvent());
      }
      print('State emitted with ${regularUsers.length} regular users');
    } catch (e) {
      print('Error in _onLoadAllUsers: $e');
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onAddSecurity(
    AddSecurityEvent event,
    Emitter<AdminState> emit,
  ) async {
    if (isClosed) return;
    emit(AdminLoading());
    try {
      // Resolve apartmentId so added security shows in apartment-wise list and resident app
      String? apartmentId = _selectedApartmentId;
      if ((apartmentId == null || apartmentId.isEmpty) && state is AdminLoaded) {
        final loaded = state as AdminLoaded;
        if (loaded.blocks.isNotEmpty && loaded.blocks.first.apartmentId != null) {
          apartmentId = loaded.blocks.first.apartmentId;
        }
      }
      if (apartmentId == null || apartmentId.isEmpty) {
        if (!isClosed) {
          emit(AdminError(
              message: 'Please select an apartment first so security is assigned to it. Open an apartment from the Overview tab.'));
        }
        return;
      }

      final username = event.name.toLowerCase().replaceAll(' ', '_');

      final response = await _apiService.registerUser(
        name: event.name,
        username: username,
        email: event.email,
        password: event.password,
        mobileNumber: event.mobileNumber,
        userType: 'security',
        apartmentId: apartmentId,
        profilePic: event.profilePic,
        aadhaarFront: event.idProof, // Using aadhaarFront field for ID proof
      );

      if (response['success'] == true) {
        add(LoadAllUsersEvent());
        add(LoadBlocksEvent());
      } else {
        if (!isClosed) {
          emit(AdminError(
              message: response['error'] ?? 'Failed to add security staff'));
        }
      }
    } catch (e) {
      if (!isClosed) {
        emit(AdminError(message: e.toString()));
      }
    }
  }

  Future<void> _onUpdateSecurity(
    UpdateSecurityEvent event,
    Emitter<AdminState> emit,
  ) async {
    if (isClosed) return;
    emit(AdminLoading());
    try {
      final response = await _apiService.updateSecurity(
        securityId: event.securityId,
        name: event.name,
        email: event.email,
        mobileNumber: event.mobileNumber,
        password: event.password,
        profilePic: event.profilePic,
        idProof: event.idProof,
      );

      if (response['success'] == true) {
        add(LoadAllUsersEvent());
        add(LoadBlocksEvent());
      } else {
        if (!isClosed) {
          emit(AdminError(
              message: response['error'] ?? 'Failed to update security staff'));
        }
      }
    } catch (e) {
      if (!isClosed) {
        emit(AdminError(message: e.toString()));
      }
    }
  }

  Future<void> _onDeleteSecurity(
    DeleteSecurityEvent event,
    Emitter<AdminState> emit,
  ) async {
    if (isClosed) return;
    emit(AdminLoading());
    try {
      final response = await _apiService.deleteSecurity(event.securityId);

      if (response['success'] == true) {
        add(LoadAllUsersEvent());
        add(LoadBlocksEvent());
      } else {
        if (!isClosed) {
          emit(AdminError(
              message: response['error'] ?? 'Failed to delete security staff'));
        }
      }
    } catch (e) {
      if (!isClosed) {
        emit(AdminError(message: e.toString()));
      }
    }
  }

  Future<void> _onAddUser(
    AddUserEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final user = UserModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: event.name,
        username: event.name.toLowerCase().replaceAll(' ', '_'),
        email: event.email,
        mobileNumber: event.mobileNumber,
        userType: UserType.user,
        status: AccountStatus.pending,
        block: event.block,
        floor: event.floor,
        roomNumber: event.roomNumber,
        familyType: event.familyType,
      );

      await _authRepository.saveUser(user);
      add(LoadAllUsersEvent());
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onBlockUser(
    BlockUserEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final users = await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
      final userIndex = users.indexWhere((u) => u.id == event.userId);
      if (userIndex >= 0) {
        final user = users[userIndex];
        final updatedUser = user.copyWith(status: AccountStatus.rejected);
        await _authRepository.saveUser(updatedUser);
        add(LoadAllUsersEvent());
      }
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onUnblockUser(
    UnblockUserEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final users = await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
      final userIndex = users.indexWhere((u) => u.id == event.userId);
      if (userIndex >= 0) {
        final user = users[userIndex];
        final updatedUser = user.copyWith(status: AccountStatus.approved);
        await _authRepository.saveUser(updatedUser);
        add(LoadAllUsersEvent());
      }
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onDeleteUser(
    DeleteUserEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      // Delete user from backend database
      await _apiService.deleteUser(event.userId);

      // Delete user from local cache/state
      final users = await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
      users.removeWhere((u) => u.id == event.userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'users_list',
        jsonEncode(users.map((u) => u.toJson()).toList()),
      );
      add(LoadAllUsersEvent());
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onCreateBlock(
    CreateBlockEvent event,
    Emitter<AdminState> emit,
  ) async {
    final currentState = state;
    try {
      // Create block via backend API
      final response = await _apiService.createBlock(
        event.blockName,
        apartmentId: _selectedApartmentId,
      );

      if (response['success'] != true) {
        if (!isClosed) {
          _emitCreateBlockFailure(
            emit,
            currentState,
            response['error'] ?? 'Failed to create block',
          );
        }
        return;
      }

      BlockModel? createdBlock;
      try {
        final raw = response['block'];
        if (raw is Map) {
          createdBlock =
              BlockModel.fromJson(Map<String, dynamic>.from(raw));
        }
      } catch (e) {
        debugPrint('Could not parse created block: $e');
      }

      final blockId = _blockIdFromApiMap(response['block']);

      if (blockId == null) {
        if (!isClosed) {
          _emitCreateBlockFailure(
            emit,
            currentState,
            'Failed to get block ID after creation',
          );
        }
        return;
      }

      // If floor numbers are provided, create each floor from the spec
      if (event.floorNumbers != null && event.floorNumbers!.isNotEmpty) {
        int successCount = 0;
        int failCount = 0;

        for (final floorNumber in event.floorNumbers!) {
          if (isClosed) break; // Stop if bloc is closed

          try {
            final floorResponse = await _apiService.addFloor(
              blockId: blockId,
              floorNumber: floorNumber,
              roomConfigurations: [], // Empty floor, rooms will be added later
            );

            // Check if floor creation was successful
            if (floorResponse['success'] == true) {
              successCount++;
            } else {
              failCount++;
              debugPrint(
                  'Failed to create floor $floorNumber: ${floorResponse['error']}');
            }
          } catch (e) {
            failCount++;
            debugPrint('Error creating floor $floorNumber: $e');
          }
        }

        if (failCount > 0) {
          debugPrint(
            'Block created; $successCount floor(s) added, $failCount failed',
          );
        }
      }

      // Reload blocks from backend
      if (isClosed) return;

      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      var blocks = blocksResponse['success'] == true
          ? _parseBlocksFromApi(blocksResponse['blocks'])
          : <BlockModel>[];

      if (createdBlock != null &&
          !blocks.any((b) => b.id == createdBlock!.id)) {
        blocks = [...blocks, createdBlock];
      }

      if (!isClosed) {
        if (currentState is AdminLoaded) {
          emit(AdminLoaded(
            blocks: blocks,
            allUsers: currentState.allUsers,
            securityStaff: currentState.securityStaff,
            regularUsers: currentState.regularUsers,
            complaints: currentState.complaints,
            selectedApartmentId: _selectedApartmentId,
          ));
        } else {
          final users =
              await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
          final securityStaff =
              users.where((u) => u.userType == UserType.security).toList();
          final regularUsers =
              users.where((u) => u.userType == UserType.user || u.userType == UserType.tenant).toList();
          if (!isClosed) {
            emit(AdminLoaded(
              blocks: blocks,
              allUsers: users,
              securityStaff: securityStaff,
              regularUsers: regularUsers,
              complaints: const [],
              selectedApartmentId: _selectedApartmentId,
            ));
          }
        }
      }
    } catch (e) {
      if (!isClosed) {
        _emitCreateBlockFailure(emit, currentState, e.toString());
      }
    }
  }

  void _emitCreateBlockFailure(
    Emitter<AdminState> emit,
    AdminState currentState,
    String message,
  ) {
    emit(AdminError(message: message));
    if (currentState is AdminLoaded) {
      emit(currentState);
    }
  }

  Future<void> _onAddFloor(
    AddFloorEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;

      // Add floor via backend API
      final response = await _apiService.addFloor(
        blockId: event.blockId,
        floorNumber: event.floorNumber,
        roomConfigurations: event.roomConfigurations,
        roomNumber: event.roomNumber,
      );

      if (response['success'] != true) {
        emit(AdminError(message: response['error'] ?? 'Failed to add floor'));
        return;
      }

      // Reload blocks from backend
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final blocks = blocksResponse['success'] == true
          ? _parseBlocksFromApi(blocksResponse['blocks'])
          : <BlockModel>[];

      if (currentState is AdminLoaded) {
        emit(AdminLoaded(
          blocks: blocks,
          allUsers: currentState.allUsers,
          securityStaff: currentState.securityStaff,
          regularUsers: currentState.regularUsers,
          complaints: currentState.complaints,
          selectedApartmentId: _selectedApartmentId,
        ));
      } else {
        final users = await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
        final securityStaff =
            users.where((u) => u.userType == UserType.security).toList();
        final regularUsers =
            users.where((u) => u.userType == UserType.user || u.userType == UserType.tenant).toList();
        emit(AdminLoaded(
          blocks: blocks,
          allUsers: users,
          securityStaff: securityStaff,
          regularUsers: regularUsers,
          complaints: const [],
        selectedApartmentId: _selectedApartmentId,
        ));
      }
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onToggleUserActive(
    ToggleUserActiveEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.toggleUserActive(event.userId);

      if (response['success'] != true) {
        final err = response['error'] ?? '';
        // If user not found on server (likely a local-only/dummy user), reload users to sync UI
        if (err.toLowerCase().contains('not found')) {
          add(LoadAllUsersEvent());
          return;
        }
        emit(AdminError(
            message: err.isNotEmpty ? err : 'Failed to toggle user status'));
        return;
      }

      // Reload users from backend
      final users = await _authRepository.getAllUsers(apartmentId: _selectedApartmentId);
      final securityStaff =
          users.where((u) => u.userType == UserType.security).toList();
      final regularUsers =
          users.where((u) => u.userType == UserType.user || u.userType == UserType.tenant).toList();

      emit(AdminLoaded(
        blocks: currentState.blocks,
        allUsers: users,
        securityStaff: securityStaff,
        regularUsers: regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onUpdateUserStatus(
    UpdateUserStatusEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final response = await _apiService.updateUserStatus(
        event.userId,
        event.status.name,
        block: event.block,
        floor: event.floor,
        roomNumber: event.roomNumber,
        apartmentId: event.apartmentId,
      );
      if (response['success'] == true) {
        add(LoadAllUsersEvent());
        add(LoadBlocksEvent());
      } else {
        if (!isClosed) {
          emit(AdminError(
              message: response['error'] ?? 'Failed to update user status'));
        }
        add(LoadAllUsersEvent());
        add(LoadBlocksEvent());
      }
    } catch (e) {
      if (!isClosed) {
        emit(AdminError(message: e.toString()));
      }
      add(LoadAllUsersEvent());
      add(LoadBlocksEvent());
    }
  }

  Future<void> _onUpdateUserDetails(
    UpdateUserDetailsEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final response = await _apiService.updateUser(
        userId: event.userId,
        name: event.name,
        username: event.username,
        email: event.email,
        mobileNumber: event.mobileNumber,
        secondaryMobileNumber: event.secondaryMobileNumber,
        gender: event.gender,
        address: event.address,
        familyType: event.familyType,
        totalOccupants: event.totalOccupants,
        aadhaarCard: event.aadhaarCard,
        panCard: event.panCard,
        isNRI: event.isNRI,
        department: event.department,
        employeeId: event.employeeId,
        hostelRoom: event.hostelRoom,
        hostelBed: event.hostelBed,
        occupationCategory: event.occupationCategory,
        occupationDetails: event.occupationDetails,
        dateOfBirth: event.dateOfBirth,
        password: event.password,
        profilePic: event.profilePic,
        aadhaarFront: event.aadhaarFront,
        aadhaarBack: event.aadhaarBack,
        panCardImage: event.panCardImage,
      );
      if (response['success'] == true) {
        add(LoadAllUsersEvent());
      } else if (!isClosed) {
        emit(AdminError(
            message: response['error'] ?? 'Failed to update user'));
      }
    } catch (e) {
      if (!isClosed) {
        emit(AdminError(message: e.toString()));
      }
    }
  }

  Future<void> _onToggleBlockActive(
    ToggleBlockActiveEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.toggleBlockActive(event.blockId);

      if (response['success'] != true) {
        emit(AdminError(
            message: response['error'] ?? 'Failed to toggle block status'));
        return;
      }

      // Reload blocks from backend
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: currentState.allUsers,
        securityStaff: currentState.securityStaff,
        regularUsers: currentState.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onAddRoom(
    AddRoomEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.addRoom(
        blockId: event.blockId,
        floorId: event.floorId,
        roomNumber: event.roomNumber,
        roomType: event.roomType,
        beds: event.beds,
      );

      if (response['success'] != true) {
        emit(AdminError(message: response['error'] ?? 'Failed to add room'));
        return;
      }

      // Reload blocks from backend
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: currentState.allUsers,
        securityStaff: currentState.securityStaff,
        regularUsers: currentState.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onEditBlock(
    EditBlockEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.updateBlock(event.blockId, event.name);

      if (response['success'] != true) {
        emit(
            AdminError(message: response['error'] ?? 'Failed to update block'));
        return;
      }

      // Reload blocks and users (assignments sync when block name changes)
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }
      final users = await _fetchUsersForApartment();

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: users.allUsers,
        securityStaff: users.securityStaff,
        regularUsers: users.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onDeleteBlock(
    DeleteBlockEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.deleteBlock(event.blockId);

      if (response['success'] != true) {
        emit(
            AdminError(message: response['error'] ?? 'Failed to delete block'));
        return;
      }

      // Reload blocks from backend
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: currentState.allUsers,
        securityStaff: currentState.securityStaff,
        regularUsers: currentState.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onEditFloor(
    EditFloorEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.updateFloor(
        blockId: event.blockId,
        floorId: event.floorId,
        floorNumber: event.floorNumber,
      );

      if (response['success'] != true) {
        emit(
            AdminError(message: response['error'] ?? 'Failed to update floor'));
        return;
      }

      // Reload blocks and users (assignments sync when floor number changes)
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }
      final users = await _fetchUsersForApartment();

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: users.allUsers,
        securityStaff: users.securityStaff,
        regularUsers: users.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onDeleteFloor(
    DeleteFloorEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.deleteFloor(
        blockId: event.blockId,
        floorId: event.floorId,
      );

      if (response['success'] != true) {
        emit(
            AdminError(message: response['error'] ?? 'Failed to delete floor'));
        return;
      }

      // Reload blocks from backend
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: currentState.allUsers,
        securityStaff: currentState.securityStaff,
        regularUsers: currentState.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onToggleRoomOccupied(
    ToggleRoomOccupiedEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.updateRoom(
        blockId: event.blockId,
        floorId: event.floorId,
        roomId: event.roomId,
        isOccupied: event.isOccupied,
      );

      if (response['success'] != true) {
        emit(AdminError(
            message: response['error'] ?? 'Failed to update room status'));
        return;
      }

      // Reload blocks from backend
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: currentState.allUsers,
        securityStaff: currentState.securityStaff,
        regularUsers: currentState.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onDeleteRoom(
    DeleteRoomEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.deleteRoom(
        blockId: event.blockId,
        floorId: event.floorId,
        roomId: event.roomId,
      );

      if (response['success'] != true) {
        emit(AdminError(
            message: response['error'] ?? 'Failed to delete room'));
        return;
      }

      // Reload blocks from backend
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: currentState.allUsers,
        securityStaff: currentState.securityStaff,
        regularUsers: currentState.regularUsers,
        complaints: currentState.complaints,
      selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }

  Future<void> _onEditRoom(
    EditRoomEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! AdminLoaded) return;

      final response = await _apiService.updateRoom(
        blockId: event.blockId,
        floorId: event.floorId,
        roomId: event.roomId,
        number: event.roomNumber,
        type: event.roomType,
        beds: event.beds,
      );

      if (response['success'] != true) {
        emit(AdminError(
            message: response['error'] ?? 'Failed to update room details'));
        return;
      }

      // Reload blocks and users (assignments sync when room number changes)
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: _selectedApartmentId);
      final List<BlockModel> blocks = [];
      if (blocksResponse['success'] == true &&
          blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'];
        blocks.addAll(blocksList.map((b) => BlockModel.fromJson(b)).toList());
      }
      final users = await _fetchUsersForApartment();

      emit(AdminLoaded(
        blocks: blocks,
        allUsers: users.allUsers,
        securityStaff: users.securityStaff,
        regularUsers: users.regularUsers,
        complaints: currentState.complaints,
        selectedApartmentId: _selectedApartmentId,
      ));
    } catch (e) {
      emit(AdminError(message: e.toString()));
    }
  }
}
