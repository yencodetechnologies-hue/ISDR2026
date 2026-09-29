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
  Panel,
  PasswordInput,
  Pill,
  SearchBox,
  Spinner,
  Switch,
  Tabs,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, get, post, put } from "@/lib/api";
import ExportMenu from "@/components/ExportMenu";
import type { QrConfig } from "@/lib/exporter";
import { cap, fullName, idOf } from "@/lib/format";
import { useAuth } from "@/lib/auth";
import { passCode, useLogout, useProfilePhoto } from "../common/Profile";
import { ModuleGrid, tickerTextFromLines } from "@/components/widgets";

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
    if (r.success) {
      setTicker(r.ticker ?? { ...ticker, text, enabled: enabled ?? ticker?.enabled });
      toast("Ticker updated", "success");
    } else toast(r.error || "Failed", "error");
  };

  const preview = tickerTextFromLines(text);

  return (
    <Page title="News Ticker" subtitle="Scrolling news strip shown on the home pages" width={1000}>
      {!ticker ? (
        <Loading />
      ) : (
        <div className="grid gap-5 lg:grid-cols-5">
          <Panel
            className="lg:col-span-3"
            title="Ticker messages"
            subtitle="One message per line"
            icon="newspaper"
            iconColor="#06B6D4"
          >
            <TextArea
              rows={9}
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Enter each message on a new line"
            />
            <div className="mt-4 flex justify-end">
              <Button icon="check" loading={saving} onClick={() => save()}>
                Save
              </Button>
            </div>
          </Panel>
          <div className="space-y-5 lg:col-span-2">
            <Panel title="Visibility" icon="visibility" bodyClass="p-5">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <div className="font-semibold">Ticker Enabled</div>
                  <div className="text-xs text-muted">Scrolling text on participant home</div>
                </div>
                <Switch
                  checked={ticker.enabled !== false}
                  onChange={(v) => {
                    setTicker((t: any) => ({ ...t, enabled: v }));
                    save(v);
                  }}
                />
              </div>
            </Panel>
            <Panel title="Preview" icon="preview" iconColor="#A855F7" bodyClass="p-5">
              {preview ? (
                <div className="flex items-center overflow-hidden rounded-lg border border-[#1D4ED8]/50 bg-[#1E3A8A]/70">
                  <span className="z-10 flex shrink-0 items-center gap-1 bg-[#1D4ED8] px-3 py-2 text-xs font-bold">
                    <Icon name="campaign" size={15} />
                    NEWS
                  </span>
                  <div className="relative flex-1 overflow-hidden py-2">
                    <div
                      className="flex w-max whitespace-nowrap text-[13px] font-medium"
                      style={{ animation: `ticker ${Math.max(12, preview.length * 0.18)}s linear infinite` }}
                    >
                      <span className="pr-10">{preview}</span>
                      <span className="pr-10">{preview}</span>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="text-sm text-muted">Nothing to show yet.</div>
              )}
            </Panel>
          </div>
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
    get("/youtube-live").then((r) => {
      setUrl(r.success ? String(r.url ?? "") : "");
      setLoaded(true);
    });
  }, []);

  const save = async () => {
    setSaving(true);
    const r = await put("/youtube-live", { url: url.trim() });
    setSaving(false);
    if (r.success) toast(url.trim() ? "Live URL updated" : "Live URL cleared", "success");
    else toast(r.error || "Failed", "error");
  };

  return (
    <Page title="YouTube Live" subtitle="Show a LIVE link on the home pages" width={760}>
      {!loaded ? (
        <Loading />
      ) : (
        <Panel title="Live stream link" icon="smart_display" iconColor="#DC2626">
          <div className="mb-5 flex items-start gap-2.5 rounded-lg border border-accent/20 bg-accent/5 p-3.5 text-sm">
            <Icon name="info" outline size={18} color="#60A5FA" />
            <span className="text-white/70">
              Paste a YouTube live URL to show a &ldquo;LIVE&rdquo; capsule on the participant home screen. Clear the
              URL to hide it.
            </span>
          </div>
          <Field label="YouTube Live URL">
            <Input
              icon="link"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://youtube.com/live/..."
            />
          </Field>
          <div className="mt-5 flex justify-end gap-2">
            {url && (
              <Button
                variant="outline"
                icon="delete"
                onClick={() => {
                  setUrl("");
                  save();
                }}
              >
                Clear
              </Button>
            )}
            <Button icon="check" loading={saving} onClick={save}>
              Save
            </Button>
          </div>
        </Panel>
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
    if (r.success) {
      toast("Notification sent!", "success");
      setTitle("");
      setBody("");
    } else toast(r.error || "Could not send", "error");
  };

  return (
    <Page title="Send Notification" subtitle="Push a message to every participant of an event" width={1000}>
      <div className="grid gap-5 lg:grid-cols-5">
        <Panel className="lg:col-span-3" title="Compose" icon="edit_note" iconColor="#10B981">
          <div className="space-y-4">
            <Field label="Event">
              <select value={selectedEvent} onChange={(e) => setSelectedEvent(e.target.value)} className="input">
                <option value="">Select event</option>
                {events.map((ev) => (
                  <option key={idOf(ev)} value={idOf(ev)}>
                    {ev.title}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Title">
              <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Notification title" />
            </Field>
            <Field label="Message">
              <TextArea
                rows={6}
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="Notification body"
              />
            </Field>
            <div className="flex justify-end">
              <Button icon="send" loading={sending} onClick={send}>
                Send Notification
              </Button>
            </div>
          </div>
        </Panel>
        <Panel className="lg:col-span-2 self-start" title="Preview" icon="smartphone" iconColor="#A855F7">
          <div className="rounded-xl border border-line bg-field p-4">
            <div className="flex items-start gap-3">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-accent/15">
                <Icon name="notifications" size={19} color="#60A5FA" />
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 text-[11px] text-muted">
                  ISDR 2026 <span>·</span> now
                </div>
                <div className="mt-0.5 truncate text-sm font-semibold">{title.trim() || "Notification title"}</div>
                <div className="mt-0.5 whitespace-pre-wrap text-[13px] text-white/70">
                  {body.trim() || "Notification body"}
                </div>
              </div>
            </div>
          </div>
          <div className="mt-3 text-xs text-muted">
            {selectedEvent
              ? `Goes to participants of ${events.find((ev) => idOf(ev) === selectedEvent)?.title ?? "the selected event"}.`
              : "Select an event to choose who receives it."}
          </div>
        </Panel>
      </div>
    </Page>
  );
}

/* =========================================================================
   ENGAGEMENT OVERVIEW
========================================================================= */

/** Date + time for downloads. */
const when = (v: any) => {
  const d = v ? new Date(v) : null;
  return d && !isNaN(d.getTime()) ? d.toLocaleString() : "";
};

/**
 * Team member's QR pass number (ADM0001 / STF0001…); the older id-based code until
 * the backend has assigned one. The main admin row's id is "primary_<property id>".
 */
const teamPass = (u: any, role: string) =>
  String(u.passNumber || passCode(role, String(idOf(u)).replace(/^primary_/, "")));
const teamQr = (role: string): QrConfig<any> => ({
  code: (u) => teamPass(u, role),
  badge: (u) => ({
    name: u.name,
    participantType: role,
    idNumber: teamPass(u, role),
    designation: role === "ADMIN" ? String(u.roleTitle || "Admin Member").replace("Management", "Admin") : "",
    qrCode: teamPass(u, role),
  }),
  fileName: (u) => `${teamPass(u, role)} - ${u.name || role}`,
});

export function EngagementOverview() {
  const toast = useToast();
  const confirm = useConfirm();
  const [tab, setTab] = useState<"questions" | "polls" | "speaker">("questions");
  const [data, setData] = useState<{ questions: any[]; polls: any[]; speakerQs: any[] } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  const term = query.trim().toLowerCase();
  // Every text in the item (question, session, speaker, participant, answer, options, answers).
  const textOf = (v: any, depth = 0): string =>
    v == null
      ? ""
      : typeof v === "object"
        ? depth > 2
          ? ""
          : Object.values(v)
              .map((x) => textOf(x, depth + 1))
              .join(" ")
        : String(v);
  const match = (list: any[]) => (term ? list.filter((it) => textOf(it).toLowerCase().includes(term)) : list);

  const load = useCallback(async () => {
    const [q, p, sq] = await Promise.all([
      get("/engagement/session-questions"),
      get("/engagement/session-polls"),
      get("/engagement/speaker-questions"),
    ]);
    if (!q.success) return setError(q.error || "Could not load engagement data");
    setData({ questions: q.questions ?? [], polls: p.polls ?? [], speakerQs: sq.questions ?? [] });
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  /** Admin delete of a session poll / question (same as the app's Engagement Overview). */
  const remove = async (item: any, isPoll: boolean) => {
    if (
      !(await confirm({
        title: isPoll ? "Delete poll?" : "Delete question?",
        message: isPoll
          ? "The poll and all its votes will be removed."
          : "The question and all its answers will be removed.",
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const r = await del(`/session-content/${item.scheduleId}/${isPoll ? "polls" : "questions"}/${idOf(item)}`);
    if (r.success) {
      toast(isPoll ? "Poll deleted" : "Question deleted", "success");
      setData((d) =>
        d
          ? isPoll
            ? { ...d, polls: d.polls.filter((x) => idOf(x) !== idOf(item)) }
            : { ...d, questions: d.questions.filter((x) => idOf(x) !== idOf(item)) }
          : d,
      );
    } else toast(r.error || "Could not delete", "error");
  };
  const deleteButton = (item: any, isPoll: boolean) =>
    item.scheduleId ? (
      <IconButton
        icon="delete"
        outline
        color="#EF4444"
        title={isPoll ? "Delete poll" : "Delete question"}
        onClick={() => remove(item, isPoll)}
      />
    ) : null;

  return (
    <Page
      title="Engagement Overview"
      subtitle="Session Q&A, polls and speaker questions across the conference"
      actions={
        data &&
        (tab === "questions" ? (
          <ExportMenu
            title="Session Q&A"
            rows={match(data.questions)}
            columns={[
              { header: "Session", value: (q: any) => q.scheduleName, width: 22 },
              { header: "Question", value: (q: any) => q.question, width: 34 },
              { header: "Answers", value: (q: any) => (q.answers ?? []).length, width: 9 },
              {
                header: "Answered by",
                value: (q: any) =>
                  (q.answers ?? []).map((a: any) => `${a.name || "Participant"}: ${a.text ?? ""}`).join("\n"),
                width: 40,
              },
              { header: "Asked on", value: (q: any) => when(q.createdAt), width: 18 },
            ]}
          />
        ) : tab === "polls" ? (
          <ExportMenu
            title="Polls"
            rows={match(data.polls)}
            columns={[
              { header: "Session", value: (p: any) => p.scheduleName, width: 22 },
              { header: "Question", value: (p: any) => p.question, width: 32 },
              {
                header: "Results",
                value: (p: any) =>
                  (p.options ?? [])
                    .map((o: string, i: number) => {
                      const c = (p.counts ?? [])[i] ?? 0;
                      const pct = Math.round((c / (Number(p.totalVotes) || 1)) * 100);
                      return `${o}: ${c} (${pct}%)`;
                    })
                    .join("\n"),
                width: 34,
              },
              { header: "Total votes", value: (p: any) => p.totalVotes ?? 0, width: 11 },
              { header: "Created on", value: (p: any) => when(p.createdAt), width: 18 },
            ]}
          />
        ) : (
          <ExportMenu
            title="Speaker Q&A"
            rows={match(data.speakerQs)}
            columns={[
              { header: "Speaker", value: (q: any) => q.speakerName, width: 18 },
              { header: "Asked by", value: (q: any) => q.participantName, width: 18 },
              { header: "Question", value: (q: any) => q.question, width: 32 },
              { header: "Answer", value: (q: any) => q.answer, width: 32 },
              { header: "Status", value: (q: any) => (q.answered ? "Answered" : "Unanswered"), width: 12 },
              { header: "Asked on", value: (q: any) => when(q.createdAt), width: 18 },
            ]}
          />
        ))
      }
    >
      <Tabs
        value={tab}
        onChange={setTab}
        tabs={[
          { value: "questions", label: "Session Q&A", count: data?.questions.length },
          { value: "polls", label: "Polls", count: data?.polls.length },
          { value: "speaker", label: "Speaker Q&A", count: data?.speakerQs.length },
        ]}
      />
      <div className="mt-4 max-w-md">
        <SearchBox
          value={query}
          onChange={setQuery}
          placeholder="Search question, session, speaker, participant, answer…"
        />
      </div>
      <div className="mt-5">
        {error ? (
          <ErrorState message={error} onRetry={load} />
        ) : !data ? (
          <Loading />
        ) : (
          <>
            {tab === "questions" &&
              (match(data.questions).length === 0 ? (
                <Empty icon="forum" title={query.trim() ? `No results for "${query.trim()}"` : "No session Q&A yet"} />
              ) : (
                <div className="grid gap-3 md:grid-cols-2">
                  {match(data.questions).map((q) => (
                    <div key={idOf(q)} className="card p-5">
                      <div className="flex items-center gap-2 text-xs text-muted">
                        <Icon name="event_note" size={15} outline />
                        <span className="flex-1 truncate">{q.scheduleName ?? "Session"}</span>
                        {deleteButton(q, false)}
                      </div>
                      <div className="mt-2 font-semibold">{q.question}</div>
                      <div className="mt-3">
                        <Pill color="#3B82F6">{(q.answers ?? []).length} answers</Pill>
                      </div>
                    </div>
                  ))}
                </div>
              ))}
            {tab === "polls" &&
              (match(data.polls).length === 0 ? (
                <Empty icon="bar_chart" title={query.trim() ? `No results for "${query.trim()}"` : "No polls yet"} />
              ) : (
                <div className="grid gap-3 md:grid-cols-2">
                  {match(data.polls).map((p) => (
                    <div key={idOf(p)} className="card p-5">
                      <div className="flex items-start gap-2">
                        <div className="flex-1 font-semibold">{p.question}</div>
                        {deleteButton(p, true)}
                      </div>
                      <div className="mt-1 text-xs text-muted">
                        {p.scheduleName ?? "Session"} · {p.totalVotes ?? 0} votes
                      </div>
                      <div className="mt-2 space-y-1.5">
                        {(p.options ?? []).map((o: string, i: number) => {
                          const c = (p.counts ?? [])[i] ?? 0;
                          const total = Number(p.totalVotes) || 1;
                          const pct = Math.round((c / total) * 100);
                          return (
                            <div key={i}>
                              <div className="flex justify-between text-xs">
                                <span>{o}</span>
                                <span className="text-muted">{pct}%</span>
                              </div>
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
              ))}
            {tab === "speaker" &&
              (match(data.speakerQs).length === 0 ? (
                <Empty
                  icon="help"
                  title={query.trim() ? `No results for "${query.trim()}"` : "No speaker questions yet"}
                />
              ) : (
                <div className="grid gap-3 md:grid-cols-2">
                  {match(data.speakerQs).map((q) => (
                    <div key={idOf(q)} className="card p-5">
                      <div className="flex items-center gap-2">
                        <span className="flex-1 truncate text-xs text-muted">To: {q.speakerName ?? "Speaker"}</span>
                        <Pill color={q.answered ? "#22C55E" : "#F59E0B"}>{q.answered ? "Answered" : "Unanswered"}</Pill>
                      </div>
                      <div className="mt-2 font-semibold">{q.question}</div>
                      {q.answer && <div className="mt-2 rounded-lg bg-field p-2.5 text-sm">{q.answer}</div>}
                    </div>
                  ))}
                </div>
              ))}
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
  useEffect(() => {
    load();
  }, [load]);

  const act = async (ids: string[], action: "unlock" | "revert") => {
    const label = action === "unlock" ? "Unlock certificate" : "Revoke certificate";
    if (
      !(await confirm({
        title: `${label} for ${ids.length} participant(s)?`,
        confirm: label,
        danger: action === "revert",
      }))
    )
      return;
    const r = await post(`/certificates/${action}`, { participantIds: ids });
    if (r.success) {
      toast(`${cap(action)} done`, "success");
      load();
    } else toast(r.error || "Failed", "error");
  };

  const filtered = (certs ?? []).filter((c) => {
    if (!search) return true;
    const s = search.toLowerCase();
    return (
      (c.name ?? "").toLowerCase().includes(s) ||
      fullName(c).toLowerCase().includes(s) ||
      (c.mobileNumber ?? "").includes(s)
    );
  });

  return (
    <Page title="Certificates" subtitle="Unlock or revoke participants' certificates">
      {!certs ? (
        <Loading />
      ) : (
        <div className="card overflow-hidden">
          <div className="flex flex-wrap items-center gap-3 border-b border-line px-5 py-4">
            <div className="flex-1 text-sm text-muted">
              {filtered.length} of {certs.length} participants
            </div>
            <div className="w-full sm:w-80">
              <SearchBox value={search} onChange={setSearch} placeholder="Search participants..." />
            </div>
            <ExportMenu
              title="Certificates"
              rows={filtered}
              columns={[
                { header: "Participant", value: (c: any) => fullName(c) || c.name, width: 24 },
                { header: "ID no.", value: (c: any) => c.idNumber, width: 11 },
                { header: "Mobile", value: (c: any) => c.mobileNumber, width: 14 },
                {
                  header: "Days scanned",
                  value: (c: any) => (c.totalDays != null ? `${c.daysScanned ?? 0} / ${c.totalDays}` : ""),
                  width: 12,
                },
                {
                  header: "Status",
                  value: (c: any) =>
                    (c.revoked ?? c.certificateRevoked)
                      ? "Revoked"
                      : (c.unlocked ?? c.certificateUnlocked)
                        ? "Unlocked"
                        : "Locked",
                  width: 11,
                },
              ]}
            />
          </div>
          {filtered.length === 0 ? (
            <div className="p-5">
              <Empty icon="workspace_premium" title="No participants" />
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Participant</th>
                    <th>Mobile</th>
                    <th>Status</th>
                    <th className="text-right">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((c) => {
                    const name = fullName(c) || c.name || "Participant";
                    const unlocked = c.certificateUnlocked === true;
                    const revoked = c.certificateRevoked === true;
                    return (
                      <tr key={idOf(c)}>
                        <td>
                          <div className="flex items-center gap-3">
                            <Avatar src={c.photoUrl} name={name} size={34} />
                            <span className="font-medium">{name}</span>
                          </div>
                        </td>
                        <td className="text-white/75">{c.mobileNumber || "—"}</td>
                        <td>
                          {unlocked && <Pill color="#22C55E">Unlocked</Pill>}
                          {revoked && <Pill color="#EF4444">Revoked</Pill>}
                          {!unlocked && !revoked && <Pill color="#F59E0B">Locked</Pill>}
                        </td>
                        <td className="text-right">
                          {!unlocked && !revoked && (
                            <Button small variant="success" icon="lock_open" onClick={() => act([idOf(c)], "unlock")}>
                              Unlock
                            </Button>
                          )}
                          {unlocked && !revoked && (
                            <Button small variant="danger" icon="block" onClick={() => act([idOf(c)], "revert")}>
                              Revoke
                            </Button>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
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
  // Add / edit Admin ID form (same fields as the app); editing = the member being edited.
  const [adding, setAdding] = useState(false);
  const [editing, setEditing] = useState<any | null>(null);
  const [name, setName] = useState("");
  const [mobile, setMobile] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const [mu, st] = await Promise.all([get("/auth/management-users"), get("/auth/users")]);
    if (mu.success) setUsers(mu.users ?? []);
    if (st.success) setStaff(st.users ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const openForm = (u: any | null) => {
    setEditing(u);
    setName(u?.name ?? "");
    setMobile(u?.mobileNumber ?? "");
    setEmail(u?.email ?? "");
    setPassword("");
    setAdding(true);
  };
  const closeForm = () => {
    setAdding(false);
    setEditing(null);
  };

  const saveMgmt = async () => {
    if (!name.trim()) return toast("Name is required", "error");
    if (!mobile.trim()) return toast("Mobile number is required", "error");
    if (mobile.trim().length !== 10) return toast("Enter a valid 10-digit mobile number", "error");
    if (!email.trim()) return toast("Email address is required", "error");
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return toast("Enter a valid email address", "error");
    if (!editing && !password) return toast("Password is required", "error");
    if (password && password.length < 6) return toast("Password must be at least 6 characters", "error");
    const body: Record<string, string> = {
      name: name.trim(),
      mobileNumber: mobile.trim(),
      email: email.trim().toLowerCase(),
      roleTitle: editing?.roleTitle || "Admin Member",
    };
    if (password) body.password = password;
    setSaving(true);
    const r = editing
      ? await put(`/auth/management-users/${idOf(editing)}`, body)
      : await post("/auth/management-users", body);
    setSaving(false);
    if (r.success) {
      toast(editing ? "Admin ID updated successfully" : "Admin ID created successfully", "success");
      closeForm();
      load();
    } else toast(r.error || (editing ? "Failed to update ID" : "Failed to create ID"), "error");
  };

  const removeMgmt = async (u: any) => {
    if (!(await confirm({ title: `Remove ${u.name}?`, confirm: "Remove", danger: true }))) return;
    const r = await del(`/auth/management-users/${idOf(u)}`);
    if (r.success) {
      setUsers((l) => (l ?? []).filter((x) => idOf(x) !== idOf(u)));
      toast("Removed");
    } else toast(r.error || "Failed", "error");
  };

  const toggleStaff = async (u: any) => {
    const r = await put(`/auth/users/${idOf(u)}/toggle-active`, {});
    if (r.success) {
      load();
      toast(u.isActive ? "Deactivated" : "Activated");
    } else toast(r.error || "Failed", "error");
  };

  const removeStaff = async (u: any) => {
    if (!(await confirm({ title: `Remove ${u.name}?`, confirm: "Remove", danger: true }))) return;
    const r = await del(`/auth/users/${idOf(u)}`);
    if (r.success) {
      setStaff((l) => (l ?? []).filter((x) => idOf(x) !== idOf(u)));
      toast("Removed");
    } else toast(r.error || "Failed", "error");
  };

  return (
    <Page
      title="Team"
      subtitle="Admin IDs and event staff accounts"
      actions={
        tab === "mgmt" ? (
          <div className="flex flex-wrap gap-2">
            <ExportMenu
              title="Admin IDs"
              rows={users}
              columns={[
                { header: "Pass no.", value: (u: any) => teamPass(u, "ADMIN"), width: 12 },
                { header: "Name", value: (u: any) => u.name, width: 24 },
                {
                  header: "Role",
                  value: (u: any) => String(u.roleTitle || "Admin Member").replace("Management", "Admin"),
                  width: 16,
                },
                { header: "Mobile", value: (u: any) => u.mobileNumber, width: 14 },
                { header: "Email", value: (u: any) => u.email, width: 26 },
              ]}
              qr={teamQr("ADMIN")}
            />
            <Button icon="person_add" onClick={() => openForm(null)}>
              Add Admin ID
            </Button>
          </div>
        ) : (
          <ExportMenu
            title="Event Staff"
            rows={staff}
            columns={[
              { header: "Pass no.", value: (u: any) => teamPass(u, "EVENT STAFF"), width: 12 },
              { header: "Name", value: (u: any) => u.name, width: 24 },
              { header: "Mobile", value: (u: any) => u.mobileNumber, width: 14 },
              { header: "Email", value: (u: any) => u.email, width: 26 },
              { header: "Approval", value: (u: any) => cap(u.status ?? "pending"), width: 11 },
              { header: "Status", value: (u: any) => (u.isActive ? "Active" : "Inactive"), width: 10 },
            ]}
            qr={teamQr("EVENT STAFF")}
          />
        )
      }
    >
      <Tabs
        value={tab}
        onChange={setTab}
        tabs={[
          { value: "mgmt", label: "Management", count: users?.length },
          { value: "staff", label: "Event Staff", count: staff?.length },
        ]}
      />
      <div className="mt-5">
        {tab === "mgmt" &&
          (!users ? (
            <Loading />
          ) : users.length === 0 ? (
            <Empty icon="group" title="No management users" />
          ) : (
            <div className="card overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Mobile</th>
                    <th>Email</th>
                    <th className="text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u) => (
                    <tr key={idOf(u)}>
                      <td>
                        <div className="flex items-center gap-3">
                          <Avatar name={u.name} size={34} />
                          <div>
                            <div className="font-medium">{u.name}</div>
                            {/* Older IDs were saved as 'Management Member'. */}
                            <div className="text-xs text-muted">
                              {String(u.roleTitle || "Admin Member").replace("Management", "Admin")}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="text-white/75">{u.mobileNumber || "—"}</td>
                      <td className="text-white/75">{u.email || "—"}</td>
                      <td className="text-right">
                        {/* The primary (property) admin can't be edited or removed here, same as the app. */}
                        {!String(idOf(u)).startsWith("primary_") && (
                          <span className="inline-flex gap-1">
                            <IconButton icon="edit" outline title="Edit" onClick={() => openForm(u)} />
                            <IconButton
                              icon="delete"
                              outline
                              color="#EF4444"
                              title="Remove"
                              onClick={() => removeMgmt(u)}
                            />
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
        {tab === "staff" &&
          (!staff ? (
            <Loading />
          ) : staff.length === 0 ? (
            <Empty icon="badge" title="No event staff" />
          ) : (
            <div className="card overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Approval</th>
                    <th>Status</th>
                    <th className="text-right">Active</th>
                    <th className="w-14 text-right">Remove</th>
                  </tr>
                </thead>
                <tbody>
                  {staff.map((u) => (
                    <tr key={idOf(u)}>
                      <td>
                        <div className="flex items-center gap-3">
                          <Avatar src={u.profilePic} name={u.name} size={34} />
                          <span className="font-medium">{u.name}</span>
                        </div>
                      </td>
                      <td>
                        <Pill color={u.status === "approved" ? "#22C55E" : "#F59E0B"}>
                          {cap(u.status ?? "pending")}
                        </Pill>
                      </td>
                      <td>
                        <Pill color={u.isActive ? "#22C55E" : "#EF4444"}>{u.isActive ? "Active" : "Inactive"}</Pill>
                      </td>
                      <td className="text-right">
                        <span className="inline-flex">
                          <Switch checked={u.isActive} onChange={() => toggleStaff(u)} />
                        </span>
                      </td>
                      <td className="text-right">
                        <IconButton
                          icon="delete"
                          outline
                          color="#EF4444"
                          title="Remove"
                          onClick={() => removeStaff(u)}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
      </div>
      <Modal
        open={adding}
        onClose={closeForm}
        title={editing ? "Edit Admin ID" : "Add Admin ID"}
        width={460}
        footer={
          <>
            <Button variant="outline" onClick={closeForm}>
              Cancel
            </Button>
            <Button loading={saving} onClick={saveMgmt}>
              {editing ? "Save changes" : "Create Admin ID"}
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="Name">
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Full name" />
          </Field>
          <Field label="Mobile number">
            <Input
              value={mobile}
              inputMode="numeric"
              maxLength={10}
              onChange={(e) => setMobile(e.target.value.replace(/\D/g, ""))}
              placeholder="10-digit mobile number"
            />
          </Field>
          <Field label="Email address">
            <Input
              value={email}
              type="email"
              onChange={(e) => setEmail(e.target.value)}
              placeholder="name@example.com"
            />
          </Field>
          <Field label={editing ? "New password (optional)" : "Set password"}>
            <PasswordInput
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder={editing ? "Leave blank to keep the current password" : "At least 6 characters"}
            />
          </Field>
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

  if (!user)
    return (
      <Page title="Profile">
        <Loading />
      </Page>
    );

  return (
    <Page title="My Profile" width={960}>
      <div className="grid gap-5 lg:grid-cols-3">
        <div className="card flex flex-col items-center p-6 text-center">
          <div className="relative">
            <Avatar src={user.profilePic} name={user.name} size={104} />
            <button
              onClick={pick}
              title="Change photo"
              className="absolute bottom-0 right-0 flex h-9 w-9 items-center justify-center rounded-full border-2 border-card bg-accent"
            >
              {uploading ? <Spinner size={15} color="#fff" /> : <Icon name="photo_camera" size={17} />}
            </button>
            {input}
          </div>
          <div className="mt-4 text-lg font-semibold">{user.name}</div>
          <div className="text-sm text-muted">{user.email}</div>
          <div className="mt-3">
            <Pill color="#3B82F6">Event Admin</Pill>
          </div>
        </div>
        <div className="lg:col-span-2">
          <ModuleGrid
            cols="grid-cols-1 sm:grid-cols-2"
            items={[
              {
                label: "Change Password",
                sub: "Update your password",
                icon: "lock",
                color: "#3B82F6",
                onClick: () => navigate("/change-password"),
              },
              {
                label: "QR Pass",
                sub: "Your pass",
                icon: "qr_code_2",
                color: "#10B981",
                onClick: () => navigate("/pass?role=ADMIN&profile=1"),
              },
              {
                label: "Brochure",
                sub: "Conference brochure",
                icon: "menu_book",
                color: "#F59E0B",
                onClick: () => navigate("/brochure"),
              },
              { label: "Logout", sub: "Sign out of this device", icon: "logout", color: "#EF4444", onClick: doLogout },
            ]}
          />
        </div>
      </div>
    </Page>
  );
}

/* =========================================================================
   ADMIN MORE
========================================================================= */

export function AdminMore() {
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
    <Page title="All Sections" back={false}>
      <ModuleGrid items={[...items, { label: "Logout", icon: "logout", color: "#EF4444", onClick: doLogout }]} />
    </Page>
  );
}

/* =========================================================================
   LIVE PHOTO (gallery link shown as "Get your live photos" on every home)
========================================================================= */

export function ManageLivePhoto() {
  const toast = useToast();
  const [url, setUrl] = useState("");
  const [saved, setSaved] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    get("/live-photo").then((r) => {
      if (!r.success) toast(r.error || "Could not load the link", "error");
      const u = r.success ? String(r.url ?? "").trim() : "";
      setUrl(u);
      setSaved(u);
      setLoaded(true);
    });
  }, [toast]);

  const save = async (value: string) => {
    setSaving(true);
    const r = await put("/live-photo", { url: value.trim() });
    setSaving(false);
    if (!r.success) return toast(r.error || "Could not save", "error");
    setSaved(value.trim());
    setUrl(value.trim());
    toast(value.trim() ? "Live photo link saved" : "Live photo link removed", "success");
  };

  return (
    <Page title="Live Photo" subtitle={'Displays "Get your live photos" button on every home'} width={760}>
      {!loaded ? (
        <Loading />
      ) : (
        <Panel title="Live photo link" icon="photo_camera" iconColor="#E11D48">
          <div
            className={`mb-5 flex items-center gap-2 rounded-lg border px-3.5 py-2.5 text-sm font-semibold ${
              saved ? "border-[#22C55E]/30 bg-[#22C55E]/10 text-[#86EFAC]" : "border-line bg-white/[0.03] text-muted"
            }`}
          >
            <Icon name={saved ? "check_circle" : "visibility_off"} size={18} />
            {saved ? "Active — Showing across all roles" : "Not showing — no link set"}
          </div>
          <Field label="LIVE PHOTO LINK">
            <Input
              icon="link"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="Paste live photo gallery link (Google Photos, Drive, etc.)"
            />
          </Field>
          <div className="mt-5 flex justify-end gap-2">
            {saved && (
              <Button
                variant="outline"
                icon="delete"
                className="!text-[#F87171]"
                disabled={saving}
                onClick={() => save("")}
              >
                Remove Live Photo Link
              </Button>
            )}
            <Button icon="check" loading={saving} disabled={!url.trim()} onClick={() => save(url)}>
              Save Link
            </Button>
          </div>
        </Panel>
      )}
    </Page>
  );
}
