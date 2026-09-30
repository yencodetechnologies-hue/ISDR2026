import {
  AppBannerCarousel,
  AppHomeHeader,
  AppLivePhotoButton,
  AppLiveShowCard,
  AppModuleGrid,
  DEFAULT_BANNERS,
  HOME_SLOTS,
  type AppModule,
} from "@/components/app/AppHome";
import { AppPage } from "@/components/app/AppChrome";

/**
 * The mobile app's admin modules, in the app's order, with its icons and
 * solid colours (management_module_grid.dart), linked to the website pages.
 */
export const ADMIN_APP_MODULES: AppModule[] = [
  { label: "Brochure", icon: "menu_book", color: "#8B5CF6", to: "/brochure" },
  { label: "Accommodation", icon: "hotel", color: "#0EA5E9", to: "/accommodation" },
  { label: "Events", icon: "confirmation_number", color: "#F97316", to: "/admin/events" },
  { label: "Event Staff", icon: "widgets", color: "#14B8A6", to: "/admin/team?tab=staff" },
  { label: "Admin IDs", icon: "badge", color: "#0EA5E9", to: "/admin/team" },
  { label: "QR Pass", icon: "qr_code_2", color: "#F59E0B", to: "/pass?role=ADMIN&profile=1" },
  { label: "Send Notification", icon: "notifications_active", color: "#EF4444", to: "/admin/send-notification" },
  { label: "Event Schedules", icon: "event_note", color: "#22C55E", to: "/admin/schedules" },
  { label: "Speakers", icon: "groups", color: "#EC4899", to: "/admin/speakers" },
  { label: "Scan Inclusion", icon: "qr_code_scanner", color: "#F59E0B", to: "/staff/events" },
  { label: "Q&A & Polls", icon: "forum", color: "#06B6D4", to: "/admin/engagement" },
  { label: "Add Exhibitors", icon: "add_business", color: "#10B981", to: "/admin/exhibitors" },
  { label: "YouTube Live", icon: "live_tv", color: "#FF0000", to: "/admin/youtube" },
  { label: "Live Photo", icon: "photo_camera", color: "#E11D48", to: "/admin/live-photo" },
  { label: "Banner", icon: "view_carousel", color: "#A855F7", to: "/admin/banner" },
  { label: "News Ticker", icon: "campaign", color: "#0EA5E9", to: "/admin/ticker" },
  { label: "Certificate", icon: "workspace_premium", color: "#F59E0B", to: "/admin/certificates" },
  { label: "Awards", icon: "emoji_events", color: "#EAB308", to: "/awards" },
  { label: "Feed", icon: "photo_library", color: "#EC4899", to: "/feed" },
  { label: "Support Tickets", icon: "support_agent", color: "#EF4444", to: "/support" },
];

/** Admin home at phone width — the app's management home. */
export default function AdminHomeApp() {
  return (
    <div className="min-h-screen bg-bg">
      <AppHomeHeader profilePath="/admin/profile" />
      <AppBannerCarousel images={DEFAULT_BANNERS} />
      <div className="px-4 pt-3.5">
        <AppLiveShowCard />
      </div>
      <div className="px-4 pb-[30px] pt-4">
        <AppModuleGrid title="ADMIN MODULES" modules={ADMIN_APP_MODULES} moreTo="/admin/modules" />
        <div className="mt-3.5">
          <AppLivePhotoButton />
        </div>
      </div>
    </div>
  );
}

/** "More" — the admin modules that don't fit in the home's two rows. */
export function AdminMoreModules() {
  return (
    <AppPage title="More" outfit>
      <div className="pt-0.5">
        <AppModuleGrid title="MORE MODULES" modules={ADMIN_APP_MODULES.slice(HOME_SLOTS - 1)} />
      </div>
    </AppPage>
  );
}
