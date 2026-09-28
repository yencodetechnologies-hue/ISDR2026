import type { ModuleItem, NavItem } from "@/components/widgets";

/** The participant module tiles, in the app's order. */
export const PARTICIPANT_MODULES: ModuleItem[] = [
  { label: "Schedule", icon: "event_note", color: "#F97316", to: "/participant/schedules" },
  { label: "Feed", icon: "dynamic_feed", color: "#EC4899", to: "/participant/feed" },
  { label: "Committee", icon: "account_balance", color: "#A855F7", to: "/participant/committee" },
  { label: "Favorites", icon: "star", color: "#E11D48", to: "/participant/favorites" },
  { label: "Brochure", icon: "menu_book", color: "#10B981", to: "/brochure" },
  { label: "Help & Support", icon: "help", color: "#06B6D4", to: "/support" },
  { label: "Certificate", icon: "workspace_premium", color: "#F59E0B", to: "/participant/certificate" },
  { label: "Exhibitors", icon: "storefront", color: "#EF4444", to: "/participant/exhibitors" },
  { label: "Q/A", icon: "question_answer", color: "#3B82F6", to: "/participant/qa" },
  { label: "Polls", icon: "poll", color: "#8B5CF6", to: "/participant/polls" },
  { label: "About", icon: "menu_book", color: "#6366F1", to: "/participant/about" },
  { label: "Conference", icon: "school", color: "#2563EB", to: "/participant/conference" },
  { label: "Accommodation", icon: "hotel", color: "#0EA5E9", to: "/participant/accommodation" },
  { label: "Awards", icon: "emoji_events", color: "#F59E0B", to: "/participant/awards" },
];

/** The grid shows 11 real tiles + "More"; the rest live on the More page. */
export const HOME_SLOTS = 11;

export const participantNav: NavItem[] = [
  { label: "Home", icon: "home", to: "/participant" },
  { label: "Favorites", icon: "favorite", to: "/participant/favorites" },
  { label: "Speaker", icon: "groups", to: "/participant/speakers" },
  { label: "QR Pass", icon: "qr_code", to: "/qr-pass" },
  { label: "More", icon: "grid_view", to: "/participant/more" },
];
