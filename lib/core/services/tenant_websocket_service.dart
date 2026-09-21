import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../models/tenant_message_model.dart';
import '../models/agreement_model.dart';

/// Singleton service for managing WebSocket connections for tenant-user messaging
class TenantWebSocketService {
  static final TenantWebSocketService _instance = TenantWebSocketService._internal();
  factory TenantWebSocketService() => _instance;
  TenantWebSocketService._internal();

  IO.Socket? _socket;
  String? _token;
  String? _userId;
  String? _userType;

  // Stream controllers for broadcasting events
  final _messageController = StreamController<TenantMessageModel>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _agreementController = StreamController<AgreementModel>.broadcast();

  // Public streams
  Stream<TenantMessageModel> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<AgreementModel> get agreementStream => _agreementController.stream;

  // Connection state
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Reconnection settings
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  /// Get the WebSocket URL from API config
  String get _socketUrl {
    // Extract base URL without /api suffix
    String baseUrl = ApiConfig.baseUrl;
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    }
    return baseUrl;
  }

  /// Initialize and connect to the WebSocket server
  void connect({required String token, required String userId, required String userType}) {
    if (_socket != null && _isConnected) {
      debugPrint('TenantWebSocket: Already connected');
      return;
    }

    _token = token;
    _userId = userId;
    _userType = userType;

    _initializeSocket();
  }

  void _initializeSocket() {
    if (_token == null) {
      debugPrint('TenantWebSocket: No token available');
      return;
    }

    debugPrint('TenantWebSocket: Connecting to $_socketUrl');

    _socket = IO.io(
      _socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _setupEventListeners();
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('TenantWebSocket: Connected');
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('TenantWebSocket: Disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      debugPrint('TenantWebSocket: Connection error - $error');
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    });

    // Tenant message events
    _socket!.on('tenant_message_received', (data) {
      debugPrint('TenantWebSocket: Message received');
      if (data != null && data is Map<String, dynamic>) {
        try {
          final message = TenantMessageModel.fromJson(data);
          _messageController.add(message);
        } catch (e) {
          debugPrint('TenantWebSocket: Error parsing message - $e');
        }
      }
    });

    _socket!.on('tenant_message_notification', (data) {
      debugPrint('TenantWebSocket: Message notification received');
      if (data != null && data is Map<String, dynamic>) {
        _notificationController.add(data as Map<String, dynamic>);
      }
    });

    _socket!.on('tenant_message_sent', (data) {
      debugPrint('TenantWebSocket: Message sent confirmation');
    });

    _socket!.on('tenant_messages_read', (data) {
      debugPrint('TenantWebSocket: Messages read by other');
    });

    _socket!.on('tenant_messages_marked_read', (data) {
      debugPrint('TenantWebSocket: Messages marked as read');
    });

    _socket!.on('joined_tenant_conversation', (data) {
      debugPrint('TenantWebSocket: Joined tenant conversation');
    });

    // Agreement events
    _socket!.on('agreement_uploaded', (data) {
      debugPrint('TenantWebSocket: Agreement uploaded');
      if (data != null && data is Map<String, dynamic>) {
        try {
          final agreementData = data['agreement'] as Map<String, dynamic>?;
          if (agreementData != null) {
            final agreement = AgreementModel.fromJson(agreementData);
            _agreementController.add(agreement);
          }
        } catch (e) {
          debugPrint('TenantWebSocket: Error parsing agreement - $e');
        }
      }
    });

    _socket!.on('agreement_uploaded_notification', (data) {
      debugPrint('TenantWebSocket: Agreement upload notification');
      if (data != null && data is Map<String, dynamic>) {
        try {
          final agreementData = data['agreement'] as Map<String, dynamic>?;
          if (agreementData != null) {
            final agreement = AgreementModel.fromJson(agreementData);
            _agreementController.add(agreement);
          }
        } catch (e) {
          debugPrint('TenantWebSocket: Error parsing agreement notification - $e');
        }
      }
    });

    _socket!.on('error', (data) {
      debugPrint('TenantWebSocket: Server error - $data');
    });
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('TenantWebSocket: Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _reconnectAttempts * 2 + 1);
    debugPrint('TenantWebSocket: Scheduling reconnect in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _initializeSocket();
    });
  }

  /// Join a tenant conversation room to receive real-time messages
  void joinConversation(String conversationId) {
    if (_socket == null || !_isConnected) {
      debugPrint('TenantWebSocket: Cannot join conversation - not connected');
      return;
    }

    debugPrint('TenantWebSocket: Joining tenant conversation $conversationId');
    _socket!.emit('join_tenant_conversation', {'conversationId': conversationId});
  }

  /// Leave a tenant conversation room
  void leaveConversation(String conversationId) {
    if (_socket == null || !_isConnected) return;

    debugPrint('TenantWebSocket: Leaving tenant conversation $conversationId');
    _socket!.emit('leave_tenant_conversation', {'conversationId': conversationId});
  }

  /// Send a tenant message through WebSocket
  void sendMessage({
    String? conversationId,
    String? recipientId,
    required String message,
    List<String>? attachments,
  }) {
    if (_socket == null || !_isConnected) {
      debugPrint('TenantWebSocket: Cannot send message - not connected');
      return;
    }

    debugPrint('TenantWebSocket: Sending tenant message');
    _socket!.emit('send_tenant_message', {
      'conversationId': conversationId,
      'recipientId': recipientId,
      'message': message,
      'attachments': attachments ?? [],
    });
  }

  /// Mark messages as read in a conversation
  void markAsRead(String conversationId) {
    if (_socket == null || !_isConnected) return;

    debugPrint('TenantWebSocket: Marking messages as read');
    _socket!.emit('mark_tenant_messages_read', {'conversationId': conversationId});
  }

  /// Notify that an agreement was uploaded
  void notifyAgreementUploaded(String conversationId, AgreementModel agreement) {
    if (_socket == null || !_isConnected) return;

    debugPrint('TenantWebSocket: Notifying agreement upload');
    _socket!.emit('agreement_uploaded', {
      'conversationId': conversationId,
      'agreement': agreement.toJson(),
    });
  }

  /// Disconnect from WebSocket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    debugPrint('TenantWebSocket: Disconnected');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _notificationController.close();
    _connectionController.close();
    _agreementController.close();
  }
}
