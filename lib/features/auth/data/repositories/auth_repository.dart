import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/user_model.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/fcm_service.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();
  static const String _userKey = 'current_user';
  static const String _selectedApartmentIdKey = 'selected_apartment_id';

  Future<UserModel?> getCurrentUser() async {
    try {
      // First try to get from API (source of truth - ensures correct userType)
      final response = await _apiService.getCurrentUser();
      if (response['success'] == true && response['user'] != null) {
        final user = UserModel.fromJson(response['user']);
        await saveCurrentUser(user);
        return user;
      }

      // API failed - check if token was cleared (e.g. 401 unauthorized)
      // If no token, don't use stale cache - user must re-login
      final token = await _apiService.getToken();
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_userKey);
        return null;
      }

      // Offline/network error - use cached user only if we have valid token
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        return UserModel.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      // On error, only use cache if we have a token (likely offline)
      final token = await _apiService.getToken();
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_userKey);
        return null;
      }
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        return UserModel.fromJson(jsonDecode(userJson));
      }
      return null;
    }
  }

  Future<void> saveCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_selectedApartmentIdKey);
    await _apiService.clearToken();
  }

  Future<String?> getSelectedApartmentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedApartmentIdKey);
  }

  Future<void> saveSelectedApartmentId(String? apartmentId) async {
    final prefs = await SharedPreferences.getInstance();
    if (apartmentId == null || apartmentId.isEmpty) {
      await prefs.remove(_selectedApartmentIdKey);
    } else {
      await prefs.setString(_selectedApartmentIdKey, apartmentId);
    }
  }

  /// Saves the latest FCM token after login (iOS often gets APNS/FCM after the login request).
  /// Sends this device's push token to the server for the logged-in account.
  Future<void> syncFcmToken() async {
    try {
      final token = await FCMService().getTokenForLogin(
        maxWait: const Duration(seconds: 15),
      );
      if (token == null || token.isEmpty) return;
      await _apiService.updateFcmToken(token);
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }

  Future<void> _syncFcmTokenAfterLogin(String? tokenAtLogin) async {
    final token = await FCMService().getTokenForLogin(
      maxWait: const Duration(seconds: 15),
    );
    if (token == null || token.isEmpty) {
      debugPrint('FCM token sync after login: no token yet');
      return;
    }
    if (tokenAtLogin != null && tokenAtLogin == token) {
      debugPrint('FCM token already synced at login');
      return;
    }

    try {
      final result = await _apiService.updateFcmToken(token);
      if (result['success'] == true) {
        debugPrint('FCM token synced to server after login');
      }
    } catch (e) {
      debugPrint('FCM token sync after login failed: $e');
    }
  }

  Future<UserModel?> login(
    String email,
    String password, [
    UserType? userType,
  ]) async {
    try {
      debugPrint('=== AUTH REPOSITORY LOGIN ===');
      debugPrint('Email: $email');
      debugPrint('UserType enum: $userType');
      debugPrint('UserType.name: ${userType?.name}');
      debugPrint('Sending to API service...');

      // Wait for the same FCM init as main.dart (token is often ready only after init finishes).
      final fcmService = FCMService();
      final fcmToken = await fcmService.getTokenForLogin();

      final response = await _apiService.login(
        email: email,
        password: password,
        userType: userType?.name,
        fcmToken: fcmToken,
      );

      debugPrint('=== API RESPONSE ===');
      debugPrint('Success: ${response['success']}');
      debugPrint('Error: ${response['error']}');
      debugPrint('User data: ${response['user']}');

      if (response['success'] == true && response['user'] != null) {
        final userData = response['user'];
        debugPrint('Parsing user data...');
        debugPrint('User userType from response: ${userData['userType']}');
        final user = UserModel.fromJson(userData);
        debugPrint('Parsed user userType: ${user.userType}');
        await saveCurrentUser(user);
        debugPrint('User saved successfully');
        // If token was not ready before login, sync once auth token is saved.
        unawaited(_syncFcmTokenAfterLogin(fcmToken));
        return user;
      } else {
        debugPrint('Login failed: ${response['error']}');
        throw Exception(response['error'] ?? 'Login failed');
      }
    } catch (e) {
      debugPrint('=== LOGIN ERROR ===');
      debugPrint('Error: $e');
      throw Exception(e.toString());
    }
  }

  Future<UserModel> registerUser({
    required String name,
    required String username,
    required String email,
    required String password,
    required String mobileNumber,
    bool persistAuth = true,
    String? secondaryMobileNumber,
    Gender? gender,
    UserType? userType,
    FamilyType? familyType,
    String? aadhaarCard,
    String? panCard,
    int? totalOccupants,
    String? block,
    String? floor,
    String? roomNumber,
    String? apartmentId,
    String? department,
    String? employeeId,
    String? hostelRoom,
    String? hostelBed,
    String? address,
    OccupationCategory? occupationCategory,
    String? occupationDetails,
    DateTime? dateOfBirth,
    File? profilePic,
    File? aadhaarFront,
    File? aadhaarBack,
    File? panCardImage,
    bool? isNRI,
  }) async {
    try {
      final response = await _apiService.registerUser(
        name: name,
        username: username,
        email: email,
        password: password,
        mobileNumber: mobileNumber,
        saveAuthToken: persistAuth,
        secondaryMobileNumber: secondaryMobileNumber,
        gender: gender?.name,
        userType: userType?.name,
        familyType: familyType?.name,
        aadhaarCard: aadhaarCard,
        panCard: panCard,
        totalOccupants: totalOccupants,
        block: block,
        floor: floor,
        roomNumber: roomNumber,
        apartmentId: apartmentId,
        department: department,
        employeeId: employeeId,
        hostelRoom: hostelRoom,
        hostelBed: hostelBed,
        address: address,
        occupationCategory: occupationCategory?.name,
        occupationDetails: occupationDetails,
        dateOfBirth: dateOfBirth != null ? dateOfBirth.toIso8601String().split('T').first : null,
        profilePic: profilePic,
        aadhaarFront: aadhaarFront,
        aadhaarBack: aadhaarBack,
        panCardImage: panCardImage,
        isNRI: isNRI,
      );

      if (response['success'] == true && response['user'] != null) {
        final userData = response['user'];
        final user = UserModel.fromJson(userData);
        if (persistAuth) {
          await saveCurrentUser(user);
        }
        return user;
      } else {
        throw Exception(response['error'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> sendOtp(String email) async {
    final response = await _apiService.sendOtp(email);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to send OTP');
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    final response = await _apiService.verifyOtp(email, otp);
    if (response['success'] != true || response['verified'] != true) {
      throw Exception(response['error'] ?? 'Invalid OTP');
    }
  }

  Future<void> forgotPassword(String email) async {
    final response = await _apiService.forgotPassword(email);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to send OTP');
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _apiService.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to reset password');
    }
  }

  // Get all users from backend (optionally filtered by apartmentId, block, floor)
  Future<List<UserModel>> getAllUsers({
    String? apartmentId,
    String? block,
    String? floor,
    bool assignedOnly = false,
  }) async {
    try {
      print('=== AuthRepository getAllUsers CALLED ===');
      print('apartmentId parameter: $apartmentId');

      final response = await _apiService.getAllUsers(
        apartmentId: apartmentId,
        block: block,
        floor: floor,
        assignedOnly: assignedOnly,
      );
      print('API response success: ${response['success']}');
      print('API response users count: ${(response['users'] as List?)?.length ?? 0}');
      
      if (response['success'] == true && response['users'] != null) {
        final List<dynamic> usersList = response['users'];
        final parsedUsers = usersList
            .map((userJson) => UserModel.fromJson(userJson))
            .toList();
        print('Parsed ${parsedUsers.length} users from repository');
        return parsedUsers;
      }
      print('No users returned or success is false');
      return [];
    } catch (e) {
      print('Error in getAllUsers repository: $e');
      return [];
    }
  }

  /// Assigned (approved + block/floor/room) users for a block, optionally one floor.
  Future<List<UserModel>> getAssignedUsers({
    String? apartmentId,
    required String block,
    String? floor,
  }) {
    return getAllUsers(
      apartmentId: apartmentId,
      block: block,
      floor: floor,
      assignedOnly: true,
    );
  }

  Future<void> saveUser(UserModel user) async {
    // Save locally for now
    await saveCurrentUser(user);
  }

  // Get users by mobile number (for switching between users with same mobile)
  Future<List<UserModel>> getUsersByMobileNumber(String mobileNumber) async {
    try {
      final response = await _apiService.getUsersByMobileNumber(mobileNumber);
      if (response['success'] == true && response['users'] != null) {
        final List<dynamic> usersList = response['users'];
        return usersList
            .map((userJson) => UserModel.fromJson(userJson))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error in getUsersByMobileNumber repository: $e');
      return [];
    }
  }
}
