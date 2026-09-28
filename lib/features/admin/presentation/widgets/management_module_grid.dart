import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
class AppColors {
  static const ink = Color(0xFF0F172A);
  static const charcoal2 = Color(0xFF1E3A8A);
  static const orange = Color(0xFF13275D);
  static const orangeDeep = Color(0xFF0284C7);
  static const bg = Color(0xFFFAFAF9);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8C8C90);
  static const line = Color(0xFFECECEA);
  static const iconBg = Color(0xFFF2F2F1);
}

// ---------------------------------------------------------------------------
// Data models & Visual Mappings
// ---------------------------------------------------------------------------
class _ModuleVisual {
  final String label;
  final IconData icon;
  final String group;
  final bool active;
  final bool accent;

  const _ModuleVisual(
    this.label,
    this.icon, {
    required this.group,
    this.active = false,
    this.accent = false,
  });
}

const List<_ModuleVisual> _predefinedVisuals = [
  _ModuleVisual(
    'Overview',
    Icons.grid_view_rounded,
    group: 'OVERVIEW',
    active: true,
  ),
  _ModuleVisual('Blocks', Icons.apartment_rounded, group: 'OVERVIEW'),
  _ModuleVisual('Users', Icons.people_alt_rounded, group: 'OVERVIEW'),
  _ModuleVisual('Staffs', Icons.people_alt_rounded, group: 'OVERVIEW'),

  _ModuleVisual(
    'Events',
    Icons.confirmation_number_rounded,
    group: 'COMMUNITY',
  ),
  _ModuleVisual(
    'Complaints',
    Icons.warning_amber_rounded,
    group: 'COMMUNITY',
    accent: true,
  ),
  _ModuleVisual('Out pass', Icons.exit_to_app_rounded, group: 'COMMUNITY'),
  _ModuleVisual('Amenities', Icons.pool_rounded, group: 'COMMUNITY'),

  _ModuleVisual(
    'Notices',
    Icons.campaign_rounded,
    group: 'OPERATIONS',
    accent: true,
  ),
  _ModuleVisual('Facility', Icons.build_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Maintenance', Icons.handyman_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Support', Icons.support_agent_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Ads', Icons.ads_click_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Documents', Icons.description_rounded, group: 'OPERATIONS'),

  _ModuleVisual('Admin IDs', Icons.badge_outlined, group: 'ACCOUNT'),
  _ModuleVisual('Brochure', Icons.menu_book_rounded, group: 'ACCOUNT'),
  _ModuleVisual('QR Pass', Icons.qr_code_2_rounded, group: 'ACCOUNT'),
  _ModuleVisual(
    'Send Notification',
    Icons.notifications_active_rounded,
    group: 'ACCOUNT',
  ),
  _ModuleVisual('Event Schedules', Icons.event_note_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Speakers', Icons.groups_rounded, group: 'ACCOUNT'),
  _ModuleVisual(
    'Scan Inclusion',
    Icons.qr_code_scanner_rounded,
    group: 'ACCOUNT',
  ),
  _ModuleVisual('Q&A & Polls', Icons.forum_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Add Exhibitors', Icons.add_business_rounded, group: 'ACCOUNT'),
  _ModuleVisual('YouTube Live', Icons.live_tv_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Banner', Icons.view_carousel_rounded, group: 'ACCOUNT'),
  _ModuleVisual('News Ticker', Icons.campaign_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Entry / Exit Scan', Icons.qr_code_scanner_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Certificate', Icons.workspace_premium_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Awards', Icons.emoji_events_rounded, group: 'ACCOUNT'),
  _ModuleVisual(
    'Support Tickets',
    Icons.support_agent_rounded,
    group: 'ACCOUNT',
  ),
];

class _ModuleGroupData {
  final String title;
  final List<_ModuleVisual> items;
  const _ModuleGroupData(this.title, this.items);
}

// ---------------------------------------------------------------------------
// Main Module Grid Widget
// ---------------------------------------------------------------------------
class ManagementModuleGrid extends StatelessWidget {
  final List<String> moduleLabels;
  final ValueChanged<String> onModuleTap;

  const ManagementModuleGrid({
    super.key,
    required this.moduleLabels,
    required this.onModuleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (moduleLabels.isEmpty) return const SizedBox.shrink();

    // Map labels to visual items
    final List<_ModuleVisual> activeVisuals = [];
    for (final label in moduleLabels) {
      if (label.toLowerCase() == 'overview') continue;
      final match = _predefinedVisuals.firstWhere(
        (v) => v.label.toLowerCase() == label.toLowerCase(),
        orElse: () =>
            _ModuleVisual(label, Icons.widgets_rounded, group: 'OPERATIONS'),
      );
      activeVisuals.add(match);
    }

    // Everything in one "MANAGEMENT MODULES" box.
    final groups = [_ModuleGroupData('ADMIN MODULES', activeVisuals)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _GroupSection(group: group, onModuleTap: onModuleTap),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group Section Widget — the participant homepage's boxed 6-column grid
// ---------------------------------------------------------------------------
class _GroupSection extends StatelessWidget {
  final _ModuleGroupData group;
  final ValueChanged<String> onModuleTap;

  const _GroupSection({required this.group, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8, left: 2),
          child: Text(
            group.title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF14141F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              // 4 across: management labels are longer than the participant
              // ones and would break mid-word in 6 narrow columns.
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 2,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final item = group.items[index];
              return _ModuleTile(
                item: item,
                onTap: () => onModuleTap(item.label),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Solid colour of each module's icon square (participant homepage palette).
Color _moduleColor(String label) {
  const colors = <String, Color>{
    'brochure': Color(0xFF8B5CF6),
    'events': Color(0xFFF97316),
    'event staff': Color(0xFF14B8A6),
    'staffs': Color(0xFF14B8A6),
    'admin ids': Color(0xFF0EA5E9),
    'profile': Color(0xFF6366F1),
    'send notification': Color(0xFFEF4444),
    'event schedules': Color(0xFF22C55E),
    'speakers': Color(0xFFEC4899),
    'scan inclusion': Color(0xFFF59E0B),
    'q&a & polls': Color(0xFF06B6D4),
    'add exhibitors': Color(0xFF10B981),
    'youtube live': Color(0xFFFF0000),
    'banner': Color(0xFFA855F7),
    'news ticker': Color(0xFF0EA5E9),
    'entry / exit scan': Color(0xFF10B981),
    'certificate': Color(0xFFF59E0B),
    'awards': Color(0xFFEAB308),
    'support tickets': Color(0xFFEF4444),
  };
  const fallback = [
    Color(0xFF2563EB),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFF06B6D4),
  ];
  return colors[label.toLowerCase()] ??
      fallback[label.length % fallback.length];
}

// ---------------------------------------------------------------------------
// Module Tile Widget — solid coloured icon square with the label under it
// ---------------------------------------------------------------------------
class _ModuleTile extends StatefulWidget {
  final _ModuleVisual item;
  final VoidCallback onTap;

  const _ModuleTile({required this.item, required this.onTap});

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _moduleColor(item.label),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
