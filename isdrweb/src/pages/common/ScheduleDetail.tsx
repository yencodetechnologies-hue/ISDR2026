import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { SessionContent } from "@/components/SessionContent";
import { Avatar, Button, ErrorState, Icon, Loading, Page, Pill, useToast } from "@/components/ui";
import { useAuth } from "@/lib/auth";
import { monthShort, scheduleDay, scheduleTimes, weekdayLong } from "@/lib/format";
import { loadFavorites, loadSchedule, participantShowsDate, participantTimeLabel, splitSpeakerNames, toggleFavorite } from "@/lib/schedules";
import { useAppLayout } from "@/lib/appLayout";
import ScheduleDetailApp from "./ScheduleDetailApp";

/** Program details: speaker, date/time/hall/location, about, session content, save. */
export default function ScheduleDetail() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <ScheduleDetailApp /> : <ScheduleDetailWeb />;
}

function ScheduleDetailWeb() {
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

  if (!data)
    return (
      <Page title="Program Details">
        <Loading />
      </Page>
    );
  if (!data.schedule)
    return (
      <Page title="Program Details">
        <ErrorState message={data.error || "Session not found"} />
      </Page>
    );

  const s = data.schedule;
  const speakers = splitSpeakerNames(s.speakerName);
  const venue = String(data.event?.venue ?? "");
  const day = scheduleDay(s);
  const w = scheduleTimes(s);
  const now = new Date();
  const isLive = !!w && now >= w.start && now < w.end;
  const isPast = !!w && now >= w.end;
  const status = !w ? "" : isLive ? "LIVE NOW" : isPast ? "ENDED" : "UPCOMING";
  const isKeynote = String(s.scheduleName ?? "")
    .toLowerCase()
    .includes("keynote");

  const row = (icon: string, color: string, label: string, value: React.ReactNode, href?: string) => {
    const body = (
      <div className={`flex gap-3 px-5 py-3.5 ${href ? "transition hover:bg-white/[0.03]" : ""}`}>
        <div
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
          style={{ background: `${color}22` }}
        >
          <Icon name={icon} size={19} color={color} />
        </div>
        <div className="min-w-0 flex-1">
          <div className="text-xs text-muted">{label}</div>
          <div className="mt-0.5 text-sm font-semibold">{value}</div>
        </div>
        {href && <Icon name="open_in_new" size={16} color="#6B7280" />}
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
    <Page
      eyebrow={data.event?.title}
      title={s.scheduleName}
      actions={
        isParticipant && (
          <Button
            variant={saved ? "outline" : "primary"}
            icon={saved ? "bookmark_added" : "bookmark_add"}
            onClick={toggleSaved}
          >
            {saved ? "Saved to My Schedule" : "Save to My Schedule"}
          </Button>
        )
      }
    >
      <div className="grid gap-5 lg:grid-cols-3">
        <div className="space-y-5 lg:col-span-2">
          <div className="card p-6">
            <div className="flex flex-wrap items-center gap-2">
              {status && <Pill color={isLive ? "#EF4444" : isPast ? "#9CA3AF" : "#3B82F6"}>{status}</Pill>}
              <Pill color="#8B5CF6">{isKeynote ? "KEYNOTE" : "SESSION"}</Pill>
            </div>
            {speakers.length > 0 && (
              <div className="mt-5 flex items-center gap-4">
                <Avatar src={s.speakerPhoto} name={speakers[0]} size={60} />
                <div>
                  <div className="eyebrow">Speaker</div>
                  {speakers.map((name, i) => (
                    <div key={i} className="mt-0.5 text-lg font-semibold leading-snug">
                      {name}
                    </div>
                  ))}
                </div>
              </div>
            )}
            {s.description && (
              <div className="mt-6 border-t border-line pt-5">
                <div className="eyebrow flex items-center gap-2">
                  <Icon name="description" size={16} />
                  Designation & Affiliation
                </div>
                <div className="mt-2 whitespace-pre-wrap text-[15px] leading-relaxed text-white/85">
                  {s.description}
                </div>
              </div>
            )}
          </div>
          <SessionContent scheduleId={scheduleId} />
        </div>
        <aside className="lg:sticky lg:top-24 lg:self-start">
          <div className="card divide-y divide-line overflow-hidden">
            {day &&
              participantShowsDate(s) &&
              row(
                "calendar_month",
                "#3B82F6",
                "Date",
                `${weekdayLong(day)}, ${day.getDate()} ${monthShort(day)} ${day.getFullYear()}`,
              )}
            {participantTimeLabel(s) && row("schedule", "#14B8A6", "Time", participantTimeLabel(s))}
            {s.hall && row("apartment", "#8B5CF6", "Hall", s.hall)}
            {venue &&
              row(
                "location_on",
                "#E11D48",
                "Location",
                venue,
                `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(venue)}`,
              )}
          </div>
        </aside>
      </div>
    </Page>
  );
}
