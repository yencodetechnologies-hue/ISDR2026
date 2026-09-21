import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../models/guard_message_model.dart';

/// Singleton service for managing WebSocket connections for real-time chat
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  String? _token;
  String? _userId;
  String? _userType;

  // Stream controllers for broadcasting events
  final _messageController = StreamController<GuardMessageModel>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineStatusController = StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<GuardMessageModel> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get messagesReadStream => _messagesReadController.stream;
  Stream<Map<String, dynamic>> get onlineStatusStream => _onlineStatusController.stream;

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
      debugPrint('WebSocket: Already connected');
      return;
    }

    _token = token;
    _userId = userId;
    _userType = userType;

    _initializeSocket();
  }

  void _initializeSocket() {
    if (_token == null) {
      debugPrint('WebSocket: No token available');
      return;
    }

    debugPrint('WebSocket: Connecting to $_socketUrl');

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
      debugPrint('WebSocket: Connected');
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('WebSocket: Disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      debugPrint('WebSocket: Connection error - $error');
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    });

    _socket!.onError((error) {
      debugPrint('WebSocket: Error - $error');
    });

    // Chat events
    _socket!.on('new_message', (data) {
      debugPrint('WebSocket: New message received');
      if (data != null) {
        final message = GuardMessageModel.fromJson(data as Map<String, dynamic>);
        _messageController.add(message);
      }
    });

    _socket!.on('new_message_notification', (data) {
      debugPrint('WebSocket: Message notification received');
      if (data != null) {
        _notificationController.add(data as Map<String, dynamic>);
      }
    });

    _socket!.on('message_sent', (data) {
      debugPrint('WebSocket: Message sent confirmation');
      if (data != null) {
        final message = GuardMessageModel.fromJson(data as Map<String, dynamic>);
        _messageController.add(message);
      }
    });

    _socket!.on('user_typing', (data) {
      debugPrint('WebSocket: Typing indicator');
      if (data != null) {
        _typingController.add(data as Map<String, dynamic>);
      }
    });

    _socket!.on('messages_read', (data) {
      debugPrint('WebSocket: Messages read');
      if (data != null) {
        _messagesReadController.add(data as Map<String, dynamic>);
      }
    });

    _socket!.on('joined_conversation', (data) {
      debugPrint('WebSocket: Joined conversation');
    });

    _socket!.on('user_online', (data) {
      debugPrint('WebSocket: User online');
      if (data != null) {
        _onlineStatusController.add({...data as Map<String, dynamic>, 'isOnline': true});
      }
    });

    _socket!.on('user_offline', (data) {
      debugPrint('WebSocket: User offline');
      if (data != null) {
        _onlineStatusController.add({...data as Map<String, dynamic>, 'isOnline': false});
      }
    });

    _socket!.on('online_status', (data) {
      debugPrint('WebSocket: Online status response');
      if (data != null) {
        _onlineStatusController.add(data as Map<String, dynamic>);
      }
    });

    _socket!.on('error', (data) {
      debugPrint('WebSocket: Server error - $data');
    });
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _reconnectAttempts * 2 + 1);
    debugPrint('WebSocket: Scheduling reconnect in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _initializeSocket();
    });
  }

  /// Join a conversation room to receive real-time messages
  void joinConversation(String conversationId) {
    if (_socket == null || !_isConnected) {
      debugPrint('WebSocket: Cannot join conversation - not connected');
      return;
    }

    debugPrint('WebSocket: Joining conversation $conversationId');
    _socket!.emit('join_conversation', {'conversationId': conversationId});
  }

  /// Leave a conversation room
  void leaveConversation(String conversationId) {
    if (_socket == null || !_isConnected) return;

    debugPrint('WebSocket: Leaving conversation $conversationId');
    _socket!.emit('leave_conversation', {'conversationId': conversationId});
  }

  /// Send a message through WebSocket
  void sendMessage({
    String? conversationId,
    required String recipientId,
    required String message,
  }) {
    if (_socket == null || !_isConnected) {
      debugPrint('WebSocket: Cannot send message - not connected');
      return;
    }

    debugPrint('WebSocket: Sending message');
    _socket!.emit('send_message', {
      'conversationId': conversationId,
      'recipientId': recipientId,
      'message': message,
    });
  }

  /// Mark messages as read in a conversation
  void markAsRead(String conversationId) {
    if (_socket == null || !_isConnected) return;

    debugPrint('WebSocket: Marking messages as read');
    _socket!.emit('mark_as_read', {'conversationId': conversationId});
  }

  /// Emit typing indicator
  void emitTyping(String conversationId, bool isTyping) {
    if (_socket == null || !_isConnected) return;

    _socket!.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  /// Check if a user is online
  void checkOnlineStatus(String odId) {
    if (_socket == null || !_isConnected) return;

    _socket!.emit('check_online', {'userId': odId});
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    debugPrint('WebSocket: Disconnecting');
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _token = null;
    _userId = null;
    _userType = null;
    _connectionController.add(false);
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    disconnect();
    _messageController.close();
    _notificationController.close();
    _connectionController.close();
    _typingController.close();
    _messagesReadController.close();
    _onlineStatusController.close();
  }
}
