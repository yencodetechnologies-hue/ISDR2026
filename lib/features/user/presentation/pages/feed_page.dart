import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/post_model.dart';
import '../../../../core/models/poll_model.dart';
import '../../../../core/models/user_event_model.dart';
import '../../../../core/services/api_service.dart';

enum _FeedItemType { post, poll, event }

class _FeedItem {
  final _FeedItemType type;
  final DateTime sortDate;
  final dynamic data;

  _FeedItem({required this.type, required this.sortDate, required this.data});
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ApiService _apiService = ApiService();
  List<_FeedItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getPosts(),
        _apiService.getPolls(),
        _apiService.getCommunityEvents(),
      ]);
      if (!mounted) return;
      final items = <_FeedItem>[];
      final posts = results[0]['posts'] as List?;
      if (posts != null) {
        for (final e in posts) {
          final post = PostModel.fromJson(e as Map<String, dynamic>);
          items.add(_FeedItem(type: _FeedItemType.post, sortDate: post.createdAt, data: post));
        }
      }
      final polls = results[1]['polls'] as List?;
      if (polls != null) {
        for (final e in polls) {
          final poll = PollModel.fromJson(e as Map<String, dynamic>);
          items.add(_FeedItem(type: _FeedItemType.poll, sortDate: poll.createdAt, data: poll));
        }
      }
      final events = results[2]['events'] as List?;
      if (events != null) {
        for (final e in events) {
          final event = UserEventModel.fromJson(e as Map<String, dynamic>);
          items.add(_FeedItem(type: _FeedItemType.event, sortDate: event.eventDate, data: event));
        }
      }
      items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Feed'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.article_outlined, size: 36, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No posts, polls, or events yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFeed,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      if (item.type == _FeedItemType.post) {
                        return _PostCard(post: item.data as PostModel);
                      }
                      if (item.type == _FeedItemType.poll) {
                        return _PollCard(
                          poll: item.data as PollModel,
                          apiService: _apiService,
                          onVoteSuccess: _loadFeed,
                        );
                      }
                      return _EventCard(event: item.data as UserEventModel);
                    },
                  ),
                ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (post.block != null && post.block!.isNotEmpty) parts.add('Block ${post.block}');
    if (post.floor != null && post.floor!.isNotEmpty) parts.add('Floor ${post.floor}');
    if (post.roomNumber != null && post.roomNumber!.isNotEmpty) parts.add('Door ${post.roomNumber}');
    final location = parts.isEmpty ? null : parts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEEF2FF),
                  backgroundImage: post.createdByProfilePic != null
                      ? NetworkImage(post.createdByProfilePic!)
                      : null,
                  child: post.createdByProfilePic == null
                      ? const Icon(Icons.person, color: AppTheme.primaryColor, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.createdByName ?? 'Resident',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                      if (location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textColor.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.description,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textColor,
                height: 1.4,
              ),
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  height: 200,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (post.link != null && post.link!.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {},
                child: Text(
                  post.link!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _PollCard extends StatefulWidget {
  final PollModel poll;
  final ApiService apiService;
  final VoidCallback onVoteSuccess;

  const _PollCard({
    required this.poll,
    required this.apiService,
    required this.onVoteSuccess,
  });

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  bool _voting = false;

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _vote(int optionIndex) async {
    if (_voting || widget.poll.myVoteOptionIndex != null) return;
    setState(() => _voting = true);
    try {
      final res = await widget.apiService.votePoll(widget.poll.id, optionIndex);
      if (!mounted) return;
      if (res['success'] == true) {
        widget.onVoteSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to vote'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final parts = <String>[];
    if (poll.block != null && poll.block!.isNotEmpty) parts.add('Block ${poll.block}');
    if (poll.floor != null && poll.floor!.isNotEmpty) parts.add('Floor ${poll.floor}');
    if (poll.roomNumber != null && poll.roomNumber!.isNotEmpty) parts.add('Door ${poll.roomNumber}');
    final location = parts.isEmpty ? null : parts.join(' • ');
    final hasVoteCounts = poll.optionVoteCounts.isNotEmpty &&
        poll.optionVoteCounts.length == poll.options.length;
    final totalVotes = poll.totalVotes;
    final alreadyVoted = poll.myVoteOptionIndex != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.poll_rounded, color: Color(0xFFEA580C), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poll.createdByName ?? 'Resident',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                      if (location != null)
                        Text(
                          location,
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textColor.withValues(alpha: 0.6)),
                        ),
                      Text(
                        _formatDate(poll.createdAt),
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textColor.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              poll.question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(poll.options.length, (index) {
              final option = poll.options[index];
              final count = hasVoteCounts && index < poll.optionVoteCounts.length
                  ? poll.optionVoteCounts[index]
                  : 0;
              final isSelected = poll.myVoteOptionIndex == index;
              final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: _voting || alreadyVoted ? null : () => _vote(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: AppTheme.textColor,
                                ),
                              ),
                              if (hasVoteCounts && totalVotes > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 5,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isSelected ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (hasVoteCounts)
                          Text(
                            '$count vote${count != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textColor.withValues(alpha: 0.6),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (totalVotes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$totalVotes total vote${totalVotes != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textColor.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final UserEventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (event.block != null && event.block!.isNotEmpty) parts.add('Block ${event.block}');
    if (event.floor != null && event.floor!.isNotEmpty) parts.add('Floor ${event.floor}');
    if (event.roomNumber != null && event.roomNumber!.isNotEmpty) parts.add('Door ${event.roomNumber}');
    final location = parts.isEmpty ? null : parts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_rounded, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.createdByName ?? 'Resident',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                      if (location != null)
                        Text(
                          location,
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textColor.withValues(alpha: 0.6)),
                        ),
                      Text(
                        DateFormat('MMM d, y • hh:mm a').format(event.eventDate),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              event.description,
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textColor.withValues(alpha: 0.85),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (event.venue != null && event.venue!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: AppTheme.textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.venue!,
                      style: TextStyle(fontSize: 12, color: AppTheme.textColor.withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  event.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  height: 160,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
