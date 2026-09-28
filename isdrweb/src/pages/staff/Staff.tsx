/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Avatar, Empty, Icon, Loading, Page, Pill, SearchBox, Tabs } from "@/components/ui";
import { BottomNav, NotificationBell, type NavItem } from "@/components/widgets";
import { asset, get } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cap, fmtDate, fullName, idOf, parseDate } from "@/lib/format";
import { useLogout } from "../common/Profile";

const staffNav: NavItem[] = [
  { label: "Home", icon: "home", to: "/staff" },
  { label: "Events", icon: "event", to: "/staff/events" },
  { label: "QR Pass", icon: "qr_code", to: "/qr-pass" },
  { label: "More", icon: "grid_view", to: "/staff/more" },
];

/* =========================================================================
   STAFF HOME
========================================================================= */

export function StaffHome() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[] | null>(null);

  useEffect(() => {
    get("/managed-events").then((r) => setEvents(r.success ? r.events ?? [] : []));
  }, []);

  const now = new Date();
  const h = now.getHours();
  const dayPart = h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening";

  return (
    <div className="min-h-screen bg-bg pb-24">
      <header className="sticky top-0 z-30 border-b border-line bg-bg/90 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-[760px] items-center gap-2 px-3">
          <img src={asset("ISDR 2026 Logo.png")} alt="" className="h-11 w-11 object-contain" />
          <div className="min-w-0 flex-1">
            <div className="text-[17px] font-bold">
              ISDR <span className="text-[#60A5FA]">2026</span> <span className="text-xs font-medium text-white/50">Staff</span>
            </div>
            <div className="truncate text-[10.5px] font-medium text-white/60">Event Staff Portal</div>
          </div>
          <NotificationBell />
          <Avatar src={user?.profilePic} name={user?.name ?? "S"} size={34} />
        </div>
      </header>

      <main className="mx-auto max-w-[760px] px-4 py-3">
        <div className="card p-4">
          <div className="text-lg font-bold">
            Good <span className="text-[#34D399]">{dayPart}</span>, {user?.name?.split(" ")[0] ?? ""}!
          </div>
          <div className="text-sm text-muted">Welcome to the event staff portal</div>
        </div>

        <div className="mt-4 grid grid-cols-2 gap-2.5">
          {[
            { label: "Events", icon: "event", color: "#3B82F6", to: "/staff/events" },
            { label: "QR Pass", icon: "qr_code", color: "#10B981", to: "/qr-pass" },
            { label: "Notifications", icon: "notifications", color: "#F59E0B", to: "/notifications" },
            { label: "Support", icon: "help", color: "#06B6D4", to: "/support" },
          ].map((item) => (
            <button
              key={item.label}
              onClick={() => navigate(item.to)}
              className="card flex flex-col items-center gap-2 p-5 hover:bg-[#191926]"
            >
              <span className="flex h-12 w-12 items-center justify-center rounded-2xl" style={{ background: `${item.color}22` }}>
                <Icon name={item.icon} size={26} color={item.color} />
              </span>
              <span className="text-sm font-semibold">{item.label}</span>
            </button>
          ))}
        </div>

        {events && events.length > 0 && (
          <>
            <div className="mb-2.5 mt-6 text-[13px] font-extrabold uppercase tracking-wide text-white/85">Events</div>
            <div className="space-y-2.5">
              {events.map((e) => (
                <button
                  key={idOf(e)}
                  onClick={() => navigate(`/staff/events/${idOf(e)}`)}
                  className="card flex w-full items-center gap-3 p-4 text-left hover:bg-[#191926]"
                >
                  <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-accent/15">
                    <Icon name="event" size={24} color="#3B82F6" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-bold">{e.title}</span>
                    <span className="block text-xs text-muted">{fmtDate(parseDate(e.eventDate))} · {e.bookedCount ?? 0} participants</span>
                  </span>
                  <Icon name="chevron_right" color="#9CA3AF" />
                </button>
              ))}
            </div>
          </>
        )}
      </main>
      <BottomNav items={staffNav} active={0} />
    </div>
  );
}

/* =========================================================================
   STAFF EVENT LIST
========================================================================= */

export function StaffEventList() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<any[] | null>(null);

  useEffect(() => {
    get("/managed-events").then((r) => setEvents(r.success ? r.events ?? [] : []));
  }, []);

  return (
    <Page title="Events" back={false} bottom={<BottomNav items={staffNav} active={1} />}>
      {!events ? <Loading /> : events.length === 0 ? <Empty icon="event" title="No events" /> : (
        <div className="space-y-2.5">
          {events.map((e) => (
            <button
              key={idOf(e)}
              onClick={() => navigate(`/staff/events/${idOf(e)}`)}
              className="card flex w-full items-center gap-3 p-4 text-left hover:bg-[#191926]"
            >
              <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-accent/15">
                <Icon name="event" size={24} color="#3B82F6" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate font-bold">{e.title}</span>
                <span className="block text-xs text-muted">{fmtDate(parseDate(e.eventDate))} · {e.bookedCount ?? 0}</span>
              </span>
              <Icon name="chevron_right" color="#9CA3AF" />
            </button>
          ))}
        </div>
      )}
    </Page>
  );
}

/* =========================================================================
   STAFF EVENT DETAIL — view participants, scan attendance
========================================================================= */

export function StaffEventDetail() {
  const id = window.location.pathname.split("/").pop() ?? "";
  const [event, setEvent] = useState<any>(null);
  const [regs, setRegs] = useState<any[]>([]);
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState<"all" | "checked_in" | "registered">("all");

  const load = useCallback(async () => {
    const [ev, r] = await Promise.all([get(`/managed-events/${id}`), get(`/managed-events/${id}/registrations`)]);
    if (ev.success) setEvent(ev.event);
    setRegs(r.registrations ?? []);
  }, [id]);
  useEffect(() => { load(); }, [load]);

  const filtered = regs.filter((r) => {
    if (tab !== "all" && r.status !== tab) return false;
    if (!search) return true;
    const s = search.toLowerCase();
    return (r.name ?? "").toLowerCase().includes(s) || fullName(r).toLowerCase().includes(s) || (r.mobileNumber ?? "").includes(s) || (r.idNumber ?? "").includes(s);
  });

  const checkedIn = regs.filter((r) => r.status === "checked_in").length;
  const registered = regs.filter((r) => r.status === "registered").length;

  return (
    <Page title={event?.title ?? "Event"}>
      {!event ? <Loading /> : (
        <>
          <div className="mb-3 grid grid-cols-3 gap-2">
            <div className="card p-3 text-center">
              <div className="text-2xl font-extrabold">{regs.length}</div>
              <div className="text-[10px] font-semibold text-muted">Total</div>
            </div>
            <div className="card p-3 text-center">
              <div className="text-2xl font-extrabold text-[#22C55E]">{checkedIn}</div>
              <div className="text-[10px] font-semibold text-muted">Checked In</div>
            </div>
            <div className="card p-3 text-center">
              <div className="text-2xl font-extrabold text-[#F59E0B]">{registered}</div>
              <div className="text-[10px] font-semibold text-muted">Registered</div>
            </div>
          </div>

          <Tabs value={tab} onChange={setTab} tabs={[
            { value: "all", label: "All", count: regs.length },
            { value: "checked_in", label: "Checked In", count: checkedIn },
            { value: "registered", label: "Registered", count: registered },
          ]} />

          <div className="mt-3">
            <SearchBox value={search} onChange={setSearch} placeholder="Search participants..." />
          </div>

          <div className="mt-3 space-y-2">
            {filtered.length === 0 ? <Empty icon="group_off" title="No participants found" /> : (
              filtered.map((r) => {
                const name = fullName(r) || r.name || "Participant";
                return (
                  <div key={idOf(r)} className="card flex items-center gap-3 p-3.5">
                    <Avatar src={r.photoUrl} name={name} size={40} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-semibold">{name}</div>
                      <div className="truncate text-xs text-muted">{r.mobileNumber}{r.idNumber ? ` · ID: ${r.idNumber}` : ""}</div>
                    </div>
                    <Pill color={r.status === "checked_in" ? "#22C55E" : r.status === "cancelled" ? "#EF4444" : "#F59E0B"}>
                      {cap(r.status ?? "registered")}
                    </Pill>
                  </div>
                );
              })
            )}
          </div>
        </>
      )}
    </Page>
  );
}

/* =========================================================================
   STAFF MORE
========================================================================= */

export function StaffMore() {
  const navigate = useNavigate();
  const doLogout = useLogout();
  return (
    <Page title="More" back={false} bottom={<BottomNav items={staffNav} active={3} />}>
      <div className="space-y-2">
        {[
          { label: "Notifications", icon: "notifications", color: "#F59E0B", to: "/notifications" },
          { label: "Support", icon: "help", color: "#06B6D4", to: "/support" },
          { label: "Change Password", icon: "lock", color: "#3B82F6", to: "/change-password" },
          { label: "Brochure", icon: "menu_book", color: "#84CC16", to: "/brochure" },
        ].map((item) => (
          <button key={item.label} onClick={() => navigate(item.to)} className="card flex w-full items-center gap-3 p-4 text-left hover:bg-[#191926]">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl" style={{ background: `${item.color}22` }}>
              <Icon name={item.icon} color={item.color} />
            </span>
            <span className="flex-1 font-semibold">{item.label}</span>
            <Icon name="chevron_right" color="#9CA3AF" />
          </button>
        ))}
        <button onClick={doLogout} className="card flex w-full items-center gap-3 p-4 text-left hover:bg-[#191926]">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-red-500/15">
            <Icon name="logout" color="#EF4444" />
          </span>
          <span className="flex-1 font-semibold text-[#F87171]">Logout</span>
        </button>
      </div>
    </Page>
  );
}
