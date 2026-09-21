import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/support_message_model.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/services/api_service.dart';

class SupportChatPage extends StatefulWidget {
  final String ticketId;
  final bool isAdmin;

  const SupportChatPage({
    super.key,
    required this.ticketId,
    this.isAdmin = false,
  });

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final ApiService _api = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<SupportMessageModel> _messages = [];
  TicketModel? _ticket;
  String? _ticketError;
  bool _loading = false;
  bool _sending = false;
  bool _closing = false;
  File? _pickedImage;

  bool get _isClosed => _ticket?.status == TicketStatus.closed;

  @override
  void initState() {
    super.initState();
    _loadTicket();
    _loadMessages();
  }

  Future<void> _loadTicket() async {
    setState(() => _ticketError = null);
    try {
      final res = await _api.getTicket(widget.ticketId);
      if (mounted) {
        if (res['success'] == true && res['ticket'] != null) {
          setState(() {
            _ticket = TicketModel.fromJson(res['ticket'] as Map<String, dynamic>);
            _ticketError = null;
          });
        } else {
          setState(() {
            _ticket = null;
            _ticketError = res['error']?.toString() ?? 'Failed to load ticket';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ticket = null;
          _ticketError = e.toString();
        });
      }
    }
  }

  Future<void> _closeTicket() async {
    if (_isClosed || _closing) return;
    setState(() => _closing = true);
    try {
      final res = await _api.updateTicketStatus(widget.ticketId, 'closed');
      if (mounted) {
        setState(() => _closing = false);
        if (res['success'] == true && res['ticket'] != null) {
          setState(() {
            _ticket = TicketModel.fromJson(res['ticket'] as Map<String, dynamic>);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket closed'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Failed to close ticket'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _closing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSupportMessages(widget.ticketId);
      if (mounted) {
        if (res['success'] == true) {
          final list = (res['messages'] as List?)
              ?.map((e) => SupportMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ?? [];
          setState(() {
            _messages = list;
            _loading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        } else {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Failed to load messages'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      setState(() => _pickedImage = File(file.path));
    }
  }

  Future<void> _sendMessage() async {
    if (_isClosed) return;
    final text = _messageController.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    setState(() => _sending = true);
    try {
      final res = await _api.sendSupportMessage(
        widget.ticketId,
        message: text.isEmpty ? null : text,
        image: _pickedImage,
      );
      if (mounted) {
        setState(() {
          _sending = false;
          _messageController.clear();
          _pickedImage = null;
        });
        if (res['success'] == true) {
          final msg = res['message'];
          if (msg != null) {
            setState(() {
              _messages.add(SupportMessageModel.fromJson(msg as Map<String, dynamic>));
            });
            _scrollToBottom();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Failed to send'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTicketError = _ticketError != null && _ticket == null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(titleSpacing: 0,
        title: Text(widget.isAdmin ? 'Support chat ' : 'Support chat'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.isAdmin && !_isClosed)
      ElevatedButton.icon(
    onPressed: _closing ? null : _closeTicket,
      icon: _closing
          ? const SizedBox(
        width: 20,
        height: 15,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : const Icon(Icons.close_rounded),
      label: Text(_closing ? 'Closing...' : 'Close Ticket'),
      style: AppTheme.errorElevatedStyle.copyWith(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    ),
    ],
      ),
      body: showTicketError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      _ticketError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textColor),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _loadTicket,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _loading && _messages.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                      : _messages.isEmpty
                          ? Center(
                              child: Text(
                                'No messages yet. Send one below.',
                                style: TextStyle(color: AppTheme.textColor.withOpacity(0.7)),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isUser = msg.isUser;
                                return _MessageBubble(
                                  message: msg,
                                  isUser: isUser,
                                );
                              },
                            ),
                ),
                if (_isClosed) _buildClosedBanner() else _buildInputArea(),
              ],
            ),
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.dividerColor.withOpacity(0.5),
        border: Border(top: BorderSide(color: AppTheme.textColor.withOpacity(0.2))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.textColor.withOpacity(0.7), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.isAdmin
                    ? 'Ticket closed'
                    : 'This conversation is closed. You cannot send messages.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textColor.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _isClosed ? null : _pickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _pickedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          _pickedImage!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.image_rounded, size: 24, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                readOnly: _isClosed,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.dividerColor.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: (_sending || _isClosed) ? null : _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _sending ? Colors.grey : AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessageModel message;
  final bool isUser;

  const _MessageBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('hh:mm a').format(message.createdAt);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primaryColor
              : AppTheme.dividerColor.withOpacity(0.6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null && message.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.imageUrl!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (message.message != null && message.message!.isNotEmpty)
              Text(
                message.message!,
                style: TextStyle(
                  fontSize: 15,
                  color: isUser ? Colors.white : AppTheme.textColor,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: isUser ? Colors.white70 : AppTheme.textColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
