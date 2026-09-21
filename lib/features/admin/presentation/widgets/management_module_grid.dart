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
  _ModuleVisual('Overview', Icons.grid_view_rounded, group: 'OVERVIEW', active: true),
  _ModuleVisual('Blocks', Icons.apartment_rounded, group: 'OVERVIEW'),
  _ModuleVisual('Users', Icons.people_alt_rounded, group: 'OVERVIEW'),
  _ModuleVisual('Staffs', Icons.people_alt_rounded, group: 'OVERVIEW'),

  _ModuleVisual('Events', Icons.confirmation_number_rounded, group: 'COMMUNITY'),
  _ModuleVisual('Security', Icons.shield_rounded, group: 'COMMUNITY'),
  _ModuleVisual('Visitors', Icons.badge_rounded, group: 'COMMUNITY'),
  _ModuleVisual('Complaints', Icons.warning_amber_rounded, group: 'COMMUNITY', accent: true),
  _ModuleVisual('Assign pay', Icons.payments_rounded, group: 'COMMUNITY'),
  _ModuleVisual('Out pass', Icons.exit_to_app_rounded, group: 'COMMUNITY'),
  _ModuleVisual('Amenities', Icons.pool_rounded, group: 'COMMUNITY'),

  _ModuleVisual('Notices', Icons.campaign_rounded, group: 'OPERATIONS', accent: true),
  _ModuleVisual('Facility', Icons.build_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Maintenance', Icons.handyman_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Support', Icons.support_agent_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Ads', Icons.ads_click_rounded, group: 'OPERATIONS'),
  _ModuleVisual('Documents', Icons.description_rounded, group: 'OPERATIONS'),

  _ModuleVisual('Subscription', Icons.dns_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Management IDs', Icons.badge_outlined, group: 'ACCOUNT'),
  _ModuleVisual('Brochure', Icons.menu_book_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Profile', Icons.person_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Send Notification', Icons.notifications_active_rounded, group: 'ACCOUNT'),
  _ModuleVisual('Event Schedules', Icons.event_note_rounded, group: 'ACCOUNT'),
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
        orElse: () => _ModuleVisual(label, Icons.widgets_rounded, group: 'OPERATIONS'),
      );
      activeVisuals.add(match);
    }

    // Group items by category
    const groupOrder = ['OVERVIEW', 'COMMUNITY', 'OPERATIONS', 'ACCOUNT'];
    final Map<String, List<_ModuleVisual>> groupedMap = {};

    for (final item in activeVisuals) {
      groupedMap.putIfAbsent(item.group, () => []).add(item);
    }

    final List<_ModuleGroupData> groups = [];
    if (activeVisuals.length <= 8) {
      // Streamlined view for School/College properties: group into a single clean grid
      groups.add(_ModuleGroupData('MANAGEMENT MODULES', activeVisuals));
    } else {
      for (final groupTitle in groupOrder) {
        if (groupedMap.containsKey(groupTitle) && groupedMap[groupTitle]!.isNotEmpty) {
          groups.add(_ModuleGroupData(groupTitle, groupedMap[groupTitle]!));
          groupedMap.remove(groupTitle);
        }
      }
      groupedMap.forEach((title, items) {
        if (items.isNotEmpty) {
          groups.add(_ModuleGroupData(title, items));
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _GroupSection(
            group: group,
            onModuleTap: onModuleTap,
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group Section Widget
// ---------------------------------------------------------------------------
class _GroupSection extends StatelessWidget {
  final _ModuleGroupData group;
  final ValueChanged<String> onModuleTap;

  const _GroupSection({
    required this.group,
    required this.onModuleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text(
            group.title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
              color: AppColors.muted,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: group.items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final item = group.items[index];
            return _ModuleTile(
              item: item,
              onTap: () => onModuleTap(item.label),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Module Tile Widget
// ---------------------------------------------------------------------------
class _ModuleTile extends StatefulWidget {
  final _ModuleVisual item;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.item,
    required this.onTap,
  });

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final iconBg = item.active
        ? Colors.white.withOpacity(.20)
        : item.accent
            ? AppColors.orange.withOpacity(.14)
            : AppColors.iconBg;
    final iconColor = item.active
        ? Colors.white
        : item.accent
            ? AppColors.orangeDeep
            : AppColors.ink;
    final labelColor = item.active ? Colors.white : AppColors.ink;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: item.active
                ? const LinearGradient(
                    colors: [AppColors.ink, AppColors.charcoal2],
                  )
                : null,
            color: item.active ? null : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: item.active ? null : Border.all(color: AppColors.line),
            boxShadow: [
              if (!item.active)
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
