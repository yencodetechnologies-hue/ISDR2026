/* eslint-disable react-refresh/only-export-components */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { fmtTime, idOf } from "@/lib/format";
import {
  loadFavorites,
  loadReminders,
  reminderLabel,
  scheduleHref,
  setReminder,
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
  return (
    <div onClick={() => navigate(scheduleHref(item))} className="card flex cursor-pointer items-center gap-3 p-3 hover:bg-[#191926]">
      <Avatar src={s.speakerPhoto} name={s.speakerName} size={42} />
      <div className="min-w-0 flex-1">
        <div className="text-xs font-semibold" style={{ color }}>
          {showDate && `${item.start.getDate()}/${item.start.getMonth() + 1} · `}
          {fmtTime(item.start)} - {fmtTime(item.end)}
          {s.speakerName && <span className="text-white/60"> · {s.speakerName}</span>}
        </div>
        <div className="truncate text-sm font-bold">{s.scheduleName}</div>
        {s.hall && (
          <div className="flex items-center gap-1 text-[11px] text-white/45">
            <Icon name="location_on" size={12} />
            {s.hall}
          </div>
        )}
      </div>
      <span className="rounded-full px-2 py-1 text-[10px] font-extrabold" style={{ background: `${color}2e`, color }}>
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
  );
}
