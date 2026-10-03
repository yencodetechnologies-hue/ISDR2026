/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Avatar,
  Button,
  Empty,
  Icon,
  Loading,
  Page,
  Panel,
  Pill,
  SearchBox,
  StatCard,
  Tabs,
  useToast,
} from "@/components/ui";
import { LivePhotoButton, ModuleGrid, SectionTitle } from "@/components/widgets";
import { get, post } from "@/lib/api";
import ExportMenu from "@/components/ExportMenu";
import { fullNameOf } from "@/lib/exporter";
import { ClaimHistoryModal } from "./ClaimHistory";
import { ScannerModal } from "./Scanner";
import { useAuth } from "@/lib/auth";
import { cap, fmtDate, fmtDMon, fullName, idOf, isoDay, parseDate } from "@/lib/format";
import { useLogout } from "../common/Profile";
import { useAppLayout } from "@/lib/appLayout";
import { StaffEventDetailApp, StaffEventsApp } from "./StaffScanApp";

/** Event cards in a responsive grid. */
function EventCards({ events }: { events: any[] }) {
  const navigate = useNavigate();
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {events.map((e) => (
        <button
          key={idOf(e)}
          onClick={() => navigate(`/staff/events/${idOf(e)}`)}
          className="card card-hover group overflow-hidden text-left"
        >
          {e.photoUrl ? (
            <img src={e.photoUrl} alt="" className="h-32 w-full object-cover" />
          ) : (
            <div className="flex h-32 items-center justify-center bg-gradient-to-br from-[#1E3A8A]/60 to-card">
              <Icon name="event" size={40} color="#60A5FA" />
            </div>
          )}
          <div className="p-4">
            <div className="truncate font-semibold group-hover:text-[#93C5FD]">{e.title}</div>
            <div className="mt-1 flex items-center gap-3 text-xs text-muted">
              <span className="flex items-center gap-1">
                <Icon name="calendar_today" size={14} outline />
                {fmtDate(parseDate(e.eventDate))}
              </span>
              <span className="flex items-center gap-1">
                <Icon name="group" size={14} outline />
                {e.bookedCount ?? 0} participants
              </span>
            </div>
          </div>
        </button>
      ))}
    </div>
  );
}

/* =========================================================================
   STAFF HOME
========================================================================= */

export function StaffHome() {
  const { user } = useAuth();
  const [events, setEvents] = useState<any[] | null>(null);

  useEffect(() => {
    get("/managed-events").then((r) => setEvents(r.success ? (r.events ?? []) : []));
  }, []);

  const now = new Date();
  const h = now.getHours();
  const dayPart = h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening";
  const participants = (events ?? []).reduce((n, e) => n + (Number(e.bookedCount) || 0), 0);

  return (
    <main className="mx-auto w-full max-w-[1264px] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <div className="relative overflow-hidden rounded-2xl border border-line bg-gradient-to-br from-[#0B2A24] via-[#0E1E26] to-card p-6 sm:p-8">
        <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full bg-[#34D399]/15 blur-3xl" />
        <div className="relative">
          <div className="eyebrow">Event Staff Portal</div>
          <h1 className="mt-2 text-2xl font-bold tracking-tight sm:text-3xl">
            Good <span className="text-[#34D399]">{dayPart}</span>, {user?.name?.split(" ")[0] ?? ""}!
          </h1>
          <p className="mt-1.5 text-sm text-white/65">Welcome to the event staff portal</p>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Events" value={events ? events.length : "–"} icon="event" color="#3B82F6" />
        <StatCard label="Participants" value={events ? participants : "–"} icon="group" color="#10B981" />
        <div className="col-span-2">
          <ModuleGrid
            cols="grid-cols-2 h-full"
            items={[
              {
                label: "QR Pass",
                sub: "Your staff pass",
                icon: "qr_code_2",
                color: "#10B981",
                to: "/pass?role=EVENT%20STAFF",
              },
              {
                label: "Notifications",
                sub: "Your alerts",
                icon: "notifications",
                color: "#F59E0B",
                to: "/notifications",
              },
              { label: "Support", sub: "Support tickets", icon: "help", color: "#06B6D4", to: "/support" },
              { label: "Events", sub: "All events", icon: "event", color: "#3B82F6", to: "/staff/events" },
            ]}
          />
        </div>
      </div>

      <div className="mt-5">
        <LivePhotoButton />
      </div>

      {events && events.length > 0 && (
        <>
          <SectionTitle>Events</SectionTitle>
          <EventCards events={events} />
        </>
      )}
    </main>
  );
}

/* =========================================================================
   STAFF EVENT LIST
========================================================================= */

export function StaffEventList() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <StaffEventsApp /> : <StaffEventListWeb />;
}

function StaffEventListWeb() {
  const [events, setEvents] = useState<any[] | null>(null);

  useEffect(() => {
    get("/managed-events").then((r) => setEvents(r.success ? (r.events ?? []) : []));
  }, []);

  return (
    <Page title="Events" subtitle="Open an event to see its participants" back={false}>
      {!events ? (
        <Loading />
      ) : events.length === 0 ? (
        <Empty icon="event" title="No events" />
      ) : (
        <EventCards events={events} />
      )}
    </Page>
  );
}

/* =========================================================================
   STAFF EVENT DETAIL — view participants, scan attendance
========================================================================= */

export function StaffEventDetail() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <StaffEventDetailApp /> : <StaffEventDetailWeb />;
}

function StaffEventDetailWeb() {
  const id = window.location.pathname.split("/").pop() ?? "";
  const [event, setEvent] = useState<any>(null);
  const [regs, setRegs] = useState<any[]>([]);
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState<"all" | "checked_in" | "registered">("all");
  const toast = useToast();
  const [scan, setScan] = useState<{ kind: "entry" | "exit" | "claim"; name: string; packageId?: string } | null>(null);
  const [history, setHistory] = useState(false);

  const load = useCallback(async () => {
    const [ev, r] = await Promise.all([get(`/managed-events/${id}`), get(`/managed-events/${id}/registrations`)]);
    if (ev.success) setEvent(ev.event);
    setRegs(r.registrations ?? []);
  }, [id]);
  useEffect(() => {
    load();
  }, [load]);

  const filtered = regs.filter((r) => {
    if (tab !== "all" && r.status !== tab) return false;
    if (!search) return true;
    const s = search.toLowerCase();
    return (
      (r.name ?? "").toLowerCase().includes(s) ||
      fullName(r).toLowerCase().includes(s) ||
      (r.mobileNumber ?? "").includes(s) ||
      (r.idNumber ?? "").includes(s)
    );
  });

  const checkedIn = regs.filter((r) => r.status === "checked_in").length;
  const registered = regs.filter((r) => r.status === "registered").length;

  return (
    <Page
      title={event?.title ?? "Event"}
      subtitle={event ? fmtDate(parseDate(event.eventDate)) : undefined}
      actions={
        <Button variant="outline" icon="history" onClick={() => setHistory(true)}>
          Scan &amp; Claim History
        </Button>
      }
    >
      {!event ? (
        <Loading />
      ) : (
        <>
          <div className="mb-6 grid grid-cols-3 gap-4">
            <StatCard label="Total" value={regs.length} icon="group" color="#3B82F6" />
            <StatCard label="Checked In" value={checkedIn} icon="how_to_reg" color="#22C55E" />
            <StatCard label="Registered" value={registered} icon="pending_actions" color="#F59E0B" />
          </div>

          <div className="mb-6 grid gap-5 lg:grid-cols-3">
            <Panel
              title="Entry & Exit"
              subtitle="Once per participant per day — both are needed for the certificate."
              icon="how_to_reg"
              iconColor="#22C55E"
            >
              <div className="grid grid-cols-2 gap-3">
                {(
                  [
                    ["entry", "Entry Scan", "login", "#22C55E"],
                    ["exit", "Exit Scan", "logout", "#EF4444"],
                  ] as const
                ).map(([kind, label, icon, color]) => (
                  <button
                    key={kind}
                    onClick={() => setScan({ kind, name: label })}
                    className="flex items-center gap-3 rounded-xl border p-3 text-left transition hover:brightness-125"
                    style={{ borderColor: `${color}80`, background: `${color}1f` }}
                  >
                    <span
                      className="flex h-10 w-10 items-center justify-center rounded-lg"
                      style={{ background: color }}
                    >
                      <Icon name={icon} size={20} />
                    </span>
                    <span>
                      <span className="block font-bold">{label}</span>
                      <span className="block text-xs text-muted">Click to scan</span>
                    </span>
                  </button>
                ))}
              </div>
            </Panel>
            <Panel
              className="lg:col-span-2"
              title="Packages & Inclusions"
              subtitle="Click an inclusion to scan and claim it"
              icon="redeem"
              iconColor="#3B82F6"
            >
              {(event.packages ?? []).length === 0 ? (
                <div className="text-sm text-muted">No packages configured for this event.</div>
              ) : (
                <div className="space-y-4">
                  {(event.packages as any[]).map((pkg) => {
                    const today = isoDay(new Date());
                    const incs = (pkg.inclusions ?? []).map((i: any) =>
                      i && typeof i === "object"
                        ? { name: String(i.name), dates: (i.dates ?? []).map(String) }
                        : { name: String(i), dates: [] as string[] },
                    );
                    const rate = Number(pkg.rate) || 0;
                    return (
                      <div key={pkg.id}>
                        <div className="mb-2 flex items-center gap-2">
                          <span className="flex-1 font-semibold">{pkg.name}</span>
                          <Pill color={rate === 0 ? "#22C55E" : "#3B82F6"}>{rate === 0 ? "Free" : `₹${rate}`}</Pill>
                        </div>
                        {incs.length === 0 ? (
                          <div className="text-sm text-muted">No inclusions listed.</div>
                        ) : (
                          <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 xl:grid-cols-5">
                            {incs.map((inc: { name: string; dates: string[] }) => {
                              const ok = inc.dates.length === 0 || inc.dates.includes(today);
                              return (
                                <button
                                  key={inc.name}
                                  onClick={() =>
                                    ok
                                      ? setScan({ kind: "claim", name: inc.name, packageId: String(pkg.id ?? "") })
                                      : toast(
                                          `"${inc.name}" is not available today. Scheduled for: ${[...inc.dates]
                                            .sort()
                                            .map((d) => fmtDMon(new Date(`${d}T00:00:00`)))
                                            .join(", ")}.`,
                                          "error",
                                        )
                                  }
                                  className={`flex flex-col items-center gap-1.5 rounded-lg border px-2 py-3 text-center text-[13px] font-semibold transition ${
                                    ok ? "border-line bg-field hover:border-accent/60" : "border-line bg-bg text-muted"
                                  }`}
                                >
                                  <Icon
                                    name={ok ? "restaurant" : "lock"}
                                    size={20}
                                    color={ok ? "#2563EB" : "#6B7280"}
                                    outline={!ok}
                                  />
                                  <span className="line-clamp-2">{inc.name}</span>
                                </button>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </Panel>
          </div>

          <div className="card overflow-hidden">
            <div className="flex flex-wrap items-center gap-3 px-5 pt-3">
              <div className="flex-1">
                <Tabs
                  value={tab}
                  onChange={setTab}
                  tabs={[
                    { value: "all", label: "All", count: regs.length },
                    { value: "checked_in", label: "Checked In", count: checkedIn },
                    { value: "registered", label: "Registered", count: registered },
                  ]}
                />
              </div>
              <div className="w-full pb-3 sm:w-72">
                <SearchBox value={search} onChange={setSearch} placeholder="Search participants..." />
              </div>
              <div className="pb-3">
                <ExportMenu
                  title={`${event?.title || "Event"} - Participants`}
                  rows={filtered}
                  columns={[
                    { header: "ID no.", value: (r: any) => r.idNumber, width: 10 },
                    { header: "Name", value: (r: any) => fullNameOf(r), width: 24 },
                    { header: "Package", value: (r: any) => r.packageName, width: 14 },
                    { header: "Mobile", value: (r: any) => r.mobileNumber, width: 14 },
                    { header: "Email", value: (r: any) => r.email, width: 24 },
                    {
                      header: "Status",
                      value: (r: any) => cap(String(r.status ?? "registered").replace("_", " ")),
                      width: 12,
                    },
                  ]}
                  qr={{
                    code: (r: any) => String(r.qrCode || r.idNumber || ""),
                    badge: (r: any) => ({
                      name: r.name,
                      title: r.title,
                      participantType: /^spot register$/i.test(String(r.packageName || "")) ? "" : r.participantType,
                      participantTypeColor: r.participantTypeColor,
                      idNumber: r.idNumber,
                      designation: r.designation,
                      institution: r.institution,
                      qrCode: r.qrCode || r.idNumber,
                    }),
                    fileName: (r: any) => {
                      const id = r.idNumber || "SPOT";
                      const name = fullNameOf(r);
                      return name ? `${id} - ${name}` : id;
                    },
                  }}
                />
              </div>
            </div>
            {filtered.length === 0 ? (
              <div className="p-5">
                <Empty icon="group_off" title="No participants found" />
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Participant</th>
                      <th>Mobile</th>
                      <th>ID Number</th>
                      <th className="text-right">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map((r) => {
                      const name = fullName(r) || r.name || "Participant";
                      return (
                        <tr key={idOf(r)}>
                          <td>
                            <div className="flex items-center gap-3">
                              <Avatar src={r.photoUrl} name={name} size={34} />
                              <span className="font-medium">{name}</span>
                            </div>
                          </td>
                          <td className="text-white/75">{r.mobileNumber}</td>
                          <td className="font-mono text-xs text-white/75">{r.idNumber || "—"}</td>
                          <td className="text-right">
                            <Pill
                              color={
                                r.status === "checked_in" ? "#22C55E" : r.status === "cancelled" ? "#EF4444" : "#F59E0B"
                              }
                            >
                              {cap(r.status ?? "registered")}
                            </Pill>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
      {scan && (
        <ScannerModal
          heading={scan.kind === "claim" ? "Claim Benefit" : "Attendance"}
          name={scan.name}
          itemLabel={scan.kind === "claim" ? "Benefit" : "Scan"}
          successText={
            scan.kind === "claim"
              ? "Participant is eligible. Benefit claim registered."
              : scan.kind === "entry"
                ? "Entry recorded for today."
                : "Exit recorded for today."
          }
          event={event}
          submit={(c) =>
            scan.kind === "claim"
              ? post("/managed-events/claim-inclusion", {
                  inclusionName: scan.name,
                  ...(scan.packageId ? { packageId: scan.packageId } : {}),
                  ...c,
                })
              : post("/certificates/scan", { type: scan.kind, ...c })
          }
          onSuccess={scan.kind === "claim" ? load : undefined}
          onClose={() => setScan(null)}
        />
      )}
      {history && <ClaimHistoryModal onClose={() => setHistory(false)} />}
    </Page>
  );
}

/* =========================================================================
   STAFF MORE
========================================================================= */

export function StaffMore() {
  const doLogout = useLogout();
  return (
    <Page title="More" back={false}>
      <ModuleGrid
        items={[
          { label: "Notifications", icon: "notifications", color: "#F59E0B", to: "/notifications" },
          { label: "Support", icon: "help", color: "#06B6D4", to: "/support" },
          { label: "Change Password", icon: "lock", color: "#3B82F6", to: "/change-password" },
          { label: "Brochure", icon: "menu_book", color: "#84CC16", to: "/brochure" },
          { label: "Logout", icon: "logout", color: "#EF4444", onClick: doLogout },
        ]}
      />
    </Page>
  );
}
