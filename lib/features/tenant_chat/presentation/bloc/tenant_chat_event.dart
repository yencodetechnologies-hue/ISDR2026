import 'package:equatable/equatable.dart';
import 'dart:io';
import '../../../../core/models/tenant_message_model.dart';
import '../../../../core/models/agreement_model.dart';

abstract class TenantChatEvent extends Equatable {
  const TenantChatEvent();

  @override
  List<Object?> get props => [];
}

/// Load all conversations for the current user or tenant
class LoadTenantConversations extends TenantChatEvent {
  const LoadTenantConversations();
}

/// Refresh conversations list
class RefreshTenantConversations extends TenantChatEvent {
  const RefreshTenantConversations();
}

/// Get or create conversation with tenant
class GetOrCreateTenantConversation extends TenantChatEvent {
  final String tenantId;

  const GetOrCreateTenantConversation({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}

/// Load messages for a specific conversation
class LoadTenantMessages extends TenantChatEvent {
  final String conversationId;
  final int page;

  const LoadTenantMessages({
    required this.conversationId,
    this.page = 1,
  });

  @override
  List<Object?> get props => [conversationId, page];
}

/// Send a new message
class SendTenantMessage extends TenantChatEvent {
  final String? conversationId;
  final String? recipientId;
  final String message;
  final List<String>? attachments;
  final List<File>? attachmentFiles;

  const SendTenantMessage({
    this.conversationId,
    this.recipientId,
    required this.message,
    this.attachments,
    this.attachmentFiles,
  });

  @override
  List<Object?> get props => [conversationId, recipientId, message, attachments, attachmentFiles];
}

/// Mark messages as read in a conversation
class MarkTenantMessagesAsRead extends TenantChatEvent {
  final String conversationId;

  const MarkTenantMessagesAsRead({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// New message received via WebSocket
class NewTenantMessageReceived extends TenantChatEvent {
  final TenantMessageModel message;

  const NewTenantMessageReceived({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Message notification received (when not in conversation)
class TenantMessageNotificationReceived extends TenantChatEvent {
  final Map<String, dynamic> notification;

  const TenantMessageNotificationReceived({required this.notification});

  @override
  List<Object?> get props => [notification];
}

/// Upload agreement document
class UploadAgreement extends TenantChatEvent {
  final String conversationId;
  final File agreementFile;
  final String? description;

  const UploadAgreement({
    required this.conversationId,
    required this.agreementFile,
    this.description,
  });

  @override
  List<Object?> get props => [conversationId, agreementFile, description];
}

/// Get all agreements for a conversation
class GetAgreements extends TenantChatEvent {
  final String conversationId;

  const GetAgreements({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Delete agreement
class DeleteAgreement extends TenantChatEvent {
  final String agreementId;

  const DeleteAgreement({required this.agreementId});

  @override
  List<Object?> get props => [agreementId];
}

/// Agreement uploaded notification
class AgreementUploaded extends TenantChatEvent {
  final AgreementModel agreement;
  final String conversationId;

  const AgreementUploaded({
    required this.agreement,
    required this.conversationId,
  });

  @override
  List<Object?> get props => [agreement, conversationId];
}

/// Join a conversation room
class JoinTenantConversation extends TenantChatEvent {
  final String conversationId;

  const JoinTenantConversation({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Leave a conversation room
class LeaveTenantConversation extends TenantChatEvent {
  final String conversationId;

  const LeaveTenantConversation({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Clear current conversation state
class ClearCurrentTenantConversation extends TenantChatEvent {
  const ClearCurrentTenantConversation();
}

/// Connection status changed
class TenantConnectionStatusChanged extends TenantChatEvent {
  final bool isConnected;

  const TenantConnectionStatusChanged({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}
