import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/tenant_message_model.dart';
import '../../../../core/models/agreement_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/tenant_chat_bloc.dart';
import '../bloc/tenant_chat_event.dart';
import '../bloc/tenant_chat_state.dart';

class TenantChatPage extends StatefulWidget {
  final String? conversationId;
  final String recipientId;
  final String recipientName;
  final String? recipientProfilePic;
  final String currentUserType;

  const TenantChatPage({
    super.key,
    this.conversationId,
    required this.recipientId,
    required this.recipientName,
    this.recipientProfilePic,
    required this.currentUserType,
  });

  @override
  State<TenantChatPage> createState() => _TenantChatPageState();
}

class _TenantChatPageState extends State<TenantChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final ApiService _apiService = ApiService();
  String? _currentConversationId;
  TenantChatBloc? _tenantChatBloc;
  bool _showAgreements = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tenantChatBloc ??= context.read<TenantChatBloc>();
  }

  @override
  void initState() {
    super.initState();
    _currentConversationId = widget.conversationId;

    if (_currentConversationId != null) {
      _loadConversation();
    } else {
      // Get or create conversation
      context.read<TenantChatBloc>().add(
            GetOrCreateTenantConversation(tenantId: widget.recipientId),
          );
    }

    _scrollController.addListener(_onScroll);
  }

  void _loadConversation() {
    final bloc = context.read<TenantChatBloc>();

    // Join conversation room
    bloc.add(JoinTenantConversation(conversationId: _currentConversationId!));

    // Load messages
    bloc.add(LoadTenantMessages(conversationId: _currentConversationId!));

    // Load agreements
    bloc.add(GetAgreements(conversationId: _currentConversationId!));

    // Mark messages as read
    bloc.add(MarkTenantMessagesAsRead(conversationId: _currentConversationId!));
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      final state = context.read<TenantChatBloc>().state;
      if (state.hasMoreMessages &&
          !state.isLoadingMessages &&
          _currentConversationId != null) {
        context.read<TenantChatBloc>().add(LoadTenantMessages(
              conversationId: _currentConversationId!,
              page: state.currentPage + 1,
            ));
      }
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final bloc = context.read<TenantChatBloc>();
    bloc.add(SendTenantMessage(
      conversationId: _currentConversationId,
      recipientId: widget.recipientId,
      message: message,
    ));

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _uploadAgreement() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final conversationId = _currentConversationId ?? widget.conversationId;

        if (conversationId != null) {
          context.read<TenantChatBloc>().add(
                UploadAgreement(
                  conversationId: conversationId,
                  agreementFile: file,
                ),
              );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  Future<void> _downloadAgreement(AgreementModel agreement) async {
    try {
      final result = await _apiService.downloadAgreement(agreement.id);
      if (result['success'] == true) {
        final fileUrl = result['fileUrl'] as String;
        final uri = Uri.parse(fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
    }
  }

  @override
  void dispose() {
    if (_currentConversationId != null && _tenantChatBloc != null) {
      _tenantChatBloc!.add(LeaveTenantConversation(conversationId: _currentConversationId!));
    }
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: widget.recipientProfilePic != null &&
                      widget.recipientProfilePic!.isNotEmpty
                  ? NetworkImage(widget.recipientProfilePic!)
                  : null,
              child: widget.recipientProfilePic == null ||
                      widget.recipientProfilePic!.isEmpty
                  ? Text(
                      widget.recipientName.isNotEmpty
                          ? widget.recipientName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  BlocBuilder<TenantChatBloc, TenantChatState>(
                    builder: (context, state) {
                      return Text(
                        state.isConnected ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: state.isConnected ? Colors.green : Colors.grey,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showAgreements ? Icons.chat : Icons.description),
            onPressed: () {
              setState(() {
                _showAgreements = !_showAgreements;
              });
            },
            tooltip: _showAgreements ? 'Show Messages' : 'Show Agreements',
          ),
        ],
      ),
      body: BlocBuilder<TenantChatBloc, TenantChatState>(
        builder: (context, state) {
          // Update conversation ID when it's created
          if (state.currentConversationId != null &&
              _currentConversationId != state.currentConversationId) {
            _currentConversationId = state.currentConversationId;
            _loadConversation();
          }

          if (_showAgreements) {
            return _buildAgreementsView(state);
          }

          return Column(
            children: [
              Expanded(
                child: _buildMessagesList(state),
              ),
              _buildMessageInput(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessagesList(TenantChatState state) {
    if (state.isLoadingMessages && state.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (state.messagesError != null && state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              state.messagesError!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_currentConversationId != null) {
                  context.read<TenantChatBloc>().add(
                        LoadTenantMessages(conversationId: _currentConversationId!),
                      );
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length + (state.hasMoreMessages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final message = state.messages[state.messages.length - 1 - index];
        final isMe = message.senderId == _getCurrentUserId();

        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(TenantMessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.message != null && message.message!.isNotEmpty)
              Text(
                message.message!,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            if (message.attachments.isNotEmpty) ...[
              if (message.message != null && message.message!.isNotEmpty)
                const SizedBox(height: 8),
              ...message.attachments.map((url) => _buildAttachment(url)),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? Colors.blue.shade300 : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Attachment',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementsView(TenantChatState state) {
    if (state.isLoadingAgreements) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (state.agreementsError != null && state.agreements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              state.agreementsError!,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (state.agreements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No agreements yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload agreements to share with tenant',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.agreements.length,
            itemBuilder: (context, index) {
              final agreement = state.agreements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    agreement.isPdf ? Icons.picture_as_pdf : Icons.description,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  title: Text(
                    agreement.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Size: ${agreement.formattedFileSize}'),
                      if (agreement.description != null)
                        Text(agreement.description!),
                      Text(
                        'Version ${agreement.version} • ${_formatTime(agreement.createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _downloadAgreement(agreement),
                        tooltip: 'Download',
                      ),
                      if (widget.currentUserType == 'user')
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                          onPressed: () {
                            context.read<TenantChatBloc>().add(
                                  DeleteAgreement(agreementId: agreement.id),
                                );
                          },
                          tooltip: 'Delete',
                        ),
                    ],
                  ),
                  onTap: () => _downloadAgreement(agreement),
                ),
              );
            },
          ),
        ),
        if (widget.currentUserType == 'user')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: state.isUploadingAgreement ? null : _uploadAgreement,
              icon: const Icon(Icons.upload_file),
              label: Text(state.isUploadingAgreement ? 'Uploading...' : 'Upload Agreement'),
              style: AppTheme.primaryElevatedStyle.copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageInput(TenantChatState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.currentUserType == 'user')
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: state.isSendingMessage ? null : _uploadAgreement,
              tooltip: 'Upload Agreement',
            ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: state.isSendingMessage
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: state.isSendingMessage ? null : _sendMessage,
            color: AppTheme.primaryColor,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }

  String _getCurrentUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    return '';
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
