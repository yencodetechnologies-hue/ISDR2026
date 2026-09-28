import type { ModuleItem, NavItem } from "@/components/widgets";

/** Admin module tiles – mirrors the Flutter admin dashboard's management module grid. */
export const ADMIN_MODULES: ModuleItem[] = [
  { label: "Events", icon: "event", color: "#3B82F6", to: "/admin/events" },
  { label: "Schedules", icon: "calendar_month", color: "#F97316", to: "/admin/schedules" },
  { label: "Speakers", icon: "mic", color: "#A855F7", to: "/admin/speakers" },
  { label: "Exhibitors", icon: "storefront", color: "#EF4444", to: "/admin/exhibitors" },
  { label: "Notifications", icon: "campaign", color: "#10B981", to: "/admin/send-notification" },
  { label: "Banner", icon: "image", color: "#EC4899", to: "/admin/banner" },
  { label: "News Ticker", icon: "newspaper", color: "#06B6D4", to: "/admin/ticker" },
  { label: "YouTube Live", icon: "smart_display", color: "#DC2626", to: "/admin/youtube" },
  { label: "Feed", icon: "dynamic_feed", color: "#F59E0B", to: "/feed" },
  { label: "Engagement", icon: "analytics", color: "#8B5CF6", to: "/admin/engagement" },
  { label: "Certificates", icon: "workspace_premium", color: "#14B8A6", to: "/admin/certificates" },
  { label: "Team", icon: "group", color: "#6366F1", to: "/admin/team" },
  { label: "Support", icon: "help", color: "#0EA5E9", to: "/support" },
  { label: "Brochure", icon: "menu_book", color: "#84CC16", to: "/brochure" },
  { label: "Awards", icon: "emoji_events", color: "#F59E0B", to: "/awards" },
  { label: "Profile", icon: "person", color: "#9CA3AF", to: "/admin/profile" },
];

export const adminNav: NavItem[] = [
  { label: "Home", icon: "home", to: "/admin" },
  { label: "Events", icon: "event", to: "/admin/events" },
  { label: "Feed", icon: "dynamic_feed", to: "/feed" },
  { label: "QR Pass", icon: "qr_code", to: "/qr-pass" },
  { label: "More", icon: "grid_view", to: "/admin/more" },
];
