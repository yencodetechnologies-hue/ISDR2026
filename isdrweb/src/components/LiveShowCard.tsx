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
      <div className="card flex items-center gap-3 p-4">
        <div className="flex h-11 w-11 items-center justify-center rounded-full bg-white/5">
          <Icon name="tv_off" color="#6B7280" />
        </div>
        <div className="flex-1">
          <div className="font-bold">No Live Program</div>
          <div className="text-xs text-muted">No live program is currently active</div>
        </div>
        <span className="rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-bold text-muted">OFFLINE</span>
      </div>
    );

  const isLive = now >= live.start && now < live.end;
  return (
    <div
      onClick={() => navigate(scheduleHref(live))}
      className="relative cursor-pointer overflow-hidden rounded-2xl"
      style={{ background: `linear-gradient(90deg, rgba(10,14,26,0.92), rgba(10,14,26,0.55)), url("${asset("live banner-clean.png")}") center/cover` }}
    >
      <div className="p-4">
        <span
          className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10.5px] font-extrabold"
          style={{ background: isLive ? "#DC2626" : "#6366F1" }}
        >
          <Icon name={isLive ? "radio_button_checked" : "campaign"} size={12} />
          {isLive ? "LIVE NOW" : "Next Session"}
        </span>
        <div className="mt-2 text-lg font-extrabold">{live.schedule.scheduleName}</div>
        {live.schedule.speakerName && (
          <div className="mt-1 flex items-center gap-2 text-sm text-white/80">
            <Avatar src={live.schedule.speakerPhoto} name={live.schedule.speakerName} size={24} />
            {live.schedule.speakerName}
          </div>
        )}
        <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-white/75">
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
        <div className="mt-3 flex items-center justify-between">
          <span className="inline-flex items-center gap-1 text-xs font-semibold text-[#60A5FA]">
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
