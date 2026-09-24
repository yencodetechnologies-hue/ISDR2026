import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/dio_response_utils.dart';
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

  /// Register owner + tenant (admin/apartment Add User — tenant account type).
  Future<Map<String, dynamic>> registerResidentBundle({
    required String name,
    required String username,
    required String email,
    required String password,
    required String mobileNumber,
    required String ownerName,
    required String ownerMobile,
    required String ownerPassword,
    String? secondaryMobileNumber,
    String? gender,
    String? familyType,
    String? aadhaarCard,
    String? panCard,
    int? totalOccupants,
    String? apartmentId,
    bool? isNRI,
    File? profilePic,
    File? aadhaarFront,
    File? aadhaarBack,
    File? panCardImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'mobileNumber': mobileNumber,
        'ownerName': ownerName,
        'ownerMobile': ownerMobile,
        'ownerPassword': ownerPassword,
        if (secondaryMobileNumber != null && secondaryMobileNumber.isNotEmpty)
          'secondaryMobileNumber': secondaryMobileNumber,
        if (gender != null) 'gender': gender,
        if (familyType != null) 'familyType': familyType,
        if (aadhaarCard != null && aadhaarCard.isNotEmpty) 'aadhaarCard': aadhaarCard,
        if (panCard != null && panCard.isNotEmpty) 'panCard': panCard,
        if (totalOccupants != null) 'totalOccupants': totalOccupants.toString(),
        if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
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
        ApiConfig.registerResidentBundle,
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'owner': response.data['owner'],
          'tenant': response.data['tenant'],
          'message': response.data['message'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to register owner and tenant',
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

  /// Change the management account password only (name/email/mobile stay untouched).
  Future<Map<String, dynamic>> changeManagementPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.put(
        ApiConfig.updateManagementProfile,
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
        'error': response.data['error'] ?? 'Failed to load management team',
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
        'roleTitle': roleTitle ?? 'Management Member',
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
          'message': response.data['message'] ?? 'Management ID added successfully',
          'user': response.data['user'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to add management ID',
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
        'roleTitle': roleTitle ?? 'Management Member',
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
          'message': response.data['message'] ?? 'Management ID updated successfully',
          'user': response.data['user'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update management ID',
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
          'message': response.data['message'] ?? 'Management ID removed successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to remove management ID',
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

  /// Create a visitor (resident flow). Persists to backend so security can see in today's visitors.
  /// [data] must include: name, mobileNumber, category, reasonForVisit, visitTime (ISO string).
  /// For category 'relative': relativeType required. For 'outsider': type required.
  ///
  /// If [image] is provided, this sends a multipart request with the `image` file.
  /// Otherwise, it sends JSON.
  Future<Map<String, dynamic>> createVisitor(
    Map<String, dynamic> data, {
    File? image,
  }) async {
    try {
      final dynamic payload = (image != null)
          ? FormData.fromMap({
              ...data,
              'image': await MultipartFile.fromFile(
                image.path,
                filename: 'visitor_${DateTime.now().millisecondsSinceEpoch}.jpg',
              ),
            })
          : data;

      final response = await _dio.post(ApiConfig.visitorsBase, data: payload);
      if (response.statusCode == 201 &&
          response.data != null &&
          response.data['visitor'] != null) {
        return {
          'success': true,
          'visitor': response.data['visitor'],
          'message': response.data['message'] ?? 'Visitor created successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create visitor',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get visitors registered by the current user (resident). Used to sync list with backend.
  Future<Map<String, dynamic>> getUserVisitors() async {
    try {
      final response = await _dio.get(ApiConfig.visitorsBase);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'visitors': response.data['visitors'] ?? [],
          'count': response.data['count'] ?? response.data['visitors']?.length ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get visitors',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all visitors for security dashboard. Optionally filter by [date] (yyyy-MM-dd) for today's visitors.
  Future<Map<String, dynamic>> getSecurityVisitors({String? date}) async {
    try {
      final queryParams = date != null ? {'date': date} : null;
      final response = await _dio.get(
        ApiConfig.getSecurityVisitors,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'visitors': response.data['visitors'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get visitors',
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

  /// Create a visitor from security dashboard (persists to backend).
  /// [data] must include: name, mobileNumber, type, block, homeNumber.
  /// Optional: reasonForVisit, vehicleNumber, visitTime (ISO string).
  /// If [image] is provided, sends multipart so the server can upload to Cloudinary.
  Future<Map<String, dynamic>> createSecurityVisitor(
    Map<String, dynamic> data, {
    File? image,
  }) async {
    try {
      final dynamic payload = (image != null)
          ? FormData.fromMap({
              ...data,
              'image': await MultipartFile.fromFile(
                image.path,
                filename: 'visitor_${DateTime.now().millisecondsSinceEpoch}.jpg',
              ),
            })
          : data;

      final response = await _dio.post(
        ApiConfig.createSecurityVisitor,
        data: payload,
      );

      if (response.statusCode == 201 &&
          response.data != null &&
          response.data['visitor'] != null) {
        return {
          'success': true,
          'visitor': response.data['visitor'],
          'message': response.data['message'] ?? 'Visitor created successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create visitor',
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

  /// Create bulk visitors from security dashboard (same person, multiple homes).
  /// [data] must include: name, mobileNumber, type, homes (list of { block, homeNumber }).
  /// Optional: reasonForVisit, vehicleNumber.
  /// If [image] is provided, sends multipart ([homes] is JSON-encoded in the form).
  Future<Map<String, dynamic>> createSecurityVisitorBulk(
    Map<String, dynamic> data, {
    File? image,
  }) async {
    try {
      final dynamic payload = (image != null)
          ? FormData.fromMap({
              'name': data['name'],
              'mobileNumber': data['mobileNumber'],
              'category': data['category'] ?? 'outsider',
              'type': data['type'],
              'homes': jsonEncode(data['homes']),
              if (data['reasonForVisit'] != null &&
                  '${data['reasonForVisit']}'.trim().isNotEmpty)
                'reasonForVisit': data['reasonForVisit'],
              if (data['vehicleNumber'] != null &&
                  '${data['vehicleNumber']}'.trim().isNotEmpty)
                'vehicleNumber': data['vehicleNumber'],
              if (data['typeDetail'] != null &&
                  '${data['typeDetail']}'.trim().isNotEmpty)
                'typeDetail': data['typeDetail'],
              'image': await MultipartFile.fromFile(
                image.path,
                filename: 'visitor_${DateTime.now().millisecondsSinceEpoch}.jpg',
              ),
            })
          : data;

      final response = await _dio.post(
        ApiConfig.createSecurityVisitorBulk,
        data: payload,
      );

      if (response.statusCode == 201 &&
          response.data != null &&
          response.data['visitors'] != null) {
        return {
          'success': true,
          'visitors': response.data['visitors'],
          'count': response.data['count'] ?? 0,
          'message': response.data['message'] ?? 'Visitors created successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to create visitors',
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

  /// Get visitors for resident's unit (block + room) for Gate approval.
  Future<Map<String, dynamic>> getVisitorsForMyUnit() async {
    try {
      final response = await _dio.get(ApiConfig.getVisitorsForMyUnit);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'visitors': response.data['visitors'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get visitors',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all monthly visitor passes for the apartment (Security use).
  Future<Map<String, dynamic>> getMonthlyAttendanceForSecurity() async {
    try {
      final response = await _dio.get(ApiConfig.getMonthlyAttendance);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'passes': response.data['passes'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get monthly attendance',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update visitor approval status. [status] must be 'approved' or 'rejected'.
  Future<Map<String, dynamic>> updateVisitorApproval(String visitorId, String status) async {
    try {
      final response = await _dio.patch(
        ApiConfig.visitorApprovalUrl(visitorId),
        data: {'status': status},
      );
      if (response.statusCode == 200 && response.data['visitor'] != null) {
        return {
          'success': true,
          'visitor': response.data['visitor'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to update approval',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markVisitorEntry(
    String visitorId, {
    String entryMethod = 'manual',
    String? securityNotes,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConfig.visitorEntryUrl(visitorId),
        data: {
          'entryMethod': entryMethod,
          if (securityNotes != null && securityNotes.trim().isNotEmpty)
            'securityNotes': securityNotes.trim(),
        },
      );
      if (response.statusCode == 200 && response.data['visitor'] != null) {
        return {
          'success': true,
          'visitor': response.data['visitor'],
          'message': response.data['message'] ?? 'Visitor entry recorded successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to record entry',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markVisitorExit(
    String visitorId, {
    String? securityNotes,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConfig.visitorExitUrl(visitorId),
        data: {
          if (securityNotes != null && securityNotes.trim().isNotEmpty)
            'securityNotes': securityNotes.trim(),
        },
      );
      if (response.statusCode == 200 && response.data['visitor'] != null) {
        return {
          'success': true,
          'visitor': response.data['visitor'],
          'message': response.data['message'] ?? 'Visitor exit recorded successfully',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to record exit',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getActiveVisitors({String? apartmentId}) async {
    try {
      final response = await _dio.get(
        ApiConfig.getActiveVisitors,
        queryParameters: {
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'visitors': response.data['visitors'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get active visitors',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getVisitorHistory({
    String? apartmentId,
    String? visitStatus,
    String? date,
    String? block,
    String? homeNumber,
    String? type,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.getVisitorHistory,
        queryParameters: {
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
          if (visitStatus != null && visitStatus.isNotEmpty) 'visitStatus': visitStatus,
          if (date != null && date.isNotEmpty) 'date': date,
          if (block != null && block.isNotEmpty) 'block': block,
          if (homeNumber != null && homeNumber.isNotEmpty) 'homeNumber': homeNumber,
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'visitors': response.data['visitors'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get visitor history',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getVisitorAnalytics({String? apartmentId, String? date}) async {
    try {
      final response = await _dio.get(
        ApiConfig.getVisitorAnalytics,
        queryParameters: {
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
          if (date != null && date.isNotEmpty) 'date': date,
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'analytics': response.data['analytics'] ?? const <String, dynamic>{},
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load visitor analytics',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMonthlyAttendance({String? apartmentId, String? visitorType}) async {
    try {
      final response = await _dio.get(
        ApiConfig.getMonthlyAttendance,
        queryParameters: {
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
          if (visitorType != null && visitorType.isNotEmpty) 'visitorType': visitorType,
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'passes': response.data['passes'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load monthly attendance',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// List monthly reusable OTP passes for current user's unit.
  Future<Map<String, dynamic>> getMyMonthlyVisitorPasses() async {
    try {
      final response = await _dio.get(ApiConfig.getMonthlyVisitorPasses);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'passes': response.data['passes'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get monthly passes',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create/activate a monthly visitor OTP pass (reuses OTP within rolling validity window).
  Future<Map<String, dynamic>> createMonthlyVisitorPass({
    required String visitorType,
    required String personName,
    required String mobileNumber,
    String? reasonForPass,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.createMonthlyVisitorPass,
        data: {
          'visitorType': visitorType,
          'personName': personName,
          'mobileNumber': mobileNumber,
          if (reasonForPass != null) 'reasonForPass': reasonForPass,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'pass': response.data['pass'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create monthly pass',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Enable/disable a monthly visitor pass for current user.
  Future<Map<String, dynamic>> toggleMonthlyVisitorPass({
    required String passId,
    required bool enabled,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConfig.monthlyVisitorPassToggleUrl(passId),
        data: {'enabled': enabled},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'pass': response.data['pass'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to toggle monthly pass',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verify visitor by OTP only (no visitor ID). Security use. Returns success and visitor info or error.
  Future<Map<String, dynamic>> verifyVisitorByOtp(String otp) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyVisitorByOtp,
        data: {'otp': otp.trim()},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'OTP verified successfully',
          'visitor': response.data['visitor'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Verification failed',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verify visitor by QR payload (visitorId + otp from scanned QR). Security use.
  Future<Map<String, dynamic>> verifyVisitorByQr(String visitorId, String otp) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyVisitorByQr,
        data: {'visitorId': visitorId, 'otp': otp},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Visitor verified successfully',
          'visitor': response.data['visitor'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Verification failed',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verify staff entry by QR payload (type: staff_entry). Security use.
  /// Sends the full QR payload to the same verify-by-qr endpoint.
  Future<Map<String, dynamic>> verifyStaffByQr(Map<String, dynamic> qrPayload) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyVisitorByQr,
        data: qrPayload,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Staff entry logged',
          'visitor': response.data['visitor'],
          'user': response.data['user'],
          'entryType': response.data['entryType'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Staff verification failed',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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

  /// Files, polls and questions of one session. The speaker also gets vote counts
  /// and answers; a participant gets their own `myVote` / `myAnswer`.
  Future<Map<String, dynamic>> getSessionContent(String scheduleId) =>
      _sessionContentCall(() => _dio.get(ApiConfig.sessionContent(scheduleId)));

  Future<Map<String, dynamic>> uploadSessionFile(
    String scheduleId, {
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) =>
      _sessionContentCall(() async => _dio.post(
            '${ApiConfig.sessionContent(scheduleId)}/files',
            data: FormData.fromMap({
              'file': await MultipartFile.fromFile(filePath, filename: fileName),
            }),
            options: Options(
              sendTimeout: const Duration(minutes: 5),
              receiveTimeout: const Duration(minutes: 2),
            ),
            onSendProgress: onProgress,
          ));

  Future<Map<String, dynamic>> deleteSessionFile(String scheduleId, String fileId) =>
      _sessionContentCall(
        () => _dio.delete('${ApiConfig.sessionContent(scheduleId)}/files/$fileId'),
      );

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

  Future<Map<String, dynamic>> createSpeaker({
    required String name,
    required String mobileNumber,
    required String password,
    String? photoPath,
  }) =>
      _sessionContentCall(() async => _dio.post(
            ApiConfig.speakers,
            data: FormData.fromMap({
              'name': name,
              'mobileNumber': mobileNumber,
              'password': password,
              if (photoPath != null)
                'photo':
                    await MultipartFile.fromFile(photoPath, filename: 'speaker.jpg'),
            }),
          ));

  Future<Map<String, dynamic>> deleteSpeaker(String speakerId) =>
      _sessionContentCall(() => _dio.delete('${ApiConfig.speakers}/$speakerId'));

  Future<Map<String, dynamic>> createEventSchedule({
    required String eventId,
    required String speakerId, // picked from the Speakers list
    required String scheduleName,
    String hall = '',
    // One entry per date: {date: yyyy-MM-dd, fromTime: HH:mm, toTime: HH:mm}
    required List<Map<String, String>> slots,
    String description = '',
  }) async {
    try {
      final formData = FormData.fromMap({
        'speakerId': speakerId,
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

  /// Likes a feed post, or removes the like if already liked.
  /// Returns {success, liked, likeCount}.
  Future<Map<String, dynamic>> toggleFeedPostLike(String postId) =>
      _sessionContentCall(
        () => _dio.post('${ApiConfig.feedPostsBase}/$postId/like'),
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

  /// Get security staff list for residents (name, mobileNumber, profilePic). Optionally filter by apartmentId.
  Future<Map<String, dynamic>> getSecurityList({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.getSecurityList,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'security': response.data['security'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get security list',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
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
  Future<Map<String, dynamic>> getAllPayments({
    String? month,
    int? year,
    String? status,
    String? apartmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;
      if (status != null) queryParams['status'] = status;
      if (apartmentId != null && apartmentId.isNotEmpty) queryParams['apartmentId'] = apartmentId;

      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;

      final response = await _dio.get(
        ApiConfig.getAllPayments,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: headers != null ? Options(headers: headers) : null,
      );

      if (response.statusCode == 200) {
        final payments = response.data['payments'];
        final count = response.data['count'];
        debugPrint('[getAllPayments] success=true, count=$count');
        if (payments is List) {
          for (var i = 0; i < payments.length; i++) {
            final p = payments[i];
            if (p is Map) {
              debugPrint('  [$i] id=${p['id'] ?? p['_id']} month=${p['month']} year=${p['year']} status=${p['status']} totalAmount=${p['totalAmount']}');
            }
          }
        }
        return {
          'success': true,
          'payments': payments,
          'count': count,
        };
      } else {
        final err = response.data['error'] ?? 'Failed to get payments';
        debugPrint('[getAllPayments] non-200: statusCode=${response.statusCode}, error=$err');
        return {
          'success': false,
          'error': err,
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

      debugPrint('[getAllPayments] DioException: $errorMessage');
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      debugPrint('[getAllPayments] catch: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get payment statistics
  Future<Map<String, dynamic>> getPaymentStats({
    String? month,
    int? year,
    String? apartmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;
      if (apartmentId != null && apartmentId.isNotEmpty) queryParams['apartmentId'] = apartmentId;

      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;

      final response = await _dio.get(
        ApiConfig.getPaymentStats,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: headers != null ? Options(headers: headers) : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'stats': response.data['stats'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get payment stats',
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

  Future<Map<String, dynamic>> getMyPayments({
    String? month,
    int? year,
    String? status,
    String? apartmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;
      if (status != null) queryParams['status'] = status;
      if (apartmentId != null && apartmentId.isNotEmpty) queryParams['apartmentId'] = apartmentId;

      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;

      final response = await _dio.get(
        ApiConfig.getMyPayments,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: headers != null ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'payments': response.data['payments'],
          'count': response.data['count'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get payments',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPaymentById(String id) async {
    try {
      final response = await _dio.get(ApiConfig.getPaymentByIdUrl(id));
      if (response.statusCode == 200) {
        return {'success': true, 'payment': response.data['payment']};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get payment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendPaymentReminder(String paymentId, {String? note}) async {
    try {
      final response = await _dio.post(
        ApiConfig.sendPaymentReminderUrl(paymentId),
        data: {
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reminder sent',
          'payment': response.data['payment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to send reminder',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> downloadPaymentReport({
    String? month,
    int? year,
    String? status,
    String? apartmentId,
    String scope = 'admin',
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.downloadPaymentReport,
        queryParameters: {
          if (month != null && month.isNotEmpty) 'month': month,
          if (year != null) 'year': year,
          if (status != null && status.isNotEmpty) 'status': status,
          if (apartmentId != null && apartmentId.isNotEmpty) 'apartmentId': apartmentId,
          'scope': scope,
          'format': 'csv',
        },
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'content': response.data?.toString() ?? '',
        };
      }
      return {
        'success': false,
        'error': 'Failed to download payment report',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? (data['error']?.toString() ?? e.message ?? 'Network error') : (e.message ?? 'Network error');
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> downloadPaymentInvoice(
    String paymentId, {
    String? apartmentId,
  }) async {
    try {
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get<List<int>>(
        ApiConfig.downloadPaymentInvoiceUrl(paymentId),
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final disposition =
            response.headers.value('content-disposition') ?? '';
        final fileNameMatch = RegExp(
          r'filename="?([^"]+)"?',
          caseSensitive: false,
        ).firstMatch(disposition);

        return {
          'success': true,
          'bytes': response.data,
          'fileName': fileNameMatch?.group(1) ?? 'invoice_$paymentId.html',
        };
      }

      return {
        'success': false,
        'error': 'Failed to download invoice',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['error']?.toString();
      } else if (data is List<int>) {
        msg = null;
      }
      return {
        'success': false,
        'error': msg ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

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

  Future<Map<String, dynamic>> assignPayment({
    required String userId,
    required String month,
    required int year,
    required List<Map<String, dynamic>> lineItems,
    String? apartmentId,
  }) async {
    const fallbackError = 'Failed to assign payment';
    try {
      final data = <String, dynamic>{
        'userId': userId,
        'month': month,
        'year': year,
        'lineItems': lineItems,
      };
      if (apartmentId != null && apartmentId.isNotEmpty) data['apartmentId'] = apartmentId;

      final response = await _dio.post(
        ApiConfig.assignPayment,
        data: data,
      );
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Payment assigned',
          'payment': response.data['payment'],
        };
      }
      final err = response.data['error'] ?? response.data['message'];
      final msg = (err is String && err.trim().isNotEmpty) ? err : fallbackError;
      return {'success': false, 'error': msg};
    } on DioException catch (e) {
      final data = e.response?.data;
      Object? err = data is Map ? (data['error'] ?? data['message']) : null;
      final msg = (err is String && err.trim().isNotEmpty)
          ? err
          : (e.message?.trim().isNotEmpty == true ? e.message! : 'Network error');
      return {'success': false, 'error': msg};
    } catch (e) {
      final s = e.toString().replaceFirst('Exception: ', '').trim();
      return {'success': false, 'error': s.isNotEmpty ? s : fallbackError};
    }
  }

  Future<Map<String, dynamic>> updatePayment(
    String paymentId, {
    String? month,
    int? year,
    List<Map<String, dynamic>>? lineItems,
    String? status,
    String? paymentMethod,
    String? transactionId,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (month != null) data['month'] = month;
      if (year != null) data['year'] = year;
      if (lineItems != null) data['lineItems'] = lineItems;
      if (status != null) data['status'] = status;
      if (paymentMethod != null) data['paymentMethod'] = paymentMethod;
      if (transactionId != null) data['transactionId'] = transactionId;
      if (notes != null) data['notes'] = notes;

      final response = await _dio.patch(
        ApiConfig.getPaymentByIdUrl(paymentId),
        data: data,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Payment updated',
          'payment': response.data['payment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update payment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePayment(String paymentId) async {
    try {
      final response = await _dio.delete(ApiConfig.getPaymentByIdUrl(paymentId));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Payment deleted',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to delete payment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createRazorpayOrder(String paymentId) async {
    try {
      final response = await _dio.post(
        ApiConfig.createRazorpayOrder,
        data: {'paymentId': paymentId},
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'orderId': response.data['orderId'],
          'amount': response.data['amount'],
          'currency': response.data['currency'] ?? 'INR',
          'keyId': response.data['keyId'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create order',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completePayment(
    String paymentId, {
    String? transactionId,
    String paymentMethod = 'online',
  }) async {
    try {
      final response = await _dio.patch(
        ApiConfig.completePaymentUrl(paymentId),
        data: {
          if (transactionId != null) 'transactionId': transactionId,
          'paymentMethod': paymentMethod,
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'payment': response.data['payment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to complete payment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadPaymentProof(String paymentId, File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'proof': await MultipartFile.fromFile(imageFile.path),
      });
      final response = await _dio.post(
        ApiConfig.uploadPaymentProofUrl(paymentId),
        data: formData,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'payment': response.data['payment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to upload proof',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyPaymentProof(String paymentId, {String? notes}) async {
    try {
      final response = await _dio.patch(
        ApiConfig.verifyPaymentProofUrl(paymentId),
        data: notes != null ? {'notes': notes} : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'payment': response.data['payment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to verify payment',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectPaymentProof(String paymentId) async {
    try {
      final response = await _dio.patch(
        ApiConfig.rejectPaymentProofUrl(paymentId),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'payment': response.data['payment'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to reject proof',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Subscription (admin plans, create order, verify, my, app-active). Optionally filter by apartmentId.
  Future<Map<String, dynamic>> getSubscriptionPlans({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.subscriptionPlans,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'plans': response.data['plans'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get plans',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all subscription plans (history) - admin only, includes inactive. Optionally filter by apartmentId.
  Future<Map<String, dynamic>> getSubscriptionPlansHistory({String? apartmentId}) async {
    try {
      final queryParams = apartmentId != null && apartmentId.isNotEmpty
          ? {'apartmentId': apartmentId}
          : null;
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get(
        ApiConfig.subscriptionPlansHistory,
        queryParameters: queryParams,
        options: headers != null ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'plans': response.data['plans'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get plan history',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createSubscriptionOrder(
    String planId, {
    String? apartmentId,
  }) async {
    try {
      final data = <String, dynamic>{'planId': planId};
      if (apartmentId != null && apartmentId.isNotEmpty) data['apartmentId'] = apartmentId;
      final response = await _dio.post(
        ApiConfig.subscriptionCreateOrder,
        data: data,
      );
      final body = asJsonMap(response.data);
      if (response.statusCode == 200 && body != null) {
        return {
          'success': true,
          'orderId': body['orderId']?.toString(),
          'amount': body['amount'],
          'currency': body['currency']?.toString() ?? 'INR',
          'keyId': body['keyId']?.toString(),
        };
      }
      return {
        'success': false,
        'error': errorMessageFromData(response.data) ?? 'Failed to create order',
      };
    } on DioException catch (e) {
      final msg =
          errorMessageFromData(e.response?.data) ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifySubscription({
    required String orderId,
    required String razorpayPaymentId,
    required String signature,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.subscriptionVerify,
        data: {
          'orderId': orderId,
          'razorpayPaymentId': razorpayPaymentId,
          'signature': signature,
        },
      );
      final body = asJsonMap(response.data);
      if (response.statusCode == 200 && body != null) {
        return {
          'success': true,
          'message': body['message'],
          'subscriptionStatus': body['subscriptionStatus'],
          'subscriptionEndsAt': body['subscriptionEndsAt'],
          'daysLeft': body['daysLeft'],
        };
      }
      return {
        'success': false,
        'error': errorMessageFromData(response.data) ?? 'Verification failed',
      };
    } on DioException catch (e) {
      final msg =
          errorMessageFromData(e.response?.data) ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMySubscription() async {
    try {
      final response = await _dio.get(ApiConfig.subscriptionMy);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'subscriptionStatus': response.data['subscriptionStatus'],
          'subscriptionEndsAt': response.data['subscriptionEndsAt'],
          'daysLeft': response.data['daysLeft'],
          'plan': response.data['plan'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get subscription',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get subscription for a specific apartment (admin or apartment).
  Future<Map<String, dynamic>> getSubscriptionByApartment(String apartmentId) async {
    try {
      final response = await _dio.get(ApiConfig.subscriptionByApartment(apartmentId));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'subscriptionStatus': response.data['subscriptionStatus'],
          'subscriptionEndsAt': response.data['subscriptionEndsAt'],
          'daysLeft': response.data['daysLeft'],
          'plan': response.data['plan'],
          'apartmentName': response.data['apartmentName'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get subscription',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Apartment subscription purchase history (admin / apartment).
  Future<Map<String, dynamic>> getSubscriptionPurchases({
    required String apartmentId,
  }) async {
    try {
      final headers = apartmentId.isNotEmpty ? {'X-Apartment-Id': apartmentId} : null;
      final response = await _dio.get(
        ApiConfig.subscriptionPurchases,
        queryParameters: {'apartmentId': apartmentId},
        options: headers != null ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'purchases': response.data['purchases'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to load purchases',
      };
    } on DioException catch (e) {
      final msg = e.response?.data is Map && (e.response!.data as Map)['error'] != null
          ? (e.response!.data as Map)['error'].toString()
          : e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> downloadSubscriptionPurchaseInvoice(
    String purchaseId, {
    String? apartmentId,
    String format = 'pdf',
  }) async {
    try {
      final headers = apartmentId != null && apartmentId.isNotEmpty
          ? {'X-Apartment-Id': apartmentId}
          : null;
      final response = await _dio.get<List<int>>(
        ApiConfig.subscriptionPurchaseInvoiceDownload(purchaseId, format: format),
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final disposition = response.headers.value('content-disposition') ?? '';
        final fileNameMatch = RegExp(
          r'filename="?([^"]+)"?',
          caseSensitive: false,
        ).firstMatch(disposition);
        final ct = response.headers.value('content-type') ?? '';
        return {
          'success': true,
          'bytes': response.data,
          'contentType': ct,
          'fileName': fileNameMatch?.group(1) ?? 'subscription_invoice_$purchaseId.pdf',
        };
      }
      return {'success': false, 'error': 'Failed to download invoice'};
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['error']?.toString();
      }
      return {
        'success': false,
        'error': msg ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create a new subscription plan (admin only). Optionally filter by apartmentId.
  Future<Map<String, dynamic>> createSubscriptionPlan({
    required String name,
    required int daysValidity,
    required double amount,
    String? description,
    String? color,
    int? displayOrder,
    String? apartmentId,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'daysValidity': daysValidity,
        'amount': amount,
      };
      if (description != null && description.isNotEmpty) {
        data['description'] = description;
      }
      if (color != null && color.isNotEmpty) {
        data['color'] = color;
      }
      if (displayOrder != null) {
        data['displayOrder'] = displayOrder;
      }
      if (apartmentId != null && apartmentId.isNotEmpty) {
        data['apartmentId'] = apartmentId;
      }
      final response = await _dio.post(
        ApiConfig.subscriptionCreatePlan,
        data: data,
      );
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'],
          'plan': response.data['plan'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to create subscription plan',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update a subscription plan (admin only).
  Future<Map<String, dynamic>> updateSubscriptionPlan({
    required String id,
    String? name,
    int? daysValidity,
    double? amount,
    String? description,
    String? color,
    int? displayOrder,
    String? apartmentId,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (daysValidity != null) data['daysValidity'] = daysValidity;
      if (amount != null) data['amount'] = amount;
      if (description != null) data['description'] = description;
      if (color != null) data['color'] = color;
      if (displayOrder != null) data['displayOrder'] = displayOrder;
      if (apartmentId != null) data['apartmentId'] = apartmentId.isEmpty ? null : apartmentId;
      if (isActive != null) data['isActive'] = isActive;
      final response = await _dio.put(
        ApiConfig.subscriptionUpdatePlan(id),
        data: data,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'plan': response.data['plan'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to update subscription plan',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete a subscription plan (admin only) - soft delete by setting isActive=false.
  Future<Map<String, dynamic>> deleteSubscriptionPlan(String id) async {
    try {
      final response = await _dio.delete(ApiConfig.subscriptionDeletePlan(id));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to delete subscription plan',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

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
  Future<Map<String, dynamic>> reportKidExit({
    required String kidName,
    String? familyMemberId,
    String? note,
    DateTime? exitTime,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.reportKidExit,
        data: {
          'kidName': kidName.trim(),
          if (familyMemberId != null && familyMemberId.isNotEmpty) 'familyMemberId': familyMemberId,
          if (note != null && note.isNotEmpty) 'note': note.trim(),
          if (exitTime != null) 'exitTime': exitTime.toIso8601String(),
        },
      );

      if (response.statusCode == 201 && response.data['kidExit'] != null) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Kid exit reported. Security has been notified.',
          'kidExit': response.data['kidExit'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to report kid exit',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getKidExits({String? date}) async {
    try {
      final queryParams = date != null ? {'date': date} : null;
      final response = await _dio.get(
        ApiConfig.getKidExits,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'kidExits': response.data['kidExits'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to get kid exits',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acknowledgeKidExit(String kidExitId) async {
    try {
      final response = await _dio.patch(
        ApiConfig.kidExitAcknowledgeUrl(kidExitId),
      );

      if (response.statusCode == 200 && response.data['kidExit'] != null) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Kid exit acknowledged',
          'kidExit': response.data['kidExit'],
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Failed to acknowledge',
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

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
  Future<Map<String, dynamic>> updateSecurity({
    required String securityId,
    String? name,
    String? email,
    String? mobileNumber,
    String? password,
    File? profilePic,
    File? idProof,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (mobileNumber != null && mobileNumber.isNotEmpty)
          'mobileNumber': mobileNumber,
        if (password != null && password.isNotEmpty) 'password': password,
        if (profilePic != null)
          'profilePic': await MultipartFile.fromFile(
            profilePic.path,
            filename: 'profilePic.jpg',
          ),
        if (idProof != null)
          'aadhaarFront': await MultipartFile.fromFile(
            idProof.path,
            filename: 'idProof.jpg',
          ),
      });

      final response = await _dio.put(
        '${ApiConfig.updateSecurity}/$securityId',
        data: formData,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'security': response.data['security'],
          'message':
              response.data['message'] ?? 'Security staff updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Update failed',
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

  // Delete security staff
  Future<Map<String, dynamic>> deleteSecurity(String securityId) async {
    try {
      final response = await _dio.delete(
        '${ApiConfig.deleteSecurity}/$securityId',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message':
              response.data['message'] ?? 'Security staff deleted successfully',
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

  /// Get all conversations for the logged-in user
  Future<Map<String, dynamic>> getGuardConversations() async {
    try {
      final response = await _dio.get(ApiConfig.guardConversations);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'conversations': response.data['conversations'] ?? [],
          'userType': response.data['userType'] ?? 'user',
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get conversations',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get messages for a specific conversation
  Future<Map<String, dynamic>> getGuardMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.guardConversationMessages(conversationId),
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'messages': response.data['messages'] ?? [],
          'pagination': response.data['pagination'],
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

  /// Send a message to a recipient
  Future<Map<String, dynamic>> sendGuardMessage({
    required String recipientId,
    required String message,
    String? conversationId,
  }) async {
    try {
      final data = <String, dynamic>{
        'recipientId': recipientId,
        'message': message.trim(),
      };
      if (conversationId != null) {
        data['conversationId'] = conversationId;
      }

      final response = await _dio.post(
        ApiConfig.guardSendMessage,
        data: data,
      );
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'],
          'conversationId': response.data['conversationId'],
        };
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

  /// Mark a single message as read
  Future<Map<String, dynamic>> markGuardMessageAsRead(String messageId) async {
    try {
      final response = await _dio.put(
        ApiConfig.guardMarkMessageRead(messageId),
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to mark message as read',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark all messages in a conversation as read
  Future<Map<String, dynamic>> markConversationAsRead(String conversationId) async {
    try {
      final response = await _dio.put(
        ApiConfig.guardMarkConversationRead(conversationId),
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to mark conversation as read',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get total unread message count
  Future<Map<String, dynamic>> getGuardUnreadCount() async {
    try {
      final response = await _dio.get(ApiConfig.guardUnreadCount);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'unreadCount': response.data['unreadCount'] ?? 0,
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get unread count',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get list of security guards for tenants to start chat
  Future<Map<String, dynamic>> getSecurityListForChat() async {
    try {
      final response = await _dio.get(ApiConfig.guardSecurityList);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'securities': response.data['securities'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get security list',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get list of tenants for security to start chat
  Future<Map<String, dynamic>> getTenantListForChat({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        ApiConfig.guardTenantList,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'tenants': response.data['tenants'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get tenant list',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get or create a conversation with a recipient
  Future<Map<String, dynamic>> getOrCreateConversation(String recipientId) async {
    try {
      final response = await _dio.post(
        ApiConfig.guardGetOrCreateConversation,
        data: {'recipientId': recipientId},
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'conversation': response.data['conversation'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get or create conversation',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========== TENANT MESSAGING API METHODS ==========

  /// Get or create conversation with tenant
  Future<Map<String, dynamic>> getOrCreateTenantConversation(String tenantId) async {
    try {
      final response = await _dio.get(
        ApiConfig.tenantGetOrCreateConversation(tenantId),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'conversation': response.data['conversation'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get or create conversation',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all tenant conversations
  Future<Map<String, dynamic>> getTenantConversations() async {
    try {
      final response = await _dio.get(ApiConfig.tenantConversations);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'conversations': response.data['conversations'] ?? [],
          'userType': response.data['userType'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get conversations',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get messages for a tenant conversation
  Future<Map<String, dynamic>> getTenantMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.tenantConversationMessages(conversationId),
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'messages': response.data['messages'] ?? [],
          'page': response.data['page'],
          'limit': response.data['limit'],
          'total': response.data['total'],
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

  /// Send tenant message
  Future<Map<String, dynamic>> sendTenantMessage({
    String? conversationId,
    String? recipientId,
    required String message,
    List<String>? attachments,
    List<File>? attachmentFiles,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (conversationId != null) 'conversationId': conversationId,
        if (recipientId != null) 'recipientId': recipientId,
        'message': message,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments,
      });

      // Add file attachments if provided
      if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
        final multipartFiles = await Future.wait(
          attachmentFiles.map((file) => MultipartFile.fromFile(file.path)),
        );
        formData.files.addAll(
          multipartFiles.map((file) => MapEntry('attachments', file)),
        );
      }

      final response = await _dio.post(
        ApiConfig.tenantSendMessage,
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'],
        };
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

  /// Mark tenant messages as read
  Future<Map<String, dynamic>> markTenantMessagesAsRead(String conversationId) async {
    try {
      final response = await _dio.put(
        ApiConfig.tenantMarkConversationRead(conversationId),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to mark messages as read',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload agreement document
  Future<Map<String, dynamic>> uploadAgreement({
    required String conversationId,
    required File agreementFile,
    String? description,
  }) async {
    try {
      final formData = FormData.fromMap({
        'conversationId': conversationId,
        if (description != null && description.isNotEmpty) 'description': description,
        'agreement': await MultipartFile.fromFile(agreementFile.path),
      });

      final response = await _dio.post(
        ApiConfig.tenantUploadAgreement,
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'agreement': response.data['agreement'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to upload agreement',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all agreements for a conversation
  Future<Map<String, dynamic>> getAgreements(String conversationId) async {
    try {
      final response = await _dio.get(
        ApiConfig.tenantGetAgreements(conversationId),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'agreements': response.data['agreements'] ?? [],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get agreements',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete agreement (soft delete)
  Future<Map<String, dynamic>> deleteAgreement(String agreementId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.tenantDeleteAgreement(agreementId),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to delete agreement',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get agreement download URL
  Future<Map<String, dynamic>> downloadAgreement(String agreementId) async {
    try {
      final response = await _dio.get(
        ApiConfig.tenantDownloadAgreement(agreementId),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'fileUrl': response.data['fileUrl'],
          'fileName': response.data['fileName'],
          'fileType': response.data['fileType'],
          'fileSize': response.data['fileSize'],
        };
      }
      return {
        'success': false,
        'error': response.data['error'] ?? 'Failed to get agreement download URL',
      };
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

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
