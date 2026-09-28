/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import {
  Avatar,
  Button,
  Empty,
  ErrorState,
  Field,
  Icon,
  IconButton,
  Input,
  Loading,
  Modal,
  Page,
  Pill,
  SearchBox,
  Switch,
  Tabs,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, get, post, put } from "@/lib/api";
import { cap, fullName, idOf } from "@/lib/format";
import { useAuth } from "@/lib/auth";
import { useLogout, useProfilePhoto } from "../common/Profile";
import { BottomNav } from "@/components/widgets";
import { adminNav } from "./modules";

/* =========================================================================
   NEWS TICKER
========================================================================= */

export function ManageTicker() {
  const toast = useToast();
  const [ticker, setTicker] = useState<any>(null);
  const [text, setText] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    get("/news-ticker").then((r) => {
      if (r.success && r.ticker) {
        setTicker(r.ticker);
        setText(r.ticker.text ?? "");
      }
    });
  }, []);

  const save = async (enabled?: boolean) => {
    setSaving(true);
    const r = await put("/news-ticker", { text, enabled: enabled ?? ticker?.enabled ?? true });
    setSaving(false);
    if (r.success) { setTicker(r.ticker ?? { ...ticker, text, enabled: enabled ?? ticker?.enabled }); toast("Ticker updated", "success"); }
    else toast(r.error || "Failed", "error");
  };

  return (
    <Page title="News Ticker">
      {!ticker ? <Loading /> : (
        <div className="space-y-4">
          <div className="card flex items-center justify-between p-4">
            <div>
              <div className="font-bold">Ticker Enabled</div>
              <div className="text-xs text-muted">Scrolling text on participant home</div>
            </div>
            <Switch checked={ticker.enabled !== false} onChange={(v) => { setTicker((t: any) => ({ ...t, enabled: v })); save(v); }} />
          </div>
          <Field label="Ticker Text (one message per line)">
            <TextArea rows={6} value={text} onChange={(e) => setText(e.target.value)} placeholder="Enter each message on a new line" />
          </Field>
          <Button full icon="check" loading={saving} onClick={() => save()}>Save</Button>
        </div>
      )}
    </Page>
  );
}

/* =========================================================================
   YOUTUBE LIVE
========================================================================= */

export function ManageYoutubeLive() {
  const toast = useToast();
  const [url, setUrl] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    get("/youtube-live").then((r) => { setUrl(r.success ? String(r.url ?? "") : ""); setLoaded(true); });
  }, []);

  const save = async () => {
    setSaving(true);
    const r = await put("/youtube-live", { url: url.trim() });
    setSaving(false);
    if (r.success) toast(url.trim() ? "Live URL updated" : "Live URL cleared", "success");
    else toast(r.error || "Failed", "error");
  };

  return (
    <Page title="YouTube Live">
      {!loaded ? <Loading /> : (
        <div className="space-y-4">
          <div className="card p-4">
            <div className="flex items-center gap-2 text-sm">
              <Icon name="info" outline size={18} color="#60A5FA" />
              <span className="text-white/70">Paste a YouTube live URL to show a &ldquo;LIVE&rdquo; capsule on the participant home screen. Clear the URL to hide it.</span>
            </div>
          </div>
          <Field label="YouTube Live URL">
            <Input icon="smart_display" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://youtube.com/live/..." />
          </Field>
          <div className="flex gap-2">
            <Button full icon="check" loading={saving} onClick={save}>Save</Button>
            {url && <Button variant="outline" icon="delete" onClick={() => { setUrl(""); save(); }}>Clear</Button>}
          </div>
        </div>
      )}
    </Page>
  );
}

/* =========================================================================
   SEND NOTIFICATION
========================================================================= */

export function SendNotification() {
  const toast = useToast();
  const [params] = useSearchParams();
  const eventId = params.get("event") ?? "";
  const [events, setEvents] = useState<any[]>([]);
  const [selectedEvent, setSelectedEvent] = useState(eventId);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [sending, setSending] = useState(false);

  useEffect(() => {
    get("/managed-events").then((r) => r.success && setEvents(r.events ?? []));
  }, []);

  const send = async () => {
    if (!title.trim()) return toast("Enter the notification title", "error");
    if (!body.trim()) return toast("Enter the notification body", "error");
    if (!selectedEvent) return toast("Select an event", "error");
    setSending(true);
    const r = await post(`/managed-events/${selectedEvent}/notifications`, { title: title.trim(), body: body.trim() });
    setSending(false);
    if (r.success) { toast("Notification sent!", "success"); setTitle(""); setBody(""); }
    else toast(r.error || "Could not send", "error");
  };

  return (
    <Page title="Send Notification">
      <div className="space-y-4">
        <Field label="Event">
          <select
            value={selectedEvent}
            onChange={(e) => setSelectedEvent(e.target.value)}
            className="input"
          >
            <option value="">Select event</option>
            {events.map((ev) => <option key={idOf(ev)} value={idOf(ev)}>{ev.title}</option>)}
          </select>
        </Field>
        <Field label="Title">
          <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Notification title" />
        </Field>
        <Field label="Message">
          <TextArea rows={4} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Notification body" />
        </Field>
        <Button full icon="send" loading={sending} onClick={send}>Send Notification</Button>
      </div>
    </Page>
  );
}

/* =========================================================================
   ENGAGEMENT OVERVIEW
========================================================================= */

export function EngagementOverview() {
  const [tab, setTab] = useState<"questions" | "polls" | "speaker">("questions");
  const [data, setData] = useState<{ questions: any[]; polls: any[]; speakerQs: any[] } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [q, p, sq] = await Promise.all([
      get("/engagement/session-questions"),
      get("/engagement/session-polls"),
      get("/engagement/speaker-questions"),
    ]);
    if (!q.success) return setError(q.error || "Could not load engagement data");
    setData({ questions: q.questions ?? [], polls: p.polls ?? [], speakerQs: sq.questions ?? [] });
  }, []);
  useEffect(() => { load(); }, [load]);

  return (
    <Page title="Engagement Overview">
      <Tabs
        value={tab}
        onChange={setTab}
        tabs={[
          { value: "questions", label: "Session Q&A", count: data?.questions.length },
          { value: "polls", label: "Polls", count: data?.polls.length },
          { value: "speaker", label: "Speaker Q&A", count: data?.speakerQs.length },
        ]}
      />
      <div className="mt-4">
        {error ? <ErrorState message={error} onRetry={load} /> : !data ? <Loading /> : (
          <>
            {tab === "questions" && (
              data.questions.length === 0 ? <Empty icon="forum" title="No session Q&A yet" /> : (
                <div className="space-y-2.5">
                  {data.questions.map((q) => (
                    <div key={idOf(q)} className="card p-3.5">
                      <div className="font-semibold">{q.question}</div>
                      <div className="mt-1 text-xs text-muted">{q.scheduleName ?? "Session"} · {(q.answers ?? []).length} answers</div>
                    </div>
                  ))}
                </div>
              )
            )}
            {tab === "polls" && (
              data.polls.length === 0 ? <Empty icon="bar_chart" title="No polls yet" /> : (
                <div className="space-y-2.5">
                  {data.polls.map((p) => (
                    <div key={idOf(p)} className="card p-3.5">
                      <div className="font-semibold">{p.question}</div>
                      <div className="mt-1 text-xs text-muted">{p.scheduleName ?? "Session"} · {p.totalVotes ?? 0} votes</div>
                      <div className="mt-2 space-y-1.5">
                        {(p.options ?? []).map((o: string, i: number) => {
                          const c = (p.counts ?? [])[i] ?? 0;
                          const total = Number(p.totalVotes) || 1;
                          const pct = Math.round((c / total) * 100);
                          return (
                            <div key={i}>
                              <div className="flex justify-between text-xs"><span>{o}</span><span className="text-muted">{pct}%</span></div>
                              <div className="mt-0.5 h-1.5 overflow-hidden rounded-full bg-white/10">
                                <div className="h-full rounded-full bg-accent" style={{ width: `${pct}%` }} />
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  ))}
                </div>
              )
            )}
            {tab === "speaker" && (
              data.speakerQs.length === 0 ? <Empty icon="help" title="No speaker questions yet" /> : (
                <div className="space-y-2.5">
                  {data.speakerQs.map((q) => (
                    <div key={idOf(q)} className="card p-3.5">
                      <div className="font-semibold">{q.question}</div>
                      <div className="mt-1 text-xs text-muted">
                        To: {q.speakerName ?? "Speaker"} · {q.answered ? "Answered" : "Unanswered"}
                      </div>
                      {q.answer && <div className="mt-2 rounded-lg bg-field p-2.5 text-sm">{q.answer}</div>}
                    </div>
                  ))}
                </div>
              )
            )}
          </>
        )}
      </div>
    </Page>
  );
}

/* =========================================================================
   CERTIFICATES
========================================================================= */

export function ManageCertificates() {
  const toast = useToast();
  const confirm = useConfirm();
  const [certs, setCerts] = useState<any[] | null>(null);
  const [search, setSearch] = useState("");

  const load = useCallback(async () => {
    const r = await get("/certificates");
    if (r.success) setCerts(r.participants ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  const act = async (ids: string[], action: "unlock" | "revert") => {
    const label = action === "unlock" ? "Unlock certificate" : "Revoke certificate";
    if (!(await confirm({ title: `${label} for ${ids.length} participant(s)?`, confirm: label, danger: action === "revert" }))) return;
    const r = await post(`/certificates/${action}`, { participantIds: ids });
    if (r.success) { toast(`${cap(action)} done`, "success"); load(); }
    else toast(r.error || "Failed", "error");
  };

  const filtered = (certs ?? []).filter((c) => {
    if (!search) return true;
    const s = search.toLowerCase();
    return (c.name ?? "").toLowerCase().includes(s) || fullName(c).toLowerCase().includes(s) || (c.mobileNumber ?? "").includes(s);
  });

  return (
    <Page title="Certificates">
      {!certs ? <Loading /> : (
        <>
          <SearchBox value={search} onChange={setSearch} placeholder="Search participants..." />
          <div className="mt-3 space-y-2">
            {filtered.length === 0 ? <Empty icon="workspace_premium" title="No participants" /> : (
              filtered.map((c) => {
                const name = fullName(c) || c.name || "Participant";
                const unlocked = c.certificateUnlocked === true;
                const revoked = c.certificateRevoked === true;
                return (
                  <div key={idOf(c)} className="card flex items-center gap-3 p-3.5">
                    <Avatar src={c.photoUrl} name={name} size={38} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-semibold">{name}</div>
                      <div className="flex gap-1.5 text-xs">
                        {unlocked && <Pill color="#22C55E">Unlocked</Pill>}
                        {revoked && <Pill color="#EF4444">Revoked</Pill>}
                        {!unlocked && !revoked && <Pill color="#F59E0B">Locked</Pill>}
                      </div>
                    </div>
                    {!unlocked && !revoked && (
                      <Button small variant="success" onClick={() => act([idOf(c)], "unlock")}>Unlock</Button>
                    )}
                    {unlocked && !revoked && (
                      <Button small variant="danger" onClick={() => act([idOf(c)], "revert")}>Revoke</Button>
                    )}
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
   MANAGEMENT TEAM
========================================================================= */

export function ManagementTeam() {
  const toast = useToast();
  const confirm = useConfirm();
  const [users, setUsers] = useState<any[] | null>(null);
  const [staff, setStaff] = useState<any[] | null>(null);
  const [tab, setTab] = useState<"mgmt" | "staff">("mgmt");
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState("");
  const [mobile, setMobile] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const [mu, st] = await Promise.all([get("/auth/management-users"), get("/auth/users")]);
    if (mu.success) setUsers(mu.users ?? []);
    if (st.success) setStaff(st.users ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  const addMgmt = async () => {
    if (!name.trim()) return toast("Enter name", "error");
    if (!mobile.trim()) return toast("Enter mobile", "error");
    setSaving(true);
    const r = await post("/auth/management-users", { name: name.trim(), mobile: mobile.trim() });
    setSaving(false);
    if (r.success) { toast("Added", "success"); setAdding(false); setName(""); setMobile(""); load(); }
    else toast(r.error || "Failed", "error");
  };

  const removeMgmt = async (u: any) => {
    if (!(await confirm({ title: `Remove ${u.name}?`, confirm: "Remove", danger: true }))) return;
    const r = await del(`/auth/management-users/${idOf(u)}`);
    if (r.success) { setUsers((l) => (l ?? []).filter((x) => idOf(x) !== idOf(u))); toast("Removed"); }
    else toast(r.error || "Failed", "error");
  };

  const toggleStaff = async (u: any) => {
    const r = await put(`/auth/users/${idOf(u)}/toggle-active`, {});
    if (r.success) { load(); toast(u.isActive ? "Deactivated" : "Activated"); }
    else toast(r.error || "Failed", "error");
  };

  const removeStaff = async (u: any) => {
    if (!(await confirm({ title: `Remove ${u.name}?`, confirm: "Remove", danger: true }))) return;
    const r = await del(`/auth/users/${idOf(u)}`);
    if (r.success) { setStaff((l) => (l ?? []).filter((x) => idOf(x) !== idOf(u))); toast("Removed"); }
    else toast(r.error || "Failed", "error");
  };

  return (
    <Page title="Team" actions={tab === "mgmt" ? <Button small icon="add" onClick={() => setAdding(true)}>Add</Button> : undefined}>
      <Tabs value={tab} onChange={setTab} tabs={[
        { value: "mgmt", label: "Management", count: users?.length },
        { value: "staff", label: "Event Staff", count: staff?.length },
      ]} />
      <div className="mt-4">
        {tab === "mgmt" && (
          !users ? <Loading /> : users.length === 0 ? <Empty icon="group" title="No management users" /> : (
            <div className="space-y-2">
              {users.map((u) => (
                <div key={idOf(u)} className="card flex items-center gap-3 p-3.5">
                  <Avatar name={u.name} size={40} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-semibold">{u.name}</div>
                    <div className="text-xs text-muted">{u.mobile}</div>
                  </div>
                  <IconButton icon="delete" outline color="#EF4444" onClick={() => removeMgmt(u)} />
                </div>
              ))}
            </div>
          )
        )}
        {tab === "staff" && (
          !staff ? <Loading /> : staff.length === 0 ? <Empty icon="badge" title="No event staff" /> : (
            <div className="space-y-2">
              {staff.map((u) => (
                <div key={idOf(u)} className="card flex items-center gap-3 p-3.5">
                  <Avatar src={u.profilePic} name={u.name} size={40} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-semibold">{u.name}</div>
                    <div className="flex gap-1.5 text-xs">
                      <Pill color={u.isActive ? "#22C55E" : "#EF4444"}>{u.isActive ? "Active" : "Inactive"}</Pill>
                      <Pill color={u.status === "approved" ? "#22C55E" : "#F59E0B"}>{cap(u.status ?? "pending")}</Pill>
                    </div>
                  </div>
                  <Switch checked={u.isActive} onChange={() => toggleStaff(u)} />
                  <IconButton icon="delete" outline color="#EF4444" onClick={() => removeStaff(u)} />
                </div>
              ))}
            </div>
          )
        )}
      </div>
      <Modal open={adding} onClose={() => setAdding(false)} title="Add Management ID">
        <div className="space-y-3">
          <Field label="Name"><Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Full name" /></Field>
          <Field label="Mobile"><Input value={mobile} onChange={(e) => setMobile(e.target.value)} placeholder="Mobile number" /></Field>
          <Button full loading={saving} onClick={addMgmt}>Add</Button>
        </div>
      </Modal>
    </Page>
  );
}

/* =========================================================================
   ADMIN PROFILE
========================================================================= */

export function AdminProfile() {
  const { user } = useAuth();
  const doLogout = useLogout();
  const { uploading, pick, input } = useProfilePhoto();
  const navigate = useNavigate();

  if (!user) return <Page title="Profile"><Loading /></Page>;

  return (
    <Page title="My Profile">
      <div className="flex flex-col items-center py-4">
        <div className="relative">
          <Avatar src={user.profilePic} name={user.name} size={90} />
          <button
            onClick={pick}
            className="absolute -bottom-1 -right-1 flex h-8 w-8 items-center justify-center rounded-full border-2 border-bg bg-accent"
          >
            {uploading ? <Loading /> : <Icon name="camera_alt" size={16} />}
          </button>
          {input}
        </div>
        <div className="mt-3 text-lg font-bold">{user.name}</div>
        <div className="text-sm text-muted">{user.email}</div>
        <Pill color="#3B82F6">Event Admin</Pill>
      </div>

      <div className="mt-4 space-y-2">
        {[
          { label: "Change Password", icon: "lock", color: "#3B82F6", to: "/change-password" },
          { label: "QR Pass", icon: "qr_code", color: "#10B981", to: "/qr-pass" },
          { label: "Brochure", icon: "menu_book", color: "#F59E0B", to: "/brochure" },
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

/* =========================================================================
   ADMIN MORE
========================================================================= */

export function AdminMore() {
  const navigate = useNavigate();
  const doLogout = useLogout();
  const items = [
    { label: "Profile", icon: "person", color: "#3B82F6", to: "/admin/profile" },
    { label: "Engagement", icon: "analytics", color: "#8B5CF6", to: "/admin/engagement" },
    { label: "Certificates", icon: "workspace_premium", color: "#14B8A6", to: "/admin/certificates" },
    { label: "Team", icon: "group", color: "#6366F1", to: "/admin/team" },
    { label: "Banner", icon: "image", color: "#EC4899", to: "/admin/banner" },
    { label: "News Ticker", icon: "newspaper", color: "#06B6D4", to: "/admin/ticker" },
    { label: "YouTube Live", icon: "smart_display", color: "#DC2626", to: "/admin/youtube" },
    { label: "Send Notification", icon: "campaign", color: "#10B981", to: "/admin/send-notification" },
    { label: "Support", icon: "help", color: "#0EA5E9", to: "/support" },
    { label: "Brochure", icon: "menu_book", color: "#84CC16", to: "/brochure" },
    { label: "Awards", icon: "emoji_events", color: "#F59E0B", to: "/awards" },
    { label: "Change Password", icon: "lock", color: "#9CA3AF", to: "/change-password" },
  ];
  return (
    <Page title="More" back={false} bottom={<BottomNav items={adminNav} active={4} />}>
      <div className="space-y-2">
        {items.map((item) => (
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
