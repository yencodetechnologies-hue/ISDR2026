import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { SessionContent } from "@/components/SessionContent";
import { Avatar, Button, ErrorState, Icon, Loading, Page, Pill, useToast } from "@/components/ui";
import { useAuth } from "@/lib/auth";
import { fmtTime, monthShort, scheduleTimes, weekdayLong } from "@/lib/format";
import { loadFavorites, loadSchedule, toggleFavorite } from "@/lib/schedules";

/** Program details: speaker, date/time/hall/location, about, session content, save. */
export default function ScheduleDetail() {
  const [params] = useSearchParams();
  const eventId = params.get("e") ?? "";
  const scheduleId = params.get("s") ?? "";
  const toast = useToast();
  const { user } = useAuth();
  const isParticipant = user?.userType === "participant";
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [data, setData] = useState<{ event: any; schedule: any; error?: string } | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    loadSchedule(eventId, scheduleId).then(setData);
    if (isParticipant) loadFavorites().then((s) => setSaved(s.has(scheduleId)));
  }, [eventId, scheduleId, isParticipant]);

  const toggleSaved = async () => {
    const was = saved;
    setSaved(!was);
    const res = await toggleFavorite(scheduleId);
    if (!res.success) {
      setSaved(was);
      toast(res.error || "Could not update", "error");
      return;
    }
    toast(!was ? "Saved to My Schedule" : "Removed from My Schedule", "success");
  };

  if (!data) return <Page title="Program Details"><Loading /></Page>;
  if (!data.schedule) return <Page title="Program Details"><ErrorState message={data.error || "Session not found"} /></Page>;

  const s = data.schedule;
  const venue = String(data.event?.venue ?? "");
  const w = scheduleTimes(s);
  const now = new Date();
  const isLive = !!w && now >= w.start && now < w.end;
  const isPast = !!w && now >= w.end;
  const status = isLive ? "LIVE NOW" : isPast ? "ENDED" : "UPCOMING";
  const isKeynote = String(s.scheduleName ?? "").toLowerCase().includes("keynote");

  const tile = (icon: string, color: string, label: string, value: React.ReactNode, href?: string) => {
    const body = (
      <div className="card flex h-full gap-3 p-3.5">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl" style={{ background: `${color}22` }}>
          <Icon name={icon} size={20} color={color} />
        </div>
        <div className="min-w-0">
          <div className="text-[10.5px] font-bold tracking-wider text-muted">{label}</div>
          <div className="mt-0.5 text-sm font-semibold">{value}</div>
        </div>
      </div>
    );
    return href ? (
      <a href={href} target="_blank" rel="noreferrer" className="block">
        {body}
      </a>
    ) : (
      body
    );
  };

  return (
    <Page title="Program Details">
      <div className="card p-4">
        <div className="flex flex-wrap items-center gap-2">
          <Pill color={isLive ? "#EF4444" : isPast ? "#9CA3AF" : "#3B82F6"}>{status}</Pill>
          <Pill color="#8B5CF6">{isKeynote ? "KEYNOTE" : "SESSION"}</Pill>
        </div>
        <div className="mt-3 text-xl font-extrabold">{s.scheduleName}</div>
        {data.event?.title && <div className="mt-1 text-sm text-muted">{data.event.title}</div>}
        {s.speakerName && (
          <div className="mt-4 flex items-center gap-3 rounded-xl bg-field p-3">
            <Avatar src={s.speakerPhoto} name={s.speakerName} size={48} />
            <div>
              <div className="text-[10.5px] font-bold tracking-wider text-muted">SPEAKER</div>
              <div className="font-bold">{s.speakerName}</div>
            </div>
          </div>
        )}
      </div>
      <div className="mt-3 grid grid-cols-2 gap-3">
        {w && tile("calendar_month", "#3B82F6", "DATE", `${weekdayLong(w.start)}, ${w.start.getDate()} ${monthShort(w.start)} ${w.start.getFullYear()}`)}
        {w && tile("schedule", "#14B8A6", "TIME", `${fmtTime(w.start)} - ${fmtTime(w.end)}`)}
        {s.hall && tile("apartment", "#8B5CF6", "HALL", s.hall)}
        {venue && tile("location_on", "#E11D48", "LOCATION", venue, `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(venue)}`)}
      </div>
      {s.description && (
        <div className="card mt-3 p-4">
          <div className="flex items-center gap-2 text-[11px] font-bold tracking-wider text-muted">
            <Icon name="description" size={16} />
            ABOUT THIS SESSION
          </div>
          <div className="mt-2 whitespace-pre-wrap text-sm text-white/85">{s.description}</div>
        </div>
      )}
      <SessionContent scheduleId={scheduleId} />
      {isParticipant && (
        <Button full className="mt-5 py-3" variant={saved ? "outline" : "primary"} icon={saved ? "bookmark_added" : "bookmark_add"} onClick={toggleSaved}>
          {saved ? "Saved to My Schedule" : "Save to My Schedule"}
        </Button>
      )}
    </Page>
  );
}
