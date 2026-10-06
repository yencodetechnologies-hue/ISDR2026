import type { User } from "./auth";

export type Role = "participant" | "speaker" | "apartment" | "user";

/** One sidebar link. `soon` shows a "coming soon" toast instead of navigating. `match` adds extra paths that count as this link. */
export type NavLink = { label: string; icon: string; color: string; to?: string; soon?: string; match?: string[] };
export type NavSection = { title?: string; items: NavLink[] };

export function roleOf(user: User | null): Role | null {
  const t = String(user?.userType ?? "").toLowerCase();
  if (t === "tenant" || t === "user") return "user";
  if (t === "participant" || t === "speaker" || t === "apartment") return t;
  return null;
}

export const ROLE_TITLE: Record<Role, string> = {
  participant: "Delegate Portal",
  speaker: "Speaker Portal",
  apartment: "Admin Console",
  user: "Event Staff Portal",
};

/** Where each role's "profile" link goes. */
export const PROFILE_PATH: Record<Role, string> = {
  participant: "/participant/profile",
  speaker: "/my-profile",
  apartment: "/admin/profile",
  user: "/my-profile",
};

const NAV: Record<Role, NavSection[]> = {
  participant: [
    { items: [{ label: "Home", icon: "space_dashboard", color: "#3B82F6", to: "/participant" }] },
    {
      title: "Programme",
      items: [
        { label: "Schedule", icon: "event_note", color: "#F97316", to: "/participant/schedules" },
        {
          label: "All Sessions",
          icon: "view_agenda",
          color: "#2DD4BF",
          to: "/participant/sessions",
          match: ["/schedule"],
        },
        { label: "Favorites", icon: "star", color: "#E11D48", to: "/participant/favorites" },
        { label: "Speakers", icon: "groups", color: "#A855F7", to: "/participant/speakers" },
      ],
    },
    {
      title: "Engage",
      items: [
        { label: "Q/A", icon: "question_answer", color: "#3B82F6", to: "/participant/qa" },
        { label: "Polls", icon: "poll", color: "#8B5CF6", to: "/participant/polls" },
        { label: "Paper & Poster", icon: "picture_as_pdf", color: "#EA580C", to: "/participant/paper-poster" },
        { label: "Feed", icon: "dynamic_feed", color: "#EC4899", to: "/participant/feed" },
        { label: "Awards", icon: "emoji_events", color: "#F59E0B", to: "/participant/awards" },
      ],
    },
    {
      title: "Conference",
      items: [
        { label: "Preconference", icon: "school", color: "#6366F1", to: "/participant/preconference" },
        { label: "Committee", icon: "account_balance", color: "#A855F7", to: "/participant/committee" },
        { label: "Student Conference", icon: "school", color: "#2563EB", to: "/participant/conference" },
        { label: "Accommodation", icon: "hotel", color: "#0EA5E9", to: "/participant/accommodation" },
        { label: "Exhibitors", icon: "storefront", color: "#EF4444", to: "/participant/exhibitors" },
        { label: "Brochure", icon: "menu_book", color: "#10B981", to: "/brochure" },
        { label: "UG Paper", icon: "picture_as_pdf", color: "#F59E0B", to: "/participant/ug-paper" },
        { label: "Hall Arrangement", icon: "meeting_room", color: "#14B8A6", to: "/participant/hall-arrangement" },
      ],
    },
    {
      title: "My Account",
      items: [
        { label: "QR Pass", icon: "qr_code_2", color: "#10B981", to: "/qr-pass" },
        { label: "Certificate", icon: "workspace_premium", color: "#F59E0B", to: "/participant/certificate" },
        { label: "Notifications", icon: "notifications", color: "#F59E0B", to: "/notifications" },
        { label: "Help & Support", icon: "support_agent", color: "#06B6D4", to: "/support" },
      ],
    },
  ],
  apartment: [
    { items: [{ label: "Dashboard", icon: "space_dashboard", color: "#3B82F6", to: "/admin" }] },
    {
      title: "Event",
      items: [
        { label: "Events", icon: "event", color: "#3B82F6", to: "/admin/events" },
        { label: "Schedules", icon: "calendar_month", color: "#F97316", to: "/admin/schedules", match: ["/schedule"] },
        { label: "Schedule PDF", icon: "picture_as_pdf", color: "#F97316", to: "/admin/schedule-pdf" },
        { label: "UG Paper PDF", icon: "picture_as_pdf", color: "#F59E0B", to: "/admin/ug-paper-pdf" },
        { label: "Paper & Poster", icon: "picture_as_pdf", color: "#EA580C", to: "/admin/paper-poster" },
        { label: "Hall Arrangement", icon: "meeting_room", color: "#14B8A6", to: "/admin/hall-arrangement" },
        { label: "Speakers", icon: "mic", color: "#A855F7", to: "/admin/speakers" },
        { label: "Exhibitors", icon: "storefront", color: "#EF4444", to: "/admin/exhibitors" },
        { label: "Preconference", icon: "school", color: "#6366F1", to: "/admin/preconference" },
      ],
    },
    {
      title: "Engagement",
      items: [
        { label: "Feed", icon: "dynamic_feed", color: "#F59E0B", to: "/feed" },
        { label: "Q&A / Polls", icon: "analytics", color: "#8B5CF6", to: "/admin/engagement" },
        { label: "Certificates", icon: "workspace_premium", color: "#14B8A6", to: "/admin/certificates" },
        { label: "Awards", icon: "emoji_events", color: "#F59E0B", to: "/awards" },
        { label: "Support", icon: "support_agent", color: "#0EA5E9", to: "/support" },
      ],
    },
    {
      title: "Broadcast",
      items: [
        { label: "Send Notification", icon: "campaign", color: "#10B981", to: "/admin/send-notification" },
        { label: "Home Banner", icon: "image", color: "#EC4899", to: "/admin/banner" },
        { label: "News Ticker", icon: "newspaper", color: "#06B6D4", to: "/admin/ticker" },
        { label: "YouTube Live", icon: "smart_display", color: "#DC2626", to: "/admin/youtube" },
        { label: "Live Photo", icon: "photo_camera", color: "#E11D48", to: "/admin/live-photo" },
      ],
    },
    {
      title: "Organisation",
      items: [
        { label: "Team", icon: "group", color: "#6366F1", to: "/admin/team" },
        { label: "Brochure", icon: "menu_book", color: "#84CC16", to: "/brochure" },
        { label: "QR Pass", icon: "qr_code_2", color: "#10B981", to: "/pass?role=ADMIN&profile=1" },
        { label: "Notifications", icon: "notifications", color: "#F59E0B", to: "/notifications" },
      ],
    },
  ],
  speaker: [
    { items: [{ label: "Home", icon: "space_dashboard", color: "#3B82F6", to: "/speaker" }] },
    {
      title: "My Sessions",
      items: [
        {
          label: "Sessions",
          icon: "event_note",
          color: "#A855F7",
          to: "/speaker/sessions?feature=sessions",
          match: ["/schedule"],
        },
        { label: "Q&A", icon: "forum", color: "#3B82F6", to: "/speaker/sessions?feature=qa", match: ["/speaker/qa"] },
        {
          label: "Polls",
          icon: "bar_chart",
          color: "#10B981",
          to: "/speaker/sessions?feature=poll",
          match: ["/speaker/polls"],
        },
        { label: "Participant Questions", icon: "help", color: "#F59E0B", to: "/speaker/questions" },
      ],
    },
    {
      title: "Conference",
      items: [
        { label: "Full Schedule", icon: "calendar_month", color: "#F97316", to: "/sessions" },
        { label: "Speakers", icon: "groups", color: "#EC4899", to: "/speakers" },
        { label: "Accommodation", icon: "hotel", color: "#0EA5E9", to: "/accommodation" },
      ],
    },
    {
      title: "My Account",
      items: [
        { label: "QR Pass", icon: "qr_code_2", color: "#10B981", to: "/pass?role=SPEAKER" },
        { label: "Notifications", icon: "notifications", color: "#F59E0B", to: "/notifications" },
      ],
    },
  ],
  user: [
    { items: [{ label: "Home", icon: "space_dashboard", color: "#3B82F6", to: "/staff" }] },
    {
      title: "Event",
      items: [
        { label: "Events", icon: "event", color: "#F97316", to: "/staff/events" },
        { label: "History", icon: "history", color: "#14B8A6", to: "/staff/history" },
        { label: "Support Tickets", icon: "support_agent", color: "#EF4444", to: "/support" },
        { label: "Accommodation", icon: "hotel", color: "#0EA5E9", to: "/accommodation" },
        { label: "Brochure", icon: "menu_book", color: "#84CC16", to: "/brochure" },
      ],
    },
    {
      title: "My Account",
      items: [
        { label: "QR Pass", icon: "qr_code_2", color: "#10B981", to: "/pass?role=EVENT%20STAFF" },
        { label: "Notifications", icon: "notifications", color: "#F59E0B", to: "/notifications" },
      ],
    },
  ],
};

export const navFor = (role: Role) => NAV[role];

/** The link that best matches the current location (longest path wins; query must match when the link has one). */
export function activeLink(role: Role, pathname: string, search: string): NavLink | null {
  const params = new URLSearchParams(search);
  let best: NavLink | null = null;
  let bestLen = -1;
  for (const section of NAV[role]) {
    for (const link of section.items) {
      if (!link.to) continue;
      const [path, query] = link.to.split("?");
      const paths = [path, ...(link.match ?? [])];
      for (const p of paths) {
        const hit = pathname === p || (p !== "/" && pathname.startsWith(`${p}/`));
        if (!hit) continue;
        if (p === path && query) {
          const want = new URLSearchParams(query);
          if ([...want.entries()].some(([k, v]) => params.get(k) !== v)) continue;
        }
        const len = p.length + (p === path && query ? 1 : 0);
        if (len > bestLen) {
          best = link;
          bestLen = len;
        }
      }
    }
  }
  return best;
}
