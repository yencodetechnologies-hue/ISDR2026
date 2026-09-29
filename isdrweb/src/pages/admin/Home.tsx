/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import LiveShowCard from "@/components/LiveShowCard";
import { Button, Icon, Panel, Pill, Spinner, StatCard } from "@/components/ui";
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
import { cap, fmtDate, idOf, parseDate } from "@/lib/format";
import { ADMIN_MODULES } from "./modules";

export default function AdminHome() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const banner = useHomeBanner();

  const [stats, setStats] = useState<{ events: number; participants: number; staff: number; speakers: number } | null>(
    null,
  );
  const [events, setEvents] = useState<any[]>([]);

  const load = useCallback(async () => {
    const [evts, staff, speakers] = await Promise.all([get("/managed-events"), get("/auth/users"), get("/speakers")]);
    let participants = 0;
    if (evts.success && Array.isArray(evts.events)) {
      for (const e of evts.events) participants += Number(e.bookedCount) || 0;
      setEvents(evts.events);
    }
    setStats({
      events: Array.isArray(evts.events) ? evts.events.length : 0,
      participants,
      staff: Array.isArray(staff.users) ? staff.users.length : 0,
      speakers: Array.isArray(speakers.speakers) ? speakers.speakers.length : 0,
    });
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const value = (n: number | undefined) => (stats === null ? <Spinner size={22} /> : n);

  return (
    <main className="mx-auto w-full max-w-[1264px] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <div className="mb-6 flex flex-wrap items-end gap-4">
        <div className="min-w-0 flex-1">
          <div className="eyebrow">Admin Console</div>
          <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-[28px]">
            Welcome back, {user?.name?.split(" ")[0] ?? "Admin"}
          </h1>
          <div className="mt-1 text-sm text-muted">Here's what's happening across your events.</div>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" icon="campaign" onClick={() => navigate("/admin/send-notification")}>
            Send Notification
          </Button>
          <Button icon="add" onClick={() => navigate("/admin/events/new")}>
            New Event
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          label="Events"
          value={value(stats?.events)}
          icon="event"
          color="#3B82F6"
          onClick={() => navigate("/admin/events")}
        />
        <StatCard
          label="Participants"
          value={value(stats?.participants)}
          icon="group"
          color="#10B981"
          onClick={() => navigate("/admin/events")}
        />
        <StatCard
          label="Event Staff"
          value={value(stats?.staff)}
          icon="badge"
          color="#F59E0B"
          onClick={() => navigate("/admin/team")}
        />
        <StatCard
          label="Speakers"
          value={value(stats?.speakers)}
          icon="mic"
          color="#A855F7"
          onClick={() => navigate("/admin/speakers")}
        />
      </div>

      <div className="mt-5">
        <NewsTicker />
      </div>

      <div className="mt-5 grid gap-5 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <LiveShowCard />
        </div>
        <Panel
          title="Events"
          icon="event"
          action={
            <Link to="/admin/events" className="text-sm font-semibold text-[#60A5FA] hover:underline">
              View all
            </Link>
          }
          bodyClass="p-2"
        >
          {events.length === 0 ? (
            <div className="px-3 py-8 text-center text-sm text-muted">
              {stats === null ? "Loading…" : "No events yet"}
            </div>
          ) : (
            events.slice(0, 5).map((e) => (
              <button
                key={idOf(e)}
                onClick={() => navigate(`/admin/events/${idOf(e)}`)}
                className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left transition hover:bg-white/5"
              >
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-accent/15">
                  <Icon name="event" size={18} color="#3B82F6" />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-semibold">{e.title}</span>
                  <span className="block text-xs text-muted">
                    {fmtDate(parseDate(e.eventDate))} · {e.bookedCount ?? 0} participants
                  </span>
                </span>
                <Pill color={e.status === "published" ? "#22C55E" : e.status === "cancelled" ? "#EF4444" : "#F59E0B"}>
                  {cap(e.status ?? "draft")}
                </Pill>
              </button>
            ))
          )}
        </Panel>
      </div>

      <div className="mt-5 grid gap-5 lg:grid-cols-3">
        <div className="space-y-3 lg:col-span-3">
          <YoutubeLiveCapsule />
          <LivePhotoButton />
          <BannerCarousel urls={banner} height={240} />
        </div>
      </div>

      <SectionTitle>Management</SectionTitle>
      <ModuleGrid items={ADMIN_MODULES} />
    </main>
  );
}
