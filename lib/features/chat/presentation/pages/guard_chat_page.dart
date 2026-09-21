import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../bloc/guard_chat_bloc.dart';
import '../bloc/guard_chat_event.dart';
import '../bloc/guard_chat_state.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_bubble.dart';

class GuardChatPage extends StatefulWidget {
  final String? conversationId;
  final String recipientId;
  final String recipientName;
  final String? recipientProfilePic;
  final String? recipientSubtitle;
  final String currentUserType;

  const GuardChatPage({
    super.key,
    this.conversationId,
    required this.recipientId,
    required this.recipientName,
    this.recipientProfilePic,
    this.recipientSubtitle,
    required this.currentUserType,
  });

  @override
  State<GuardChatPage> createState() => _GuardChatPageState();
}

class _GuardChatPageState extends State<GuardChatPage> {
  final ScrollController _scrollController = ScrollController();
  String? _currentConversationId;
  GuardChatBloc? _guardChatBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _guardChatBloc ??= context.read<GuardChatBloc>();
  }

  @override
  void initState() {
    super.initState();
    _currentConversationId = widget.conversationId;

    if (_currentConversationId != null) {
      _loadConversation();
    }

    _scrollController.addListener(_onScroll);
  }

  void _loadConversation() {
    final bloc = context.read<GuardChatBloc>();

    // Join conversation room
    bloc.add(JoinConversation(conversationId: _currentConversationId!));

    // Load messages
    bloc.add(LoadMessages(conversationId: _currentConversationId!));

    // Mark messages as read
    bloc.add(MarkMessagesAsRead(conversationId: _currentConversationId!));
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Load more messages when scrolled to top (since list is reversed)
      final state = context.read<GuardChatBloc>().state;
      if (state.hasMoreMessages &&
          !state.isLoadingMessages &&
          _currentConversationId != null) {
        context.read<GuardChatBloc>().add(LoadMessages(
              conversationId: _currentConversationId!,
              page: state.currentPage + 1,
            ));
      }
    }
  }

  @override
  void dispose() {
    if (_currentConversationId != null && _guardChatBloc != null) {
      _guardChatBloc!.add(
            LeaveConversation(conversationId: _currentConversationId!),
          );
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Connection banner
          BlocBuilder<GuardChatBloc, GuardChatState>(
            buildWhen: (prev, curr) => prev.isConnected != curr.isConnected,
            builder: (context, state) {
              if (!state.isConnected) {
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFFECACA), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Connecting to live chat service...',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFDC2626),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Messages list
          Expanded(
            child: BlocConsumer<GuardChatBloc, GuardChatState>(
              listenWhen: (prev, curr) {
                // Listen for new messages to auto-scroll
                return prev.messages.length < curr.messages.length;
              },
              listener: (context, state) {
                // Auto-scroll to bottom on new message
                if (_scrollController.hasClients) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                }

                // Update conversation ID if it was created
                if (_currentConversationId == null &&
                    state.currentConversationId != null) {
                  _currentConversationId = state.currentConversationId;
                }
              },
              builder: (context, state) {
                if (state.isLoadingMessages && state.messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF13275D),
                      ),
                    ),
                  );
                }

                if (state.messagesError != null && state.messages.isEmpty) {
                  return _buildErrorState(state.messagesError!);
                }

                if (state.messages.isEmpty && _currentConversationId == null) {
                  return _buildEmptyState();
                }

                return _buildMessagesList(state);
              },
            ),
          ),

          // Typing indicator
          BlocBuilder<GuardChatBloc, GuardChatState>(
            buildWhen: (prev, curr) => prev.typingUsers != curr.typingUsers,
            builder: (context, state) {
              final typingUser =
                  state.typingUsers[_currentConversationId ?? ''];
              if (typingUser != null) {
                return TypingIndicator(userName: typingUser);
              }
              return const SizedBox.shrink();
            },
          ),

          // Chat input
          BlocBuilder<GuardChatBloc, GuardChatState>(
            buildWhen: (prev, curr) =>
                prev.isSendingMessage != curr.isSendingMessage,
            builder: (context, state) {
              return ChatInput(
                onSend: _sendMessage,
                onTypingStart: () {
                  if (_currentConversationId != null) {
                    context.read<GuardChatBloc>().add(
                          StartTyping(conversationId: _currentConversationId!),
                        );
                  }
                },
                onTypingStop: () {
                  if (_currentConversationId != null) {
                    context.read<GuardChatBloc>().add(
                          StopTyping(conversationId: _currentConversationId!),
                        );
                  }
                },
                isSending: state.isSendingMessage,
              );
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF13275D),
      elevation: 0,
      leadingWidth: 46,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Profile picture
          _buildAvatar(),
          const SizedBox(width: 12),
          // Name and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipientName,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.recipientSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.recipientSubtitle!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2A437E), Color(0xFF13275D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.recipientProfilePic != null &&
              widget.recipientProfilePic!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.recipientProfilePic!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitials(),
                errorWidget: (context, url, error) => _buildInitials(),
              ),
            )
          : _buildInitials(),
    );
  }

  Widget _buildInitials() {
    final initials = widget.recipientName.isNotEmpty
        ? widget.recipientName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMessagesList(GuardChatState state) {
    final messages = state.messages;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length + (state.isLoadingMessages ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingMessages && index == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF13275D),
                  ),
                ),
              ),
            ),
          );
        }

        // Reverse index because list is reversed
        final messageIndex = messages.length - 1 - index;
        final message = messages[messageIndex];
        final isMe = message.senderType == widget.currentUserType;

        // Determine if message is first/last in a group
        final prevMessage =
            messageIndex > 0 ? messages[messageIndex - 1] : null;
        final nextMessage = messageIndex < messages.length - 1
            ? messages[messageIndex + 1]
            : null;

        final isFirstInGroup = prevMessage == null ||
            prevMessage.senderType != message.senderType ||
            _isDifferentDay(prevMessage.createdAt, message.createdAt);

        final isLastInGroup = nextMessage == null ||
            nextMessage.senderType != message.senderType ||
            _isDifferentMinuteGroup(message.createdAt, nextMessage.createdAt);

        // Show date separator
        Widget? dateSeparator;
        if (prevMessage == null ||
            _isDifferentDay(prevMessage.createdAt, message.createdAt)) {
          dateSeparator = DateSeparator(date: message.createdAt);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            MessageBubble(
              message: message,
              isMe: isMe,
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Double-ring icon container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF13275D).withValues(alpha: 0.05),
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF13275D).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 40,
                  color: Color(0xFF13275D),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start the conversation',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF13275D),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a direct message to ${widget.recipientName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 28),
            // Quick suggested prompt chip
            InkWell(
              onTap: () => _sendMessage("Hello! 👋"),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF13275D).withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.waving_hand_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Say Hello 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF13275D),
                      ),
                    ),
                  ],
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textColor.withOpacityCompat(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_currentConversationId != null) {
                  context.read<GuardChatBloc>().add(
                        LoadMessages(conversationId: _currentConversationId!),
                      );
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String message) {
    context.read<GuardChatBloc>().add(SendMessage(
          conversationId: _currentConversationId,
          recipientId: widget.recipientId,
          message: message,
        ));

    // If this is a new conversation, we need to refresh to get the conversation ID
    if (_currentConversationId == null) {
      context.read<GuardChatBloc>().add(
            GetOrCreateConversation(recipientId: widget.recipientId),
          );
    }
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  bool _isDifferentMinuteGroup(DateTime a, DateTime b) {
    // Group messages within 2 minutes of each other
    return b.difference(a).inMinutes > 2;
  }
}
