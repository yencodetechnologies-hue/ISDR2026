import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/user_model.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/fcm_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {}

class RefreshCurrentUserEvent extends AuthEvent {}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  final UserType? userType;

  const LoginEvent({
    required this.email,
    required this.password,
    this.userType,
  });

  @override
  List<Object?> get props => [email, password, userType];
}

class RegisterUserEvent extends AuthEvent {
  final String name;
  final String username;
  final String email;
  final String password;
  final String mobileNumber;
  final bool persistAuth;
  final String? secondaryMobileNumber;
  final Gender? gender;
  final UserType? userType;
  final FamilyType? familyType;
  final String? aadhaarCard;
  final String? panCard;
  final int? totalOccupants;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final String? apartmentId;
  final String? department;
  final String? employeeId;
  final String? hostelRoom;
  final String? hostelBed;
  final String? address;
  final OccupationCategory? occupationCategory;
  final String? occupationDetails;
  final DateTime? dateOfBirth;
  final String? profilePicPath;
  final String? aadhaarFrontPath;
  final String? aadhaarBackPath;
  final String? panCardImagePath;
  final bool? isNRI;

  const RegisterUserEvent({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    required this.mobileNumber,
    this.persistAuth = true,
    this.secondaryMobileNumber,
    this.gender,
    this.userType,
    this.familyType,
    this.aadhaarCard,
    this.panCard,
    this.totalOccupants,
    this.block,
    this.floor,
    this.roomNumber,
    this.apartmentId,
    this.department,
    this.employeeId,
    this.hostelRoom,
    this.hostelBed,
    this.address,
    this.occupationCategory,
    this.occupationDetails,
    this.dateOfBirth,
    this.profilePicPath,
    this.aadhaarFrontPath,
    this.aadhaarBackPath,
    this.panCardImagePath,
    this.isNRI,
  });

  @override
  List<Object?> get props => [
        name,
        username,
        email,
        password,
        mobileNumber,
        persistAuth,
        secondaryMobileNumber,
        gender,
        userType,
        familyType,
        aadhaarCard,
        panCard,
        totalOccupants,
        block,
        floor,
        roomNumber,
        apartmentId,
        department,
        employeeId,
        hostelRoom,
        hostelBed,
        address,
        occupationCategory,
        occupationDetails,
        dateOfBirth,
        profilePicPath,
        aadhaarFrontPath,
        aadhaarBackPath,
        panCardImagePath,
        isNRI,
      ];
}

class SendOtpEvent extends AuthEvent {
  final String email;
  final bool isForgotPassword;

  const SendOtpEvent({
    required this.email,
    this.isForgotPassword = false,
  });

  @override
  List<Object?> get props => [email, isForgotPassword];
}

class VerifyOtpEvent extends AuthEvent {
  final String email;
  final String otp;

  const VerifyOtpEvent({required this.email, required this.otp});

  @override
  List<Object?> get props => [email, otp];
}

class ResetPasswordEvent extends AuthEvent {
  final String email;
  final String otp;
  final String newPassword;

  const ResetPasswordEvent({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [email, otp, newPassword];
}

class LogoutEvent extends AuthEvent {}

class SelectUserApartmentEvent extends AuthEvent {
  final String? apartmentId;

  const SelectUserApartmentEvent({this.apartmentId});

  @override
  List<Object?> get props => [apartmentId];
}

class SwitchUserEvent extends AuthEvent {
  final UserModel user;

  const SwitchUserEvent({required this.user});

  @override
  List<Object?> get props => [user];
}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  final String? selectedApartmentId;

  const AuthAuthenticated({required this.user, this.selectedApartmentId});

  @override
  List<Object?> get props => [user, selectedApartmentId];
}

class AuthUnauthenticated extends AuthState {}

/// Success state used when we should NOT replace the current session (e.g. admin creates a user).
class UserRegisteredSuccess extends AuthState {
  final UserModel user;

  const UserRegisteredSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class OtpSent extends AuthState {
  final String email;

  const OtpSent({required this.email});

  @override
  List<Object?> get props => [email];
}

class OtpVerified extends AuthState {
  final String email;

  const OtpVerified({required this.email});

  @override
  List<Object?> get props => [email];
}

class PasswordResetSuccess extends AuthState {
  const PasswordResetSuccess();
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  late final StreamSubscription<String> _fcmTokenSub;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    // The APNs token often arrives after the first sync attempt.
    _fcmTokenSub = FCMService().tokenStream.listen((_) {
      authRepository.syncFcmToken();
    });
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<RefreshCurrentUserEvent>(_onRefreshCurrentUser);
    on<LoginEvent>(_onLogin);
    on<RegisterUserEvent>(_onRegisterUser);
    on<SendOtpEvent>(_onSendOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<ResetPasswordEvent>(_onResetPassword);
    on<LogoutEvent>(_onLogout);
    on<SelectUserApartmentEvent>(_onSelectUserApartment);
    on<SwitchUserEvent>(_onSwitchUser);
  }

  void _logSignInDetails(UserModel user, String? selectedApartmentId, String source) {
    String propertyName = user.apartmentName ?? 'N/A';
    if (user.apartments != null && user.apartments!.isNotEmpty) {
      final matched = user.apartments!.firstWhere(
        (a) => a.id == selectedApartmentId,
        orElse: () => user.apartments!.first,
      );
      propertyName = matched.name;
    }

    debugPrint('====================================================');
    debugPrint('🚀 SIGN IN DETAILS ($source) 🚀');
    debugPrint('👤 User Name     : ${user.name}');
    debugPrint('📧 Contact       : ${user.email} / ${user.mobileNumber}');
    debugPrint('🎭 Role (userType): ${user.userType.name.toUpperCase()} (loginRole: ${user.loginRole ?? 'N/A'})');
    debugPrint('🏢 Property ID   : ${selectedApartmentId ?? user.apartmentId ?? 'N/A'}');
    debugPrint('🏢 Property Name : $propertyName');
    debugPrint('🏫 Property Type : ${user.propertyType?.name ?? 'N/A'}');
    debugPrint('====================================================');
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final user = await authRepository.getCurrentUser();
    if (user != null) {
      final savedId = await authRepository.getSelectedApartmentId();
      final selectedId = _resolveSelectedApartmentId(user, savedId);
      if (selectedId != null && selectedId != savedId) {
        await authRepository.saveSelectedApartmentId(selectedId);
      }
      _logSignInDetails(user, selectedId, 'CHECK_AUTH / AUTO-LOGIN');
      emit(AuthAuthenticated(user: user, selectedApartmentId: selectedId));
      // Push notifications: keep this device's token on the server.
      authRepository.syncFcmToken().ignore();
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRefreshCurrentUser(
    RefreshCurrentUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthAuthenticated) return;
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(
          user: user,
          selectedApartmentId: current.selectedApartmentId,
        ));
      }
    } catch (_) {}
  }

  String? _resolveSelectedApartmentId(UserModel user, String? savedId) {
    final allowed = user.apartments != null && user.apartments!.isNotEmpty
        ? user.apartments!.map((a) => a.id).toList()
        : (user.apartmentId != null ? [user.apartmentId!] : <String>[]);
    if (savedId != null && allowed.contains(savedId)) return savedId;
    return user.apartmentId ?? (user.apartments?.isNotEmpty == true ? user.apartments!.first.id : null);
  }

  Future<void> _onLogin(
    LoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint('=== AUTH BLOC LOGIN ===');
    debugPrint('Email: ${event.email}');
    debugPrint('UserType: ${event.userType}');
    debugPrint('UserType.name: ${event.userType?.name}');

    emit(AuthLoading());
    try {
      debugPrint('Calling authRepository.login...');
      final user = await authRepository
          .login(event.email, event.password, event.userType)
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
            'Connection timeout to ${ApiConfig.baseUrl}. '
            'Simulator: ensure backend is running (npm start in backend/). '
            'Physical device: flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:5000/api',
          );
        },
      );
      debugPrint('AuthRepository returned user: ${user != null}');
      if (user != null) {
        final savedId = await authRepository.getSelectedApartmentId();
        final selectedId = _resolveSelectedApartmentId(user, savedId);
        if (selectedId != null && selectedId != savedId) {
          await authRepository.saveSelectedApartmentId(selectedId);
        }
        _logSignInDetails(user, selectedId, 'LOGIN');
        emit(AuthAuthenticated(user: user, selectedApartmentId: selectedId));
      } else {
        debugPrint('User is null, emitting error');
        emit(const AuthError(message: 'Invalid email or password'));
      }
    } on TimeoutException catch (e) {
      debugPrint('=== AUTH BLOC TIMEOUT ===');
      debugPrint('Current API baseUrl: ${ApiConfig.baseUrl}');
      emit(AuthError(
        message: e.message ??
            'Connection timeout to ${ApiConfig.baseUrl}. Ensure the server is running and the app is pointing to the right URL.',
      ));
    } catch (e) {
      debugPrint('=== AUTH BLOC ERROR ===');
      debugPrint('Error: $e');
      final message = e is Exception ? _readableMessage(e) : e.toString();
      emit(AuthError(message: message));
    }
  }

  /// Prefer a short, user-friendly message from API/Exception.
  String _readableMessage(Exception e) {
    final s = e.toString();
    if (s.startsWith('Exception: ')) {
      return s.substring('Exception: '.length);
    }
    return s;
  }

  Future<void> _onRegisterUser(
    RegisterUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    // Admin/apartment registering someone else must keep the current session. We
    // snapshot it before AuthLoading so we can re-emit AuthAuthenticated after
    // UserRegisteredSuccess (AdminRouteGuard only renders the dashboard for
    // AuthAuthenticated).
    UserModel? sessionBeforeRegister;
    if (!event.persistAuth) {
      sessionBeforeRegister = await authRepository.getCurrentUser();
    }
    emit(AuthLoading());
    try {
      final user = await authRepository.registerUser(
        name: event.name,
        username: event.username,
        email: event.email,
        password: event.password,
        mobileNumber: event.mobileNumber,
        persistAuth: event.persistAuth,
        secondaryMobileNumber: event.secondaryMobileNumber,
        gender: event.gender,
        userType: event.userType,
        familyType: event.familyType,
        aadhaarCard: event.aadhaarCard,
        panCard: event.panCard,
        totalOccupants: event.totalOccupants,
        block: event.block,
        floor: event.floor,
        roomNumber: event.roomNumber,
        apartmentId: event.apartmentId,
        department: event.department,
        employeeId: event.employeeId,
        hostelRoom: event.hostelRoom,
        hostelBed: event.hostelBed,
        address: event.address,
        occupationCategory: event.occupationCategory,
        occupationDetails: event.occupationDetails,
        dateOfBirth: event.dateOfBirth,
        profilePic: event.profilePicPath != null
            ? await _getFileFromPath(event.profilePicPath!)
            : null,
        aadhaarFront: event.aadhaarFrontPath != null
            ? await _getFileFromPath(event.aadhaarFrontPath!)
            : null,
        aadhaarBack: event.aadhaarBackPath != null
            ? await _getFileFromPath(event.aadhaarBackPath!)
            : null,
        panCardImage: event.panCardImagePath != null
            ? await _getFileFromPath(event.panCardImagePath!)
            : null,
        isNRI: event.isNRI,
      );
      if (!event.persistAuth) {
        emit(UserRegisteredSuccess(user: user));
        final session =
            sessionBeforeRegister ?? await authRepository.getCurrentUser();
        if (session != null) {
          final savedId = await authRepository.getSelectedApartmentId();
          final selectedId = _resolveSelectedApartmentId(session, savedId);
          if (selectedId != null && selectedId != savedId) {
            await authRepository.saveSelectedApartmentId(selectedId);
          }
          emit(AuthAuthenticated(
            user: session,
            selectedApartmentId: selectedId,
          ));
        }
        return;
      }

      final savedId = await authRepository.getSelectedApartmentId();
      final selectedId = _resolveSelectedApartmentId(user, savedId);
      if (selectedId != null && selectedId != savedId) {
        await authRepository.saveSelectedApartmentId(selectedId);
      }
      emit(AuthAuthenticated(user: user, selectedApartmentId: selectedId));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSelectUserApartment(
    SelectUserApartmentEvent event,
    Emitter<AuthState> emit,
  ) async {
    final state = this.state;
    if (state is! AuthAuthenticated) return;
    await authRepository.saveSelectedApartmentId(event.apartmentId);
    emit(AuthAuthenticated(user: state.user, selectedApartmentId: event.apartmentId));
  }

  Future<File?> _getFileFromPath(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _onSendOtp(
    SendOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      if (event.isForgotPassword) {
        await authRepository.forgotPassword(event.email);
      } else {
        await authRepository.sendOtp(event.email);
      }
      emit(OtpSent(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyOtp(
    VerifyOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.verifyOtp(event.email, event.otp);
      emit(OtpVerified(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.resetPassword(
        email: event.email,
        otp: event.otp,
        newPassword: event.newPassword,
      );
      emit(const PasswordResetSuccess());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onSwitchUser(
    SwitchUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // Note: This switches the user locally, but the token is still for the original user.
      // API calls may fail if the backend validates user ID from token.
      // For full functionality, a backend endpoint that validates mobile number match
      // and issues a new token would be needed.
      
      // Save the new user
      await authRepository.saveCurrentUser(event.user);
      
      // Try to fetch user data from backend to validate (this will fail if token doesn't match)
      try {
        final currentUser = await authRepository.getCurrentUser();
        if (currentUser != null && currentUser.id == event.user.id) {
          // Token is valid for this user, proceed
          final savedId = await authRepository.getSelectedApartmentId();
          final selectedId = _resolveSelectedApartmentId(currentUser, savedId);
          if (selectedId != null && selectedId != savedId) {
            await authRepository.saveSelectedApartmentId(selectedId);
          }
          emit(AuthAuthenticated(user: currentUser, selectedApartmentId: selectedId));
        } else {
          // Token doesn't match, use the provided user data anyway
          final savedId = await authRepository.getSelectedApartmentId();
          final selectedId = _resolveSelectedApartmentId(event.user, savedId);
          if (selectedId != null && selectedId != savedId) {
            await authRepository.saveSelectedApartmentId(selectedId);
          }
          emit(AuthAuthenticated(user: event.user, selectedApartmentId: selectedId));
        }
      } catch (e) {
        // Backend validation failed, but continue with local switch
        // User may need to re-login if API calls fail
        final savedId = await authRepository.getSelectedApartmentId();
        final selectedId = _resolveSelectedApartmentId(event.user, savedId);
        if (selectedId != null && selectedId != savedId) {
          await authRepository.saveSelectedApartmentId(selectedId);
        }
        emit(AuthAuthenticated(user: event.user, selectedApartmentId: selectedId));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _fcmTokenSub.cancel();
    return super.close();
  }
}
