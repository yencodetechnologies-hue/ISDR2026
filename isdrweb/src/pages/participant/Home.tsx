import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import LiveShowCard from "@/components/LiveShowCard";
import { ScheduleRow, useScheduleActions } from "@/components/ScheduleRow";
import { Button, Icon, Panel } from "@/components/ui";
import {
  BannerCarousel,
  ModuleGrid,
  NewsTicker,
  SectionTitle,
  YoutubeLiveCapsule,
  useHomeBanner,
  LivePhotoButton,
} from "@/components/widgets";
import { get } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { fmtDMon, sameDay, startOfDay } from "@/lib/format";
import { loadAllSchedules, openAsItem, type OpenSession, type ScheduleItem } from "@/lib/schedules";
import { PARTICIPANT_MODULES } from "./modules";

import { useAppLayout } from "@/lib/appLayout";
import ParticipantHomeApp, { UgPaperHomeRow } from "./ParticipantHomeApp";

const DAY_SHOWN = 3;

const SOCIAL = [
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

export default function ParticipantHome() {
  return useAppLayout() ? <ParticipantHomeApp /> : <ParticipantHomeWeb />;
}

/** Participant dashboard desktop layout. */
function ParticipantHomeWeb() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const actions = useScheduleActions();
  const banner = useHomeBanner();
  const [items, setItems] = useState<ScheduleItem[]>([]);
  const [open, setOpen] = useState<OpenSession[]>([]);
  const [eventDays, setEventDays] = useState<Date[]>([]);
  const [now, setNow] = useState(() => new Date());
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);
  const [showAll, setShowAll] = useState(false);
  const myEventId = useRef<string | null | undefined>(undefined);

  const load = useCallback(async () => {
    // Only the participant's own event, like the app's home.
    if (myEventId.current === undefined) {
      const reg = await get("/managed-events/my-registration");
      myEventId.current = reg.success && reg.registration?.eventId ? String(reg.registration.eventId) : null;
    }
    const r = await loadAllSchedules(myEventId.current);
    if (r.error) return;
    setItems(r.items);
    setOpen(r.open);
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
  // Opens on today during the event; otherwise nothing selected until clicked.
  const selected =
    selectedDay && dates.some((d) => sameDay(d, selectedDay))
      ? selectedDay
      : (dates.find((d) => sameDay(d, now)) ?? null);
  const dayItems = selected
    ? [
        ...items.filter((it) => sameDay(it.start, selected)),
        ...open.map(openAsItem).filter((it): it is ScheduleItem => !!it && sameDay(it.start, selected)),
      ]
    : [];
  const h = now.getHours();
  const dayPart = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";

  return (
    <main className="mx-auto w-full max-w-[1264px] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      {/* Hero */}
      <div className="relative overflow-hidden rounded-2xl border border-line bg-gradient-to-br from-[#0B1739] via-[#10183A] to-card p-6 sm:p-8">
        <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full bg-accent/20 blur-3xl" />
        <div className="relative flex flex-wrap items-end gap-6">
          <div className="min-w-0 flex-1">
            <div className="eyebrow text-[#93C5FD]">36th ISDR International Conference 2026</div>
            <h1 className="mt-2 text-2xl font-bold tracking-tight sm:text-3xl">
              {dayPart}, {user?.name?.split(" ")[0] ?? "Delegate"}
            </h1>
            <p className="mt-1.5 max-w-xl text-sm text-white/65">
              Translational Dental Research: Bridging Science and Care
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button icon="qr_code_2" onClick={() => navigate("/qr-pass")}>
              My QR Pass
            </Button>
            <Button variant="outline" icon="view_agenda" onClick={() => navigate("/participant/sessions")}>
              All Sessions
            </Button>
          </div>
        </div>
      </div>

      <div className="mt-5">
        <NewsTicker />
      </div>

      {/* Live + side cards */}
      <div className="mt-5 grid gap-5 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <LiveShowCard items={items} />
        </div>
        <div className="flex flex-col gap-3">
          <YoutubeLiveCapsule />
          <button
            onClick={() => navigate("/participant/certificate")}
            className="flex flex-1 items-center gap-3 rounded-xl border border-[#2DD4BF]/30 bg-gradient-to-br from-[#0F3D3A] to-[#115E59] p-5 text-left transition hover:brightness-110"
          >
            <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-white/10">
              <Icon name="school" />
            </span>
            <span className="flex-1">
              <span className="block font-semibold">CE/CME Credits</span>
              <span className="block text-xs text-white/70">Earn credits by attending sessions</span>
            </span>
            <span className="rounded-md bg-white/15 px-2.5 py-1.5 text-xs font-semibold">View Progress</span>
          </button>
          <Link
            to="/participant/accommodation"
            className="flex flex-1 items-center gap-3 rounded-xl border border-line bg-gradient-to-r from-[#0C4A6E] to-card p-5 transition hover:brightness-110"
          >
            <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-[#38BDF8]/15">
              <Icon name="hotel" color="#38BDF8" />
            </span>
            <span className="flex-1">
              <span className="block font-semibold">Accommodation &amp; Services</span>
              <span className="block text-xs text-white/70">Book your stay &amp; explore services</span>
            </span>
            <Icon name="arrow_forward" size={18} />
          </Link>
          <LivePhotoButton />
        </div>
      </div>

      {banner.length > 0 && (
        <div className="mt-5">
          <BannerCarousel urls={banner} height={260} />
        </div>
      )}

      {/* Day schedule */}
      {dates.length > 0 && (
        <Panel
          className="mt-5"
          title="Today's Schedule"
          subtitle={
            selected
              ? `${dayItems.length} ${dayItems.length === 1 ? "session" : "sessions"} on ${fmtDMon(selected)}`
              : "Pick a day to see its sessions"
          }
          icon="calendar_month"
          iconColor="#2DD4BF"
          action={
            <Link
              to="/participant/sessions"
              className="flex items-center gap-0.5 text-sm font-semibold text-[#60A5FA] hover:underline"
            >
              View all <Icon name="chevron_right" size={18} />
            </Link>
          }
        >
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
                  className="min-w-24 rounded-lg border px-4 py-2 text-left transition"
                  style={{
                    background: active ? "#0D2B28" : "transparent",
                    borderColor: active ? "#2DD4BF" : "rgba(255,255,255,0.08)",
                    color: active ? "#2DD4BF" : undefined,
                  }}
                >
                  <div className="text-sm font-bold">Day {i + 1}</div>
                  <div className="text-xs opacity-70">{fmtDMon(d)}</div>
                </button>
              );
            })}
          </div>
          <div className="mt-4 space-y-2.5">
            {dayItems.length === 0 ? (
              <div className="rounded-lg border border-dashed border-white/10 py-8 text-center text-sm text-white/50">
                {selected ? "No sessions on this day" : "Click a day to see its sessions"}
              </div>
            ) : (
              <>
                {(showAll ? dayItems : dayItems.slice(0, DAY_SHOWN)).map((it) => (
                  <ScheduleRow key={`${it.schedule.id ?? it.schedule._id}`} item={it} actions={actions} />
                ))}
                {dayItems.length > DAY_SHOWN && (
                  <button
                    onClick={() => setShowAll((s) => !s)}
                    className="flex w-full items-center justify-center gap-1 rounded-lg border border-line py-2.5 text-sm font-semibold text-[#60A5FA] hover:bg-white/5"
                  >
                    {showAll ? "Show less" : `Show ${dayItems.length - DAY_SHOWN} more`}
                    <Icon name={showAll ? "expand_less" : "expand_more"} size={20} />
                  </button>
                )}
              </>
            )}
          </div>
        </Panel>
      )}

      {/* Everything else */}
      <SectionTitle>Explore</SectionTitle>
      <UgPaperHomeRow />
      <div className="mt-4">
        <ModuleGrid items={PARTICIPANT_MODULES} />
      </div>

      {/* Follow us */}
      <div className="card mt-8 flex flex-wrap items-center gap-4 px-6 py-5">
        <div className="flex-1">
          <div className="font-semibold">Follow us</div>
          <div className="text-sm text-muted">Stay up to date with Sree Balaji Dental College &amp; Hospital</div>
        </div>
        <div className="flex gap-2.5">
          {SOCIAL.map((s) => (
            <a
              key={s.label}
              href={s.url}
              target="_blank"
              rel="noreferrer"
              title={s.label}
              className="rounded-full border border-line bg-card p-1.5 transition hover:-translate-y-0.5 hover:bg-white/5"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-white p-1.5">
                <img src={s.img} alt={s.label} className="h-full w-full object-contain" />
              </span>
            </a>
          ))}
        </div>
      </div>
      {actions.sheet}
    </main>
  );
}
