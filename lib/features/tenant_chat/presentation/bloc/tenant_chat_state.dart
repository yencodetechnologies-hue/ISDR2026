import 'package:equatable/equatable.dart';
import '../../../../core/models/tenant_conversation_model.dart';
import '../../../../core/models/tenant_message_model.dart';
import '../../../../core/models/agreement_model.dart';

class TenantChatState extends Equatable {
  // Conversations list state
  final List<TenantConversationModel> conversations;
  final bool isLoadingConversations;
  final String? conversationsError;
  final String userType;

  // Current conversation state
  final String? currentConversationId;
  final List<TenantMessageModel> messages;
  final bool isLoadingMessages;
  final String? messagesError;
  final int currentPage;
  final int totalPages;
  final bool hasMoreMessages;

  // Sending message state
  final bool isSendingMessage;
  final String? sendError;

  // Agreements state
  final List<AgreementModel> agreements;
  final bool isLoadingAgreements;
  final String? agreementsError;
  final bool isUploadingAgreement;

  // Connection status
  final bool isConnected;

  const TenantChatState({
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
    this.agreements = const [],
    this.isLoadingAgreements = false,
    this.agreementsError,
    this.isUploadingAgreement = false,
    this.isConnected = false,
  });

  TenantChatState copyWith({
    List<TenantConversationModel>? conversations,
    bool? isLoadingConversations,
    String? conversationsError,
    bool clearConversationsError = false,
    String? userType,
    String? currentConversationId,
    bool clearCurrentConversationId = false,
    List<TenantMessageModel>? messages,
    bool? isLoadingMessages,
    String? messagesError,
    bool clearMessagesError = false,
    int? currentPage,
    int? totalPages,
    bool? hasMoreMessages,
    bool? isSendingMessage,
    String? sendError,
    bool clearSendError = false,
    List<AgreementModel>? agreements,
    bool? isLoadingAgreements,
    String? agreementsError,
    bool clearAgreementsError = false,
    bool? isUploadingAgreement,
    bool? isConnected,
  }) {
    return TenantChatState(
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
      agreements: agreements ?? this.agreements,
      isLoadingAgreements: isLoadingAgreements ?? this.isLoadingAgreements,
      agreementsError: clearAgreementsError ? null : agreementsError ?? this.agreementsError,
      isUploadingAgreement: isUploadingAgreement ?? this.isUploadingAgreement,
      isConnected: isConnected ?? this.isConnected,
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
        agreements,
        isLoadingAgreements,
        agreementsError,
        isUploadingAgreement,
        isConnected,
      ];
}
