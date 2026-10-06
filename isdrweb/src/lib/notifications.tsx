/* eslint-disable @typescript-eslint/no-explicit-any */
import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useToast } from "@/components/ui";
import { get, getToken, qs } from "./api";
import { useAuth } from "./auth";
import { idOf } from "./format";

/** How often the open website checks for notifications the server just stored. */
const POLL_MS = 10000;

export const NOTIFICATION_TYPES: { key: string; label: string; icon: string; color: string }[] = [
  { key: "support_ticket", label: "Support", icon: "support_agent", color: "#06B6D4" },
  { key: "schedule_reminder", label: "Reminder", icon: "alarm", color: "#F59E0B" },
  { key: "event_notification", label: "Announcement", icon: "campaign", color: "#3B82F6" },
  { key: "message", label: "Message", icon: "message", color: "#10B981" },
  { key: "general", label: "General", icon: "notifications", color: "#60A5FA" },
];

const TYPE_BY_KEY = Object.fromEntries(NOTIFICATION_TYPES.map((t) => [t.key, t]));

export function notificationMeta(type?: string) {
  return TYPE_BY_KEY[type ?? ""] ?? { key: type ?? "general", label: "Notification", icon: "notifications", color: "#60A5FA" };
}

/** Where a notification should open, when it points at a ticket or a session. */
export function notificationHref(n: { type?: string; data?: any }): string | null {
  const data = n?.data && typeof n.data === "object" ? n.data : {};
  if (n?.type === "support_ticket" && data.ticketId) return `/support/${encodeURIComponent(String(data.ticketId))}`;
  if (n?.type === "schedule_reminder" && data.scheduleId && data.eventId) {
    return `/schedule?e=${encodeURIComponent(String(data.eventId))}&s=${encodeURIComponent(String(data.scheduleId))}`;
  }
  return null;
}

type LiveCtx = {
  unread: number;
  /** Bumps each time a new notification arrives, so open lists can reload. */
  revision: number;
  refresh: () => void;
  /** Browser permission needs a click; the bell is that click. */
  askPermission: () => void;
};

const Ctx = createContext<LiveCtx>({ unread: 0, revision: 0, refresh: () => {}, askPermission: () => {} });

export function useLiveNotifications() {
  return useContext(Ctx);
}

export function useUnreadCount() {
  return useLiveNotifications().unread;
}

function showBrowserNotification(title: string, body: string, tag: string, onClick: () => void) {
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return;
  try {
    const note = new Notification(title, { body, tag });
    note.onclick = () => {
      window.focus();
      note.close();
      onClick();
    };
  } catch {
    /* some browsers throw if constructed off a secure context */
  }
}

/** Polls the signed-in account's notifications and surfaces new ones while the site is open. */
export function NotificationProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const toast = useToast();
  const navigate = useNavigate();
  const [unread, setUnread] = useState(0);
  const [revision, setRevision] = useState(0);
  const seen = useRef<Set<string> | null>(null);
  const inflight = useRef(false);
  const userKey = user ? String(user.id ?? user._id ?? user.email ?? "in") : "";

  const openNotification = useCallback(
    (n: any) => {
      navigate(notificationHref(n) ?? "/notifications");
    },
    [navigate],
  );

  const poll = useCallback(async () => {
    if (!getToken() || inflight.current) return;
    inflight.current = true;
    try {
      const [countRes, listRes] = await Promise.all([
        get("/notifications/unread-count"),
        get(`/notifications${qs({ page: 1, limit: 8, read: "false" })}`),
      ]);
      if (countRes.success) setUnread(Number(countRes.count) || 0);
      if (!listRes.success) return;
      const list: any[] = listRes.notifications ?? [];
      const ids = list.map((n) => idOf(n)).filter(Boolean);
      if (seen.current === null) {
        seen.current = new Set(ids);
        return;
      }
      const fresh = list.filter((n) => {
        const id = idOf(n);
        return id && !seen.current!.has(id);
      });
      for (const id of ids) seen.current.add(id);
      if (!fresh.length) return;
      setRevision((r) => r + 1);
      for (const n of fresh.slice(0, 3)) {
        const title = String(n.title || "Notification");
        const body = String(n.body || "");
        const open = () => openNotification(n);
        toast(body ? `${title}\n${body}` : title, "info", { icon: "notifications", duration: 6000, onClick: open });
        showBrowserNotification(title, body, idOf(n), open);
      }
    } finally {
      inflight.current = false;
    }
  }, [openNotification, toast]);

  const askPermission = useCallback(() => {
    if (typeof Notification !== "undefined" && Notification.permission === "default") {
      void Notification.requestPermission();
    }
  }, []);

  useEffect(() => {
    if (!userKey) {
      seen.current = null;
      setUnread(0);
      return;
    }
    seen.current = null;
    let timer = 0;
    const tick = () => {
      void poll();
    };
    const arm = () => {
      window.clearInterval(timer);
      if (document.visibilityState === "visible") timer = window.setInterval(tick, POLL_MS);
    };
    tick();
    arm();
    const onVis = () => {
      if (document.visibilityState === "visible") tick();
      arm();
    };
    document.addEventListener("visibilitychange", onVis);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVis);
    };
  }, [userKey, poll]);

  return <Ctx.Provider value={{ unread, revision, refresh: () => void poll(), askPermission }}>{children}</Ctx.Provider>;
}
