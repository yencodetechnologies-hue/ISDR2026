/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  AppBannerCarousel,
  AppHomeHeader,
  AppLivePhotoButton,
  AppLiveShowCard,
  AppModuleGrid,
  AppTickerStrap,
  HOME_SLOTS,
  type AppModule,
} from "@/components/app/AppHome";
import { AppPage } from "@/components/app/AppChrome";
import { Icon } from "@/components/ui";
import { ReminderSheet, YoutubeLiveCapsule, tickerTextFromLines, useHomeBanner } from "@/components/widgets";
import { get } from "@/lib/api";
import { fmtTimeStr, sameDay } from "@/lib/format";
import {
  loadAllSchedules,
  loadFavorites,
  scheduleHref,
  toggleFavorite,
  type ScheduleItem,
} from "@/lib/schedules";

export const PARTICIPANT_APP_MODULES: AppModule[] = [
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

const SOCIAL_LINKS = [
  {
    label: "Facebook",
    img: "https://img.icons8.com/color/96/facebook-new.png",
    url: "https://www.facebook.com/sbdch.dental",
  },
  {
    label: "Instagram",
    img: "https://img.icons8.com/color/96/instagram-new.png",
    url: "https://www.instagram.com/sbdch_dental/",
  },
  {
    label: "YouTube",
    img: "https://img.icons8.com/color/96/youtube-play.png",
    url: "https://www.youtube.com/@TheDental-Classroom",
  },
  { label: "X", img: "https://img.icons8.com/color/96/twitterx.png", url: "https://x.com/sbdch_dental" },
  {
    label: "LinkedIn",
    img: "https://img.icons8.com/color/96/linkedin.png",
    url: "https://www.linkedin.com/school/sree-balaji-dental-college-and-hospital/?originalSubdomain=in",
  },
];

const SCHEDULE_ACCENTS = ["#14B8A6", "#2563EB", "#8B5CF6", "#F59E0B"];

function AdminNewsTicker() {
  const [text, setText] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    const load = () =>
      get("/news-ticker").then((r) => {
        if (!alive || !r.success || !r.ticker) return;
        const t = r.ticker.enabled === false ? "" : tickerTextFromLines(String(r.ticker.text ?? ""));
        setText(t || null);
      });
    load();
    const id = setInterval(load, 60000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, []);
  if (!text) return null;
  return <AppTickerStrap text={text} />;
}

export function ParticipantBottomNav({ activeTab = "home" }: { activeTab?: "home" | "favorites" | "speaker" | "qr" | "more" }) {
  const navigate = useNavigate();
  const items = [
    { key: "home", label: "Home", icon: "home", to: "/participant" },
    { key: "favorites", label: "Favorites", icon: "favorite", to: "/participant/favorites" },
    { key: "speaker", label: "Speaker", icon: "groups", to: "/participant/speakers" },
    { key: "qr", label: "QR Pass", icon: "qr_code", to: "/qr-pass" },
    { key: "more", label: "More", icon: "grid_view", to: "/participant/more" },
  ];
  return (
    <nav
      aria-label="Bottom Navigation"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-white/[0.08] bg-[#0A0A12] pb-[env(safe-area-inset-bottom)]"
    >
      <div className="flex h-[58px] items-center">
        {items.map((it) => {
          const active = it.key === activeTab;
          return (
            <button
              key={it.key}
              onClick={() => navigate(it.to)}
              className="flex flex-1 flex-col items-center justify-center transition active:scale-95"
            >
              <Icon
                name={it.icon}
                size={22}
                color={active ? "#60A5FA" : "rgba(255,255,255,0.6)"}
              />
              <span
                className="mt-1 font-outfit text-[10.5px] font-semibold tracking-[0.2px]"
                style={{ color: active ? "#60A5FA" : "rgba(255,255,255,0.6)" }}
              >
                {it.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}

/** Participant home at phone width — the mobile app's ParticipantHomePage. */
export default function ParticipantHomeApp() {
  const navigate = useNavigate();
  const bannerUrls = useHomeBanner();
  const [items, setItems] = useState<ScheduleItem[]>([]);
  const [eventDays, setEventDays] = useState<Date[]>([]);
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);
  const [showAllDaySessions, setShowAllDaySessions] = useState(false);
  const [favIds, setFavIds] = useState<Set<string>>(new Set());
  const [reminderItem, setReminderItem] = useState<{ id: string; name: string; start: Date } | null>(null);

  const loadData = useCallback(async () => {
    const res = await loadAllSchedules();
    if (!res.error) {
      setItems(res.items);
      const days = res.days.length
        ? res.days
        : [...new Set(res.items.map((i) => new Date(i.start.getFullYear(), i.start.getMonth(), i.start.getDate()).getTime()))]
            .map((t) => new Date(t))
            .sort((a, b) => a.getTime() - b.getTime());
      setEventDays(days);
      const today = new Date();
      const matchToday = days.find((d) => sameDay(d, today));
      setSelectedDay((prev) => prev ?? (matchToday || days[0] || null));
    }
    const favs = await loadFavorites();
    setFavIds(favs);
  }, []);

  useEffect(() => {
    loadData();
    const t = setInterval(loadData, 30000);
    return () => clearInterval(t);
  }, [loadData]);

  const onToggleFav = async (e: React.MouseEvent, scheduleId: string) => {
    e.stopPropagation();
    setFavIds((prev) => {
      const next = new Set(prev);
      if (next.has(scheduleId)) next.delete(scheduleId);
      else next.add(scheduleId);
      return next;
    });
    await toggleFavorite(scheduleId);
  };

  const dayItems = selectedDay
    ? items.filter((it) => sameDay(it.start, selectedDay)).sort((a, b) => a.start.getTime() - b.start.getTime())
    : [];

  const DAY_SESSIONS_SHOWN = 3;
  const visibleDayItems = showAllDaySessions ? dayItems : dayItems.slice(0, DAY_SESSIONS_SHOWN);
  const extraSessionsCount = dayItems.length - DAY_SESSIONS_SHOWN;
  const now = new Date();

  return (
    <div className="min-h-screen bg-bg pb-[80px]">
      {/* 1. App Header */}
      <AppHomeHeader profilePath="/participant/profile" />

      {/* Hero Live Show Card */}
      <div className="px-4 py-3">
        <AppLiveShowCard />
      </div>

      {/* News Ticker */}
      <div className="px-4 pb-2.5">
        <AdminNewsTicker />
      </div>

      <div className="space-y-5 px-4">
        {/* 2. Participant Module Grid */}
        <AppModuleGrid
          title="PARTICIPANT MODULES"
          modules={PARTICIPANT_APP_MODULES}
          moreTo="/participant/more"
        />

        {/* YouTube Live Capsule */}
        <YoutubeLiveCapsule />

        {/* Admin image banner (if configured) */}
        {bannerUrls.length > 0 && (
          <div className="overflow-hidden rounded-2xl">
            <AppBannerCarousel images={bannerUrls} height={160} />
          </div>
        )}

        {/* Today's Schedule (day tabs + list) */}
        {eventDays.length > 0 && (
          <div>
            <div className="flex items-center justify-between">
              <h2 className="font-outfit text-base font-extrabold text-white">Today's Schedule</h2>
              <button
                onClick={() => navigate("/sessions")}
                className="flex items-center gap-0.5 text-[12.5px] font-semibold text-white/60 hover:text-white"
              >
                <span>View All</span>
                <Icon name="chevron_right" size={16} />
              </button>
            </div>

            {/* Horizontal Day Tabs */}
            <div className="mt-2.5 flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              {eventDays.map((d, i) => {
                const active = selectedDay && sameDay(d, selectedDay);
                return (
                  <button
                    key={d.getTime()}
                    onClick={() => {
                      setSelectedDay(d);
                      setShowAllDaySessions(false);
                    }}
                    className={`flex min-w-[70px] flex-1 flex-col items-center justify-center rounded-[7px] py-1.5 transition ${
                      active
                        ? "border-[1.4px] border-[#2DD4BF] bg-[#0D2B28] shadow-[0_0_14px_rgba(45,212,191,0.55)]"
                        : "border border-white/[0.08] bg-[#14141F]"
                    }`}
                  >
                    <span
                      className={`text-xs font-bold ${
                        active ? "text-[#2DD4BF]" : "text-white/80"
                      }`}
                    >
                      Day {i + 1}
                    </span>
                    <span
                      className={`text-[10.5px] ${
                        active ? "text-[#2DD4BF]" : "text-white/50"
                      }`}
                    >
                      {d.toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                    </span>
                  </button>
                );
              })}
            </div>

            {/* Day Sessions List */}
            <div className="mt-3 space-y-2.5">
              {dayItems.length === 0 ? (
                <div className="rounded-xl border border-dashed border-white/10 py-6 text-center text-xs text-white/50">
                  {selectedDay ? "No sessions on this day" : "Tap a day to see its sessions"}
                </div>
              ) : (
                visibleDayItems.map((it, idx) => {
                  const s = it.schedule ?? {};
                  const scheduleId = String(s.id ?? s._id ?? "");
                  const isLive = now >= it.start && now < it.end;
                  const isDone = now >= it.end;
                  const rowAccent = isLive
                    ? "#22C55E"
                    : isDone
                      ? "#64748B"
                      : SCHEDULE_ACCENTS[idx % SCHEDULE_ACCENTS.length];
                  const isFav = favIds.has(scheduleId);
                  const fromTime = String(s.fromTime ?? "");
                  const toTime = String(s.toTime ?? "");

                  return (
                    <div
                      key={scheduleId}
                      onClick={() => navigate(scheduleHref(it))}
                      className="group relative cursor-pointer overflow-hidden rounded-[14px] border bg-[#14141F] transition hover:bg-white/[0.03]"
                      style={{ borderColor: `${rowAccent}66` }}
                    >
                      <div className="flex items-stretch">
                        <span className="w-1 shrink-0" style={{ background: rowAccent }} />
                        <div className="flex flex-1 items-center p-3">
                          <div
                            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px]"
                            style={{ background: `${rowAccent}26` }}
                          >
                            <Icon name="calendar_today" size={16} color={rowAccent} />
                          </div>
                          <div className="ml-2.5 min-w-0 flex-1">
                            {fromTime && toTime && (
                              <div className="text-[11px] font-semibold text-white/50">
                                {fmtTimeStr(fromTime)} - {fmtTimeStr(toTime)}
                              </div>
                            )}
                            <div className="truncate font-outfit text-sm font-bold text-white group-hover:text-[#60A5FA]">
                              {s.scheduleName}
                            </div>
                            {s.hall && (
                              <div className="mt-0.5 flex items-center gap-1 text-[11px] text-white/45">
                                <Icon name="location_on" size={12} />
                                <span className="truncate">{s.hall}</span>
                              </div>
                            )}
                          </div>
                          <div className="flex shrink-0 items-center gap-1 pl-1">
                            <span
                              className="rounded-full px-2 py-0.5 text-[10px] font-extrabold"
                              style={{ background: `${rowAccent}2e`, color: rowAccent }}
                            >
                              {isLive ? "Live" : isDone ? "Completed" : "Upcoming"}
                            </span>
                            {!isLive && !isDone && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  setReminderItem({ id: scheduleId, name: String(s.scheduleName ?? ""), start: it.start });
                                }}
                                aria-label="Remind me"
                                className="flex h-8 w-8 items-center justify-center rounded-full text-white/45 hover:text-white"
                              >
                                <Icon name="notifications_none" size={20} />
                              </button>
                            )}
                            <button
                              onClick={(e) => onToggleFav(e, scheduleId)}
                              aria-label="Favorite"
                              className="flex h-8 w-8 items-center justify-center rounded-full"
                              style={{ color: isFav ? "#EF4444" : "rgba(255,255,255,0.45)" }}
                            >
                              <Icon name={isFav ? "favorite" : "favorite_border"} size={20} />
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                })
              )}

              {/* More / Show Less Toggle Button */}
              {extraSessionsCount > 0 && (
                <button
                  onClick={() => setShowAllDaySessions((prev) => !prev)}
                  className="flex w-full items-center justify-center gap-1 rounded-xl border border-white/[0.08] bg-[#14141F] py-2.5 font-inter text-[12.5px] font-bold text-[#60A5FA] active:bg-white/5"
                >
                  <span>{showAllDaySessions ? "Show less" : `More (${extraSessionsCount})`}</span>
                  <Icon
                    name={showAllDaySessions ? "keyboard_arrow_up" : "keyboard_arrow_down"}
                    size={20}
                  />
                </button>
              )}
            </div>

            {/* CE / CME Credits Banner */}
            <div
              onClick={() => navigate("/participant/certificate")}
              className="mt-3.5 flex cursor-pointer items-center justify-between rounded-2xl border border-[#2DD4BF]/30 bg-gradient-to-br from-[#0F3D3A] to-[#115E59] p-3 shadow-lg active:scale-[0.99]"
            >
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/10">
                  <Icon name="workspace_premium" size={20} color="#5EEAD4" />
                </div>
                <div>
                  <div className="font-outfit text-[14.5px] font-extrabold text-white">CE/CME Credits</div>
                  <div className="text-[11px] text-white/70">Earn credits by attending sessions</div>
                </div>
              </div>
              <span className="flex items-center gap-1 rounded-full bg-white px-3 py-1.5 font-inter text-[11.5px] font-bold text-[#115E59]">
                View Progress
                <Icon name="arrow_forward" size={13} />
              </span>
            </div>
          </div>
        )}

        {/* 3. Accommodation & Services Section */}
        <div>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Icon name="hotel" size={18} color="rgba(255,255,255,0.85)" />
              <span className="font-inter text-xs font-extrabold tracking-[0.3px] text-white/85">
                ACCOMMODATION &amp; SERVICES
              </span>
            </div>
            <div className="mx-2 h-px flex-1 bg-white/10" />
            <Link
              to="/participant/accommodation"
              className="flex items-center gap-0.5 font-inter text-xs font-bold text-[#2563EB]"
            >
              <span>More</span>
              <Icon name="arrow_forward" size={14} />
            </Link>
          </div>

          <div
            onClick={() => navigate("/participant/accommodation")}
            className="mt-2.5 flex h-[72px] cursor-pointer items-center justify-between overflow-hidden rounded-[18px] bg-gradient-to-br from-[#2563EB] to-[#0F2B66] px-3.5 shadow-[0_4px_12px_rgba(30,58,138,0.25)] active:scale-[0.99]"
          >
            <div className="flex items-center gap-3.5">
              <div className="flex h-11 w-11 items-center justify-center rounded-[13px] bg-white/20">
                <Icon name="hotel" size={22} color="#ffffff" />
              </div>
              <div>
                <div className="font-outfit text-[15.5px] font-extrabold leading-tight text-white">
                  Accommodation
                </div>
                <div className="text-[11px] font-medium text-white/85">
                  Book your stay &amp; explore services
                </div>
              </div>
            </div>
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-white text-[#2563EB]">
              <Icon name="arrow_forward" size={16} />
            </div>
          </div>
        </div>

        {/* Live Photo Button */}
        <AppLivePhotoButton />

        {/* 4. Follow Us Social Chips */}
        <div className="pt-1">
          <div className="font-inter text-xs font-extrabold tracking-[0.3px] text-white/85">
            FOLLOW US
          </div>
          <div className="mt-2.5 flex justify-center gap-3">
            {SOCIAL_LINKS.map((s) => (
              <a
                key={s.label}
                href={s.url}
                target="_blank"
                rel="noreferrer"
                title={s.label}
                className="flex h-11 w-11 items-center justify-center rounded-[22px] border border-white/10 bg-[#14141F] transition hover:bg-white/10 active:scale-95"
              >
                <span className="flex h-[30px] w-[30px] items-center justify-center rounded-full bg-white p-1">
                  <img src={s.img} alt={s.label} className="h-full w-full object-contain" />
                </span>
              </a>
            ))}
          </div>
        </div>
      </div>

      {/* Reminder Sheet Modal */}
      {reminderItem && (
        <ReminderSheet
          open={!!reminderItem}
          scheduleName={reminderItem.name}
          start={reminderItem.start}
          current={undefined}
          onPick={() => setReminderItem(null)}
          onClose={() => setReminderItem(null)}
        />
      )}

      {/* 5. Bottom Navigation Bar on Home Screen Only */}
      <ParticipantBottomNav activeTab="home" />
    </div>
  );
}

/** "More" Modules screen at phone width — matching Flutter _openMoreModules. */
export function ParticipantMoreApp() {
  return (
    <AppPage title="More" outfit>
      <div className="pt-0.5">
        <AppModuleGrid
          title="ALL MODULES"
          modules={PARTICIPANT_APP_MODULES.slice(HOME_SLOTS - 1)}
        />
      </div>
    </AppPage>
  );
}
