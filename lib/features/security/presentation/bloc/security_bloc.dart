import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../../../../core/models/visitor_model.dart';
import '../../../../core/models/block_model.dart';
import '../../../../core/models/kid_exit_model.dart';
import '../../../../core/models/monthly_visitor_pass_model.dart';
import '../../../../core/services/api_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../pages/security_visitor_section.dart';

// Events
abstract class SecurityEvent extends Equatable {
  const SecurityEvent();

  @override
  List<Object?> get props => [];
}

class LoadSecurityDataEvent extends SecurityEvent {
  final String? apartmentId;

  const LoadSecurityDataEvent({this.apartmentId});

  @override
  List<Object?> get props => [apartmentId];
}

class AddVisitorEvent extends SecurityEvent {
  final String name;
  final String mobileNumber;
  final VisitorType type;
  final String block;
  final String homeNumber;
  /// Local file to upload; server stores Cloudinary URL.
  final File? visitorImage;
  final String? purposeOfVisit;
  final String? vehicleNumber;
  final String? typeDetail;

  const AddVisitorEvent({
    required this.name,
    required this.mobileNumber,
    required this.type,
    required this.block,
    required this.homeNumber,
    this.visitorImage,
    this.purposeOfVisit,
    this.vehicleNumber,
    this.typeDetail,
  });

  @override
  List<Object?> get props => [name, mobileNumber, type, block, homeNumber, visitorImage?.path, purposeOfVisit, vehicleNumber, typeDetail];
}

class AddBulkVisitorEvent extends SecurityEvent {
  final String name;
  final String mobileNumber;
  final VisitorType type;
  final List<({String block, String homeNumber})> homes;
  final String? purposeOfVisit;
  final String? vehicleNumber;
  final File? visitorImage;
  final String? typeDetail;

  const AddBulkVisitorEvent({
    required this.name,
    required this.mobileNumber,
    required this.type,
    required this.homes,
    this.purposeOfVisit,
    this.vehicleNumber,
    this.visitorImage,
    this.typeDetail,
  });

  @override
  List<Object?> get props => [name, mobileNumber, type, homes, purposeOfVisit, vehicleNumber, visitorImage?.path, typeDetail];
}

class ApproveVisitorEvent extends SecurityEvent {
  final String visitorId;

  const ApproveVisitorEvent({required this.visitorId});

  @override
  List<Object?> get props => [visitorId];
}

class MarkVisitorEntryEvent extends SecurityEvent {
  final String visitorId;
  final String entryMethod;
  /// When true (auto-entry after approval), UI may switch Visitors filter to Inside once.
  final bool focusInsideAfter;

  const MarkVisitorEntryEvent({
    required this.visitorId,
    this.entryMethod = 'manual',
    this.focusInsideAfter = false,
  });

  @override
  List<Object?> get props => [visitorId, entryMethod, focusInsideAfter];
}

class MarkVisitorExitEvent extends SecurityEvent {
  final String visitorId;

  const MarkVisitorExitEvent({required this.visitorId});

  @override
  List<Object?> get props => [visitorId];
}

class ClearSecurityErrorEvent extends SecurityEvent {}

class ClearPendingVisitorsSectionEvent extends SecurityEvent {}

// States
abstract class SecurityState extends Equatable {
  const SecurityState();

  @override
  List<Object?> get props => [];
}

class SecurityInitial extends SecurityState {}

class SecurityLoading extends SecurityState {}

class SecurityLoaded extends SecurityState {
  final List<VisitorModel> visitors;
  final List<BlockModel> blocks;
  final List<KidExitModel> kidExits;
  /// Non-null when the last add-visitor API call failed (visitor may still be shown locally).
  final String? lastAddVisitorError;

  /// When non-null, Visitors tab should switch to this section once, then clear via [ClearPendingVisitorsSectionEvent].
  final SecurityVisitorSection? pendingVisitorsSection;

  final List<MonthlyVisitorPassModel> monthlyPasses;

  const SecurityLoaded({
    required this.visitors,
    required this.blocks,
    this.kidExits = const [],
    this.lastAddVisitorError,
    this.pendingVisitorsSection,
    this.monthlyPasses = const [],
  });

  @override
  List<Object?> get props => [
        visitors,
        blocks,
        kidExits,
        lastAddVisitorError,
        pendingVisitorsSection,
        monthlyPasses,
      ];

  List<VisitorModel> get pendingApprovalVisitors =>
      visitors.where((visitor) => visitor.isPendingApproval).toList();

  List<VisitorModel> get approvedVisitors =>
      visitors.where((visitor) => visitor.isApprovedForGate).toList();

  List<VisitorModel> get activeVisitors =>
      visitors.where((visitor) => visitor.isInside).toList();

  List<VisitorModel> get overstayVisitors =>
      visitors.where((visitor) => visitor.isInside && visitor.isOverstayActive).toList();

  List<VisitorModel> get completedVisitors =>
      visitors.where((visitor) => visitor.isCompleted).toList();
}

// BLoC
class SecurityBloc extends Bloc<SecurityEvent, SecurityState> {
  static const String _visitorsKey = 'visitors_list';
  static const String _blocksKey = 'blocks_list';

  final ApiService _apiService = ApiService();

  SecurityBloc() : super(SecurityInitial()) {
    on<LoadSecurityDataEvent>(_onLoadSecurityData);
    on<AddVisitorEvent>(_onAddVisitor);
    on<AddBulkVisitorEvent>(_onAddBulkVisitor);
    on<ApproveVisitorEvent>(_onApproveVisitor);
    on<MarkVisitorEntryEvent>(_onMarkVisitorEntry);
    on<MarkVisitorExitEvent>(_onMarkVisitorExit);
    on<ClearSecurityErrorEvent>(_onClearSecurityError);
    on<ClearPendingVisitorsSectionEvent>(_onClearPendingVisitorsSection);
  }

  void _onClearSecurityError(ClearSecurityErrorEvent event, Emitter<SecurityState> emit) {
    final current = state;
    if (current is SecurityLoaded && current.lastAddVisitorError != null) {
      emit(SecurityLoaded(
        visitors: current.visitors,
        blocks: current.blocks,
        kidExits: current.kidExits,
        pendingVisitorsSection: current.pendingVisitorsSection,
      ));
    }
  }

  void _onClearPendingVisitorsSection(ClearPendingVisitorsSectionEvent event, Emitter<SecurityState> emit) {
    final current = state;
    if (current is SecurityLoaded && current.pendingVisitorsSection != null) {
      emit(SecurityLoaded(
        visitors: current.visitors,
        blocks: current.blocks,
        kidExits: current.kidExits,
        lastAddVisitorError: current.lastAddVisitorError,
      ));
    }
  }

  static bool _isAlreadyInsideEntryError(Object? error) {
    final s = error?.toString().toLowerCase() ?? '';
    return s.contains('already inside');
  }

  Future<void> _onLoadSecurityData(
    LoadSecurityDataEvent event,
    Emitter<SecurityState> emit,
  ) async {
    final previousVisitors = state is SecurityLoaded
        ? List<VisitorModel>.from((state as SecurityLoaded).visitors)
        : <VisitorModel>[];
    if (state is! SecurityLoaded) {
      emit(SecurityLoading());
    }
    try {
      List<VisitorModel> visitors = [];
      List<BlockModel> blocks = [];
      List<KidExitModel> kidExits = [];
      List<MonthlyVisitorPassModel> monthlyPasses = [];

      // Fetch all visitors from backend (dashboard filters Today / Upcoming / View All client-side)
      final visitorsResponse = await _apiService.getSecurityVisitors();
      if (visitorsResponse['success'] == true && visitorsResponse['visitors'] != null) {
        final List<dynamic> list = visitorsResponse['visitors'] as List<dynamic>;
        visitors = list
            .map((v) => VisitorModel.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList();
      }

      // Fetch monthly passes for security dashboard
      final monthlyResponse = await _apiService.getMonthlyAttendanceForSecurity();
      if (monthlyResponse['success'] == true && monthlyResponse['passes'] != null) {
        final List<dynamic> list = monthlyResponse['passes'] as List<dynamic>;
        monthlyPasses = list
            .map((p) => MonthlyVisitorPassModel.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
      }



      // Fetch blocks from backend so Add Visitor block dropdown has data (scoped by apartment)
      final blocksResponse = await _apiService.getAllBlocks(apartmentId: event.apartmentId);
      if (blocksResponse['success'] == true && blocksResponse['blocks'] != null) {
        final List<dynamic> blocksList = blocksResponse['blocks'] as List<dynamic>;
        blocks = blocksList
            .map((b) => BlockModel.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList();
        await _saveBlocks(blocks);
      }

      // Fallback: use cached blocks from prefs if API returned none
      if (blocks.isEmpty) {
        blocks = await _getBlocks();
      }

      // Kid exits: security sees all (today by default for dashboard)
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final kidExitsResponse = await _apiService.getKidExits(date: todayStr);
      if (kidExitsResponse['success'] == true && kidExitsResponse['kidExits'] != null) {
        final List<dynamic> list = kidExitsResponse['kidExits'] as List<dynamic>;
        kidExits = list
            .map((e) => KidExitModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      emit(SecurityLoaded(
        visitors: visitors,
        blocks: blocks,
        kidExits: kidExits,
        monthlyPasses: monthlyPasses,
      ));
    } catch (e) {
      // On error: try local cache for both (no lastAddVisitorError on load)
      try {
        final visitors = await _getVisitors();
        final blocks = await _getBlocks();
        emit(SecurityLoaded(visitors: visitors, blocks: blocks, kidExits: []));
      } catch (_) {
        emit(SecurityLoaded(visitors: [], blocks: [], kidExits: []));
      }
    }
  }

  Future<void> _onAddVisitor(
    AddVisitorEvent event,
    Emitter<SecurityState> emit,
  ) async {
    try {
      // Start from current state so API-loaded visitors are kept; only use cache when not yet loaded
      List<VisitorModel> visitors;
      final current = state;
      if (current is SecurityLoaded) {
        visitors = List<VisitorModel>.from(current.visitors);
      } else {
        visitors = await _getVisitors();
      }

      // Persist to backend so visitor still appears after close/reopen
      final mobileDigits = event.mobileNumber.replaceAll(RegExp(r'\D'), '');
      final mobile10 = mobileDigits.length >= 10 ? mobileDigits.substring(mobileDigits.length - 10) : event.mobileNumber.trim();
      final payload = <String, dynamic>{
        'name': event.name,
        'mobileNumber': mobile10,
        'category': 'outsider',
        'type': event.type.name,
        'block': event.block,
        'homeNumber': event.homeNumber,
        'visitTime': DateTime.now().toUtc().toIso8601String(),
        if (event.purposeOfVisit != null && event.purposeOfVisit!.isNotEmpty) 'reasonForVisit': event.purposeOfVisit,
        if (event.vehicleNumber != null && event.vehicleNumber!.isNotEmpty) 'vehicleNumber': event.vehicleNumber,
        if (event.typeDetail != null && event.typeDetail!.trim().isNotEmpty) 'typeDetail': event.typeDetail!.trim(),
      };
      final response = await _apiService.createSecurityVisitor(
        payload,
        image: event.visitorImage,
      );

      String? apiError;
      VisitorModel newVisitor;
      if (response['success'] == true && response['visitor'] != null) {
        final raw = response['visitor'];
        final map = Map<String, dynamic>.from(raw is Map ? raw as Map : {});
        if (!map.containsKey('id') && map.containsKey('_id')) {
          map['id'] = map['_id'].toString();
        }
        newVisitor = VisitorModel.fromJson(map);
      } else {
        // Offline/API failure: add locally so user sees it; will not persist across reopen until API is available
        apiError = response['error'] as String? ?? 'Could not save visitor to server. You may be offline.';
        final otp = _generateOTP();
        final visitorId = const Uuid().v4();
        final qrData = jsonEncode({
          'visitorId': visitorId,
          'name': event.name,
          'mobileNumber': event.mobileNumber,
          'block': event.block,
          'homeNumber': event.homeNumber,
          'visitTime': DateTime.now().toIso8601String(),
          'otp': otp,
        });
        newVisitor = VisitorModel(
          id: visitorId,
          name: event.name,
          mobileNumber: event.mobileNumber,
          category: VisitorCategory.outsider,
          type: event.type,
          block: event.block,
          homeNumber: event.homeNumber,
          visitTime: DateTime.now(),
          otp: otp,
          qrCode: qrData,
          image: event.visitorImage?.path,
          reasonForVisit: event.purposeOfVisit,
          vehicleNumber: event.vehicleNumber,
          approvalStatus: VisitorApprovalStatus.pending,
          typeDetail: event.typeDetail?.trim().isNotEmpty == true ? event.typeDetail!.trim() : null,
        );
      }

      visitors.add(newVisitor);
      await _saveVisitors(visitors);
      final blocks = await _getBlocks();
      emit(SecurityLoaded(visitors: visitors, blocks: blocks, kidExits: current is SecurityLoaded ? current.kidExits : const [], lastAddVisitorError: apiError));
    } catch (e) {
      // Exception during API or parsing: add visitor locally and surface error
      final current = state;
      List<VisitorModel> visitors = current is SecurityLoaded ? List<VisitorModel>.from(current.visitors) : await _getVisitors();
      final blocks = current is SecurityLoaded ? current.blocks : await _getBlocks();
      final otp = _generateOTP();
      final visitorId = const Uuid().v4();
      final qrData = jsonEncode({
        'visitorId': visitorId,
        'name': event.name,
        'mobileNumber': event.mobileNumber,
        'block': event.block,
        'homeNumber': event.homeNumber,
        'visitTime': DateTime.now().toIso8601String(),
        'otp': otp,
      });
      final newVisitor = VisitorModel(
        id: visitorId,
        name: event.name,
        mobileNumber: event.mobileNumber,
        category: VisitorCategory.outsider,
        type: event.type,
        block: event.block,
        homeNumber: event.homeNumber,
        visitTime: DateTime.now(),
        otp: otp,
        qrCode: qrData,
        image: event.visitorImage?.path,
        reasonForVisit: event.purposeOfVisit,
        vehicleNumber: event.vehicleNumber,
        approvalStatus: VisitorApprovalStatus.pending,
        typeDetail: event.typeDetail?.trim().isNotEmpty == true ? event.typeDetail!.trim() : null,
      );
      visitors.add(newVisitor);
      await _saveVisitors(visitors);
      emit(SecurityLoaded(visitors: visitors, blocks: blocks, kidExits: current is SecurityLoaded ? current.kidExits : const [], lastAddVisitorError: 'Could not save to server: ${e.toString()}'));
    }
  }

  Future<void> _onAddBulkVisitor(
    AddBulkVisitorEvent event,
    Emitter<SecurityState> emit,
  ) async {
    if (event.homes.isEmpty) return;
    final current = state;
    try {
      List<VisitorModel> visitors;
      if (current is SecurityLoaded) {
        visitors = List<VisitorModel>.from(current.visitors);
      } else {
        visitors = await _getVisitors();
      }

      final mobileDigits = event.mobileNumber.replaceAll(RegExp(r'\D'), '');
      final mobile10 = mobileDigits.length >= 10 ? mobileDigits.substring(mobileDigits.length - 10) : event.mobileNumber.trim();
      final homesPayload = event.homes
          .map((h) => {'block': h.block, 'homeNumber': h.homeNumber})
          .toList();
      final payload = <String, dynamic>{
        'name': event.name,
        'mobileNumber': mobile10,
        'category': 'outsider',
        'type': event.type.name,
        'homes': homesPayload,
        if (event.purposeOfVisit != null && event.purposeOfVisit!.isNotEmpty) 'reasonForVisit': event.purposeOfVisit,
        if (event.vehicleNumber != null && event.vehicleNumber!.isNotEmpty) 'vehicleNumber': event.vehicleNumber,
        if (event.typeDetail != null && event.typeDetail!.trim().isNotEmpty) 'typeDetail': event.typeDetail!.trim(),
      };

      final response = await _apiService.createSecurityVisitorBulk(
        payload,
        image: event.visitorImage,
      );

      String? apiError;
      if (response['success'] == true && response['visitors'] != null) {
        final rawList = response['visitors'] as List<dynamic>;
        for (final raw in rawList) {
          final map = Map<String, dynamic>.from(raw is Map ? raw as Map : {});
          if (!map.containsKey('id') && map.containsKey('_id')) {
            map['id'] = map['_id'].toString();
          }
          visitors.add(VisitorModel.fromJson(map));
        }
      } else {
        apiError = response['error'] as String? ?? 'Could not save bulk visitors to server.';
      }

      await _saveVisitors(visitors);
      final blocks = current is SecurityLoaded ? current.blocks : await _getBlocks();
      final kidExits = current is SecurityLoaded ? current.kidExits : <KidExitModel>[];
      emit(SecurityLoaded(visitors: visitors, blocks: blocks, kidExits: kidExits, lastAddVisitorError: apiError));
    } catch (e) {
      final visitors = current is SecurityLoaded ? List<VisitorModel>.from(current.visitors) : await _getVisitors();
      final blocks = current is SecurityLoaded ? current.blocks : await _getBlocks();
      final kidExits = current is SecurityLoaded ? current.kidExits : <KidExitModel>[];
      emit(SecurityLoaded(visitors: visitors, blocks: blocks, kidExits: kidExits, lastAddVisitorError: 'Could not save bulk visitors: ${e.toString()}'));
    }
  }

  Future<void> _onApproveVisitor(
    ApproveVisitorEvent event,
    Emitter<SecurityState> emit,
  ) async {
    final current = state;
    if (current is! SecurityLoaded) return;
    try {
      final response = await _apiService.updateVisitorApproval(event.visitorId, 'approved');
      if (response['success'] == true) {
        final visitors = List<VisitorModel>.from(current.visitors);
        final idx = visitors.indexWhere((v) => v.id == event.visitorId);
        if (idx >= 0) {
          final updated = response['visitor'] != null
              ? VisitorModel.fromJson(Map<String, dynamic>.from(response['visitor'] as Map))
              : visitors[idx].copyWith(
                  approvalStatus: VisitorApprovalStatus.approved,
                  visitStatus: VisitorVisitStatus.approved,
                  approvedAt: DateTime.now(),
                );
          visitors[idx] = updated;
          await _saveVisitors(visitors);
          emit(SecurityLoaded(visitors: visitors, blocks: current.blocks, kidExits: current.kidExits, lastAddVisitorError: current.lastAddVisitorError));
          add(const LoadSecurityDataEvent());
          if (updated.isApprovedForGate && !updated.isInside && !updated.isCompleted) {
            add(MarkVisitorEntryEvent(visitorId: event.visitorId, focusInsideAfter: true));
          }
        }
      } else {
        final err = response['error'] as String? ?? 'Could not approve visitor';
        emit(SecurityLoaded(visitors: current.visitors, blocks: current.blocks, kidExits: current.kidExits, lastAddVisitorError: err));
      }
    } catch (e) {
      emit(SecurityLoaded(visitors: current.visitors, blocks: current.blocks, kidExits: current.kidExits, lastAddVisitorError: 'Failed to approve: ${e.toString()}'));
    }
  }

  Future<void> _onMarkVisitorEntry(
    MarkVisitorEntryEvent event,
    Emitter<SecurityState> emit,
  ) async {
    final current = state;
    if (current is! SecurityLoaded) return;

    try {
      final response = await _apiService.markVisitorEntry(
        event.visitorId,
        entryMethod: event.entryMethod,
      );
      if (response['success'] == true) {
        if (response['monthlyPass'] != null) {
          final updatedPass = MonthlyVisitorPassModel.fromJson(
            Map<String, dynamic>.from(response['monthlyPass'] as Map),
          );
          final passes = List<MonthlyVisitorPassModel>.from(current.monthlyPasses);
          final idx = passes.indexWhere((p) => p.id == updatedPass.id);
          if (idx >= 0) {
            passes[idx] = updatedPass;
          } else {
            passes.insert(0, updatedPass);
          }
          emit(SecurityLoaded(
            visitors: current.visitors,
            monthlyPasses: passes,
            blocks: current.blocks,
            kidExits: current.kidExits,
            lastAddVisitorError: null,
            pendingVisitorsSection: event.focusInsideAfter
                ? SecurityVisitorSection.monthlyVisitors
                : null,
          ));
        } else if (response['visitor'] != null) {
          final updated = VisitorModel.fromJson(
            Map<String, dynamic>.from(response['visitor'] as Map),
          );
          final visitors = List<VisitorModel>.from(current.visitors);
          final index =
              visitors.indexWhere((visitor) => visitor.id == event.visitorId);
          if (index >= 0) {
            visitors[index] = updated;
          } else {
            visitors.insert(0, updated);
          }
          await _saveVisitors(visitors);
          emit(SecurityLoaded(
            visitors: visitors,
            monthlyPasses: current.monthlyPasses,
            blocks: current.blocks,
            kidExits: current.kidExits,
            lastAddVisitorError: null,
            pendingVisitorsSection:
                event.focusInsideAfter ? SecurityVisitorSection.inside : null,
          ));
          add(const LoadSecurityDataEvent());
        }
      } else {
        final err = response['error'];
        if (_isAlreadyInsideEntryError(err)) {
          emit(SecurityLoaded(
            visitors: current.visitors,
            blocks: current.blocks,
            kidExits: current.kidExits,
            lastAddVisitorError: null,
          ));
        } else {
          emit(SecurityLoaded(
            visitors: current.visitors,
            blocks: current.blocks,
            kidExits: current.kidExits,
            lastAddVisitorError: err?.toString() ?? 'Failed to record visitor entry',
          ));
        }
      }
    } catch (e) {
      if (_isAlreadyInsideEntryError(e)) {
        emit(SecurityLoaded(
          visitors: current.visitors,
          blocks: current.blocks,
          kidExits: current.kidExits,
          lastAddVisitorError: null,
        ));
      } else {
        emit(SecurityLoaded(
          visitors: current.visitors,
          blocks: current.blocks,
          kidExits: current.kidExits,
          lastAddVisitorError: 'Failed to record visitor entry: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onMarkVisitorExit(
    MarkVisitorExitEvent event,
    Emitter<SecurityState> emit,
  ) async {
    final current = state;
    if (current is! SecurityLoaded) return;

    try {
      final response = await _apiService.markVisitorExit(event.visitorId);
      if (response['success'] == true) {
        if (response['monthlyPass'] != null) {
          final updatedPass = MonthlyVisitorPassModel.fromJson(
            Map<String, dynamic>.from(response['monthlyPass'] as Map),
          );
          final passes = List<MonthlyVisitorPassModel>.from(current.monthlyPasses);
          final idx = passes.indexWhere((p) => p.id == updatedPass.id);
          if (idx >= 0) {
            passes[idx] = updatedPass;
          }
          emit(SecurityLoaded(
            visitors: current.visitors,
            monthlyPasses: passes,
            blocks: current.blocks,
            kidExits: current.kidExits,
            lastAddVisitorError: null,
          ));
        } else if (response['visitor'] != null) {
          final updated = VisitorModel.fromJson(
            Map<String, dynamic>.from(response['visitor'] as Map),
          );
          final visitors = List<VisitorModel>.from(current.visitors);
          final index =
              visitors.indexWhere((visitor) => visitor.id == event.visitorId);
          if (index >= 0) {
            visitors[index] = updated;
          } else {
            visitors.insert(0, updated);
          }
          await _saveVisitors(visitors);
          emit(SecurityLoaded(
            visitors: visitors,
            monthlyPasses: current.monthlyPasses,
            blocks: current.blocks,
            kidExits: current.kidExits,
            lastAddVisitorError: null,
          ));
          add(const LoadSecurityDataEvent());
        }
      } else {
        emit(SecurityLoaded(
          visitors: current.visitors,
          blocks: current.blocks,
          kidExits: current.kidExits,
          lastAddVisitorError: response['error'] as String? ?? 'Failed to record visitor exit',
        ));
      }
    } catch (e) {
      emit(SecurityLoaded(
        visitors: current.visitors,
        blocks: current.blocks,
        kidExits: current.kidExits,
        lastAddVisitorError: 'Failed to record visitor exit: ${e.toString()}',
      ));
    }
  }

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
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

  Future<List<BlockModel>> _getBlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final blocksJson = prefs.getString(_blocksKey);
    if (blocksJson != null) {
      final List<dynamic> blocksList = jsonDecode(blocksJson);
      return blocksList.map((b) => BlockModel.fromJson(b)).toList();
    }
    return [];
  }

  Future<void> _saveBlocks(List<BlockModel> blocks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _blocksKey,
      jsonEncode(blocks.map((b) => b.toJson()).toList()),
    );
  }
}

