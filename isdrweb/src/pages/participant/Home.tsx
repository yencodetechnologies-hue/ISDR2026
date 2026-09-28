import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import LiveShowCard from "@/components/LiveShowCard";
import { ScheduleRow, useScheduleActions } from "@/components/ScheduleRow";
import { Avatar, Icon, useToast } from "@/components/ui";
import {
  BannerCarousel,
  BottomNav,
  ModuleGrid,
  NewsTicker,
  NotificationBell,
  SectionTitle,
  YoutubeLiveCapsule,
  useHomeBanner,
} from "@/components/widgets";
import { asset } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { fmtDMon, sameDay, startOfDay } from "@/lib/format";
import { loadAllSchedules, type ScheduleItem } from "@/lib/schedules";
import { HOME_SLOTS, PARTICIPANT_MODULES, participantNav } from "./modules";

const DAY_SHOWN = 3;

const SOCIAL = [
  { label: "Facebook", img: "https://img.icons8.com/color/96/facebook-new.png", url: "https://www.facebook.com/sbdch.dental" },
  { label: "Instagram", img: "https://img.icons8.com/color/96/instagram-new.png", url: "https://www.instagram.com/sbdch_dental/" },
  { label: "YouTube", img: "https://img.icons8.com/color/96/youtube-play.png", url: "https://www.youtube.com/@TheDental-Classroom" },
  { label: "X", img: "https://img.icons8.com/color/96/twitterx.png", url: "https://x.com/sbdch_dental" },
  {
    label: "LinkedIn",
    img: "https://img.icons8.com/color/96/linkedin.png",
    url: "https://www.linkedin.com/school/sree-balaji-dental-college-and-hospital/?originalSubdomain=in",
  },
];

/** Participant home: live/next session card, ticker, modules, banner, day schedule, accommodation, social links. */
export default function ParticipantHome() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();
  const actions = useScheduleActions();
  const banner = useHomeBanner();
  const [items, setItems] = useState<ScheduleItem[]>([]);
  const [eventDays, setEventDays] = useState<Date[]>([]);
  const [now, setNow] = useState(() => new Date());
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);
  const [showAll, setShowAll] = useState(false);

  const load = useCallback(async () => {
    const r = await loadAllSchedules();
    if (r.error) return;
    setItems(r.items);
    setEventDays(r.days);
  }, []);

  useEffect(() => {
    load();
    const t = setInterval(() => {
      setNow(new Date());
      load();
    }, 30000);
    return () => clearInterval(t);
  }, [load]);

  const dates =
    eventDays.length > 0
      ? eventDays
      : [...new Map(items.map((it) => [startOfDay(it.start).getTime(), startOfDay(it.start)])).values()].sort(
          (a, b) => a.getTime() - b.getTime(),
        );
  // Opens on today during the event; otherwise nothing selected until tapped.
  const selected = selectedDay && dates.some((d) => sameDay(d, selectedDay)) ? selectedDay : (dates.find((d) => sameDay(d, now)) ?? null);
  const dayItems = selected ? items.filter((it) => sameDay(it.start, selected)) : [];

  const gridItems =
    PARTICIPANT_MODULES.length > HOME_SLOTS + 1
      ? [...PARTICIPANT_MODULES.slice(0, HOME_SLOTS), { label: "More", icon: "grid_view", color: "#94A3B8", to: "/participant/more" }]
      : PARTICIPANT_MODULES;

  return (
    <div className="min-h-screen bg-bg pb-24">
      <header className="sticky top-0 z-30 border-b border-line bg-bg/90 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-[760px] items-center gap-2 px-3">
          <img src={asset("ISDR 2026 Logo.png")} alt="" className="h-11 w-11 object-contain" />
          <div className="min-w-0 flex-1">
            <div className="text-[17px] font-bold">
              ISDR <span className="text-[#60A5FA]">2026</span>
            </div>
            <div className="truncate text-[10.5px] font-medium text-white/60">Indian Division • IADR</div>
          </div>
          <NotificationBell />
          <button onClick={() => navigate("/participant/profile")} title="Profile">
            <Avatar src={user?.profilePic} name={user?.name ?? "P"} size={34} />
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-[760px] px-4 py-3">
        <LiveShowCard items={items} />

        <div className="mt-3">
          <NewsTicker />
        </div>

        <div className="card mt-3 p-2">
          <ModuleGrid items={gridItems} />
        </div>

        <div className="mt-5">
          <YoutubeLiveCapsule />
          <BannerCarousel urls={banner} />
        </div>

        {/* Day tabs + that day's sessions */}
        {dates.length > 0 && (
          <>
            <SectionTitle
              action={
                <Link to="/participant/sessions" className="flex items-center text-xs font-semibold text-white/60">
                  View All <Icon name="chevron_right" size={16} />
                </Link>
              }
            >
              Today's Schedule
            </SectionTitle>
            <div className="flex gap-2 overflow-x-auto pb-1">
              {dates.map((d, i) => {
                const active = !!selected && sameDay(d, selected);
                return (
                  <button
                    key={d.getTime()}
                    onClick={() => {
                      setSelectedDay(d);
                      setShowAll(false);
                    }}
                    className="min-w-16 flex-1 rounded-md border py-1.5 text-center"
                    style={{
                      background: active ? "#0D2B28" : "#14141F",
                      borderColor: active ? "#2DD4BF" : "rgba(255,255,255,0.08)",
                      color: active ? "#2DD4BF" : undefined,
                    }}
                  >
                    <div className="text-xs font-bold">Day {i + 1}</div>
                    <div className="text-[10.5px] opacity-70">{fmtDMon(d)}</div>
                  </button>
                );
              })}
            </div>
            <div className="mt-2.5 space-y-2.5">
              {dayItems.length === 0 ? (
                <div className="py-3 text-[13px] text-white/50">{selected ? "No sessions on this day" : "Tap a day to see its sessions"}</div>
              ) : (
                <>
                  {(showAll ? dayItems : dayItems.slice(0, DAY_SHOWN)).map((it) => (
                    <ScheduleRow key={`${it.schedule.id ?? it.schedule._id}`} item={it} actions={actions} />
                  ))}
                  {dayItems.length > DAY_SHOWN && (
                    <button
                      onClick={() => setShowAll((s) => !s)}
                      className="card flex w-full items-center justify-center gap-1 py-2.5 text-[13px] font-bold text-[#60A5FA]"
                    >
                      {showAll ? "Show less" : `More (${dayItems.length - DAY_SHOWN})`}
                      <Icon name={showAll ? "expand_less" : "expand_more"} size={20} />
                    </button>
                  )}
                </>
              )}
            </div>
            <button
              onClick={() => toast("CE/CME credit tracking is coming soon")}
              className="mt-3 flex w-full items-center gap-3 rounded-2xl border border-[#2DD4BF]/30 bg-gradient-to-br from-[#0F3D3A] to-[#115E59] px-4 py-3 text-left"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/10">
                <Icon name="school" />
              </span>
              <span className="flex-1">
                <span className="block font-bold">CE/CME Credits</span>
                <span className="block text-xs text-white/70">Earn credits by attending sessions</span>
              </span>
              <span className="rounded-full bg-white/15 px-3 py-1.5 text-xs font-semibold">View Progress</span>
            </button>
          </>
        )}

        {/* Accommodation */}
        <SectionTitle
          action={
            <Link to="/participant/accommodation" className="flex items-center gap-0.5 text-xs font-bold text-accent">
              More <Icon name="arrow_forward" size={15} />
            </Link>
          }
        >
          <span className="flex items-center gap-2">
            <Icon name="bed" size={18} />
            Accommodation &amp; Services
          </span>
        </SectionTitle>
        <Link
          to="/participant/accommodation"
          className="flex items-center gap-3 rounded-2xl border border-line bg-gradient-to-r from-[#0C4A6E] to-[#14141F] p-4"
        >
          <Icon name="hotel" size={30} color="#38BDF8" />
          <div className="flex-1">
            <div className="font-bold">Accommodation</div>
            <div className="text-xs text-white/70">Book your stay &amp; explore services</div>
          </div>
          <Icon name="chevron_right" />
        </Link>

        {/* Follow us */}
        <SectionTitle>Follow us</SectionTitle>
        <div className="flex justify-center gap-3">
          {SOCIAL.map((s) => (
            <a
              key={s.label}
              href={s.url}
              target="_blank"
              rel="noreferrer"
              title={s.label}
              className="rounded-full border border-line bg-card p-1.5 hover:bg-white/5"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-white p-1.5">
                <img src={s.img} alt={s.label} className="h-full w-full object-contain" />
              </span>
            </a>
          ))}
        </div>
      </main>
      {actions.sheet}
      <BottomNav items={participantNav} active={0} />
    </div>
  );
}
