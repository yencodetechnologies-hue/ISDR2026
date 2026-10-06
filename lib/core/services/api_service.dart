import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _tokenKey = 'auth_token';
  late Dio _dio;

  ApiService() {
    if (kDebugMode) {
      debugPrint('API base URL: ${ApiConfig.baseUrl}');
    }
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout:
            const Duration(seconds: 60), // Increased from 30 to 60 seconds
        receiveTimeout:
            const Duration(seconds: 60), // Increased from 30 to 60 seconds
        sendTimeout: const Duration(seconds: 60), // Added send timeout
      ),
    );

    // Add interceptor to include token in requests and log API traffic
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // IMPORTANT:
          // - Do not force a global Content-Type header. Dio must be able to set
          //   `multipart/form-data; boundary=...` automatically for FormData.
          // - For non-FormData payloads, explicitly use JSON content-type.
          final data = options.data;
          final isMultipart = data is FormData;
          if (isMultipart) {
            // Let Dio generate the correct multipart content-type with boundary.
            options.headers.remove('Content-Type');
            options.headers.remove('content-type');
            options.contentType = null;
          } else {
            options.contentType = Headers.jsonContentType;
          }

          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            final fullUrl = options.path.startsWith('http') ? options.path : '${options.baseUrl}${options.path}';
            debugPrint('[API REQUEST] ${options.method} $fullUrl');
            if (options.queryParameters.isNotEmpty) {
              debugPrint('   QueryParams: ${options.queryParameters}');
            }
            if (options.headers.containsKey('X-Apartment-Id')) {
              debugPrint('   X-Apartment-Id: ${options.headers['X-Apartment-Id']}');
            }
            if (options.data != null) {
              debugPrint('   Data: ${options.data}');
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('[API RESPONSE] ${response.statusCode} ${response.requestOptions.path}');
            debugPrint('   ResponseData: ${response.data}');
            debugPrint('--------------------------------------------------');
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint('[API ERROR] ${error.response?.statusCode} ${error.requestOptions.path}');
            debugPrint('   ErrorResponse: ${error.response?.data}');
            debugPrint('   ErrorMessage: ${error.message}');
            debugPrint('--------------------------------------------------');
          }
          // Only clear token on 401 from authentication endpoints (token is actually invalid)
          // Don't clear token on 401 from other endpoints (those might be permission-based, not auth failures)
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            // Only clear token if it's the /auth/me endpoint (token validation endpoint)
            // For other endpoints, 401 might be permission-based (e.g., pending users accessing restricted endpoints)
            if (path.contains('/auth/me')) {
              clearToken();
            }
          }

          // Handle connection timeout / unreachable server - show URL and hint for physical device
          String? customMessage;
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            customMessage =
                'Connection timeout. Ensure the server is running at ${ApiConfig.baseUrl}. '
                'On a physical device, use your PC IP: run with --dart-define=API_BASE_URL=http://YOUR_IP:5000/api';
          } else if (error.type == DioExceptionType.connectionError) {
            customMessage =
                'Cannot reach server at ${ApiConfig.baseUrl}. '
                'Check: (1) Backend is running (npm start), (2) Phone and PC on same Wi-Fi, (3) On physical device use your PC IP in API_BASE_URL.';
          }

          if (customMessage != null) {
            // Create a new error with custom message
            final customError = DioException(
              requestOptions: error.requestOptions,
              type: error.type,
              error: customMessage,
              response: error.response,
            );
            handler.next(customError);
          } else {
            handler.next(error);
          }
        },
      ),
    );
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Register user with images
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String username,
    required String email,
    required String password,
    required String mobileNumber,
    bool saveAuthToken = true,
    String? secondaryMobileNumber,
    String? gender,
    String? userType,
    String? familyType,
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
    String? occupationCategory,
    String? occupationDetails,
    String? dateOfBirth,
    File? profilePic,
    File? aadhaarFront,
    File? aadhaarBack,
    File? panCardImage,
    bool? isNRI,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'mobileNumber': mobileNumber,
        if (secondaryMobileNumber != null && secondaryMobileNumber.isNotEmpty)
          'secondaryMobileNumber': secondaryMobileNumber,
        if (gender != null) 'gender': gender,
        if (userType != null) 'userType': userType,
        if (familyType != null) 'familyType': familyType,
        if (aadhaarCard != null && aadhaarCard.isNotEmpty)
          'aadhaarCard': aadhaarCard,
        if (panCard != null && panCard.isNotEmpty) 'panCard': panCard,
        if (totalOccupants != null) 'totalOccupants': totalOccupants.toString(),
        if (block != null && block.isNotEmpty) 'block': block,
        if (floor != null && floor.isNotEmpty) 'floor': floor,
        if (roomNumber != null && roomNumber.isNotEmpty)
          'roomNumber': roomNumber,
        if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
        if (department != null && department.isNotEmpty) 'department': department,
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        if (hostelRoom != null && hostelRoom.isNotEmpty) 'hostelRoom': hostelRoom,
        if (hostelBed != null && hostelBed.isNotEmpty) 'hostelBed': hostelBed,
        if (address != null && address.isNotEmpty) 'address': address,
        if (occupationCategory != null && occupationCategory.isNotEmpty) 'occupationCategory': occupationCategory,
        if (occupationDetails != null && occupationDetails.isNotEmpty) 'occupationDetails': occupationDetails,
        if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
        if (isNRI != null) 'isNRI': isNRI.toString(),
        if (profilePic != null)
          'profilePic': await MultipartFile.fromFile(
            profilePic.path,
            filename: 'profilePic.jpg',
          ),
        if (aadhaarFront != null)
          'aadhaarFront': await MultipartFile.fromFile(
            aadhaarFront.path,
            filename: 'aadhaarFront.jpg',
          ),
        if (aadhaarBack != null)
          'aadhaarBack': await MultipartFile.fromFile(
            aadhaarBack.path,
            filename: 'aadhaarBack.jpg',
          ),
        if (panCardImage != null)
          'panCard': await MultipartFile.fromFile(
            panCardImage.path,
            filename: 'panCard.jpg',
          ),
      });

      final response = await _dio.post(
        ApiConfig.register,
        data: formData,
      );

      if (response.statusCode == 201) {
        final data = response.data;
        if (saveAuthToken && data['token'] != null) {
          await saveToken(data['token']);
        }
        return {
          'success': true,
          'user': data['user'],
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Registration failed',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Register a tenant (called by User/owner). Requires auth token.
  Future<Map<String, dynamic>> registerTenant({
    required String name,
    required String mobileNumber,
    required String password,
    String? gender,
    String? apartmentId,
    String? block,
    String? floor,
    String? roomNumber,
    File? profilePic,
    File? idProof,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        'mobileNumber': mobileNumber,
        'password': password,
        if (gender != null) 'gender': gender,
        if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
        if (block != null && block.isNotEmpty) 'block': block,
        if (floor != null && floor.isNotEmpty) 'floor': floor,
        if (roomNumber != null && roomNumber.isNotEmpty) 'roomNumber': roomNumber,
        if (profilePic != null)
          'profilePic': await MultipartFile.fromFile(
            profilePic.path,
            filename: 'profilePic.jpg',
          ),
        if (idProof != null)
          'idProof': await MultipartFile.fromFile(
            idProof.path,
            filename: 'idProof.jpg',
          ),
      });

      final response = await _dio.post(
        ApiConfig.registerTenant,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'tenant': response.data['tenant'],
          'message': response.data['message'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create tenant',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get tenants added by the current user. Requires auth token. Optionally filter by apartmentId.
  Future<Map<String, dynamic>> getTenants({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.getTenants,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'tenants': response.data['tenants'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load tenants',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get blocks and rooms list for building/room dropdowns
  Future<Map<String, dynamic>> getBlocks({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final response = await _dio.get(
        '/blocks',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'blocks': response.data['blocks'] ?? [],
        };
      }
      return {'success': false, 'error': 'Failed to load blocks'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Register FCM device token for the logged-in user (e.g. after login when token was late).
  Future<Map<String, dynamic>> updateFcmToken(String fcmToken) async {
    try {
      final response = await _dio.put(
        ApiConfig.updateFcmToken,
        data: {'fcmToken': fcmToken},
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update FCM token',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    }
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? userType,
    String? mobile,
    String? fcmToken,
  }) async {
    try {
      debugPrint('=== API SERVICE LOGIN ===');
      debugPrint('URL: ${ApiConfig.login}');
      debugPrint('Email: $email');
      debugPrint('Password: ${password.isNotEmpty ? "***" : "empty"}');
      debugPrint('UserType: $userType');

      String loginIdentifier = email;
      if (userType == 'apartment') {
        final digits = email.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 10) {
          loginIdentifier = digits.substring(digits.length - 10);
        }
      }

      final requestData = <String, dynamic>{
        'email': userType == 'tenant' ? (mobile ?? email) : loginIdentifier,
        'password': password,
        if (userType != null) 'userType': userType,
        if (fcmToken != null) 'fcmToken': fcmToken,
      };
      if (userType == 'apartment') {
        requestData['mobile'] = loginIdentifier;
        requestData['mobileNumber'] = loginIdentifier;
      }
      if (userType == 'tenant') {
        final mobileVal = mobile ?? email;
        requestData['email'] = mobileVal;
        requestData['mobile'] = mobileVal;
        requestData['mobileNumber'] = mobileVal;
      }
      if (userType == 'user' && RegExp(r'^\d{10}$').hasMatch(email)) {
        requestData['mobileNumber'] = email;
      }
      debugPrint('Request data: $requestData');

      final response = await _dio.post(
        ApiConfig.login,
        data: requestData,
      );

      debugPrint('=== API RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['token'] != null) {
          await saveToken(data['token']);
          debugPrint('Token saved successfully');
        }
        return {
          'success': true,
          'user': data['user'],
          'token': data['token'],
        };
      } else {
        debugPrint('Non-200 status code: ${response.statusCode}');
        return {
          'success': false,
          'error': response.data['error'] ?? 'Login failed',
        };
      }
    } on DioException catch (e) {
      debugPrint('=== DIO EXCEPTION ===');
      debugPrint('Error type: ${e.type}');
      debugPrint('Error message: ${e.message}');
      debugPrint('Response: ${e.response?.data}');
      debugPrint('Status code: ${e.response?.statusCode}');

      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      debugPrint('Final error message: $errorMessage');

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      debugPrint('=== GENERAL EXCEPTION ===');
      debugPrint('Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Send OTP
  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await _dio.post(
        ApiConfig.sendOtp,
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to send OTP',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyOtp,
        data: {
          'email': email,
          'otp': otp,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'verified': response.data['verified'] ?? false,
          'message': response.data['message'] ?? 'OTP verified successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Invalid OTP',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Forgot password
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        ApiConfig.forgotPassword,
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to send OTP',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Change the logged-in account's own password (any role).
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.put(
        ApiConfig.changePassword,
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
      return {
        'success': response.data['success'] == true,
        'message': response.data['message'],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  /// Management (apartment) self-service profile update including optional password change.
  Future<Map<String, dynamic>> updateManagementProfile({
    required String name,
    required String email,
    required String mobileNumber,
    String? currentPassword,
    String? newPassword,
    String? wardenName,
    String? wardenContact,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'email': email,
        'mobileNumber': mobileNumber,
      };
      if (currentPassword != null && currentPassword.isNotEmpty) {
        data['currentPassword'] = currentPassword;
      }
      if (newPassword != null && newPassword.isNotEmpty) {
        data['newPassword'] = newPassword;
      }
      if (wardenName != null) data['wardenName'] = wardenName;
      if (wardenContact != null) data['wardenContact'] = wardenContact;

      final response = await _dio.put(
        ApiConfig.updateManagementProfile,
        data: data,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Profile updated successfully',
          'user': response.data['user'],
          'apartment': response.data['apartment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update profile',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get management team list for property
  Future<Map<String, dynamic>> getManagementTeam({String? apartmentId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.managementUsers,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: headers != null ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'users': response.data['users'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load admin team',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create a new co-management ID
  Future<Map<String, dynamic>> createManagementTeamUser({
    required String name,
    required String mobileNumber,
    required String email,
    required String password,
    String? roleTitle,
    String? apartmentId,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name.trim(),
        'mobileNumber': mobileNumber.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'roleTitle': roleTitle ?? 'Admin Member',
      };
      if (apartmentId != null && apartmentId.isNotEmpty) {
        data['apartmentId'] = apartmentId;
      }
      final response = await _dio.post(
        ApiConfig.managementUsers,
        data: data,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Admin ID added successfully',
          'user': response.data['user'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to add admin ID',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update a co-management ID's details (and optionally its password)
  Future<Map<String, dynamic>> updateManagementTeamUser({
    required String id,
    required String name,
    required String mobileNumber,
    required String email,
    String? roleTitle,
    String? password,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name.trim(),
        'mobileNumber': mobileNumber.trim(),
        'email': email.trim().toLowerCase(),
        'roleTitle': roleTitle ?? 'Admin Member',
      };
      if (password != null && password.isNotEmpty) {
        data['password'] = password;
      }
      final response = await _dio.put(
        ApiConfig.deleteManagementUserUrl(id),
        data: data,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Admin ID updated successfully',
          'user': response.data['user'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update admin ID',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Remove a co-management ID by ID
  Future<Map<String, dynamic>> deleteManagementTeamUser(String id) async {
    try {
      final response = await _dio.delete(ApiConfig.deleteManagementUserUrl(id));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Admin ID removed successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to remove admin ID',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.resetPassword,
        data: {
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Password reset successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to reset password',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Register admin
  Future<Map<String, dynamic>> registerAdmin({
    required String name,
    required String username,
    required String email,
    required String password,
    required String mobileNumber,
    String? apartmentId,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'mobileNumber': mobileNumber,
      };
      if (apartmentId != null && apartmentId.isNotEmpty) {
        data['apartmentId'] = apartmentId;
      }
      final response = await _dio.post(
        ApiConfig.registerAdmin,
        data: data,
      );

      if (response.statusCode == 201) {
        final data = response.data;
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        return {
          'success': true,
          'user': data['user'],
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Registration failed',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Upload / replace the management profile photo
  Future<Map<String, dynamic>> uploadManagementProfilePhoto(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'profilePic': await MultipartFile.fromFile(filePath, filename: 'profilePic.jpg'),
      });
      final response = await _dio.put(
        ApiConfig.updateManagementProfilePhoto,
        data: formData,
      );
      return {
        'success': response.data['success'] == true,
        'profilePic': response.data['profilePic'],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? 'Failed to upload photo',
      };
    }
  }

  // Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConfig.getCurrentUser);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': response.data['user'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get user',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Apartments (admin)
  Future<Map<String, dynamic>> getApartments() async {
    try {
      final response = await _dio.get(ApiConfig.getAllApartments);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'apartments': response.data['apartments'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get apartments',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getApartment(String id) async {
    try {
      final response = await _dio.get(ApiConfig.getApartmentUrl(id));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'apartment': response.data['apartment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get apartment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createApartment({
    required String name,
    String? address,
    String? contactPhone,
    String? password,
    String propertyType = 'apartment',
    String? hostelType,
    String? roomType,
    int? bedCountPerRoom,
    String? ownerName,
    String? ownerMobile,
    String? wardenName,
    String? wardenContact,
    String? email,
    String? institutionType,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        if (address != null && address.isNotEmpty) 'address': address,
        if (contactPhone != null && contactPhone.isNotEmpty) 'contactPhone': contactPhone,
        if (password != null && password.isNotEmpty) 'password': password,
        'propertyType': propertyType,
      };
      if (propertyType == 'hostel') {
        if (hostelType != null && hostelType.isNotEmpty) data['hostelType'] = hostelType;
        if (roomType != null && roomType.isNotEmpty) data['roomType'] = roomType;
        if (bedCountPerRoom != null) data['bedCountPerRoom'] = bedCountPerRoom;
        if (ownerName != null && ownerName.isNotEmpty) data['ownerName'] = ownerName;
        if (ownerMobile != null && ownerMobile.isNotEmpty) {
          data['ownerMobile'] = ownerMobile;
          data['contactPhone'] = ownerMobile;
        }
        if (wardenName != null && wardenName.isNotEmpty) data['wardenName'] = wardenName;
        if (wardenContact != null && wardenContact.isNotEmpty) data['wardenContact'] = wardenContact;
        if (email != null && email.isNotEmpty) data['email'] = email;
      }
      if (propertyType == 'company' || propertyType == 'college' || propertyType == 'events') {
        if (email != null && email.isNotEmpty) data['email'] = email;
        if (ownerName != null && ownerName.isNotEmpty) data['ownerName'] = ownerName;
        if (institutionType != null && institutionType.isNotEmpty) {
          data['institutionType'] = institutionType;
        }
      }
      final response = await _dio.post(ApiConfig.createApartment, data: data);
      if (response.statusCode == 201) {
        return {
          'success': true,
          'apartment': response.data['apartment'],
          'message': response.data['message'] ?? 'Apartment created successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create apartment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createCompanyPublic({
    required String name,
    String? address,
    required String contactPhone,
    required String password,
    required String email,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        'contactPhone': contactPhone.trim(),
        'password': password,
        'email': email.trim(),
      };

      final response = await _dio.post(ApiConfig.createCompanyPublic, data: data);
      if (response.statusCode == 201) {
        return {
          'success': true,
          'apartment': response.data['apartment'],
          'message': response.data['message'] ?? 'Company created successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create company',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateApartment({
    required String id,
    String? name,
    String? address,
    String? contactPhone,
    bool? isActive,
    bool? securityEnabled,
    bool? assignPaymentEnabled,
    bool? complaintsEnabled,
    bool? showUserMobile,
    bool? blockCreationEnabled,
    bool? addUserEnabled,
    bool? wardenFacilityEnabled,
    bool? supportEnabled,
    bool? adsEnabled,
    String? propertyType,
    String? hostelType,
    String? roomType,
    int? bedCountPerRoom,
    String? ownerName,
    String? ownerMobile,
    String? wardenName,
    String? wardenContact,
    String? email,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (address != null) data['address'] = address;
      if (contactPhone != null) data['contactPhone'] = contactPhone;
      if (isActive != null) data['isActive'] = isActive;
      if (securityEnabled != null) data['securityEnabled'] = securityEnabled;
      if (assignPaymentEnabled != null) data['assignPaymentEnabled'] = assignPaymentEnabled;
      if (complaintsEnabled != null) data['complaintsEnabled'] = complaintsEnabled;
      if (showUserMobile != null) data['showUserMobile'] = showUserMobile;
      if (blockCreationEnabled != null) data['blockCreationEnabled'] = blockCreationEnabled;
      if (addUserEnabled != null) data['addUserEnabled'] = addUserEnabled;
      if (wardenFacilityEnabled != null) data['wardenFacilityEnabled'] = wardenFacilityEnabled;
      if (supportEnabled != null) data['supportEnabled'] = supportEnabled;
      if (adsEnabled != null) data['adsEnabled'] = adsEnabled;
      if (propertyType != null) data['propertyType'] = propertyType;
      if (hostelType != null) data['hostelType'] = hostelType;
      if (roomType != null) data['roomType'] = roomType;
      if (bedCountPerRoom != null) data['bedCountPerRoom'] = bedCountPerRoom;
      if (ownerName != null) data['ownerName'] = ownerName;
      if (ownerMobile != null) data['ownerMobile'] = ownerMobile;
      if (wardenName != null) data['wardenName'] = wardenName;
      if (wardenContact != null) data['wardenContact'] = wardenContact;
      if (email != null) data['email'] = email;
      final response = await _dio.put(ApiConfig.updateApartmentUrl(id), data: data);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'apartment': response.data['apartment'],
          'message': response.data['message'] ?? 'Apartment updated successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update apartment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteApartment(String id) async {
    try {
      final response = await _dio.delete(ApiConfig.deleteApartmentUrl(id));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Apartment deactivated successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to delete apartment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get all users (optionally filtered by apartmentId, block, floor, assignedOnly)
  Future<Map<String, dynamic>> getAllUsers({
    String? apartmentId,
    String? block,
    String? floor,
    bool assignedOnly = false,
  }) async {
    try {
      print('=== API Service getAllUsers CALLED ===');
      print('apartmentId parameter: $apartmentId');
      print('block parameter: $block');
      print('floor parameter: $floor');
      print('assignedOnly parameter: $assignedOnly');

      final queryParams = <String, dynamic>{};
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }
      if (block != null && block.trim().isNotEmpty) {
        queryParams['block'] = block.trim();
      }
      if (floor != null && floor.trim().isNotEmpty) {
        queryParams['floor'] = floor.trim();
      }
      if (assignedOnly) {
        queryParams['assignedOnly'] = 'true';
      }
      final hasQueryParams = queryParams.isNotEmpty;
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      
      print('queryParams: $queryParams');
      print('headers: $headers');
      print('API URL: ${ApiConfig.getAllUsers}');
      
      final response = await _dio.get(
        ApiConfig.getAllUsers,
        queryParameters: hasQueryParams ? queryParams : null,
        options: headers != null ? Options(headers: headers) : null,
      );

      print('Response statusCode: ${response.statusCode}');
      print('Response data success: ${response.data['success']}');
      print('Response data count: ${response.data['count']}');
      print('Response users length: ${(response.data['users'] as List?)?.length ?? 0}');

      if (response.statusCode == 200) {
        final users = response.data['users'] ?? [];
        print('Returning ${users.length} users');
        return {
          'success': true,
          'users': users,
        };
      } else {
        final err = response.data is Map
            ? (response.data['error'] ?? response.data['message'])
            : null;
        print(
          'getAllUsers failed: statusCode=${response.statusCode} error=$err',
        );
        return {
          'success': false,
          'error': err ?? 'Failed to get users',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      final status = e.response?.statusCode;
      final bodyErr = e.response?.data is Map
          ? (e.response?.data['error'] ?? e.response?.data['message'])
          : null;
      print(
        'getAllUsers DioException: statusCode=$status responseError=$bodyErr message=$errorMessage',
      );

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get users by mobile number (for switching between users with same mobile)
  Future<Map<String, dynamic>> getUsersByMobileNumber(String mobileNumber) async {
    try {
      if (mobileNumber.isEmpty || !RegExp(r'^\d{10}$').hasMatch(mobileNumber)) {
        return {
          'success': false,
          'error': 'Valid 10-digit mobile number is required',
        };
      }

      final response = await _dio.get(
        ApiConfig.getUsersByMobileNumber,
        queryParameters: {'mobileNumber': mobileNumber},
      );

      if (response.statusCode == 200) {
        final users = response.data['users'] ?? [];
        return {
          'success': true,
          'users': users,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get users by mobile number',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get all blocks (optionally filtered by apartmentId)
  Future<Map<String, dynamic>> getAllBlocks({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.getAllBlocks,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'blocks': response.data['blocks'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get blocks',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Send a notification to an event's participants (optionally one package / inclusion).
  Future<Map<String, dynamic>> sendEventNotification({
    required String eventId,
    required String message,
    String? packageId,
    String? inclusionName,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.managedEventNotifications(eventId),
        data: {
          'message': message,
          if (packageId != null && packageId.isNotEmpty) 'packageId': packageId,
          if (inclusionName != null && inclusionName.isNotEmpty) 'inclusionName': inclusionName,
        },
      );
      return {
        'success': response.data['success'] == true,
        'recipientCount': response.data['recipientCount'] ?? 0,
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  // ---- Event schedules (speaker sessions) ----
  Future<Map<String, dynamic>> listEventSchedules(String eventId) async {
    try {
      final response = await _dio.get(ApiConfig.managedEventSchedules(eventId));
      return {
        'success': response.data['success'] == true,
        'schedules': response.data['schedules'] ?? [],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  /// Speaker login: all of this speaker's sessions (one per date) and the event.
  Future<Map<String, dynamic>> getMySpeakerSessions() async {
    try {
      final response = await _dio.get(ApiConfig.managedEventMySpeakerSessions);
      return {
        'success': response.data['success'] == true,
        'sessions': response.data['sessions'] ?? [],
        'event': response.data['event'],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  // ---- Session content: files / polls / questions a speaker adds to a session ----

  /// Runs a session-content request and flattens the reply to {success, ...data, error}.
  Future<Map<String, dynamic>> _sessionContentCall(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return {...data, 'success': data['success'] == true};
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  /// Polls and questions of one session. The speaker also gets vote counts
  /// and answers; a participant gets their own `myVote` / `myAnswer`.
  Future<Map<String, dynamic>> getSessionContent(String scheduleId) =>
      _sessionContentCall(() => _dio.get(ApiConfig.sessionContent(scheduleId)));

  Future<Map<String, dynamic>> createSessionPoll(
    String scheduleId, {
    required String question,
    required List<String> options,
  }) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.sessionContent(scheduleId)}/polls',
            data: {'question': question, 'options': options},
          ));

  Future<Map<String, dynamic>> deleteSessionPoll(String scheduleId, String pollId) =>
      _sessionContentCall(
        () => _dio.delete('${ApiConfig.sessionContent(scheduleId)}/polls/$pollId'),
      );

  Future<Map<String, dynamic>> voteSessionPoll(
    String scheduleId,
    String pollId,
    int option,
  ) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.sessionContent(scheduleId)}/polls/$pollId/vote',
            data: {'option': option},
          ));

  /// Participant's one-time 1–5 star rating (and optional comment) of a session.
  Future<Map<String, dynamic>> rateSession(
    String scheduleId, {
    required int stars,
    String comment = '',
  }) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.sessionContent(scheduleId)}/rating',
            data: {'stars': stars, 'comment': comment},
          ));

  Future<Map<String, dynamic>> createSessionQuestion(
    String scheduleId,
    String question,
  ) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.sessionContent(scheduleId)}/questions',
            data: {'question': question},
          ));

  Future<Map<String, dynamic>> deleteSessionQuestion(
    String scheduleId,
    String questionId,
  ) =>
      _sessionContentCall(
        () => _dio.delete(
          '${ApiConfig.sessionContent(scheduleId)}/questions/$questionId',
        ),
      );

  /// Speaker edits a poll. Pass [options] only when changing them (allowed
  /// while nobody has voted).
  Future<Map<String, dynamic>> updateSessionPoll(
    String scheduleId,
    String pollId, {
    required String question,
    List<String>? options,
  }) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.sessionContent(scheduleId)}/polls/$pollId',
            data: {'question': question, if (options != null) 'options': options},
          ));

  /// Speaker edits a question (allowed until someone answers it).
  Future<Map<String, dynamic>> updateSessionQuestion(
    String scheduleId,
    String questionId,
    String question,
  ) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.sessionContent(scheduleId)}/questions/$questionId',
            data: {'question': question},
          ));

  /// Every speaker's session poll, with this participant's own vote.
  Future<Map<String, dynamic>> getAllSessionPolls() => _sessionContentCall(
        () => _dio.get('${ApiConfig.speakerQuestions}/session-polls'),
      );

  /// Management: all session questions with every participant's answer.
  Future<Map<String, dynamic>> getAllQuestionsForManagement() =>
      _sessionContentCall(
        () => _dio.get('${ApiConfig.engagement}/session-questions'),
      );

  /// Management: all session polls with vote counts.
  Future<Map<String, dynamic>> getAllPollsForManagement() => _sessionContentCall(
        () => _dio.get('${ApiConfig.engagement}/session-polls'),
      );

  /// Management: participants' questions to speakers and the answers.
  Future<Map<String, dynamic>> getSpeakerQuestionsForManagement() =>
      _sessionContentCall(
        () => _dio.get('${ApiConfig.engagement}/speaker-questions'),
      );

  /// Speakers a participant can ask a question (A–Z).
  Future<Map<String, dynamic>> listAskableSpeakers() => _sessionContentCall(
        () => _dio.get('${ApiConfig.speakerQuestions}/speakers'),
      );

  /// Participant asks [speakerId] a question.
  Future<Map<String, dynamic>> askSpeakerQuestion(
    String speakerId,
    String question,
  ) =>
      _sessionContentCall(() => _dio.post(
            ApiConfig.speakerQuestions,
            data: {'speakerId': speakerId, 'question': question},
          ));

  /// The participant's own questions to speakers, with any answers.
  Future<Map<String, dynamic>> getMySpeakerQuestions() => _sessionContentCall(
        () => _dio.get('${ApiConfig.speakerQuestions}/mine'),
      );

  /// Published speaker questions and the current answer, for every participant.
  Future<Map<String, dynamic>> getPublicSpeakerQuestions() =>
      _sessionContentCall(
        () => _dio.get('${ApiConfig.speakerQuestions}/public'),
      );

  /// Management writes or updates the answer on a participant's speaker question.
  Future<Map<String, dynamic>> answerSpeakerQuestionAsAdmin(
    String questionId,
    String answer,
  ) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.speakerQuestions}/$questionId/answer',
            data: {'answer': answer},
          ));

  /// Management shows or hides that question and answer on the participant Q/A.
  Future<Map<String, dynamic>> setSpeakerQuestionPublic(
    String questionId,
    bool isPublic,
  ) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.speakerQuestions}/$questionId/public',
            data: {'isPublic': isPublic},
          ));

  /// Every speaker's session question, with this participant's own answer.
  Future<Map<String, dynamic>> getAllSessionQuestions() => _sessionContentCall(
        () => _dio.get('${ApiConfig.speakerQuestions}/session-questions'),
      );

  /// Speaker: questions participants asked them.
  Future<Map<String, dynamic>> getSpeakerInbox() => _sessionContentCall(
        () => _dio.get('${ApiConfig.speakerQuestions}/inbox'),
      );

  /// Speaker answers a participant's question (one time).
  Future<Map<String, dynamic>> answerParticipantQuestion(
    String questionId,
    String answer,
  ) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.speakerQuestions}/$questionId/answer',
            data: {'answer': answer},
          ));

  Future<Map<String, dynamic>> answerSessionQuestion(
    String scheduleId,
    String questionId,
    String text,
  ) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.sessionContent(scheduleId)}/questions/$questionId/answer',
            data: {'text': text},
          ));

  // ---- Speakers (added on the management Speakers page) ----

  Future<Map<String, dynamic>> listSpeakers() =>
      _sessionContentCall(() => _dio.get(ApiConfig.speakers));

  Future<Map<String, dynamic>> createSpeaker({required String name}) =>
      _sessionContentCall(() => _dio.post(
            ApiConfig.speakers,
            data: {'name': name},
          ));

  /// Admin renames a speaker. Mobile and password already stored are kept.
  Future<Map<String, dynamic>> updateSpeaker({
    required String id,
    required String name,
  }) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.speakers}/$id',
            data: {'name': name},
          ));

  /// Show or hide this speaker on the participant Ask a Speaker list.
  Future<Map<String, dynamic>> setSpeakerAskEnabled(String id, bool askEnabled) =>
      _sessionContentCall(() => _dio.patch(
            '${ApiConfig.speakers}/$id',
            data: {'askEnabled': askEnabled},
          ));

  /// Help & Support tickets: a participant's own, or all for staff/admin.
  Future<Map<String, dynamic>> listHelpTickets() =>
      _sessionContentCall(() => _dio.get(ApiConfig.helpTickets));

  /// Participant raises a ticket; [category] is emergency / medical / others / app.
  Future<Map<String, dynamic>> createHelpTicket({
    required String category,
    required String description,
  }) =>
      _sessionContentCall(() => _dio.post(
            ApiConfig.helpTickets,
            data: {'category': category, 'description': description},
          ));

  /// One ticket with its chat messages.
  Future<Map<String, dynamic>> getHelpTicket(String ticketId) =>
      _sessionContentCall(() => _dio.get('${ApiConfig.helpTickets}/$ticketId'));

  /// Event staff / admin close a ticket (the participant can then only read it).
  Future<Map<String, dynamic>> closeHelpTicket(String ticketId) =>
      _sessionContentCall(() => _dio.post('${ApiConfig.helpTickets}/$ticketId/close'));

  /// Adds a chat message to a ticket.
  Future<Map<String, dynamic>> sendHelpMessage(String ticketId, String text) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.helpTickets}/$ticketId/messages',
            data: {'text': text},
          ));

  /// The sender edits one of their own chat messages.
  Future<Map<String, dynamic>> editHelpMessage(
    String ticketId,
    String messageId,
    String text,
  ) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.helpTickets}/$ticketId/messages/$messageId',
            data: {'text': text},
          ));

  /// The participant edits their own open ticket's category and description.
  Future<Map<String, dynamic>> updateHelpTicket({
    required String ticketId,
    required String category,
    required String description,
  }) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.helpTickets}/$ticketId',
            data: {'category': category, 'description': description},
          ));

  /// Deletes a ticket: the participant's own, or any ticket for staff/admin.
  Future<Map<String, dynamic>> deleteHelpTicket(String ticketId) =>
      _sessionContentCall(() => _dio.delete('${ApiConfig.helpTickets}/$ticketId'));

  /// Event staff / admin scan a participant's entry or exit for today.
  Future<Map<String, dynamic>> scanAttendance({
    required String type,
    String? qrData,
    String? idNumber,
  }) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.certificates}/scan',
            data: {
              'type': type,
              if (qrData != null) 'qrData': qrData,
              if (idNumber != null) 'idNumber': idNumber,
            },
          ));

  /// Participant: day-by-day entry/exit progress and whether the certificate is open.
  Future<Map<String, dynamic>> getMyCertificate() =>
      _sessionContentCall(() => _dio.get('${ApiConfig.certificates}/me'));

  /// Admin: every participant with their certificate status.
  Future<Map<String, dynamic>> listCertificates() =>
      _sessionContentCall(() => _dio.get(ApiConfig.certificates));

  /// Admin unlocks the certificates of the selected participants.
  Future<Map<String, dynamic>> unlockCertificates(List<String> registrationIds) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.certificates}/unlock',
            data: {'registrationIds': registrationIds},
          ));

  /// Admin locks the selected certificates again (admin-unlocked or earned by scans).
  Future<Map<String, dynamic>> revertCertificates(List<String> registrationIds) =>
      _sessionContentCall(() => _dio.post(
            '${ApiConfig.certificates}/revert',
            data: {'registrationIds': registrationIds},
          ));

  /// Award winners: {winners: {"<awardNumber>": {registrationId, name}}}.
  Future<Map<String, dynamic>> getAwardWinners() =>
      _sessionContentCall(() => _dio.get(ApiConfig.awards));

  /// Admin sets an award's winner; an empty id removes it.
  Future<Map<String, dynamic>> setAwardWinner(int awardNumber, String registrationId) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.awards}/$awardNumber',
            data: {'registrationId': registrationId},
          ));

  /// The programme PDF on Cloudinary: {url, fileName, updatedAt}. url is '' until uploaded.
  Future<Map<String, dynamic>> getSchedulePdf() =>
      _sessionContentCall(() => _dio.get(ApiConfig.schedulePdf));

  /// Downloads the schedule PDF from its Cloudinary URL.
  Future<Uint8List> downloadSchedulePdf() async {
    final meta = await getSchedulePdf();
    if (meta['success'] != true) {
      throw Exception(meta['error']?.toString() ?? 'Could not load the schedule');
    }
    final url = meta['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('No schedule PDF has been uploaded yet');
    }
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('Schedule PDF is empty');
  }

  /// Admin replaces the programme PDF participants see when they open Schedule.
  Future<Map<String, dynamic>> uploadSchedulePdf(String filePath) =>
      _sessionContentCall(() async => _dio.post(
            ApiConfig.schedulePdf,
            data: FormData.fromMap({
              'pdf': await MultipartFile.fromFile(
                filePath,
                filename: filePath.split(Platform.pathSeparator).last,
              ),
            }),
          ));

  /// The UG paper / e-poster PDF on Cloudinary. url is '' until an admin uploads one.
  Future<Map<String, dynamic>> getUgPaperPdf() =>
      _sessionContentCall(() => _dio.get(ApiConfig.ugPaperPdf));

  /// Downloads the presentation PDF from its Cloudinary URL.
  Future<Uint8List> downloadUgPaperPdf() async {
    final meta = await getUgPaperPdf();
    if (meta['success'] != true) {
      throw Exception(meta['error']?.toString() ?? 'Could not load the presentation');
    }
    final url = meta['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('No presentation PDF has been uploaded yet');
    }
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('Presentation PDF is empty');
  }

  /// Admin replaces the presentation PDF shown on the participant home.
  Future<Map<String, dynamic>> uploadUgPaperPdf(String filePath) =>
      _sessionContentCall(() async => _dio.post(
            ApiConfig.ugPaperPdf,
            data: FormData.fromMap({
              'pdf': await MultipartFile.fromFile(
                filePath,
                filename: filePath.split(Platform.pathSeparator).last,
              ),
            }),
          ));

  /// The preconference PDF on Cloudinary. url is '' until an admin uploads one.
  Future<Map<String, dynamic>> getPreconferencePdf() =>
      _sessionContentCall(() => _dio.get(ApiConfig.preconferencePdf));

  /// Downloads the preconference PDF from its Cloudinary URL.
  Future<Uint8List> downloadPreconferencePdf() async {
    final meta = await getPreconferencePdf();
    if (meta['success'] != true) {
      throw Exception(meta['error']?.toString() ?? 'Could not load the preconference PDF');
    }
    final url = meta['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('No preconference PDF has been uploaded yet');
    }
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('Preconference PDF is empty');
  }

  /// Admin replaces the preconference PDF participants open from View PDF.
  Future<Map<String, dynamic>> uploadPreconferencePdf(String filePath) =>
      _sessionContentCall(() async => _dio.post(
            ApiConfig.preconferencePdf,
            data: FormData.fromMap({
              'pdf': await MultipartFile.fromFile(
                filePath,
                filename: filePath.split(Platform.pathSeparator).last,
              ),
            }),
          ));

  /// The hall arrangement PDF on Cloudinary. url is '' until an admin uploads one.
  Future<Map<String, dynamic>> getHallArrangementPdf() =>
      _sessionContentCall(() => _dio.get(ApiConfig.hallArrangementPdf));

  /// Downloads the hall arrangement PDF from its Cloudinary URL.
  Future<Uint8List> downloadHallArrangementPdf() async {
    final meta = await getHallArrangementPdf();
    if (meta['success'] != true) {
      throw Exception(meta['error']?.toString() ?? 'Could not load the hall arrangement');
    }
    final url = meta['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('No hall arrangement PDF has been uploaded yet');
    }
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('Hall arrangement PDF is empty');
  }

  /// Admin replaces the hall arrangement PDF participants open from More.
  Future<Map<String, dynamic>> uploadHallArrangementPdf(String filePath) =>
      _sessionContentCall(() async => _dio.post(
            ApiConfig.hallArrangementPdf,
            data: FormData.fromMap({
              'pdf': await MultipartFile.fromFile(
                filePath,
                filename: filePath.split(Platform.pathSeparator).last,
              ),
            }),
          ));

  /// The paper and poster PDF on Cloudinary. url is '' until an admin uploads one.
  Future<Map<String, dynamic>> getPaperPosterPdf() =>
      _sessionContentCall(() => _dio.get(ApiConfig.paperPosterPdf));

  /// Downloads the paper and poster PDF from its Cloudinary URL.
  Future<Uint8List> downloadPaperPosterPdf() async {
    final meta = await getPaperPosterPdf();
    if (meta['success'] != true) {
      throw Exception(meta['error']?.toString() ?? 'Could not load the presentation');
    }
    final url = meta['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('No presentation PDF has been uploaded yet');
    }
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('Presentation PDF is empty');
  }

  /// Admin replaces the paper and poster PDF participants open from the home grid.
  Future<Map<String, dynamic>> uploadPaperPosterPdf(String filePath) =>
      _sessionContentCall(() async => _dio.post(
            ApiConfig.paperPosterPdf,
            data: FormData.fromMap({
              'pdf': await MultipartFile.fromFile(
                filePath,
                filename: filePath.split(Platform.pathSeparator).last,
              ),
            }),
          ));

  /// The admin's YouTube live link: {url} ('' when none is set).
  Future<Map<String, dynamic>> getYoutubeLive() =>
      _sessionContentCall(() => _dio.get(ApiConfig.youtubeLive));

  /// Admin sets the YouTube live link; an empty url removes it.
  Future<Map<String, dynamic>> setYoutubeLive(String url) =>
      _sessionContentCall(() => _dio.put(ApiConfig.youtubeLive, data: {'url': url}));

  /// The admin's Live Photo link: {url} ('' when none is set).
  Future<Map<String, dynamic>> getLivePhoto() =>
      _sessionContentCall(() => _dio.get(ApiConfig.livePhoto));

  /// Admin sets the Live Photo link; an empty url removes it.
  Future<Map<String, dynamic>> setLivePhoto(String url) =>
      _sessionContentCall(() => _dio.put(ApiConfig.livePhoto, data: {'url': url}));

  /// The home-screen news ticker: {enabled, text} (one message per line).
  Future<Map<String, dynamic>> getNewsTicker() =>
      _sessionContentCall(() => _dio.get(ApiConfig.newsTicker));

  /// Admin switches the ticker on/off and/or changes its text.
  Future<Map<String, dynamic>> updateNewsTicker({bool? enabled, String? text}) =>
      _sessionContentCall(() => _dio.put(
            ApiConfig.newsTicker,
            data: {
              if (enabled != null) 'enabled': enabled,
              if (text != null) 'text': text,
            },
          ));

  /// The participant-home image banner: {enabled, images: [{id, url}]}.
  Future<Map<String, dynamic>> getHomeBanner() =>
      _sessionContentCall(() => _dio.get(ApiConfig.homeBanner));

  /// Admin switches the whole banner on or off.
  Future<Map<String, dynamic>> setHomeBannerEnabled(bool enabled) =>
      _sessionContentCall(
        () => _dio.put(ApiConfig.homeBanner, data: {'enabled': enabled}),
      );

  /// Admin adds one banner image.
  Future<Map<String, dynamic>> addHomeBannerImage(String imagePath) =>
      _sessionContentCall(() async => _dio.post(
            '${ApiConfig.homeBanner}/images',
            data: FormData.fromMap({
              'image': await MultipartFile.fromFile(imagePath, filename: 'banner.jpg'),
            }),
          ));

  /// Admin removes one banner image.
  Future<Map<String, dynamic>> deleteHomeBannerImage(String imageId) =>
      _sessionContentCall(
        () => _dio.delete('${ApiConfig.homeBanner}/images/$imageId'),
      );

  /// The property's exhibitors (any login), newest first.
  Future<Map<String, dynamic>> listExhibitors() =>
      _sessionContentCall(() => _dio.get(ApiConfig.exhibitors));

  /// Admin adds an exhibitor; [photoPath] is optional.
  Future<Map<String, dynamic>> createExhibitor({
    required String shopName,
    required String category,
    required String location,
    String? photoPath,
  }) =>
      _sessionContentCall(() async => _dio.post(
            ApiConfig.exhibitors,
            data: FormData.fromMap({
              'shopName': shopName,
              'category': category,
              'location': location,
              if (photoPath != null)
                'photo':
                    await MultipartFile.fromFile(photoPath, filename: 'exhibitor.jpg'),
            }),
          ));

  Future<Map<String, dynamic>> deleteExhibitor(String exhibitorId) =>
      _sessionContentCall(() => _dio.delete('${ApiConfig.exhibitors}/$exhibitorId'));

  /// Pre-conference courses (any login), ordered by S No.
  Future<Map<String, dynamic>> listPreconference() =>
      _sessionContentCall(() => _dio.get(ApiConfig.preconference));

  Future<Map<String, dynamic>> createPreconference({
    required int serialNo,
    required String date,
    required String course,
    required String venue,
  }) =>
      _sessionContentCall(() => _dio.post(
            ApiConfig.preconference,
            data: {
              'serialNo': serialNo,
              'date': date,
              'course': course,
              'venue': venue,
            },
          ));

  Future<Map<String, dynamic>> updatePreconference(
    String id, {
    required int serialNo,
    required String date,
    required String course,
    required String venue,
  }) =>
      _sessionContentCall(() => _dio.put(
            '${ApiConfig.preconference}/$id',
            data: {
              'serialNo': serialNo,
              'date': date,
              'course': course,
              'venue': venue,
            },
          ));

  Future<Map<String, dynamic>> deletePreconference(String id) =>
      _sessionContentCall(() => _dio.delete('${ApiConfig.preconference}/$id'));

  Future<Map<String, dynamic>> deleteSpeaker(String speakerId) =>
      _sessionContentCall(() => _dio.delete('${ApiConfig.speakers}/$speakerId'));

  Future<Map<String, dynamic>> createEventSchedule({
    required String eventId,
    required String speakerId, // picked from the Speakers list
    // Event package ids whose participants see this schedule.
    required List<String> packageIds,
    required String scheduleName,
    String hall = '',
    // One entry per date: {date: yyyy-MM-dd, fromTime: HH:mm, toTime: HH:mm}
    required List<Map<String, String>> slots,
    String description = '',
  }) async {
    try {
      final formData = FormData.fromMap({
        'speakerId': speakerId,
        'packageIds': jsonEncode(packageIds),
        'scheduleName': scheduleName,
        'hall': hall,
        'slots': jsonEncode(slots),
        'description': description,
      });
      final response = await _dio.post(
        ApiConfig.managedEventSchedules(eventId),
        data: formData,
      );
      return {
        'success': response.data['success'] == true,
        'schedule': response.data['schedule'],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  /// Admin edits one schedule row. [slot] is {date: yyyy-MM-dd, fromTime, toTime}.
  Future<Map<String, dynamic>> updateEventSchedule({
    required String eventId,
    required String scheduleId,
    required String speakerId,
    required List<String> packageIds,
    required String scheduleName,
    String hall = '',
    required Map<String, String> slot,
    String description = '',
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.managedEventSchedules(eventId)}/$scheduleId',
        data: {
          'speakerId': speakerId,
          'packageIds': packageIds,
          'scheduleName': scheduleName,
          'hall': hall,
          ...slot,
          'description': description,
        },
      );
      return {
        'success': response.data['success'] == true,
        'schedule': response.data['schedule'],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> deleteEventSchedule(String eventId, String scheduleId) async {
    try {
      final response =
          await _dio.delete('${ApiConfig.managedEventSchedules(eventId)}/$scheduleId');
      return {
        'success': response.data['success'] == true,
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  /// Management re-registers a fresh claim for an inclusion (e.g. after a
  /// mis-scan) — the original claim stays in history, tagged reclaimedByAdmin.
  Future<Map<String, dynamic>> reclaimInclusion({
    required String eventId,
    required String regId,
    required String claimId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.managedEventReclaimInclusion(eventId, regId, claimId),
      );
      return {
        'success': response.data['success'] == true,
        'registration': response.data['registration'],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  /// Every participant selfie posted to the feed, newest first.
  Future<Map<String, dynamic>> listFeedPosts() async {
    try {
      final response = await _dio.get(ApiConfig.feedPostsBase);
      return {
        'success': response.data['success'] == true,
        'posts': response.data['posts'] ?? [],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  /// Posts a selfie (with the event banner baked in) to the participant feed.
  /// The participant's hearted schedules: {success, scheduleIds, schedules, events}.
  Future<Map<String, dynamic>> getMyFavorites() => _sessionContentCall(
        () => _dio.get(ApiConfig.managedEventMyFavorites),
      );

  /// Hearts a schedule, or removes it from favorites if already hearted.
  /// Returns {success, favorite, scheduleIds}.
  Future<Map<String, dynamic>> toggleFavoriteSchedule(String scheduleId) =>
      _sessionContentCall(
        () => _dio.post(ApiConfig.managedEventToggleFavorite(scheduleId)),
      );

  /// Ids of the schedules this participant set a start reminder for.
  Future<Map<String, dynamic>> getMyReminders() =>
      _sessionContentCall(() => _dio.get(ApiConfig.managedEventMyReminders));

  /// Turns the start reminder for [scheduleId] on/off. Returns {success, reminder}.
  Future<Map<String, dynamic>> toggleScheduleReminder(String scheduleId) =>
      _sessionContentCall(
        () => _dio.post(ApiConfig.managedEventToggleReminder(scheduleId)),
      );

  /// Sets when to be reminded about a session: [minutesBefore] its start
  /// (0 = at the start), or turns the reminder off when [minutesBefore] is null.
  Future<Map<String, dynamic>> setScheduleReminder(
    String scheduleId,
    int? minutesBefore,
  ) =>
      _sessionContentCall(
        () => _dio.post(
          ApiConfig.managedEventToggleReminder(scheduleId),
          data: minutesBefore == null
              ? {'remove': true}
              : {'minutesBefore': minutesBefore},
        ),
      );

  /// Likes a feed post, or removes the like if already liked.
  /// Returns {success, liked, likeCount}.
  Future<Map<String, dynamic>> toggleFeedPostLike(String postId) =>
      _sessionContentCall(
        () => _dio.post('${ApiConfig.feedPostsBase}/$postId/like'),
      );

  /// Deletes one of the logged-in participant's own feed posts.
  Future<Map<String, dynamic>> deleteFeedPost(String postId) =>
      _sessionContentCall(
        () => _dio.delete('${ApiConfig.feedPostsBase}/$postId'),
      );

  Future<Map<String, dynamic>> createFeedPost(String imagePath) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(imagePath, filename: 'selfie.png'),
      });
      final response = await _dio.post(ApiConfig.feedPostsBase, data: formData);
      return {
        'success': response.data['success'] == true,
        'post': response.data['post'],
        'error': response.data['error'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> listManagedEvents({String? apartmentId}) async {
    try {
      final response = await _dio.get(
        ApiConfig.managedEventsList,
        queryParameters: apartmentId != null && apartmentId.isNotEmpty
            ? {'apartmentId': apartmentId}
            : null,
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'events': response.data['events'] ?? [],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Scan overview (registered / scanned / not scanned / rejected + who rejected).
  Future<Map<String, dynamic>> getClaimSummary({String? eventId, String? apartmentId, String? date}) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.managedEventsList}/summary',
        queryParameters: {
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
          if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
          if (date != null && date.isNotEmpty) 'date': date,
        },
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200) {
        return {'success': true, 'summary': response.data['summary']};
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// The logged-in participant's own registration (ticket, package, claimed inclusions).
  Future<Map<String, dynamic>> getMyRegistration() async {
    try {
      final response = await _dio.get('${ApiConfig.managedEventsList}/my-registration');
      if (response.statusCode == 200) {
        return {
          'success': true,
          'registration': response.data['registration'],
          'availableInclusions': response.data['availableInclusions'] ?? [],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createManagedEvent({
    required String title,
    String description = '',
    String venue = '',
    required DateTime eventDate,
    DateTime? eventEndDate,
    String? apartmentId,
    String? photoPath,
  }) async {
    try {
      final map = <String, dynamic>{
        'title': title,
        'description': description,
        'venue': venue,
        'eventDate': eventDate.toUtc().toIso8601String(),
        if (eventEndDate != null) 'eventEndDate': eventEndDate.toUtc().toIso8601String(),
        if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
      };
      dynamic requestData;
      if (photoPath != null && photoPath.isNotEmpty) {
        final formMap = Map<String, dynamic>.from(map);
        formMap['photo'] = await MultipartFile.fromFile(photoPath);
        requestData = FormData.fromMap(formMap);
      } else {
        requestData = map;
      }
      final response = await _dio.post(
        ApiConfig.managedEventsCreate,
        data: requestData,
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'event': response.data['event'],
          'registerPath': response.data['registerPath'],
          'message': response.data['message'],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateManagedEvent({
    required String eventId,
    String? title,
    String? description,
    String? venue,
    DateTime? eventDate,
    DateTime? eventEndDate,
    bool clearEventEndDate = false,
    int? totalSlots,
    bool? isActive,
    String? status,
    List<Map<String, dynamic>>? formQuestions,
    List<Map<String, dynamic>>? packages,
    String? apartmentId,
    String? photoPath,
    bool clearPhoto = false,
  }) async {
    try {
      final data = <String, dynamic>{
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (venue != null) 'venue': venue,
        if (eventDate != null) 'eventDate': eventDate.toUtc().toIso8601String(),
        if (eventEndDate != null) 'eventEndDate': eventEndDate.toUtc().toIso8601String(),
        if (clearEventEndDate) 'eventEndDate': null,
        if (totalSlots != null) 'totalSlots': totalSlots,
        if (isActive != null) 'isActive': isActive,
        if (status != null) 'status': status,
        if (formQuestions != null) 'formQuestions': formQuestions,
        if (packages != null) 'packages': packages,
        if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
        if (clearPhoto) 'clearPhoto': 'true',
      };
      dynamic requestData;
      if (photoPath != null && photoPath.isNotEmpty) {
        final formMap = Map<String, dynamic>.from(data);
        formMap['photo'] = await MultipartFile.fromFile(photoPath);
        requestData = FormData.fromMap(formMap);
      } else {
        requestData = data;
      }
      final response = await _dio.put(
        ApiConfig.managedEventById(eventId),
        data: requestData,
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200 && response.data['success'] != false) {
        return {
          'success': true,
          'event': response.data['event'],
          'message': response.data['message'],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> listManagedEventRegistrations(
    String eventId, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.managedEventRegistrations(eventId),
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'registrations': response.data['registrations'] ?? [],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<FormData> _participantFormData(Map<String, String> fields, String? photoPath) async {
    final map = <String, dynamic>{...fields};
    if (photoPath != null && photoPath.isNotEmpty) {
      map['photo'] = await MultipartFile.fromFile(photoPath);
    }
    return FormData.fromMap(map);
  }

  /// Management-created participant registration with the full profile (multipart, optional photo).
  Future<Map<String, dynamic>> createSpotRegistration({
    required String eventId,
    required Map<String, String> fields,
    String? photoPath,
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.managedEventRegistrationSpot(eventId),
        data: await _participantFormData(fields, photoPath),
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'registration': response.data['registration'],
          'message': response.data['message'],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Edits a participant's profile (multipart, optional new photo).
  Future<Map<String, dynamic>> updateEventRegistration({
    required String eventId,
    required String registrationId,
    required Map<String, String> fields,
    String? photoPath,
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.put(
        ApiConfig.managedEventRegistrationById(eventId, registrationId),
        data: await _participantFormData(fields, photoPath),
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200 && response.data['success'] != false) {
        return {
          'success': true,
          'registration': response.data['registration'],
          'message': response.data['message'],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Deletes a participant registration (mirrors web `deleteRegistration`).
  Future<Map<String, dynamic>> deleteEventRegistration({
    required String eventId,
    required String registrationId,
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.delete(
        ApiConfig.managedEventRegistrationById(eventId, registrationId),
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200 && response.data['success'] != false) {
        return {'success': true, 'message': response.data['message']};
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Bulk-imports "Name, Institution, PackageId" lines (mirrors web `bulkImportRegistrations`).
  Future<Map<String, dynamic>> bulkImportEventRegistrations({
    required String eventId,
    required String text,
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.managedEventRegistrationBulk(eventId),
        data: {'text': text},
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'registrations': response.data['registrations'] ?? [],
          'failed': response.data['failed'] ?? [],
          'message': response.data['message'],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getManagedEvent(
    String eventId, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.managedEventById(eventId),
        queryParameters: apartmentId != null && apartmentId.isNotEmpty
            ? {'apartmentId': apartmentId}
            : null,
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200) {
        return {'success': true, 'event': response.data['event']};
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Claims an event package "inclusion" (e.g. Breakfast, Lunch) for a
  /// registered participant, identified via a scanned QR payload or a
  /// manually entered ID number (e.g. ID1001 or 1001). Mirrors the web management
  /// "Scan & Claim" flow (POST /managed-events/claim-inclusion).
  Future<Map<String, dynamic>> claimInclusion({
    required String inclusionName,
    String? packageId,
    String? qrData,
    String? idNumber,
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.managedEventClaimInclusion,
        data: {
          'inclusionName': inclusionName,
          if (packageId != null && packageId.isNotEmpty) 'packageId': packageId,
          if (qrData != null) 'qrData': qrData,
          if (idNumber != null) 'idNumber': idNumber,
        },
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'alreadyClaimed': false,
          'message': response.data['message'],
          'registration': response.data['registration'],
        };
      }
      return {
        'success': false,
        'alreadyClaimed': response.data['alreadyClaimed'] == true,
        'error': response.data['error'] ?? 'Failed to claim inclusion',
        'registration': response.data['registration'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'alreadyClaimed': data is Map && data['alreadyClaimed'] == true,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
        'registration': data is Map ? data['registration'] : null,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Permanently deletes an event together with all of its registrations.
  Future<Map<String, dynamic>> deleteManagedEventPermanently(
    String eventId, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.delete(
        ApiConfig.managedEventById(eventId),
        queryParameters: {'permanent': 'true'},
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'error': (data is Map ? data['error'] : null) ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelManagedEvent(
    String eventId, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.delete(
        ApiConfig.managedEventById(eventId),
        options: apartmentId != null && apartmentId.isNotEmpty
            ? Options(headers: {'X-Apartment-Id': apartmentId})
            : null,
      );
      if (response.statusCode == 200) {
        return {'success': true, 'event': response.data['event']};
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyEventTicketQr({
    String? registrationId,
    String? otp,
    String? idNumber,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.managedEventVerifyQr,
        data: {
          if (registrationId != null) 'registrationId': registrationId,
          if (otp != null) 'otp': otp,
          if (idNumber != null) 'idNumber': idNumber,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'],
          'alreadyCheckedIn': response.data['alreadyCheckedIn'] == true,
          'registration': response.data['registration'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Verification failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMyEventTickets({String? mobile}) async {
    try {
      final response = await _dio.get(
        ApiConfig.managedEventMyTickets,
        queryParameters:
            mobile != null && mobile.isNotEmpty ? {'mobile': mobile} : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'tickets': response.data['tickets'] ?? [],
        };
      }
      return {'success': false, 'error': response.data['error'] ?? 'Failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create block (optionally for apartmentId)
  Future<Map<String, dynamic>> createBlock(String name, {String? apartmentId}) async {
    try {
      final data = <String, dynamic>{'name': name};
      if (apartmentId != null && apartmentId.isNotEmpty) {
        data['apartmentId'] = apartmentId;
      }
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.post(
        ApiConfig.createBlock,
        data: data,
        options: headers != null ? Options(headers: headers) : null,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'block': response.data['block'],
          'message': response.data['message'] ?? 'Block created successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create block',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Add floor to block
  Future<Map<String, dynamic>> addFloor({
    required String blockId,
    required String floorNumber,
    required List<Map<String, dynamic>>
        roomConfigurations, // [{type: '1BHK', count: 4}, {type: '2BHK', count: 2}]
    String? roomNumber, // Optional specific room number for single room
  }) async {
    try {
      // Generate rooms based on configurations
      final rooms = <Map<String, dynamic>>[];
      int roomIndex = 1;

      for (final config in roomConfigurations) {
        final roomType = config['type'] as String;
        final roomCount = config['count'] as int;

        for (int i = 0; i < roomCount; i++) {
          // Use provided room number if available and it's the first room, otherwise auto-generate
          final number = (roomNumber != null &&
                  roomNumber.isNotEmpty &&
                  i == 0 &&
                  roomCount == 1)
              ? roomNumber
              : '$floorNumber${roomIndex.toString().padLeft(2, '0')}';
          final roomData = <String, dynamic>{'number': number, 'type': roomType};
          final beds = config['beds'];
          if (beds != null && (beds is int ? beds > 0 : int.tryParse(beds.toString()) != null)) {
            roomData['beds'] = beds is int ? beds : int.tryParse(beds.toString());
          }
          rooms.add(roomData);
          roomIndex++;
        }
      }

      final response = await _dio.post(
        '${ApiConfig.addFloor}/$blockId/floors',
        data: {
          'number': floorNumber,
          'rooms': rooms,
        },
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'block': response.data['block'],
          'message': response.data['message'] ?? 'Floor added successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to add floor',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Add room to floor
  Future<Map<String, dynamic>> addRoom({
    required String blockId,
    required String floorId,
    required String roomNumber,
    required String roomType,
    int? beds,
  }) async {
    try {
      final data = <String, dynamic>{'number': roomNumber, 'type': roomType};
      if (beds != null && beds > 0) data['beds'] = beds;
      final response = await _dio.post(
        '${ApiConfig.addRoom}/$blockId/floors/$floorId/rooms',
        data: data,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'block': response.data['block'],
          'message': response.data['message'] ?? 'Room added successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to add room',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete room
  Future<Map<String, dynamic>> deleteRoom({
    required String blockId,
    required String floorId,
    required String roomId,
  }) async {
    try {
      final response = await _dio.delete(
        '${ApiConfig.deleteRoom}/$blockId/floors/$floorId/rooms/$roomId',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'block': response.data['block'],
          'message': response.data['message'] ?? 'Room deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete room',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update room (number, type, or occupied)
  Future<Map<String, dynamic>> updateRoom({
    required String blockId,
    required String floorId,
    required String roomId,
    String? number,
    String? type,
    bool? isOccupied,
    int? beds,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (number != null) data['number'] = number;
      if (type != null) data['type'] = type;
      if (isOccupied != null) data['occupied'] = isOccupied;
      if (beds != null) data['beds'] = beds;

      final response = await _dio.put(
        '${ApiConfig.updateRoom}/$blockId/floors/$floorId/rooms/$roomId',
        data: data,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'block': response.data['block'],
          'message': response.data['message'] ?? 'Room updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update room',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Toggle user active status
  Future<Map<String, dynamic>> toggleUserActive(String userId) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.getAllUsers}/$userId/toggle-active',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'User status updated',
          'user': response.data['user'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update user status',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update block
  Future<Map<String, dynamic>> updateBlock(String blockId, String name) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.updateBlock}/$blockId',
        data: {'name': name},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Block updated successfully',
          'block': response.data['block'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update block',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete block
  Future<Map<String, dynamic>> deleteBlock(String blockId) async {
    try {
      final response = await _dio.delete(
        '${ApiConfig.deleteBlock}/$blockId',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Block deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete block',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update floor
  Future<Map<String, dynamic>> updateFloor({
    required String blockId,
    required String floorId,
    required String floorNumber,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.updateFloor}/$blockId/floors/$floorId',
        data: {'number': floorNumber},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Floor updated successfully',
          'block': response.data['block'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update floor',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete floor
  Future<Map<String, dynamic>> deleteFloor({
    required String blockId,
    required String floorId,
  }) async {
    try {
      final response = await _dio.delete(
        '${ApiConfig.deleteFloor}/$blockId/floors/$floorId',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Floor deleted successfully',
          'block': response.data['block'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete floor',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Toggle block active status
  Future<Map<String, dynamic>> toggleBlockActive(String blockId) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.toggleBlockActive}/$blockId/toggle-active',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Block status updated',
          'block': response.data['block'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update block status',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get all maintenance records
  Future<Map<String, dynamic>> getAllMaintenance({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.getAllMaintenance,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'maintenance': response.data['maintenance'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get maintenance list',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Cannot reach server at ${ApiConfig.baseUrl}. '
            'Check: (1) Backend is running (npm start), (2) Phone and PC on same Wi-Fi, (3) On physical device use your PC IP in API_BASE_URL.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get maintenance amount
  Future<Map<String, dynamic>> getMaintenance({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.getMaintenance,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'maintenance': response.data['maintenance'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get maintenance',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Cannot reach server at ${ApiConfig.baseUrl}. '
            'Check: (1) Backend is running (npm start), (2) Phone and PC on same Wi-Fi, (3) On physical device use your PC IP in API_BASE_URL.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Set maintenance amount
  Future<Map<String, dynamic>> setMaintenance({
    required double amount,
    String? month,
    int? year,
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.setMaintenance,
        data: {
          'amount': amount,
          'month': month,
          'year': year,
          if (apartmentId != null && apartmentId.isNotEmpty)
            'apartmentId': apartmentId,
        },
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message':
              response.data['message'] ?? 'Maintenance amount set successfully',
          'maintenance': response.data['maintenance'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to set maintenance',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update user status (approve/reject)
  Future<Map<String, dynamic>> updateUserStatus(
    String userId,
    String status, {
    String? block,
    String? floor,
    String? roomNumber,
    String? apartmentId,
  }) async {
    try {
      final data = {'status': status};
      if (block != null) data['block'] = block;
      if (floor != null) data['floor'] = floor;
      if (roomNumber != null) data['roomNumber'] = roomNumber;
      if (apartmentId != null) data['apartmentId'] = apartmentId;

      final response = await _dio.put(
        '${ApiConfig.updateUserStatus}/$userId/status',
        data: data,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'User status updated',
          'user': response.data['user'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update user status',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update resident user details
  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? name,
    String? username,
    String? email,
    String? mobileNumber,
    String? secondaryMobileNumber,
    String? gender,
    String? address,
    String? familyType,
    int? totalOccupants,
    String? aadhaarCard,
    String? panCard,
    bool? isNRI,
    String? department,
    String? employeeId,
    String? hostelRoom,
    String? hostelBed,
    String? occupationCategory,
    String? occupationDetails,
    String? dateOfBirth,
    String? password,
    File? profilePic,
    File? aadhaarFront,
    File? aadhaarBack,
    File? panCardImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (name != null && name.isNotEmpty) 'name': name,
        if (username != null && username.isNotEmpty) 'username': username,
        if (email != null && email.isNotEmpty) 'email': email,
        if (mobileNumber != null && mobileNumber.isNotEmpty) 'mobileNumber': mobileNumber,
        if (secondaryMobileNumber != null) 'secondaryMobileNumber': secondaryMobileNumber,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (address != null) 'address': address,
        if (familyType != null && familyType.isNotEmpty) 'familyType': familyType,
        if (totalOccupants != null) 'totalOccupants': totalOccupants.toString(),
        if (aadhaarCard != null) 'aadhaarCard': aadhaarCard,
        if (panCard != null) 'panCard': panCard,
        if (isNRI != null) 'isNRI': isNRI.toString(),
        if (department != null) 'department': department,
        if (employeeId != null) 'employeeId': employeeId,
        if (hostelRoom != null) 'hostelRoom': hostelRoom,
        if (hostelBed != null) 'hostelBed': hostelBed,
        if (occupationCategory != null && occupationCategory.isNotEmpty)
          'occupationCategory': occupationCategory,
        if (occupationDetails != null) 'occupationDetails': occupationDetails,
        if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
        if (password != null && password.isNotEmpty) 'password': password,
        if (profilePic != null)
          'profilePic': await MultipartFile.fromFile(
            profilePic.path,
            filename: 'profilePic.jpg',
          ),
        if (aadhaarFront != null)
          'aadhaarFront': await MultipartFile.fromFile(
            aadhaarFront.path,
            filename: 'aadhaarFront.jpg',
          ),
        if (aadhaarBack != null)
          'aadhaarBack': await MultipartFile.fromFile(
            aadhaarBack.path,
            filename: 'aadhaarBack.jpg',
          ),
        if (panCardImage != null)
          'panCard': await MultipartFile.fromFile(
            panCardImage.path,
            filename: 'panCard.jpg',
          ),
      });

      final response = await _dio.put(
        '${ApiConfig.updateUser}/$userId',
        data: formData,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': response.data['user'],
          'message': response.data['message'] ?? 'User updated successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Update failed',
      };
    } on DioException catch (e) {
      String errorMessage = 'Network error';
      if (e.response != null) {
        errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get all payments
  // Get payment statistics
  Future<Map<String, dynamic>> getSocietyOpsSummary({String? apartmentId}) async {
    try {
      final response = await _dio.get(
        ApiConfig.societyOpsSummary,
        queryParameters: {
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'summary': response.data['summary'] ?? const <String, dynamic>{},
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load society operations summary',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _fetchSocietyOpsList(
    String url, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.get(
        url,
        queryParameters: {
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
        },
      );
      if (response.statusCode == 200) {
        final raw = response.data['items'];
        final items = <Map<String, dynamic>>[];
        if (raw is List) {
          for (final e in raw) {
            if (e is Map<String, dynamic>) {
              items.add(e);
            } else if (e is Map) {
              items.add(Map<String, dynamic>.from(e));
            }
          }
        }
        return {'success': true, 'items': items};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load items',
        'items': <Map<String, dynamic>>[],
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg, 'items': <Map<String, dynamic>>[]};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'items': <Map<String, dynamic>>[]};
    }
  }

  Future<Map<String, dynamic>> listSocietyOpsFurniture({String? apartmentId}) =>
      _fetchSocietyOpsList(ApiConfig.societyOpsFurniture, apartmentId: apartmentId);

  Future<Map<String, dynamic>> listSocietyOpsLiftServices({String? apartmentId}) =>
      _fetchSocietyOpsList(ApiConfig.societyOpsLiftServices, apartmentId: apartmentId);

  Future<Map<String, dynamic>> listSocietyOpsLiftPayments({String? apartmentId}) =>
      _fetchSocietyOpsList(ApiConfig.societyOpsLiftPayments, apartmentId: apartmentId);

  Future<Map<String, dynamic>> listSocietyOpsAssets({String? apartmentId}) =>
      _fetchSocietyOpsList(ApiConfig.societyOpsAssets, apartmentId: apartmentId);

  Map<String, dynamic> _societyOpsApartmentBody(
    Map<String, dynamic> body,
    String? apartmentId,
  ) {
    final out = Map<String, dynamic>.from(body);
    if (apartmentId != null && apartmentId.isNotEmpty) {
      out['apartmentId'] = apartmentId;
    }
    return out;
  }

  Map<String, dynamic> _societyOpsScopedQuery(String? apartmentId) => {
        if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
      };

  Future<Map<String, dynamic>> _societyOpsPost(
    String url,
    Map<String, dynamic> body, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.post(
        url,
        data: _societyOpsApartmentBody(body, apartmentId),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'item': response.data['item'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _societyOpsPatch(
    String url,
    Map<String, dynamic> body, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.patch(
        url,
        data: body,
        queryParameters: _societyOpsScopedQuery(apartmentId),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'item': response.data['item'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _societyOpsDelete(
    String url, {
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.delete(
        url,
        queryParameters: _societyOpsScopedQuery(apartmentId),
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to delete',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createSocietyOpsFurniture({
    required String itemType,
    required String name,
    required int quantity,
    required int availableQuantity,
    String location = '',
    String status = 'available',
    String notes = '',
    String? apartmentId,
  }) =>
      _societyOpsPost(
        ApiConfig.societyOpsFurniture,
        {
          'itemType': itemType,
          'name': name,
          'quantity': quantity,
          'availableQuantity': availableQuantity,
          'location': location,
          'status': status,
          'notes': notes,
        },
        apartmentId: apartmentId,
      );

  Future<Map<String, dynamic>> updateSocietyOpsFurniture({
    required String id,
    String? itemType,
    String? name,
    int? quantity,
    int? availableQuantity,
    String? location,
    String? status,
    String? notes,
    String? apartmentId,
  }) {
    final body = <String, dynamic>{};
    if (itemType != null) body['itemType'] = itemType;
    if (name != null) body['name'] = name;
    if (quantity != null) body['quantity'] = quantity;
    if (availableQuantity != null) body['availableQuantity'] = availableQuantity;
    if (location != null) body['location'] = location;
    if (status != null) body['status'] = status;
    if (notes != null) body['notes'] = notes;
    return _societyOpsPatch(
      '${ApiConfig.societyOpsFurniture}/$id',
      body,
      apartmentId: apartmentId,
    );
  }

  Future<Map<String, dynamic>> deleteSocietyOpsFurniture({
    required String id,
    String? apartmentId,
  }) =>
      _societyOpsDelete(
        '${ApiConfig.societyOpsFurniture}/$id',
        apartmentId: apartmentId,
      );

  Future<Map<String, dynamic>> createSocietyOpsLiftService({
    required String title,
    String description = '',
    String vendorName = '',
    required DateTime serviceDate,
    DateTime? nextServiceDate,
    double cost = 0,
    String status = 'scheduled',
    String? apartmentId,
  }) =>
      _societyOpsPost(
        ApiConfig.societyOpsLiftServices,
        {
          'title': title,
          'description': description,
          'vendorName': vendorName,
          'serviceDate': serviceDate.toUtc().toIso8601String(),
          if (nextServiceDate != null)
            'nextServiceDate': nextServiceDate.toUtc().toIso8601String(),
          'cost': cost,
          'status': status,
        },
        apartmentId: apartmentId,
      );

  Future<Map<String, dynamic>> updateSocietyOpsLiftService({
    required String id,
    String? title,
    String? description,
    String? vendorName,
    DateTime? serviceDate,
    DateTime? nextServiceDate,
    double? cost,
    String? status,
    String? apartmentId,
  }) {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (vendorName != null) body['vendorName'] = vendorName;
    if (serviceDate != null) body['serviceDate'] = serviceDate.toUtc().toIso8601String();
    if (nextServiceDate != null) {
      body['nextServiceDate'] = nextServiceDate.toUtc().toIso8601String();
    }
    if (cost != null) body['cost'] = cost;
    if (status != null) body['status'] = status;
    return _societyOpsPatch(
      '${ApiConfig.societyOpsLiftServices}/$id',
      body,
      apartmentId: apartmentId,
    );
  }

  Future<Map<String, dynamic>> deleteSocietyOpsLiftService({
    required String id,
    String? apartmentId,
  }) =>
      _societyOpsDelete(
        '${ApiConfig.societyOpsLiftServices}/$id',
        apartmentId: apartmentId,
      );

  Future<Map<String, dynamic>> createSocietyOpsLiftPayment({
    required String vendorName,
    String description = '',
    required double amount,
    required DateTime dueDate,
    DateTime? paidDate,
    String status = 'pending',
    String? apartmentId,
  }) =>
      _societyOpsPost(
        ApiConfig.societyOpsLiftPayments,
        {
          'vendorName': vendorName,
          'description': description,
          'amount': amount,
          'dueDate': dueDate.toUtc().toIso8601String(),
          if (paidDate != null) 'paidDate': paidDate.toUtc().toIso8601String(),
          'status': status,
        },
        apartmentId: apartmentId,
      );

  Future<Map<String, dynamic>> updateSocietyOpsLiftPayment({
    required String id,
    String? vendorName,
    String? description,
    double? amount,
    DateTime? dueDate,
    DateTime? paidDate,
    String? status,
    String? apartmentId,
  }) {
    final body = <String, dynamic>{};
    if (vendorName != null) body['vendorName'] = vendorName;
    if (description != null) body['description'] = description;
    if (amount != null) body['amount'] = amount;
    if (dueDate != null) body['dueDate'] = dueDate.toUtc().toIso8601String();
    if (paidDate != null) body['paidDate'] = paidDate.toUtc().toIso8601String();
    if (status != null) body['status'] = status;
    return _societyOpsPatch(
      '${ApiConfig.societyOpsLiftPayments}/$id',
      body,
      apartmentId: apartmentId,
    );
  }

  Future<Map<String, dynamic>> deleteSocietyOpsLiftPayment({
    required String id,
    String? apartmentId,
  }) =>
      _societyOpsDelete(
        '${ApiConfig.societyOpsLiftPayments}/$id',
        apartmentId: apartmentId,
      );

  Future<Map<String, dynamic>> createSocietyOpsAsset({
    required String name,
    required String category,
    int quantity = 1,
    String location = '',
    String condition = 'good',
    DateTime? purchaseDate,
    String notes = '',
    String? apartmentId,
  }) =>
      _societyOpsPost(
        ApiConfig.societyOpsAssets,
        {
          'name': name,
          'category': category,
          'quantity': quantity,
          'location': location,
          'condition': condition,
          if (purchaseDate != null)
            'purchaseDate': purchaseDate.toUtc().toIso8601String(),
          'notes': notes,
        },
        apartmentId: apartmentId,
      );

  Future<Map<String, dynamic>> updateSocietyOpsAsset({
    required String id,
    String? name,
    String? category,
    int? quantity,
    String? location,
    String? condition,
    DateTime? purchaseDate,
    String? notes,
    String? apartmentId,
  }) {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (category != null) body['category'] = category;
    if (quantity != null) body['quantity'] = quantity;
    if (location != null) body['location'] = location;
    if (condition != null) body['condition'] = condition;
    if (purchaseDate != null) {
      body['purchaseDate'] = purchaseDate.toUtc().toIso8601String();
    }
    if (notes != null) body['notes'] = notes;
    return _societyOpsPatch(
      '${ApiConfig.societyOpsAssets}/$id',
      body,
      apartmentId: apartmentId,
    );
  }

  Future<Map<String, dynamic>> deleteSocietyOpsAsset({
    required String id,
    String? apartmentId,
  }) =>
      _societyOpsDelete(
        '${ApiConfig.societyOpsAssets}/$id',
        apartmentId: apartmentId,
      );

  // Subscription (admin plans, create order, verify, my, app-active). Optionally filter by apartmentId.
  // Get all notices
  Future<Map<String, dynamic>> getAllNotices({
    String? type,
    String? targetAudience,
    bool? isActive,
    String? apartmentId,
  }) async {
    // Get all events (notices with type='event')
    if (type == 'event') {
      type = 'event';
    }
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) queryParams['type'] = type;
      if (targetAudience != null) {
        queryParams['targetAudience'] = targetAudience;
      }
      if (isActive != null) queryParams['isActive'] = isActive.toString();
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }

      final response = await _dio.get(
        ApiConfig.getAllNotices,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'notices': response.data['notices'],
          'count': response.data['count'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get notices',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Create notice
  Future<Map<String, dynamic>> createNotice({
    required String title,
    required String content,
    String? subtitle,
    String? type,
    String? targetAudience,
    String? priority,
    String? expiryDate,
    String? eventDate,
    String? apartmentId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.createNotice,
        data: {
          'title': title,
          'subtitle': subtitle,
          'content': content,
          'type': type,
          'targetAudience': targetAudience,
          'priority': priority,
          'expiryDate': expiryDate,
          'eventDate': eventDate,
          'apartmentId': apartmentId,
        },
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Notice created successfully',
          'notice': response.data['notice'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create notice',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update notice
  Future<Map<String, dynamic>> updateNotice(
      String noticeId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.updateNotice}/$noticeId',
        data: data,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Notice updated successfully',
          'notice': response.data['notice'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update notice',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete notice
  Future<Map<String, dynamic>> deleteNotice(String noticeId) async {
    try {
      final response = await _dio.delete('${ApiConfig.deleteNotice}/$noticeId');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Notice deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete notice',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get ads
  Future<Map<String, dynamic>> getAds({String? apartmentId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }
      
      final response = await _dio.get(
        ApiConfig.getAds,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'ads': response.data['ads'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get ads',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Create ad
  Future<Map<String, dynamic>> createAd(
    File image, {
    int? displayOrder,
    required String apartmentId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          image.path,
          filename: 'ad_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'apartmentId': apartmentId,
        if (displayOrder != null) 'displayOrder': displayOrder.toString(),
      });

      final response = await _dio.post(
        ApiConfig.createAd,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Ad created successfully',
          'ad': response.data['ad'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create ad',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete ad
  Future<Map<String, dynamic>> deleteAd(String adId) async {
    try {
      final response = await _dio.delete('${ApiConfig.deleteAd}/$adId');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Ad deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete ad',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Posts (feed)
  Future<Map<String, dynamic>> getPosts({
    bool? createdByMe,
    String? block,
    String? floor,
    String? roomNumber,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (createdByMe == true) queryParams['createdByMe'] = 'true';
      if (block != null && block.isNotEmpty) queryParams['block'] = block;
      if (floor != null && floor.isNotEmpty) queryParams['floor'] = floor;
      if (roomNumber != null && roomNumber.isNotEmpty) queryParams['roomNumber'] = roomNumber;

      final response = await _dio.get(
        ApiConfig.getPosts,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'posts': response.data['posts'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get posts',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String description,
    String? link,
    String? block,
    String? floor,
    String? roomNumber,
    File? image,
  }) async {
    try {
      final formData = FormData.fromMap({
        'description': description.trim(),
        if (link != null && link.trim().isNotEmpty) 'link': link.trim(),
        if (block != null && block.trim().isNotEmpty) 'block': block.trim(),
        if (floor != null && floor.trim().isNotEmpty) 'floor': floor.trim(),
        if (roomNumber != null && roomNumber.trim().isNotEmpty) 'roomNumber': roomNumber.trim(),
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
      });

      final response = await _dio.post(
        ApiConfig.createPost,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Post created successfully',
          'post': response.data['post'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create post',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      final response = await _dio.delete(ApiConfig.deletePostUrl(postId));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Post deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete post',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Polls
  Future<Map<String, dynamic>> getPolls({
    bool? createdByMe,
    String? block,
    String? floor,
    String? roomNumber,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (createdByMe == true) queryParams['createdByMe'] = 'true';
      if (block != null && block.isNotEmpty) queryParams['block'] = block;
      if (floor != null && floor.isNotEmpty) queryParams['floor'] = floor;
      if (roomNumber != null && roomNumber.isNotEmpty) queryParams['roomNumber'] = roomNumber;

      final response = await _dio.get(
        ApiConfig.getPolls,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'polls': response.data['polls'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get polls',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createPoll({
    required String question,
    required List<String> options,
    String? block,
    String? floor,
    String? roomNumber,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.createPoll,
        data: {
          'question': question.trim(),
          'options': options,
          if (block != null && block.trim().isNotEmpty) 'block': block.trim(),
          if (floor != null && floor.trim().isNotEmpty) 'floor': floor.trim(),
          if (roomNumber != null && roomNumber.trim().isNotEmpty) 'roomNumber': roomNumber.trim(),
        },
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Poll created successfully',
          'poll': response.data['poll'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create poll',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> votePoll(String pollId, int optionIndex) async {
    try {
      final response = await _dio.post(
        ApiConfig.votePollUrl(pollId),
        data: {'optionIndex': optionIndex},
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Vote recorded',
          'poll': response.data['poll'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to vote',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePoll(String pollId) async {
    try {
      final response = await _dio.delete(ApiConfig.deletePollUrl(pollId));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Poll deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete poll',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Community events
  Future<Map<String, dynamic>> getCommunityEvents({
    bool? createdByMe,
    String? block,
    String? floor,
    String? roomNumber,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (createdByMe == true) queryParams['createdByMe'] = 'true';
      if (block != null && block.isNotEmpty) queryParams['block'] = block;
      if (floor != null && floor.isNotEmpty) queryParams['floor'] = floor;
      if (roomNumber != null && roomNumber.isNotEmpty) queryParams['roomNumber'] = roomNumber;

      final response = await _dio.get(
        ApiConfig.getCommunityEvents,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'events': response.data['events'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get events',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createCommunityEvent({
    required String title,
    required String description,
    required DateTime eventDate,
    String? venue,
    String? block,
    String? floor,
    String? roomNumber,
    File? image,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title.trim(),
        'description': description.trim(),
        'eventDate': eventDate.toIso8601String(),
        if (venue != null && venue.trim().isNotEmpty) 'venue': venue.trim(),
        if (block != null && block.trim().isNotEmpty) 'block': block.trim(),
        if (floor != null && floor.trim().isNotEmpty) 'floor': floor.trim(),
        if (roomNumber != null && roomNumber.trim().isNotEmpty) 'roomNumber': roomNumber.trim(),
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'event_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
      });

      final response = await _dio.post(
        ApiConfig.createCommunityEvent,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Event created successfully',
          'event': response.data['event'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create event',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteCommunityEvent(String eventId) async {
    try {
      final response = await _dio.delete(ApiConfig.deleteCommunityEventUrl(eventId));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Event deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete event',
        };
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get vehicles (by current user)
  Future<Map<String, dynamic>> getVehicles() async {
    try {
      final response = await _dio.get(ApiConfig.getVehicles);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'vehicles': response.data['vehicles'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get vehicles',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Add vehicle
  Future<Map<String, dynamic>> addVehicle({
    required String vehicleType,
    required String vehicleNumber,
    File? image,
  }) async {
    try {
      final formData = FormData.fromMap({
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber.trim(),
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
      });

      final response = await _dio.post(
        ApiConfig.addVehicle,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Vehicle created successfully',
          'vehicle': response.data['vehicle'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to add vehicle',
        };
      }
    } on DioException catch (e) {
    String errorMessage = 'Network error';

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      errorMessage =
          'Connection timeout. Please check your internet connection and ensure the server is running.';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage =
          'Unable to connect to server. Please check your internet connection and verify the server is running.';
    } else if (e.response != null) {
      errorMessage =
          e.response?.data['error'] ?? e.message ?? 'Network error';
    } else {
      errorMessage = e.message ?? 'Network error';
    }

    return {
      'success': false,
      'error': errorMessage,
    };
  } catch (e) {
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}

  // Delete vehicle
  Future<Map<String, dynamic>> deleteVehicle(String vehicleId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.deleteVehicleUrl(vehicleId),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Vehicle deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete vehicle',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Verify vehicle (Security only) - returns vehicle + user/tenant details
  Future<Map<String, dynamic>> verifyVehicle(String vehicleId) async {
    try {
      final response = await _dio.get(
        ApiConfig.verifyVehicleUrl(vehicleId),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'vehicle': response.data['vehicle'],
          'user': response.data['user'],
        };
      } else {
        return {
          'success': false,
          'error':
              response.data['error'] ?? 'Not a valid vehicle',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Not a valid vehicle';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get family members
  Future<Map<String, dynamic>> getFamilyMembers() async {
    try {
      final response = await _dio.get(ApiConfig.getFamilyMembers);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'familyMembers': response.data['familyMembers'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get family members',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Add family member
  Future<Map<String, dynamic>> addFamilyMember({
    required String name,
    required String relationType,
    String? dateOfBirth,
    File? profileImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name.trim(),
        'relationType': relationType,
        if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
        if (profileImage != null)
          'profileImage': await MultipartFile.fromFile(
            profileImage.path,
            filename: 'family_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
      });

      final response = await _dio.post(
        ApiConfig.addFamilyMember,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Family member added successfully',
          'familyMember': response.data['familyMember'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to add family member',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete family member
  Future<Map<String, dynamic>> deleteFamilyMember(String familyMemberId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.deleteFamilyMemberUrl(familyMemberId),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Family member deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to delete family member',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Kid exit (user–security communication)
  // Get permissions
  Future<Map<String, dynamic>> getPermissions(String userType) async {
    try {
      final response = await _dio.get('${ApiConfig.getPermissions}/$userType');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'permission': response.data['permission'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get permissions',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update permissions
  Future<Map<String, dynamic>> updatePermissions(
    String userType,
    Map<String, bool> permissions,
  ) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.updatePermissions}/$userType',
        data: {'permissions': permissions},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message':
              response.data['message'] ?? 'Permissions updated successfully',
          'permission': response.data['permission'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update permissions',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and verify the server is running.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update security staff
  // Delete security staff
  /// Delete a user/tenant
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final response = await _dio.delete(
        '${ApiConfig.deleteUser}/$userId',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'User deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Delete failed',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Unable to connect to server.';
      } else if (e.response != null) {
        errorMessage =
            e.response?.data['error'] ?? e.message ?? 'Network error';
      } else {
        errorMessage = e.message ?? 'Network error';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Support / Help desk
  /// [status] optional: 'active' (open + in_progress) or 'closed'. Admin only; ignored for residents.
  Future<Map<String, dynamic>> getTickets({String? status, String? apartmentId}) async {
    try {
      final query = <String, String>{};
      if (status == 'active' || status == 'closed') query['status'] = status!;
      if (apartmentId != null && apartmentId.isNotEmpty) {
        query['apartmentId'] = apartmentId;
      }
      final path = query.isEmpty
          ? ApiConfig.supportTicketsBase
          : '${ApiConfig.supportTicketsBase}?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      final response = await _dio.get(path);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'tickets': response.data['tickets'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get tickets',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createTicket({
    required String issueType,
    required String description,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.supportTicketsBase,
        data: {'issueType': issueType.trim(), 'description': description.trim()},
      );
      if (response.statusCode == 201) {
        return {
          'success': true,
          'ticket': response.data['ticket'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create ticket',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getTicket(String id) async {
    try {
      final response = await _dio.get(ApiConfig.supportTicketById(id));
      if (response.statusCode == 200) {
        return {'success': true, 'ticket': response.data['ticket']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get ticket',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getSupportMessages(String ticketId) async {
    try {
      final response = await _dio.get(ApiConfig.supportMessages(ticketId));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'messages': response.data['messages'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get messages',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendSupportMessage(
    String ticketId, {
    String? message,
    File? image,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'support_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
      });
      final response = await _dio.post(
        ApiConfig.supportSendMessage(ticketId),
        data: formData,
      );
      if (response.statusCode == 201) {
        return {'success': true, 'message': response.data['message']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to send message',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTicketStatus(String ticketId, String status) async {
    try {
      final response = await _dio.patch(
        ApiConfig.supportTicketStatus(ticketId),
        data: {'status': status},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'ticket': response.data['ticket']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update status',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Complaints
  Future<Map<String, dynamic>> getComplaints({
    String? status,
    String? apartmentId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && (status == 'pending' || status == 'completed')) {
        queryParams['status'] = status;
      }
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }
      final path = queryParams.isEmpty
          ? ApiConfig.complaintsBase
          : '${ApiConfig.complaintsBase}?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      final response = await _dio.get(path);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'complaints': response.data['complaints'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get complaints',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createComplaint({
    required String type,
    required String description,
    String? block,
    String? floor,
    String? roomNumber,
    DateTime? preferredRepairDateTime,
    bool isUrgent = false,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type.trim(),
        'description': description.trim(),
        'isUrgent': isUrgent,
      };
      if (block != null) data['block'] = block;
      if (floor != null) data['floor'] = floor;
      if (roomNumber != null) data['roomNumber'] = roomNumber;
      if (preferredRepairDateTime != null) {
        data['preferredRepairDateTime'] = preferredRepairDateTime.toIso8601String();
      }
      final response = await _dio.post(ApiConfig.complaintsBase, data: data);
      if (response.statusCode == 201) {
        return {'success': true, 'complaint': response.data['complaint']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create complaint',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateComplaintStatus(String complaintId, String status) async {
    try {
      final response = await _dio.patch(
        ApiConfig.complaintStatus(complaintId),
        data: {'status': status},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'complaint': response.data['complaint']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update complaint status',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============== Leave requests (hostel) ==============

  Future<Map<String, dynamic>> createLeaveRequest({
    required DateTime outAt,
    required DateTime expectedInAt,
    required String reason,
    required String parentName,
    required String parentMobile,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.leaveRequestsBase,
        data: {
          'outAt': outAt.toIso8601String(),
          'expectedInAt': expectedInAt.toIso8601String(),
          'reason': reason.trim(),
          'parentName': parentName.trim(),
          'parentMobile': parentMobile.trim(),
        },
      );
      if (response.statusCode == 201) {
        return {'success': true, 'leaveRequest': response.data['leaveRequest']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create leave request',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMyLeaveRequests() async {
    try {
      final response = await _dio.get(ApiConfig.myLeaveRequests);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'leaveRequests': response.data['leaveRequests'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load leave requests',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> listLeaveRequests({
    required String apartmentId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.leaveRequestsList(apartmentId: apartmentId, status: status),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'leaveRequests': response.data['leaveRequests'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load leave requests',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateLeaveApproval({
    required String leaveRequestId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConfig.leaveRequestApproval(leaveRequestId),
        data: {
          'status': status,
          if (rejectionReason != null) 'rejectionReason': rejectionReason,
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'leaveRequest': response.data['leaveRequest']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update leave',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelLeaveRequest(String leaveRequestId) async {
    try {
      final response = await _dio.patch(ApiConfig.leaveRequestCancel(leaveRequestId));
      if (response.statusCode == 200) {
        return {'success': true, 'leaveRequest': response.data['leaveRequest']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to cancel',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getLeaveGatePass(String leaveRequestId) async {
    try {
      final response = await _dio.get(ApiConfig.leaveRequestGatePass(leaveRequestId));
      if (response.statusCode == 200) {
        return {'success': true, 'gatePass': response.data['gatePass']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load gate pass',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyLeaveByQr({
    String? leaveId,
    String? otp,
    String? payload,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyLeaveByQr,
        data: {
          if (leaveId != null) 'leaveId': leaveId,
          if (otp != null) 'otp': otp,
          if (payload != null) 'payload': payload,
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, ...Map<String, dynamic>.from(response.data as Map)};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Verification failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getHostelIdPayload() async {
    try {
      final response = await _dio.get(ApiConfig.hostelIdPayload);
      if (response.statusCode == 200) {
        return {'success': true, 'payload': response.data['payload']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load hostel ID',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getStaffQr() async {
    try {
      final response = await _dio.get(ApiConfig.staffQr);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'qrCode': response.data['qrCode'],
          'qrData': response.data['qrData'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load staff QR code',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyHostelQr({
    String? userId,
    String? otp,
    String? payload,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyHostelQr,
        data: {
          if (userId != null) 'userId': userId,
          if (otp != null) 'otp': otp,
          if (payload != null) 'payload': payload,
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, ...Map<String, dynamic>.from(response.data as Map)};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Verification failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============== Guard Message / Chat API Methods ==============

  // ========== TENANT MESSAGING API METHODS ==========

  // Helper methods for HTTP requests
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Request failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Request failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Request failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return response.data;
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Request failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Property document requirements
  Future<Map<String, dynamic>> getPropertyDocumentRequirements({
    String? apartmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }

      final response = await _dio.get(
        ApiConfig.propertyDocumentRequirements,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'requirements': response.data['requirements'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get document requirements',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createPropertyDocumentRequirement({
    required String name,
    required String documentType,
    required String apartmentId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.propertyDocumentRequirements,
        data: {
          'name': name,
          'documentType': documentType,
          'apartmentId': apartmentId,
        },
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Requirement created',
          'requirement': response.data['requirement'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create requirement',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePropertyDocumentRequirement(String id) async {
    try {
      final response = await _dio.delete(
        ApiConfig.deletePropertyDocumentRequirementUrl(id),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Requirement deleted',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to delete requirement',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMyPropertyDocuments({
    String? apartmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }

      final response = await _dio.get(
        ApiConfig.myPropertyDocuments,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'documents': response.data['documents'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get documents',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getUserPropertyDocuments({
    required String userId,
    String? apartmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (apartmentId != null && apartmentId.isNotEmpty) {
        queryParams['apartmentId'] = apartmentId;
      }

      final response = await _dio.get(
        ApiConfig.propertyDocumentsForUserUrl(userId),
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'documents': response.data['documents'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get user documents',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadPropertyDocument({
    required String requirementId,
    required File file,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'requirementId': requirementId,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        ApiConfig.uploadPropertyDocument,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Document uploaded',
          'submission': response.data['submission'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to upload document',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['error'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
