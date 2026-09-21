import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/conversation_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../bloc/guard_chat_bloc.dart';
import '../bloc/guard_chat_event.dart';
import '../bloc/guard_chat_state.dart';
import 'guard_chat_page.dart';
import 'select_recipient_page.dart';
import 'widgets/conversation_card.dart';

class GuardConversationsPage extends StatefulWidget {
  final String token;
  final String odId;
  final String userType;

  /// When true, renders body + FAB only (no [Scaffold]/app bar) for embedding in a parent such as a [TabBarView].
  final bool embedInParent;

  const GuardConversationsPage({
    super.key,
    required this.token,
    required this.odId,
    required this.userType,
    this.embedInParent = false,
  });

  @override
  State<GuardConversationsPage> createState() => _GuardConversationsPageState();
}

class _GuardConversationsPageState extends State<GuardConversationsPage> {
  late GuardChatBloc _chatBloc;

  @override
  void initState() {
    super.initState();

    // Initialize WebSocket connection
    WebSocketService().connect(
      token: widget.token,
      userId: widget.odId,
      userType: widget.userType,
    );

    // Initialize BLoC and load conversations
    _chatBloc = GuardChatBloc(
      apiService: ApiService(),
      webSocketService: WebSocketService(),
    );
    _chatBloc.add(const LoadConversations());
  }

  @override
  void dispose() {
    _chatBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fab = _buildFAB();
    return BlocProvider.value(
      value: _chatBloc,
      child: widget.embedInParent
          ? Container(
              color: AppTheme.backgroundColor,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _buildBody()),
                  if (fab != null)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: fab,
                    ),
                ],
              ),
            )
          : Scaffold(
              backgroundColor: AppTheme.backgroundColor,
              appBar: _buildAppBar(),
              body: _buildBody(),
              floatingActionButton: fab,
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Messages',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      actions: [
        BlocBuilder<GuardChatBloc, GuardChatState>(
          builder: (context, state) {
            return _NotificationIconWithBadge(
              unreadCount: state.totalUnreadCount,
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return BlocBuilder<GuardChatBloc, GuardChatState>(
      builder: (context, state) {
        // Connection status banner
        Widget connectionBanner = const SizedBox.shrink();
        if (!state.isConnected && state.conversations.isNotEmpty) {
          connectionBanner = Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.errorColor.withOpacityCompat(0.9),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Connecting...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (state.isLoadingConversations && state.conversations.isEmpty) {
          return Column(
            children: [
              connectionBanner,
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              ),
            ],
          );
        }

        if (state.conversationsError != null && state.conversations.isEmpty) {
          return Column(
            children: [
              connectionBanner,
              Expanded(
                child: _buildErrorState(state.conversationsError!),
              ),
            ],
          );
        }

        if (state.conversations.isEmpty) {
          return Column(
            children: [
              connectionBanner,
              Expanded(
                child: _buildEmptyState(),
              ),
            ],
          );
        }

        return Column(
          children: [
            connectionBanner,
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _chatBloc.add(const RefreshConversations());
                  // Wait for refresh to complete
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                color: AppTheme.primaryColor,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = state.conversations[index];
                    final typingUser = state.typingUsers[conversation.id];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ConversationCard(
                        conversation: conversation,
                        currentUserType: state.userType,
                        typingUserName: typingUser,
                        onTap: () => _openChat(conversation, state.userType),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13275D).withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF13275D).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: Color(0xFF13275D),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Conversations Yet',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userType == 'security'
                  ? 'Start a conversation with a resident or tenant'
                  : 'Start a conversation with security gate control',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13275D).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _navigateToSelectRecipient,
                icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                label: Text(
                  'Start Chat',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13275D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacityCompat(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textColor.withOpacityCompat(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _chatBloc.add(const RefreshConversations()),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: AppTheme.primaryElevatedStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFAB() {
    return BlocBuilder<GuardChatBloc, GuardChatState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF13275D).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _navigateToSelectRecipient,
            backgroundColor: const Color(0xFF13275D),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        );
      },
    );
  }

  void _openChat(ConversationModel conversation, String userType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _chatBloc,
          child: GuardChatPage(
            conversationId: conversation.id,
            recipientId: conversation.getOtherParticipantId(userType),
            recipientName: conversation.getDisplayName(userType),
            recipientProfilePic: conversation.getDisplayProfilePic(userType),
            recipientSubtitle: conversation.getDisplaySubtitle(userType),
            currentUserType: userType,
          ),
        ),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      _chatBloc.add(const RefreshConversations());
    });
  }

  void _navigateToSelectRecipient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _chatBloc,
          child: SelectRecipientPage(
            currentUserType: widget.userType,
            onRecipientSelected: (recipient) {
              Navigator.pop(context);
              _openChatWithRecipient(recipient);
            },
          ),
        ),
      ),
    );
  }

  void _openChatWithRecipient(ChatParticipant recipient) {
    // Check if conversation already exists
    final state = _chatBloc.state;
    ConversationModel? existingConversation;

    for (final conv in state.conversations) {
      final otherParticipantId = conv.getOtherParticipantId(state.userType);
      if (otherParticipantId == recipient.id) {
        existingConversation = conv;
        break;
      }
    }

    if (existingConversation != null) {
      _openChat(existingConversation, state.userType);
    } else {
      // Navigate to chat page - it will create conversation on first message
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: _chatBloc,
            child: GuardChatPage(
              conversationId: null,
              recipientId: recipient.id,
              recipientName: recipient.name,
              recipientProfilePic: recipient.profilePic,
              recipientSubtitle: recipient.displaySubtitle,
              currentUserType: state.userType,
            ),
          ),
        ),
      ).then((_) {
        _chatBloc.add(const RefreshConversations());
      });
    }
  }
}

/// Notification bell icon with unread count badge for Messages app bar.
/// Works for both guard and user side (same GuardConversationsPage).
class _NotificationIconWithBadge extends StatelessWidget {
  final int unreadCount;

  const _NotificationIconWithBadge({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    const double iconSize = 24.0;
    const String assetPath = 'assets/notification.svg';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: () {
          // Optional: open notifications or mark as read
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            SvgPicture.asset(
              assetPath,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -10,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
