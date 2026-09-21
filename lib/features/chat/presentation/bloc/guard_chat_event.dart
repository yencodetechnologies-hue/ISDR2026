import 'package:equatable/equatable.dart';
import '../../../../core/models/guard_message_model.dart';

abstract class GuardChatEvent extends Equatable {
  const GuardChatEvent();

  @override
  List<Object?> get props => [];
}

/// Load all conversations for the current user
class LoadConversations extends GuardChatEvent {
  const LoadConversations();
}

/// Refresh conversations list
class RefreshConversations extends GuardChatEvent {
  const RefreshConversations();
}

/// Load messages for a specific conversation
class LoadMessages extends GuardChatEvent {
  final String conversationId;
  final int page;

  const LoadMessages({
    required this.conversationId,
    this.page = 1,
  });

  @override
  List<Object?> get props => [conversationId, page];
}

/// Send a new message
class SendMessage extends GuardChatEvent {
  final String? conversationId;
  final String recipientId;
  final String message;

  const SendMessage({
    this.conversationId,
    required this.recipientId,
    required this.message,
  });

  @override
  List<Object?> get props => [conversationId, recipientId, message];
}

/// Mark messages as read in a conversation
class MarkMessagesAsRead extends GuardChatEvent {
  final String conversationId;

  const MarkMessagesAsRead({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// New message received via WebSocket
class NewMessageReceived extends GuardChatEvent {
  final GuardMessageModel message;

  const NewMessageReceived({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Message notification received (when not in conversation)
class MessageNotificationReceived extends GuardChatEvent {
  final Map<String, dynamic> notification;

  const MessageNotificationReceived({required this.notification});

  @override
  List<Object?> get props => [notification];
}

/// Update unread count
class UpdateUnreadCount extends GuardChatEvent {
  const UpdateUnreadCount();
}

/// Messages marked as read by the other participant
class MessagesReadByOther extends GuardChatEvent {
  final String conversationId;
  final String readBy;

  const MessagesReadByOther({
    required this.conversationId,
    required this.readBy,
  });

  @override
  List<Object?> get props => [conversationId, readBy];
}

/// WebSocket connection status changed
class ConnectionStatusChanged extends GuardChatEvent {
  final bool isConnected;

  const ConnectionStatusChanged({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}

/// User typing status changed
class TypingStatusChanged extends GuardChatEvent {
  final String conversationId;
  final String odId;
  final String userName;
  final bool isTyping;

  const TypingStatusChanged({
    required this.conversationId,
    required this.odId,
    required this.userName,
    required this.isTyping,
  });

  @override
  List<Object?> get props => [conversationId, odId, userName, isTyping];
}

/// Start typing indicator
class StartTyping extends GuardChatEvent {
  final String conversationId;

  const StartTyping({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Stop typing indicator
class StopTyping extends GuardChatEvent {
  final String conversationId;

  const StopTyping({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Join a conversation room
class JoinConversation extends GuardChatEvent {
  final String conversationId;

  const JoinConversation({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Leave a conversation room
class LeaveConversation extends GuardChatEvent {
  final String conversationId;

  const LeaveConversation({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Load recipient list (security guards for tenants, tenants for security)
class LoadRecipientList extends GuardChatEvent {
  final String? searchQuery;

  const LoadRecipientList({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

/// Get or create conversation with recipient
class GetOrCreateConversation extends GuardChatEvent {
  final String recipientId;

  const GetOrCreateConversation({required this.recipientId});

  @override
  List<Object?> get props => [recipientId];
}

/// Clear current conversation state
class ClearCurrentConversation extends GuardChatEvent {
  const ClearCurrentConversation();
}
