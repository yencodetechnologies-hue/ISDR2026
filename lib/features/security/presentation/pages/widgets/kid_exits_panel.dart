import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/kid_exit_model.dart';
import '../../../../../core/services/api_service.dart';

/// Shared kid-exit list for the security dashboard tab and optional bottom sheet.
class KidExitsPanel extends StatefulWidget {
  final List<KidExitModel> kidExits;
  final ScrollController? scrollController;
  final VoidCallback onRefresh;

  /// When true, omits drag handle and close button (used in [TabBarView]).
  final bool embedded;

  const KidExitsPanel({
    super.key,
    required this.kidExits,
    required this.onRefresh,
    this.scrollController,
    this.embedded = false,
  });

  @override
  State<KidExitsPanel> createState() => _KidExitsPanelState();
}

class _KidExitsPanelState extends State<KidExitsPanel> {
  final ApiService _apiService = ApiService();
  final Set<String> _acknowledgedIds = {};

  List<KidExitModel> get _effectiveList {
    return widget.kidExits.map((e) {
      if (_acknowledgedIds.contains(e.id)) {
        return e.copyWith(acknowledgedAt: e.acknowledgedAt ?? DateTime.now());
      }
      return e;
    }).toList();
  }

  int get _pendingCount {
    return widget.kidExits
        .where((e) => !e.isAcknowledged && !_acknowledgedIds.contains(e.id))
        .length;
  }

  Future<void> _acknowledge(KidExitModel exit) async {
    if (exit.isAcknowledged || _acknowledgedIds.contains(exit.id)) return;
    try {
      final response = await _apiService.acknowledgeKidExit(exit.id);
      if (mounted && response['success'] == true) {
        setState(() => _acknowledgedIds.add(exit.id));
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${exit.kidName} — acknowledged'),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  response['error']?.toString() ?? 'Failed to acknowledge'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _effectiveList;
    final pending = _pendingCount;

    final header = Container(
      margin: EdgeInsets.fromLTRB(
          16, widget.embedded ? 12 : 0, 16, widget.embedded ? 16 : 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF13275D),
                  const Color(0xFF13275D).withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13275D).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.child_care_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kid Exits',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Acknowledge when seen',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (list.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (pending > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 13, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text(
                                '$pending pending',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (pending > 0 && list.length - pending > 0)
                        const SizedBox(width: 8),
                      if (list.length - pending > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 13, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text(
                                '${list.length - pending} seen',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!widget.embedded)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  color: Color(0xFF64748B), size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
              ),
            ),
        ],
      ),
    );

    Widget listBody = list.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                      Icons.child_care_rounded,
                      size: 48,
                      color: Color(0xFF13275D),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Kid Exits Today',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Residents notify when a child leaves.\nPull down to refresh.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        : ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final e = list[index];
              final acknowledged =
                  e.isAcknowledged || _acknowledgedIds.contains(e.id);
              final exitTime = e.exitTime.toLocal();
              final timeStr = DateFormat('h:mm a').format(exitTime);
              final dateStr = DateFormat('dd MMM').format(exitTime);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: acknowledged
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: acknowledged ? null : () => _acknowledge(e),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: acknowledged
                                    ? [
                                        AppTheme.secondaryColor.withAlpha(35),
                                        AppTheme.secondaryColor.withAlpha(20),
                                      ]
                                    : [
                                        AppTheme.primaryColor.withAlpha(50),
                                        AppTheme.primaryColor.withAlpha(25),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.child_care_rounded,
                              color: acknowledged
                                  ? AppTheme.secondaryColor
                                  : AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.kidName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textColor,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: acknowledged
                                            ? AppTheme.secondaryColor
                                                .withAlpha(40)
                                            : AppTheme.accentColor
                                                .withAlpha(50),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            acknowledged
                                                ? Icons.check_circle_rounded
                                                : Icons.schedule_rounded,
                                            size: 11,
                                            color: acknowledged
                                                ? AppTheme.secondaryColor
                                                : AppTheme.accentColor,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            acknowledged ? 'Seen' : 'Pending',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: acknowledged
                                                  ? AppTheme.secondaryColor
                                                      .withAlpha(230)
                                                  : AppTheme.accentColor
                                                      .withAlpha(230),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.home_rounded,
                                            size: 12,
                                            color: AppTheme.textColor
                                                .withValues(alpha: 0.55)),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${e.block}-${e.homeNumber}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textColor
                                                  .withValues(alpha: 0.8),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.access_time_rounded,
                                            size: 12,
                                            color: AppTheme.textColor
                                                .withValues(alpha: 0.55)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$dateStr $timeStr',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textColor
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (e.reporterName != null &&
                                    e.reporterName!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reported by ${e.reporterName}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          AppTheme.textColor.withOpacity(0.55),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                if (e.note != null && e.note!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppTheme.dividerColor
                                              .withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.note_rounded,
                                            size: 12,
                                            color: AppTheme.textColor
                                                .withOpacity(0.5)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            e.note!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textColor
                                                  .withOpacity(0.85),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!acknowledged)
                            Material(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _acknowledge(e),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_rounded,
                                          size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Seen',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withAlpha(35),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded,
                                  color: AppTheme.secondaryColor, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                widget.onRefresh();
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: list.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.12),
                        listBody,
                      ],
                    )
                  : listBody,
            ),
          ),
        ],
      );
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        header,
        Expanded(child: listBody),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: column,
    );
  }
}
