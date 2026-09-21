import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/tenant_conversation_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/tenant_websocket_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/tenant_chat_bloc.dart';
import '../bloc/tenant_chat_event.dart';
import '../bloc/tenant_chat_state.dart';
import 'tenant_chat_page.dart';

class TenantChatListPage extends StatefulWidget {
  const TenantChatListPage({super.key});

  @override
  State<TenantChatListPage> createState() => _TenantChatListPageState();
}

class _TenantChatListPageState extends State<TenantChatListPage> {
  late TenantChatBloc _chatBloc;

  @override
  void initState() {
    super.initState();

    // Get auth token and user info
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final userId = authState.user.id;
      final userType = authState.user.userType.name;

      // Initialize BLoC
      _chatBloc = TenantChatBloc(
        apiService: ApiService(),
        webSocketService: TenantWebSocketService(),
      );

      // Get token and initialize WebSocket connection asynchronously
      _initializeConnection(userId, userType);
    }
  }

  Future<void> _initializeConnection(String userId, String userType) async {
    final apiService = ApiService();
    final token = await apiService.getToken() ?? '';

    // Initialize WebSocket connection
    TenantWebSocketService().connect(
      token: token,
      userId: userId,
      userType: userType,
    );

    // Load conversations
    _chatBloc.add(const LoadTenantConversations());
  }

  @override
  void dispose() {
    _chatBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Tenant Messages',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<TenantChatBloc, TenantChatState>(
      builder: (context, state) {
        // Connection status banner
        Widget connectionBanner = const SizedBox.shrink();
        if (!state.isConnected && state.conversations.isNotEmpty) {
          connectionBanner = Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.errorColor.withOpacity(0.9),
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        state.conversationsError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<TenantChatBloc>().add(const LoadTenantConversations());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        if (state.conversations.isEmpty) {
          return Column(
            children: [
              connectionBanner,
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting with your tenants',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  context.read<TenantChatBloc>().add(const RefreshTenantConversations());
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = state.conversations[index];
                    final unreadCount = conversation.getUnreadCount(state.userType);
                    final displayName = conversation.getDisplayName(state.userType);
                    final displayPic = conversation.getDisplayProfilePic(state.userType);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                          backgroundImage: displayPic != null && displayPic.isNotEmpty
                              ? NetworkImage(displayPic)
                              : null,
                          child: displayPic == null || displayPic.isEmpty
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(conversation.lastMessageAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TenantChatPage(
                                conversationId: conversation.id,
                                recipientId: conversation.getOtherParticipantId(state.userType),
                                recipientName: displayName,
                                recipientProfilePic: displayPic,
                                currentUserType: state.userType,
                              ),
                            ),
                          );
                        },
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
