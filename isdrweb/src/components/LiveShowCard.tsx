import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { asset } from "@/lib/api";
import { fmtTime, sameDay } from "@/lib/format";
import { loadAllSchedules, scheduleHref, type ScheduleItem } from "@/lib/schedules";
import { Avatar, Icon } from "./ui";

/**
 * Cycles through today's live / still-to-come sessions every 5 s.
 * Pass `items` to reuse already-loaded schedules; otherwise it loads them
 * itself (and refreshes every 30 s).
 */
export default function LiveShowCard({ items: given }: { items?: ScheduleItem[] }) {
  const navigate = useNavigate();
  const [own, setOwn] = useState<ScheduleItem[]>([]);
  const [now, setNow] = useState(() => new Date());
  const [cycle, setCycle] = useState(0);

  const load = useCallback(async () => {
    const r = await loadAllSchedules();
    if (!r.error) setOwn(r.items);
  }, []);

  useEffect(() => {
    if (!given) load();
    const t = setInterval(() => {
      setNow(new Date());
      if (!given) load();
    }, 30000);
    return () => clearInterval(t);
  }, [given, load]);

  const items = given ?? own;
  const today = items.filter((it) => sameDay(it.start, now) && it.end > now);
  useEffect(() => {
    if (today.length < 2) return;
    const t = setInterval(() => setCycle((c) => c + 1), 5000);
    return () => clearInterval(t);
  }, [today.length]);

  const live = today.length ? today[cycle % today.length] : null;
  if (!live)
    return (
      <div className="card flex h-full min-h-[180px] flex-col items-center justify-center gap-2 p-6 text-center">
        <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-white/5">
          <Icon name="tv_off" color="#6B7280" />
        </div>
        <div className="font-semibold">No Live Program</div>
        <div className="text-sm text-muted">No live program is currently active</div>
        <span className="rounded-md bg-white/10 px-2 py-0.5 text-[10px] font-bold tracking-wider text-muted">
          OFFLINE
        </span>
      </div>
    );

  const isLive = now >= live.start && now < live.end;
  return (
    <div
      onClick={() => navigate(scheduleHref(live))}
      className="relative h-full min-h-[180px] cursor-pointer overflow-hidden rounded-xl border border-line"
      style={{
        background: `linear-gradient(90deg, rgba(10,14,26,0.94), rgba(10,14,26,0.5)), url("${asset("live banner-clean.png")}") center/cover`,
      }}
    >
      <div className="flex h-full flex-col p-6">
        <span
          className="inline-flex w-fit items-center gap-1.5 rounded-md px-2 py-1 text-[11px] font-extrabold tracking-wide"
          style={{ background: isLive ? "#DC2626" : "#6366F1" }}
        >
          <Icon name={isLive ? "radio_button_checked" : "campaign"} size={13} />
          {isLive ? "LIVE NOW" : "NEXT SESSION"}
        </span>
        <div className="mt-3 text-xl font-extrabold leading-snug sm:text-2xl">{live.schedule.scheduleName}</div>
        {live.schedule.speakerName && (
          <div className="mt-2 flex items-center gap-2 text-sm text-white/80">
            <Avatar src={live.schedule.speakerPhoto} name={live.schedule.speakerName} size={26} />
            {live.schedule.speakerName}
          </div>
        )}
        <div className="flex-1" />
        <div className="mt-3 flex flex-wrap items-center gap-4 text-[13px] text-white/75">
          <span className="flex items-center gap-1">
            <Icon name="schedule" size={14} />
            {fmtTime(live.start)} - {fmtTime(live.end)}
          </span>
          {live.schedule.hall && (
            <span className="flex items-center gap-1">
              <Icon name="location_on" size={14} />
              {live.schedule.hall}
            </span>
          )}
        </div>
        <div className="mt-4 flex items-center justify-between">
          <span className="inline-flex items-center gap-1 text-sm font-semibold text-[#60A5FA]">
            View Details <Icon name="arrow_forward" size={14} />
          </span>
          {today.length > 1 && (
            <span className="flex gap-1">
              {today.map((_, i) => (
                <button
                  key={i}
                  onClick={(e) => {
                    e.stopPropagation();
                    setCycle(i);
                  }}
                  className="h-1.5 rounded-full bg-white"
                  style={{ width: i === cycle % today.length ? 14 : 6, opacity: i === cycle % today.length ? 1 : 0.4 }}
                />
              ))}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
