import type { ModuleItem } from "@/components/widgets";

/** The participant modules, in the app's order. */
export const PARTICIPANT_MODULES: ModuleItem[] = [
  { label: "Schedule", sub: "Upcoming sessions", icon: "event_note", color: "#F97316", to: "/participant/schedules" },
  { label: "Feed", sub: "Event selfies", icon: "dynamic_feed", color: "#EC4899", to: "/participant/feed" },
  {
    label: "Committee",
    sub: "Organising team",
    icon: "account_balance",
    color: "#A855F7",
    to: "/participant/committee",
  },
  { label: "Favorites", sub: "Your saved sessions", icon: "star", color: "#E11D48", to: "/participant/favorites" },
  { label: "Brochure", sub: "Conference brochure", icon: "menu_book", color: "#10B981", to: "/brochure" },
  { label: "Help & Support", sub: "Raise a ticket", icon: "help", color: "#06B6D4", to: "/support" },
  {
    label: "Preconference",
    sub: "Pre-conference courses",
    icon: "school",
    color: "#6366F1",
    to: "/participant/preconference",
  },
  {
    label: "Certificate",
    sub: "Attendance & certificate",
    icon: "workspace_premium",
    color: "#F59E0B",
    to: "/participant/certificate",
  },
  { label: "Exhibitors", sub: "Trade stalls", icon: "storefront", color: "#EF4444", to: "/participant/exhibitors" },
  { label: "Q/A", sub: "Questions & answers", icon: "question_answer", color: "#3B82F6", to: "/participant/qa" },
  { label: "Polls", sub: "Vote on session polls", icon: "poll", color: "#8B5CF6", to: "/participant/polls" },
  { label: "Conference", sub: "Student conference", icon: "school", color: "#2563EB", to: "/participant/conference" },
  { label: "Accommodation", sub: "Stay & services", icon: "hotel", color: "#0EA5E9", to: "/participant/accommodation" },
  { label: "Awards", sub: "Conference awards", icon: "emoji_events", color: "#F59E0B", to: "/participant/awards" },
  { label: "About", sub: "About ISDR", icon: "menu_book", color: "#6366F1", to: "/participant/about" },
];
