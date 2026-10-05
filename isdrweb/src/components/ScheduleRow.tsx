/* eslint-disable react-refresh/only-export-components */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { fmtTime, idOf } from "@/lib/format";
import {
  displaySpeaker,
  loadFavorites,
  loadReminders,
  reminderLabel,
  scheduleHref,
  setReminder,
  splitSpeakerNames,
  toggleFavorite,
  type ScheduleItem,
} from "@/lib/schedules";
import { Avatar, Icon, IconButton, useToast } from "./ui";
import { ReminderSheet } from "./widgets";

/** Favourites + reminders state shared by the schedule lists, with the reminder sheet. */
export function useScheduleActions() {
  const toast = useToast();
  const [favorites, setFavorites] = useState<Set<string>>(new Set());
  const [reminders, setReminders] = useState<Map<string, number>>(new Map());
  const [picking, setPicking] = useState<ScheduleItem | null>(null);

  const reload = useCallback(() => {
    loadFavorites().then(setFavorites);
    loadReminders().then(setReminders);
  }, []);

  useEffect(() => {
    reload();
  }, [reload]);

  const toggleFav = async (scheduleId: string) => {
    const was = favorites.has(scheduleId);
    const flip = (on: boolean) =>
      setFavorites((s) => {
        const n = new Set(s);
        if (on) n.add(scheduleId);
        else n.delete(scheduleId);
        return n;
      });
    flip(!was);
    const res = await toggleFavorite(scheduleId);
    if (!res.success) {
      flip(was);
      toast(res.error || "Could not update", "error");
    }
    return res.success;
  };

  const pick = async (minutesOrOff: number) => {
    const item = picking;
    setPicking(null);
    if (!item) return;
    const id = idOf(item.schedule);
    const name = String(item.schedule.scheduleName ?? "");
    const current = reminders.get(id);
    const minutes = minutesOrOff < 0 ? null : minutesOrOff;
    if (minutes === (current ?? null)) return;
    const apply = (m: number | null | undefined) =>
      setReminders((r) => {
        const n = new Map(r);
        if (m === null || m === undefined) n.delete(id);
        else n.set(id, m);
        return n;
      });
    apply(minutes);
    const res = await setReminder(id, minutes);
    if (!res.success) {
      apply(current);
      toast(res.error || "Could not update", "error");
      return;
    }
    toast(
      minutes === null
        ? "Reminder off"
        : minutes === 0
          ? `Reminder set — we'll notify you when "${name}" starts`
          : `Reminder set — ${reminderLabel(minutes)} "${name}"`,
      "success",
    );
  };

  const sheet = (
    <ReminderSheet
      open={!!picking}
      scheduleName={String(picking?.schedule.scheduleName ?? "")}
      start={picking?.start ?? null}
      current={picking ? reminders.get(idOf(picking.schedule)) : undefined}
      onPick={pick}
      onClose={() => setPicking(null)}
    />
  );

  return { favorites, reminders, toggleFav, openReminder: setPicking, sheet, reload };
}

/** One session row: time, name, speaker, hall, status, remind + favourite buttons. */
export function ScheduleRow({
  item,
  actions,
  showDate,
}: {
  item: ScheduleItem;
  actions?: ReturnType<typeof useScheduleActions>;
  showDate?: boolean;
}) {
  const navigate = useNavigate();
  const s = item.schedule;
  const id = idOf(s);
  const now = new Date();
  const isLive = now >= item.start && now < item.end;
  const isDone = now >= item.end;
  const color = isLive ? "#EF4444" : isDone ? "#9CA3AF" : "#3B82F6";
  const fav = actions?.favorites.has(id) ?? false;
  const rem = actions?.reminders.get(id);
  const speaker = displaySpeaker(s.speakerName);
  const avatarName = splitSpeakerNames(s.speakerName)[0] ?? "";
  return (
    <div
      onClick={() => navigate(scheduleHref(item))}
      className="card card-hover group flex cursor-pointer items-stretch overflow-hidden"
    >
      <div className="flex w-[92px] shrink-0 flex-col justify-center border-r border-line bg-white/[0.02] px-3 py-3 text-center sm:w-[108px]">
        {showDate && (
          <div className="text-[10.5px] font-semibold text-muted">
            {item.start.getDate()}/{item.start.getMonth() + 1}
          </div>
        )}
        <div className="text-[13px] font-bold" style={{ color }}>
          {fmtTime(item.start)}
        </div>
        <div className="text-[11px] text-muted">{fmtTime(item.end)}</div>
      </div>
      <div className="flex min-w-0 flex-1 items-center gap-3 px-4 py-3">
        <Avatar src={s.speakerPhoto} name={avatarName || s.scheduleName} size={40} />
        <div className="min-w-0 flex-1">
          <div className="truncate text-[15px] font-semibold group-hover:text-[#93C5FD]">{s.scheduleName}</div>
          <div className="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted">
            {speaker && (
              <span className="flex items-center gap-1">
                <Icon name="mic" size={13} outline />
                {speaker}
              </span>
            )}
            {s.hall && (
              <span className="flex items-center gap-1">
                <Icon name="location_on" size={13} outline />
                {s.hall}
              </span>
            )}
          </div>
        </div>
        <span
          className="hidden items-center gap-1.5 rounded-md px-2 py-1 text-[11px] font-bold sm:inline-flex"
          style={{ background: `${color}22`, color }}
        >
          {isLive && <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-current" />}
          {isLive ? "Live" : isDone ? "Completed" : "Upcoming"}
        </span>
        {actions && (
          <span className="flex" onClick={(e) => e.stopPropagation()}>
            {!isLive && !isDone && (
              <IconButton
                icon={rem !== undefined ? "notifications_active" : "notifications"}
                outline={rem === undefined}
                title={rem !== undefined ? `Reminder: ${reminderLabel(rem)}` : "Remind me"}
                color={rem !== undefined ? "#FBBF24" : "rgba(255,255,255,0.45)"}
                onClick={() => actions.openReminder(item)}
              />
            )}
            <IconButton
              icon="favorite"
              outline={!fav}
              title={fav ? "Remove from favorites" : "Add to favorites"}
              color={fav ? "#EF4444" : "rgba(255,255,255,0.45)"}
              onClick={() => actions.toggleFav(id)}
            />
          </span>
        )}
      </div>
    </div>
  );
}
