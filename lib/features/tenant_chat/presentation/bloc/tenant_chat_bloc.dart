import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/tenant_conversation_model.dart';
import '../../../../core/models/tenant_message_model.dart';
import '../../../../core/models/agreement_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/tenant_websocket_service.dart';
import 'tenant_chat_event.dart';
import 'tenant_chat_state.dart';

class TenantChatBloc extends Bloc<TenantChatEvent, TenantChatState> {
  final ApiService _apiService;
  final TenantWebSocketService _webSocketService;

  StreamSubscription<TenantMessageModel>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<AgreementModel>? _agreementSubscription;

  TenantChatBloc({
    ApiService? apiService,
    TenantWebSocketService? webSocketService,
  })  : _apiService = apiService ?? ApiService(),
        _webSocketService = webSocketService ?? TenantWebSocketService(),
        super(const TenantChatState()) {
    // Register event handlers
    on<LoadTenantConversations>(_onLoadConversations);
    on<RefreshTenantConversations>(_onRefreshConversations);
    on<GetOrCreateTenantConversation>(_onGetOrCreateConversation);
    on<LoadTenantMessages>(_onLoadMessages);
    on<SendTenantMessage>(_onSendMessage);
    on<MarkTenantMessagesAsRead>(_onMarkMessagesAsRead);
    on<NewTenantMessageReceived>(_onNewMessageReceived);
    on<TenantMessageNotificationReceived>(_onMessageNotificationReceived);
    on<UploadAgreement>(_onUploadAgreement);
    on<GetAgreements>(_onGetAgreements);
    on<DeleteAgreement>(_onDeleteAgreement);
    on<AgreementUploaded>(_onAgreementUploaded);
    on<JoinTenantConversation>(_onJoinConversation);
    on<LeaveTenantConversation>(_onLeaveConversation);
    on<ClearCurrentTenantConversation>(_onClearCurrentConversation);
    on<TenantConnectionStatusChanged>(_onConnectionStatusChanged);

    // Subscribe to WebSocket streams
    _subscribeToWebSocket();
  }

  void _subscribeToWebSocket() {
    _messageSubscription = _webSocketService.messageStream.listen((message) {
      add(NewTenantMessageReceived(message: message));
    });

    _notificationSubscription = _webSocketService.notificationStream.listen((notification) {
      add(TenantMessageNotificationReceived(notification: notification));
    });

    _connectionSubscription = _webSocketService.connectionStream.listen((isConnected) {
      add(TenantConnectionStatusChanged(isConnected: isConnected));
    });

    _agreementSubscription = _webSocketService.agreementStream.listen((agreement) {
      add(AgreementUploaded(
        agreement: agreement,
        conversationId: agreement.conversationId,
      ));
    });
  }

  Future<void> _onLoadConversations(
    LoadTenantConversations event,
    Emitter<TenantChatState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingConversations: true,
      clearConversationsError: true,
    ));

    try {
      final result = await _apiService.getTenantConversations();

      if (result['success'] == true) {
        final conversationsList = result['conversations'] as List<dynamic>? ?? [];
        final conversations = conversationsList
            .map((c) => TenantConversationModel.fromJson(c as Map<String, dynamic>))
            .toList();
        final userType = result['userType']?.toString() ?? 'user';

        emit(state.copyWith(
          conversations: conversations,
          isLoadingConversations: false,
          userType: userType,
        ));
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
    RefreshTenantConversations event,
    Emitter<TenantChatState> emit,
  ) async {
    add(const LoadTenantConversations());
  }

  Future<void> _onGetOrCreateConversation(
    GetOrCreateTenantConversation event,
    Emitter<TenantChatState> emit,
  ) async {
    emit(state.copyWith(isLoadingMessages: true));

    try {
      final result = await _apiService.getOrCreateTenantConversation(event.tenantId);

      if (result['success'] == true) {
        final conversationData = result['conversation'] as Map<String, dynamic>;
        final conversation = TenantConversationModel.fromJson(conversationData);

        emit(state.copyWith(
          currentConversationId: conversation.id,
          isLoadingMessages: false,
        ));

        // Load messages for this conversation
        add(LoadTenantMessages(conversationId: conversation.id));
        // Load agreements
        add(GetAgreements(conversationId: conversation.id));
      } else {
        emit(state.copyWith(
          isLoadingMessages: false,
          messagesError: result['error']?.toString() ?? 'Failed to get conversation',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingMessages: false,
        messagesError: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMessages(
    LoadTenantMessages event,
    Emitter<TenantChatState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingMessages: true,
      clearMessagesError: true,
      currentConversationId: event.conversationId,
    ));

    try {
      final result = await _apiService.getTenantMessages(
        event.conversationId,
        page: event.page,
      );

      if (result['success'] == true) {
        final messagesList = result['messages'] as List<dynamic>? ?? [];
        final messages = messagesList
            .map((m) => TenantMessageModel.fromJson(m as Map<String, dynamic>))
            .toList();

        final total = result['total'] as int? ?? 0;
        final limit = result['limit'] as int? ?? 50;
        final totalPages = (total / limit).ceil();

        emit(state.copyWith(
          messages: event.page == 1 ? messages : [...state.messages, ...messages],
          isLoadingMessages: false,
          currentPage: event.page,
          totalPages: totalPages,
          hasMoreMessages: event.page < totalPages,
        ));

        // Mark messages as read
        add(MarkTenantMessagesAsRead(conversationId: event.conversationId));
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
    SendTenantMessage event,
    Emitter<TenantChatState> emit,
  ) async {
    emit(state.copyWith(
      isSendingMessage: true,
      clearSendError: true,
    ));

    try {
      final result = await _apiService.sendTenantMessage(
        conversationId: event.conversationId,
        recipientId: event.recipientId,
        message: event.message,
        attachments: event.attachments,
        attachmentFiles: event.attachmentFiles,
      );

      if (result['success'] == true) {
        emit(state.copyWith(isSendingMessage: false));

        // Refresh conversations to update last message
        add(const RefreshTenantConversations());
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
    MarkTenantMessagesAsRead event,
    Emitter<TenantChatState> emit,
  ) async {
    try {
      await _apiService.markTenantMessagesAsRead(event.conversationId);

      // Update local conversation unread count
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == event.conversationId) {
          if (state.userType == 'tenant') {
            return conv.copyWith(unreadCountTenant: 0);
          } else {
            return conv.copyWith(unreadCountUser: 0);
          }
        }
        return conv;
      }).toList();

      emit(state.copyWith(conversations: updatedConversations));

      // Also emit via WebSocket
      _webSocketService.markAsRead(event.conversationId);
    } catch (e) {
      // Silent fail - not critical
    }
  }

  void _onNewMessageReceived(
    NewTenantMessageReceived event,
    Emitter<TenantChatState> emit,
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
        final unreadCount = state.userType == 'tenant' 
            ? conv.unreadCountTenant 
            : conv.unreadCountUser;
        final newUnreadCount = state.currentConversationId == message.conversationId
            ? 0
            : unreadCount + 1;

        if (state.userType == 'tenant') {
          return conv.copyWith(
            lastMessage: message.message ?? '',
            lastMessageAt: message.createdAt,
            lastMessageSenderType: message.senderType,
            unreadCountTenant: newUnreadCount,
          );
        } else {
          return conv.copyWith(
            lastMessage: message.message ?? '',
            lastMessageAt: message.createdAt,
            lastMessageSenderType: message.senderType,
            unreadCountUser: newUnreadCount,
          );
        }
      }
      return conv;
    }).toList();

    // Sort by last message time
    updatedConversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    emit(state.copyWith(conversations: updatedConversations));
  }

  void _onMessageNotificationReceived(
    TenantMessageNotificationReceived event,
    Emitter<TenantChatState> emit,
  ) {
    // Refresh conversations to get the new message
    add(const RefreshTenantConversations());
  }

  Future<void> _onUploadAgreement(
    UploadAgreement event,
    Emitter<TenantChatState> emit,
  ) async {
    emit(state.copyWith(isUploadingAgreement: true));

    try {
      final result = await _apiService.uploadAgreement(
        conversationId: event.conversationId,
        agreementFile: event.agreementFile,
        description: event.description,
      );

      if (result['success'] == true) {
        final agreementData = result['agreement'] as Map<String, dynamic>;
        final agreement = AgreementModel.fromJson(agreementData);

        emit(state.copyWith(
          isUploadingAgreement: false,
          agreements: [...state.agreements, agreement],
        ));

        // Notify via WebSocket
        _webSocketService.notifyAgreementUploaded(event.conversationId, agreement);
      } else {
        emit(state.copyWith(
          isUploadingAgreement: false,
          agreementsError: result['error']?.toString() ?? 'Failed to upload agreement',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isUploadingAgreement: false,
        agreementsError: e.toString(),
      ));
    }
  }

  Future<void> _onGetAgreements(
    GetAgreements event,
    Emitter<TenantChatState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingAgreements: true,
      clearAgreementsError: true,
    ));

    try {
      final result = await _apiService.getAgreements(event.conversationId);

      if (result['success'] == true) {
        final agreementsList = result['agreements'] as List<dynamic>? ?? [];
        final agreements = agreementsList
            .map((a) => AgreementModel.fromJson(a as Map<String, dynamic>))
            .toList();

        emit(state.copyWith(
          agreements: agreements,
          isLoadingAgreements: false,
        ));
      } else {
        emit(state.copyWith(
          isLoadingAgreements: false,
          agreementsError: result['error']?.toString() ?? 'Failed to load agreements',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingAgreements: false,
        agreementsError: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteAgreement(
    DeleteAgreement event,
    Emitter<TenantChatState> emit,
  ) async {
    try {
      final result = await _apiService.deleteAgreement(event.agreementId);

      if (result['success'] == true) {
        // Remove from local list
        final updatedAgreements = state.agreements
            .where((a) => a.id != event.agreementId)
            .toList();

        emit(state.copyWith(agreements: updatedAgreements));
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _onAgreementUploaded(
    AgreementUploaded event,
    Emitter<TenantChatState> emit,
  ) {
    // Check if agreement already exists to avoid duplicates
    final agreementExists = state.agreements.any((a) => a.id == event.agreement.id);
    if (!agreementExists && event.conversationId == state.currentConversationId) {
      emit(state.copyWith(
        agreements: [...state.agreements, event.agreement],
      ));
    }
  }

  void _onJoinConversation(
    JoinTenantConversation event,
    Emitter<TenantChatState> emit,
  ) {
    _webSocketService.joinConversation(event.conversationId);
    emit(state.copyWith(currentConversationId: event.conversationId));
  }

  void _onLeaveConversation(
    LeaveTenantConversation event,
    Emitter<TenantChatState> emit,
  ) {
    _webSocketService.leaveConversation(event.conversationId);
  }

  void _onClearCurrentConversation(
    ClearCurrentTenantConversation event,
    Emitter<TenantChatState> emit,
  ) {
    emit(state.copyWith(
      clearCurrentConversationId: true,
      messages: [],
      agreements: [],
    ));
  }

  void _onConnectionStatusChanged(
    TenantConnectionStatusChanged event,
    Emitter<TenantChatState> emit,
  ) {
    emit(state.copyWith(isConnected: event.isConnected));
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _agreementSubscription?.cancel();
    return super.close();
  }
}
