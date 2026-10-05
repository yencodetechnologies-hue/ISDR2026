/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { SessionContent } from "@/components/SessionContent";
import { Icon, Spinner, useToast } from "@/components/ui";
import { asset } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { scheduleTimes } from "@/lib/format";
import { displaySpeaker, loadFavorites, loadSchedule, toggleFavorite } from "@/lib/schedules";

const DAY = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const hm = (d: Date) => {
  const h = d.getHours();
  return `${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
};

/** Dark round app-bar button (the app's _CircleButton). */
function CircleButton({ icon, onClick, badge }: { icon: string; onClick: () => void; badge?: boolean }) {
  return (
    <button
      onClick={onClick}
      className="relative flex h-11 w-11 items-center justify-center rounded-full bg-[#16213F] active:brightness-125"
    >
      <Icon name={icon} size={22} />
      {badge && <span className="absolute right-0.5 top-0.5 h-[9px] w-[9px] rounded-full bg-[#EF4444]" />}
    </button>
  );
}

/** Small gradient pill, e.g. "SPEAKER" or "KEYNOTE". */
function Pill({ icon, label, from, to }: { icon: string; label: string; from: string; to: string }) {
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-[9px] py-[3px] text-[9.5px] font-bold tracking-[0.8px]"
      style={{ background: `linear-gradient(90deg, ${from}, ${to})` }}
    >
      <Icon name={icon} size={12} />
      {label}
    </span>
  );
}

/** One detail tile: coloured round icon, small caps label, value and chevron. */
function InfoTile({
  icon,
  color,
  label,
  value,
  href,
}: {
  icon: string;
  color: string;
  label: string;
  value: string;
  href?: string;
}) {
  const body = (
    <span className="flex h-full items-center rounded-[18px] border border-white/10 bg-[#0E1638] py-2 pl-2 pr-0.5">
      <span
        className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full border"
        style={{ background: `${color}40`, borderColor: `${color}b3` }}
      >
        <Icon name={icon} size={17} />
      </span>
      <span className="ml-2 min-w-0 flex-1">
        <span className="block text-[9.5px] font-bold tracking-[0.6px]" style={{ color: `${color}e6` }}>
          {label}
        </span>
        <span className="mt-0.5 block whitespace-pre-line font-outfit text-[12.5px] font-bold">{value}</span>
      </span>
      <Icon name="chevron_right" color="rgba(255,255,255,0.5)" />
    </span>
  );
  return href ? (
    <a href={href} target="_blank" rel="noreferrer" className="block min-w-0 flex-1">
      {body}
    </a>
  ) : (
    <div className="min-w-0 flex-1">{body}</div>
  );
}

/** Program Details at phone width — the app's ScheduleDetailPage. */
export default function ScheduleDetailApp() {
  const [params] = useSearchParams();
  const eventId = params.get("e") ?? "";
  const scheduleId = params.get("s") ?? "";
  const navigate = useNavigate();
  const toast = useToast();
  const { user } = useAuth();
  const isParticipant = user?.userType === "participant";
  const [data, setData] = useState<{ event: any; schedule: any; error?: string } | null>(null);
  // In the participant's favorites ("My Schedule"); null = not loaded yet.
  const [saved, setSaved] = useState<boolean | null>(null);
  const [saving, setSaving] = useState(false);
  const [bell, setBell] = useState(false);

  useEffect(() => {
    loadSchedule(eventId, scheduleId).then(setData);
    if (isParticipant && scheduleId) loadFavorites().then((s) => setSaved(s.has(scheduleId)));
  }, [eventId, scheduleId, isParticipant]);

  const toggleSaved = async () => {
    if (saving || saved === null) return;
    setSaving(true);
    const r = await toggleFavorite(scheduleId);
    setSaving(false);
    const now = r.success ? r.favorite === true : saved;
    if (r.success) setSaved(now);
    toast(r.success ? (now ? "Saved to My Schedule" : "Removed from My Schedule") : r.error || "Could not update");
  };

  const s = data?.schedule;
  const w = s ? scheduleTimes(s) : null;
  const now = new Date();
  const isLive = !!w && now >= w.start && now < w.end;
  const isPast = !!w && now > w.end;
  const name = displaySpeaker(s?.speakerName);
  const photo = String(s?.speakerPhoto ?? "");
  const scheduleName = String(s?.scheduleName ?? "");
  const description = String(s?.description ?? "");
  const hall = String(s?.hall ?? "");
  const eventTitle = String(data?.event?.title ?? "");
  const venue = String(data?.event?.venue ?? "");
  const initials = name
    .trim()
    .split(/\s+/)
    .filter((x) => x && !x.toLowerCase().startsWith("dr"))
    .slice(0, 2)
    .map((x) => x[0].toUpperCase())
    .join("");
  const [statusLabel, statusColor] = isLive
    ? ["LIVE NOW", "#22C55E"]
    : isPast
      ? ["ENDED", "#94A3B8"]
      : ["UPCOMING", "#60A5FA"];

  const tiles = (a: React.ReactNode, b: React.ReactNode) =>
    a || b ? (
      <div className="mt-2.5 flex gap-2.5">
        {a}
        {b}
      </div>
    ) : null;

  const showSave = isParticipant && !!scheduleId && !!s;
  return (
    <div className="flex min-h-screen flex-col bg-[#0A0F24]">
      <header className="sticky top-0 z-30 flex h-14 items-center bg-[#0A0F24] px-3.5">
        <CircleButton icon="arrow_back" onClick={() => (window.history.length > 1 ? navigate(-1) : navigate("/"))} />
        <div className="flex-1 text-center font-outfit text-[19px] font-extrabold">Program Details</div>
        <CircleButton icon={bell ? "notifications_active" : "notifications_none"} onClick={() => setBell((v) => !v)} badge={bell} />
      </header>
      {!data ? (
        <div className="flex justify-center pt-40">
          <Spinner size={36} />
        </div>
      ) : !s ? (
        <div className="pt-40 text-center text-muted">{data.error || "Session not found"}</div>
      ) : (
        <div className={`flex-1 px-3 pt-1 ${showSave ? "pb-24" : "pb-3.5"}`}>
          {/* Speaker header */}
          <div
            className="flex items-center rounded-[26px] py-3 pl-3 pr-2.5"
            style={{
              background: "linear-gradient(135deg, #0F1A46, #1A1250, #3B1780)",
              border: "1.4px solid rgba(59,130,246,0.55)",
              boxShadow: "0 0 18px rgba(59,130,246,0.25)",
            }}
          >
            <span
              className="h-[78px] w-[78px] shrink-0 rounded-full p-[3px] shadow-[0_0_20px_rgba(139,92,246,0.5)]"
              style={{ background: "conic-gradient(from 90deg, #3B82F6, #A855F7, #EC4899, #3B82F6)" }}
            >
              <span className="flex h-full w-full items-center justify-center overflow-hidden rounded-full bg-[#1E3A8A]">
                {photo ? (
                  <img src={photo} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="font-outfit text-2xl font-bold">{name ? initials || "?" : "IS"}</span>
                )}
              </span>
            </span>
            <div className="ml-3 min-w-0 flex-1">
              <Pill icon={name ? "mic" : "event_note"} label={name ? "SPEAKER" : "SESSION"} from="#7C3AED" to="#6366F1" />
              <div className="mt-[5px] font-outfit text-[18px] font-extrabold leading-[1.15]">
                {name || hall || "Programme"}
              </div>
              <div className="mt-1 text-[10px] font-medium text-white/80">Inspiring Minds&nbsp; |&nbsp; Building Futures</div>
              <span
                className="mt-[7px] inline-flex items-center gap-[5px] rounded-full border px-2.5 py-1 text-[10.5px] font-extrabold tracking-[0.5px]"
                style={{ background: `${statusColor}2e`, borderColor: `${statusColor}99` }}
              >
                <Icon name={isLive ? "sensors" : "person"} outline={!isLive} size={13} />
                {statusLabel}
              </span>
            </div>
            <div className="ml-1.5 flex w-[60px] shrink-0 flex-col items-end">
              <Icon name="lightbulb" outline size={24} color="#38BDF8" />
              <div className="mt-1 text-right font-dancing text-[11.5px] font-semibold leading-[1.15] text-white/90">
                “Ideas today build better tomorrows”
              </div>
            </div>
          </div>

          {/* Title panel */}
          <div
            className="mt-2.5 flex items-center rounded-[22px] px-2.5 py-3"
            style={{
              background: "linear-gradient(135deg, #1D2F8A, #2B2A9E, #4C1D95)",
              border: "1.4px solid rgba(96,165,250,0.7)",
              boxShadow: "0 0 18px rgba(99,102,241,0.35)",
            }}
          >
            <span className="relative h-11 w-11 shrink-0">
              <Icon name="menu_book" size={44} color="#E0E7FF" />
              <span className="absolute -top-[13px] left-1">
                <Icon name="school" size={33} color="rgba(37,99,235,0.95)" />
              </span>
            </span>
            <div className="ml-3 min-w-0 flex-1">
              <Pill
                icon="star"
                label={scheduleName.toLowerCase().includes("keynote") ? "KEYNOTE" : "SESSION"}
                from="#A855F7"
                to="#7C3AED"
              />
              <div className="mt-1.5 font-outfit text-[16.5px] font-extrabold leading-[1.2]">{scheduleName}</div>
              {eventTitle && (
                <span className="mt-[7px] inline-block rounded-full border border-[#60A5FA]/60 bg-[#1E3A8A]/60 px-2.5 py-1 text-[10.5px] font-semibold">
                  {eventTitle}
                </span>
              )}
            </div>
            <img
              src={asset("ISDR 2026 Logo.png")}
              alt=""
              className="ml-1.5 h-[38px] w-[38px] shrink-0 object-contain opacity-90"
            />
          </div>

          {w &&
            tiles(
              <InfoTile
                icon="calendar_month"
                color="#3B82F6"
                label="DATE"
                value={`${DAY[w.start.getDay()]},\n${w.start.getDate()} ${MON[w.start.getMonth()]} ${w.start.getFullYear()}`}
              />,
              <InfoTile icon="schedule" color="#14B8A6" label="TIME" value={`${hm(w.start)} -\n${hm(w.end)}`} />,
            )}
          {tiles(
            hall ? <InfoTile icon="apartment" color="#8B5CF6" label="HALL" value={hall} /> : null,
            venue ? (
              <InfoTile
                icon="location_on"
                color="#E11D48"
                label="LOCATION"
                value={venue}
                href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(venue)}`}
              />
            ) : null,
          )}

          {description && (
            <div
              className="relative mt-2.5 overflow-hidden rounded-[22px] p-3"
              style={{
                background: "linear-gradient(135deg, #14163F, #2A1466)",
                border: "1.2px solid rgba(139,92,246,0.6)",
              }}
            >
              <span className="absolute -bottom-2.5 -right-1.5">
                <Icon name="biotech" size={70} color="rgba(59,130,246,0.18)" />
              </span>
              <div className="relative flex items-start">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-r from-[#9333EA] to-[#6D28D9]">
                  <Icon name="description" size={18} />
                </span>
                <div className="ml-2.5 min-w-0 flex-1 border-l-[1.5px] border-[#3B82F6]/80 pl-3">
                  <div className="text-[10.5px] font-bold tracking-[0.8px] text-white/85">ABOUT THIS SESSION</div>
                  <div className="mt-[5px] whitespace-pre-wrap text-[12.5px] leading-[1.45] text-white/90">{description}</div>
                </div>
              </div>
            </div>
          )}

          {/* Files, polls and questions the speaker added to this session. */}
          {scheduleId && (
            <div className="mt-3">
              <SessionContent scheduleId={scheduleId} />
            </div>
          )}
        </div>
      )}
      {showSave && (
        <div className="fixed inset-x-0 bottom-0 z-30 bg-[#0A0F24] px-4 pb-3 pt-2">
          <button
            onClick={toggleSaved}
            className="flex h-12 w-full items-center rounded-[30px] border-[1.4px]"
            style={{
              background: saved
                ? "linear-gradient(90deg, #15803D, #16A34A)"
                : "linear-gradient(90deg, #9333EA, #2563EB)",
              borderColor: saved ? "rgba(34,197,94,0.7)" : "rgba(129,140,248,0.7)",
            }}
          >
            <span className="w-[26px]" />
            <Icon name={saved ? "event_available" : "calendar_month"} size={24} />
            <span className="mx-4 h-[26px] w-px bg-white/35" />
            <span className="flex-1 text-left font-outfit text-[15px] font-bold">
              {saving || saved === null ? (
                <Spinner size={18} color="#fff" />
              ) : saved ? (
                "Saved to My Schedule"
              ) : (
                "Save to My Schedule"
              )}
            </span>
            <Icon name={saved ? "check" : "arrow_forward"} />
            <span className="w-[22px]" />
          </button>
        </div>
      )}
    </div>
  );
}
