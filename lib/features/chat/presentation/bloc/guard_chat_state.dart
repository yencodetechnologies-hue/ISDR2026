import 'package:equatable/equatable.dart';
import '../../../../core/models/conversation_model.dart';
import '../../../../core/models/guard_message_model.dart';

class GuardChatState extends Equatable {
  // Conversations list state
  final List<ConversationModel> conversations;
  final bool isLoadingConversations;
  final String? conversationsError;
  final String userType;

  // Current conversation state
  final String? currentConversationId;
  final List<GuardMessageModel> messages;
  final bool isLoadingMessages;
  final String? messagesError;
  final int currentPage;
  final int totalPages;
  final bool hasMoreMessages;

  // Sending message state
  final bool isSendingMessage;
  final String? sendError;

  // Unread count
  final int totalUnreadCount;

  // Connection status
  final bool isConnected;

  // Typing indicators (conversationId -> userName)
  final Map<String, String> typingUsers;

  // Recipient list for starting new conversation
  final List<ChatParticipant> recipients;
  final bool isLoadingRecipients;
  final String? recipientsError;

  const GuardChatState({
    this.conversations = const [],
    this.isLoadingConversations = false,
    this.conversationsError,
    this.userType = 'user',
    this.currentConversationId,
    this.messages = const [],
    this.isLoadingMessages = false,
    this.messagesError,
    this.currentPage = 1,
    this.totalPages = 1,
    this.hasMoreMessages = false,
    this.isSendingMessage = false,
    this.sendError,
    this.totalUnreadCount = 0,
    this.isConnected = false,
    this.typingUsers = const {},
    this.recipients = const [],
    this.isLoadingRecipients = false,
    this.recipientsError,
  });

  GuardChatState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoadingConversations,
    String? conversationsError,
    bool clearConversationsError = false,
    String? userType,
    String? currentConversationId,
    bool clearCurrentConversationId = false,
    List<GuardMessageModel>? messages,
    bool? isLoadingMessages,
    String? messagesError,
    bool clearMessagesError = false,
    int? currentPage,
    int? totalPages,
    bool? hasMoreMessages,
    bool? isSendingMessage,
    String? sendError,
    bool clearSendError = false,
    int? totalUnreadCount,
    bool? isConnected,
    Map<String, String>? typingUsers,
    List<ChatParticipant>? recipients,
    bool? isLoadingRecipients,
    String? recipientsError,
    bool clearRecipientsError = false,
  }) {
    return GuardChatState(
      conversations: conversations ?? this.conversations,
      isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      conversationsError: clearConversationsError ? null : conversationsError ?? this.conversationsError,
      userType: userType ?? this.userType,
      currentConversationId: clearCurrentConversationId ? null : currentConversationId ?? this.currentConversationId,
      messages: messages ?? this.messages,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      messagesError: clearMessagesError ? null : messagesError ?? this.messagesError,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      sendError: clearSendError ? null : sendError ?? this.sendError,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      isConnected: isConnected ?? this.isConnected,
      typingUsers: typingUsers ?? this.typingUsers,
      recipients: recipients ?? this.recipients,
      isLoadingRecipients: isLoadingRecipients ?? this.isLoadingRecipients,
      recipientsError: clearRecipientsError ? null : recipientsError ?? this.recipientsError,
    );
  }

  @override
  List<Object?> get props => [
        conversations,
        isLoadingConversations,
        conversationsError,
        userType,
        currentConversationId,
        messages,
        isLoadingMessages,
        messagesError,
        currentPage,
        totalPages,
        hasMoreMessages,
        isSendingMessage,
        sendError,
        totalUnreadCount,
        isConnected,
        typingUsers,
        recipients,
        isLoadingRecipients,
        recipientsError,
      ];
}
