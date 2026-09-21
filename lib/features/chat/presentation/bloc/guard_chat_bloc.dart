import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/conversation_model.dart';
import '../../../../core/models/guard_message_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/websocket_service.dart';
import 'guard_chat_event.dart';
import 'guard_chat_state.dart';

class GuardChatBloc extends Bloc<GuardChatEvent, GuardChatState> {
  final ApiService _apiService;
  final WebSocketService _webSocketService;

  StreamSubscription<GuardMessageModel>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _messagesReadSubscription;

  GuardChatBloc({
    ApiService? apiService,
    WebSocketService? webSocketService,
  })  : _apiService = apiService ?? ApiService(),
        _webSocketService = webSocketService ?? WebSocketService(),
        super(const GuardChatState()) {
    // Register event handlers
    on<LoadConversations>(_onLoadConversations);
    on<RefreshConversations>(_onRefreshConversations);
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<MarkMessagesAsRead>(_onMarkMessagesAsRead);
    on<NewMessageReceived>(_onNewMessageReceived);
    on<MessageNotificationReceived>(_onMessageNotificationReceived);
    on<UpdateUnreadCount>(_onUpdateUnreadCount);
    on<MessagesReadByOther>(_onMessagesReadByOther);
    on<ConnectionStatusChanged>(_onConnectionStatusChanged);
    on<TypingStatusChanged>(_onTypingStatusChanged);
    on<StartTyping>(_onStartTyping);
    on<StopTyping>(_onStopTyping);
    on<JoinConversation>(_onJoinConversation);
    on<LeaveConversation>(_onLeaveConversation);
    on<LoadRecipientList>(_onLoadRecipientList);
    on<GetOrCreateConversation>(_onGetOrCreateConversation);
    on<ClearCurrentConversation>(_onClearCurrentConversation);

    // Subscribe to WebSocket streams
    _subscribeToWebSocket();
  }

  void _subscribeToWebSocket() {
    _messageSubscription = _webSocketService.messageStream.listen((message) {
      add(NewMessageReceived(message: message));
    });

    _notificationSubscription = _webSocketService.notificationStream.listen((notification) {
      add(MessageNotificationReceived(notification: notification));
    });

    _connectionSubscription = _webSocketService.connectionStream.listen((isConnected) {
      add(ConnectionStatusChanged(isConnected: isConnected));
    });

    _typingSubscription = _webSocketService.typingStream.listen((data) {
      final conversationId = data['conversationId']?.toString() ?? '';
      final odId = data['userId']?.toString() ?? '';
      final userName = data['userName']?.toString() ?? '';
      final isTyping = data['isTyping'] == true;

      add(TypingStatusChanged(
        conversationId: conversationId,
        odId: odId,
        userName: userName,
        isTyping: isTyping,
      ));
    });

    _messagesReadSubscription = _webSocketService.messagesReadStream.listen((data) {
      final conversationId = data['conversationId']?.toString() ?? '';
      final readBy = data['readBy']?.toString() ?? '';

      add(MessagesReadByOther(
        conversationId: conversationId,
        readBy: readBy,
      ));
    });
  }

  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<GuardChatState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingConversations: true,
      clearConversationsError: true,
    ));

    try {
      final result = await _apiService.getGuardConversations();

      if (result['success'] == true) {
        final conversationsList = result['conversations'] as List<dynamic>? ?? [];
        final conversations = conversationsList
            .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
            .toList();
        final userType = result['userType']?.toString() ?? 'user';

        emit(state.copyWith(
          conversations: conversations,
          isLoadingConversations: false,
          userType: userType,
        ));

        // Update total unread count
        add(const UpdateUnreadCount());
      } else {
        emit(state.copyWith(
          isLoadingConversations: false,
          conversationsError: result['error']?.toString() ?? 'Failed to load conversations',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingConversations: false,
        conversationsError: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshConversations(
    RefreshConversations event,
    Emitter<GuardChatState> emit,
  ) async {
    add(const LoadConversations());
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<GuardChatState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingMessages: true,
      clearMessagesError: true,
      currentConversationId: event.conversationId,
    ));

    try {
      final result = await _apiService.getGuardMessages(
        event.conversationId,
        page: event.page,
      );

      if (result['success'] == true) {
        final messagesList = result['messages'] as List<dynamic>? ?? [];
        final messages = messagesList
            .map((m) => GuardMessageModel.fromJson(m as Map<String, dynamic>))
            .toList();

        final pagination = result['pagination'] as Map<String, dynamic>?;
        final currentPage = pagination?['page'] as int? ?? 1;
        final totalPages = pagination?['pages'] as int? ?? 1;

        // If loading more pages, append to existing messages
        final updatedMessages = event.page == 1
            ? messages
            : [...state.messages, ...messages];

        emit(state.copyWith(
          messages: updatedMessages,
          isLoadingMessages: false,
          currentPage: currentPage,
          totalPages: totalPages,
          hasMoreMessages: currentPage < totalPages,
        ));
      } else {
        emit(state.copyWith(
          isLoadingMessages: false,
          messagesError: result['error']?.toString() ?? 'Failed to load messages',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingMessages: false,
        messagesError: e.toString(),
      ));
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<GuardChatState> emit,
  ) async {
    emit(state.copyWith(isSendingMessage: true, clearSendError: true));

    try {
      final result = await _apiService.sendGuardMessage(
        recipientId: event.recipientId,
        message: event.message,
        conversationId: event.conversationId,
      );

      if (result['success'] == true) {
        emit(state.copyWith(isSendingMessage: false));

        // Refresh conversations to update last message
        add(const RefreshConversations());
      } else {
        emit(state.copyWith(
          isSendingMessage: false,
          sendError: result['error']?.toString() ?? 'Failed to send message',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isSendingMessage: false,
        sendError: e.toString(),
      ));
    }
  }

  Future<void> _onMarkMessagesAsRead(
    MarkMessagesAsRead event,
    Emitter<GuardChatState> emit,
  ) async {
    try {
      await _apiService.markConversationAsRead(event.conversationId);

      // Update local conversation unread count
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == event.conversationId) {
          return conv.copyWith(unreadCount: 0);
        }
        return conv;
      }).toList();

      emit(state.copyWith(conversations: updatedConversations));

      // Update total unread count
      add(const UpdateUnreadCount());

      // Also emit via WebSocket
      _webSocketService.markAsRead(event.conversationId);
    } catch (e) {
      // Silent fail - not critical
    }
  }

  void _onNewMessageReceived(
    NewMessageReceived event,
    Emitter<GuardChatState> emit,
  ) {
    final message = event.message;

    // If we're in the same conversation, add the message
    if (state.currentConversationId == message.conversationId) {
      // Check if message already exists to avoid duplicates
      final messageExists = state.messages.any((m) => m.id == message.id);
      if (!messageExists) {
        emit(state.copyWith(
          messages: [...state.messages, message],
        ));
      }
    }

    // Update conversations list
    final updatedConversations = state.conversations.map((conv) {
      if (conv.id == message.conversationId) {
        return conv.copyWith(
          lastMessage: message.message,
          lastMessageAt: message.createdAt,
          lastMessageSenderType: message.senderType,
          unreadCount: state.currentConversationId == message.conversationId
              ? 0
              : conv.unreadCount + 1,
        );
      }
      return conv;
    }).toList();

    // Sort by last message time
    updatedConversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    emit(state.copyWith(conversations: updatedConversations));

    // Update unread count
    add(const UpdateUnreadCount());
  }

  void _onMessageNotificationReceived(
    MessageNotificationReceived event,
    Emitter<GuardChatState> emit,
  ) {
    // Refresh conversations to get the new message
    add(const RefreshConversations());
  }

  Future<void> _onUpdateUnreadCount(
    UpdateUnreadCount event,
    Emitter<GuardChatState> emit,
  ) async {
    try {
      final result = await _apiService.getGuardUnreadCount();

      if (result['success'] == true) {
        final unreadCount = result['unreadCount'] as int? ?? 0;
        emit(state.copyWith(totalUnreadCount: unreadCount));
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _onMessagesReadByOther(
    MessagesReadByOther event,
    Emitter<GuardChatState> emit,
  ) {
    // Update message read status in current conversation
    if (state.currentConversationId == event.conversationId) {
      final updatedMessages = state.messages.map((m) {
        if (!m.isRead && m.recipientId == event.readBy) {
          return m.copyWith(isRead: true, readAt: DateTime.now());
        }
        return m;
      }).toList();

      emit(state.copyWith(messages: updatedMessages));
    }
  }

  void _onConnectionStatusChanged(
    ConnectionStatusChanged event,
    Emitter<GuardChatState> emit,
  ) {
    emit(state.copyWith(isConnected: event.isConnected));
  }

  void _onTypingStatusChanged(
    TypingStatusChanged event,
    Emitter<GuardChatState> emit,
  ) {
    final updatedTypingUsers = Map<String, String>.from(state.typingUsers);

    if (event.isTyping) {
      updatedTypingUsers[event.conversationId] = event.userName;
    } else {
      updatedTypingUsers.remove(event.conversationId);
    }

    emit(state.copyWith(typingUsers: updatedTypingUsers));
  }

  void _onStartTyping(
    StartTyping event,
    Emitter<GuardChatState> emit,
  ) {
    _webSocketService.emitTyping(event.conversationId, true);
  }

  void _onStopTyping(
    StopTyping event,
    Emitter<GuardChatState> emit,
  ) {
    _webSocketService.emitTyping(event.conversationId, false);
  }

  void _onJoinConversation(
    JoinConversation event,
    Emitter<GuardChatState> emit,
  ) {
    _webSocketService.joinConversation(event.conversationId);
    emit(state.copyWith(currentConversationId: event.conversationId));
  }

  void _onLeaveConversation(
    LeaveConversation event,
    Emitter<GuardChatState> emit,
  ) {
    _webSocketService.leaveConversation(event.conversationId);
  }

  Future<void> _onLoadRecipientList(
    LoadRecipientList event,
    Emitter<GuardChatState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingRecipients: true,
      clearRecipientsError: true,
    ));

    try {
      Map<String, dynamic> result;

      if (state.userType == 'security') {
        result = await _apiService.getTenantListForChat(search: event.searchQuery);
      } else {
        result = await _apiService.getSecurityListForChat();
      }

      if (result['success'] == true) {
        final List<ChatParticipant> recipients;

        if (state.userType == 'security') {
          final tenantsList = result['tenants'] as List<dynamic>? ?? [];
          recipients = tenantsList
              .map((t) => ChatParticipant.fromJson(t as Map<String, dynamic>, userType: 'user'))
              .toList();
        } else {
          final securityList = result['securities'] as List<dynamic>? ?? [];
          recipients = securityList
              .map((s) => ChatParticipant.fromJson(s as Map<String, dynamic>, userType: 'security'))
              .toList();
        }

        emit(state.copyWith(
          recipients: recipients,
          isLoadingRecipients: false,
        ));
      } else {
        emit(state.copyWith(
          isLoadingRecipients: false,
          recipientsError: result['error']?.toString() ?? 'Failed to load recipients',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingRecipients: false,
        recipientsError: e.toString(),
      ));
    }
  }

  Future<void> _onGetOrCreateConversation(
    GetOrCreateConversation event,
    Emitter<GuardChatState> emit,
  ) async {
    emit(state.copyWith(isLoadingMessages: true));

    try {
      final result = await _apiService.getOrCreateConversation(event.recipientId);

      if (result['success'] == true) {
        final conversationData = result['conversation'] as Map<String, dynamic>?;
        if (conversationData != null) {
          final conversation = ConversationModel.fromJson(conversationData);

          emit(state.copyWith(
            currentConversationId: conversation.id,
            isLoadingMessages: false,
          ));

          // Load messages for this conversation
          add(LoadMessages(conversationId: conversation.id));

          // Join the conversation room
          add(JoinConversation(conversationId: conversation.id));

          // Refresh conversations list
          add(const RefreshConversations());
        }
      } else {
        emit(state.copyWith(
          isLoadingMessages: false,
          messagesError: result['error']?.toString() ?? 'Failed to create conversation',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingMessages: false,
        messagesError: e.toString(),
      ));
    }
  }

  void _onClearCurrentConversation(
    ClearCurrentConversation event,
    Emitter<GuardChatState> emit,
  ) {
    if (state.currentConversationId != null) {
      _webSocketService.leaveConversation(state.currentConversationId!);
    }

    emit(state.copyWith(
      clearCurrentConversationId: true,
      messages: [],
      currentPage: 1,
      totalPages: 1,
      hasMoreMessages: false,
    ));
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _typingSubscription?.cancel();
    _messagesReadSubscription?.cancel();
    return super.close();
  }
}
