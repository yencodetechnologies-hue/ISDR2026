import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/post_model.dart';
import '../../../../core/models/poll_model.dart';
import '../../../../core/models/user_event_model.dart';
import '../../../../core/services/api_service.dart';
import 'widgets/delete_feed_item_sheet.dart';

enum _MyContentType { post, poll, event }

class _MyContentItem {
  final _MyContentType type;
  final String id;
  final String titleOrDescription;
  final String? subtitle;

  _MyContentItem({
    required this.type,
    required this.id,
    required this.titleOrDescription,
    this.subtitle,
  });
}

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final ApiService _apiService = ApiService();
  List<_MyContentItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyContent();
  }

  Future<void> _loadMyContent() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getPosts(createdByMe: true),
        _apiService.getPolls(createdByMe: true),
        _apiService.getCommunityEvents(createdByMe: true),
      ]);
      if (!mounted) return;
      final items = <_MyContentItem>[];
      final posts = results[0]['posts'] as List?;
      if (posts != null) {
        for (final e in posts) {
          final post = PostModel.fromJson(e as Map<String, dynamic>);
          final parts = <String>[];
          if (post.block != null && post.block!.isNotEmpty) parts.add('Block ${post.block}');
          if (post.roomNumber != null && post.roomNumber!.isNotEmpty) parts.add('Door ${post.roomNumber}');
          items.add(_MyContentItem(
            type: _MyContentType.post,
            id: post.id,
            titleOrDescription: post.description,
            subtitle: parts.isEmpty ? null : parts.join(' • '),
          ));
        }
      }
      final polls = results[1]['polls'] as List?;
      if (polls != null) {
        for (final e in polls) {
          final poll = PollModel.fromJson(e as Map<String, dynamic>);
          final parts = <String>[];
          if (poll.block != null && poll.block!.isNotEmpty) parts.add('Block ${poll.block}');
          if (poll.roomNumber != null && poll.roomNumber!.isNotEmpty) parts.add('Door ${poll.roomNumber}');
          items.add(_MyContentItem(
            type: _MyContentType.poll,
            id: poll.id,
            titleOrDescription: poll.question,
            subtitle: parts.isEmpty ? null : parts.join(' • '),
          ));
        }
      }
      final events = results[2]['events'] as List?;
      if (events != null) {
        for (final e in events) {
          final event = UserEventModel.fromJson(e as Map<String, dynamic>);
          final parts = <String>[];
          if (event.block != null && event.block!.isNotEmpty) parts.add('Block ${event.block}');
          if (event.venue != null && event.venue!.isNotEmpty) parts.add(event.venue!);
          items.add(_MyContentItem(
            type: _MyContentType.event,
            id: event.id,
            titleOrDescription: event.title,
            subtitle: parts.isEmpty
                ? DateFormat('MMM d, h:mm a').format(event.eventDate)
                : parts.join(' • '),
          ));
        }
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(_MyContentItem item) async {
    String typeLabel;
    switch (item.type) {
      case _MyContentType.post:
        typeLabel = 'post';
        break;
      case _MyContentType.poll:
        typeLabel = 'poll';
        break;
      case _MyContentType.event:
        typeLabel = 'event';
        break;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DeleteFeedItemSheet(
        title: 'Delete $typeLabel',
        message: 'Are you sure you want to delete this $typeLabel?',
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed != true || !mounted) return;
    Map<String, dynamic> res;
    switch (item.type) {
      case _MyContentType.post:
        res = await _apiService.deletePost(item.id);
        break;
      case _MyContentType.poll:
        res = await _apiService.deletePoll(item.id);
        break;
      case _MyContentType.event:
        res = await _apiService.deleteCommunityEvent(item.id);
        break;
    }
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _items.removeWhere((i) => i.id == item.id && i.type == item.type));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$typeLabel deleted'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Failed to delete'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Posts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF2FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.dynamic_feed_rounded,
                            size: 36,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Posts Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Posts, polls, and events you publish to your society will be listed here.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _loadMyContent,
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.primaryColor),
                          label: const Text(
                            'Refresh',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _loadMyContent,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _MyContentTile(
                        item: item,
                        onDelete: () => _deleteItem(item),
                      );
                    },
                  ),
                ),
    );
  }
}

class _MyContentTile extends StatelessWidget {
  final _MyContentItem item;
  final VoidCallback onDelete;

  const _MyContentTile({required this.item, required this.onDelete});

  String get _typeLabel {
    switch (item.type) {
      case _MyContentType.post:
        return 'Post';
      case _MyContentType.poll:
        return 'Poll';
      case _MyContentType.event:
        return 'Event';
    }
  }

  IconData get _typeIcon {
    switch (item.type) {
      case _MyContentType.post:
        return Icons.article_rounded;
      case _MyContentType.poll:
        return Icons.poll_rounded;
      case _MyContentType.event:
        return Icons.event_rounded;
    }
  }

  Color get _typeColor {
    switch (item.type) {
      case _MyContentType.post:
        return AppTheme.primaryColor;
      case _MyContentType.poll:
        return const Color(0xFFD97706); // Amber
      case _MyContentType.event:
        return const Color(0xFF059669); // Emerald
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_typeIcon, color: _typeColor, size: 20),
        ),
        title: Text(
          item.titleOrDescription,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _typeColor,
                  ),
                ),
              ),
              if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
