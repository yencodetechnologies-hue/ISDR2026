import type { ModuleItem } from "@/components/widgets";

/** Admin modules – mirrors the Flutter admin dashboard's management module grid. */
export const ADMIN_MODULES: ModuleItem[] = [
  { label: "Events", sub: "Events & participants", icon: "event", color: "#3B82F6", to: "/admin/events" },
  { label: "Schedules", sub: "Sessions by event", icon: "calendar_month", color: "#F97316", to: "/admin/schedules" },
  { label: "Schedule PDF", sub: "Upload programme PDF", icon: "picture_as_pdf", color: "#F97316", to: "/admin/schedule-pdf" },
  { label: "UG Paper PDF", sub: "Upload presentation PDF", icon: "picture_as_pdf", color: "#F59E0B", to: "/admin/ug-paper-pdf" },
  { label: "Speakers", sub: "Speaker accounts", icon: "mic", color: "#A855F7", to: "/admin/speakers" },
  { label: "Exhibitors", sub: "Trade stalls", icon: "storefront", color: "#EF4444", to: "/admin/exhibitors" },
  {
    label: "Notifications",
    sub: "Send to participants",
    icon: "campaign",
    color: "#10B981",
    to: "/admin/send-notification",
  },
  { label: "Banner", sub: "Home banner images", icon: "image", color: "#EC4899", to: "/admin/banner" },
  { label: "News Ticker", sub: "Scrolling news", icon: "newspaper", color: "#06B6D4", to: "/admin/ticker" },
  { label: "YouTube Live", sub: "Live stream link", icon: "smart_display", color: "#DC2626", to: "/admin/youtube" },
  { label: "Live Photo", sub: "Live gallery link", icon: "photo_camera", color: "#E11D48", to: "/admin/live-photo" },
  { label: "Feed", sub: "Event selfies", icon: "dynamic_feed", color: "#F59E0B", to: "/feed" },
  { label: "Engagement", sub: "Q&A and polls", icon: "analytics", color: "#8B5CF6", to: "/admin/engagement" },
  {
    label: "Certificates",
    sub: "Unlock / revoke",
    icon: "workspace_premium",
    color: "#14B8A6",
    to: "/admin/certificates",
  },
  { label: "Team", sub: "Admin IDs & staff", icon: "group", color: "#6366F1", to: "/admin/team" },
  { label: "Support", sub: "Support tickets", icon: "help", color: "#0EA5E9", to: "/support" },
  { label: "Brochure", sub: "Conference brochure", icon: "menu_book", color: "#84CC16", to: "/brochure" },
  { label: "Awards", sub: "Pick winners", icon: "emoji_events", color: "#F59E0B", to: "/awards" },
  { label: "Preconference", sub: "Add, edit, delete courses", icon: "school", color: "#6366F1", to: "/admin/preconference" },
  { label: "Profile", sub: "Your account", icon: "person", color: "#9CA3AF", to: "/admin/profile" },
];
