/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppFab, AppSpinner } from "@/components/app/AppControls";
import { AppSelectField } from "@/components/app/AppForm";
import { del, get, post, put } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { idOf, parseDate } from "@/lib/format";

/** The app's helpTicketCategories (value, label, icon, colour). */
const CATEGORIES = [
  { value: "emergency", label: "Emergency", icon: "emergency", outline: false, color: "#EF4444" },
  { value: "medical", label: "Medical Issues", icon: "medical_services", outline: false, color: "#EC4899" },
  { value: "others", label: "Others", icon: "help", outline: true, color: "#94A3B8" },
  { value: "app", label: "App related issues", icon: "phone_android", outline: false, color: "#3B82F6" },
];
const categoryOf = (v: any) => CATEGORIES.find((c) => c.value === v) ?? CATEGORIES[2];

const INACTIVE_AFTER_MS = 5 * 60 * 60 * 1000;
function statusOf(t: any) {
  if (t.status === "closed") return "closed";
  const last = parseDate(t.lastParticipantAt ?? t.createdAt);
  if (!last) return "active";
  return Date.now() - last.getTime() > INACTIVE_AFTER_MS ? "inactive" : "active";
}

const FILTERS = [
  { key: "all", label: "All", icon: "all_inbox", color: "#3B82F6" },
  { key: "active", label: "Active", icon: "bolt", color: "#22C55E" },
  { key: "inactive", label: "Inactive", icon: "hourglass_bottom", color: "#F59E0B" },
  { key: "closed", label: "Closed", icon: "lock", color: "#94A3B8" },
];

const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
/** DateFormat('d MMM, h:mm a'). */
function fmt(iso: any) {
  const d = parseDate(iso);
  if (!d) return "";
  const h = d.getHours();
  return `${d.getDate()} ${MON[d.getMonth()]}, ${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

/** The app's _AddTicketSheet: category dropdown + description; onSaved gets the ticket. */
function TicketFormSheet({ ticket, onClose, onSaved }: { ticket?: any; onClose: () => void; onSaved: (t: any) => void }) {
  const toast = useToast();
  const editing = !!ticket;
  const [category, setCategory] = useState<string>(
    CATEGORIES.some((c) => c.value === ticket?.category) ? ticket.category : "",
  );
  const [description, setDescription] = useState<string>(ticket?.description ?? "");
  const [saving, setSaving] = useState(false);

  const save = async () => {
    if (!category) return toast("Choose a category");
    if (!description.trim()) return toast("Describe the problem");
    setSaving(true);
    const body = { category, description: description.trim() };
    const r = editing ? await put(`/support-tickets/${idOf(ticket)}`, body) : await post("/support-tickets", body);
    setSaving(false);
    if (r.success && r.ticket) onSaved(r.ticket);
    else toast(r.error || (editing ? "Could not save the ticket" : "Could not add the ticket"));
  };

  return (
    <div className="animate-fade fixed inset-0 z-[90] flex items-end" onClick={onClose}>
      <div className="absolute inset-0 bg-black/55" />
      <div className="animate-sheet relative w-full rounded-t-[20px] bg-card p-5" onClick={(e) => e.stopPropagation()}>
        <div className="font-outfit text-[18px] font-bold">{editing ? "Edit Ticket" : "New Ticket"}</div>
        <div className="mt-4">
          <AppSelectField
            label="Category"
            icon="category"
            hint="Select a category"
            value={category}
            onChange={setCategory}
            options={CATEGORIES.map((c) => ({ value: c.value, label: c.label }))}
            outer="#14141F"
          />
        </div>
        <div className="mt-3.5">
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value.slice(0, 2000))}
            rows={3}
            placeholder="Describe the problem"
            className="block max-h-[150px] min-h-[84px] w-full resize-none rounded-[14px] border border-line bg-field px-3 py-3 text-sm text-white outline-none placeholder:text-muted focus:border-accent"
          />
          <div className="mt-1 pr-3 text-right text-xs text-muted">{description.length}/2000</div>
        </div>
        <button
          onClick={saving ? undefined : save}
          className="mt-4 flex h-[50px] w-full items-center justify-center gap-2 rounded-[14px] bg-accent text-[15px] font-bold"
        >
          {saving ? <Spinner size={20} color="#fff" /> : editing ? "Save Changes" : "Add Ticket"}
        </button>
      </div>
    </div>
  );
}

/** Help & Support (participant) / Support Tickets (staff, admin) at phone width — the app's HelpTicketsPage. */
export function HelpTicketsApp() {
  const { user } = useAuth();
  const isParticipant = user?.userType === "participant";
  const navigate = useNavigate();
  const [tickets, setTickets] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState("all");
  const [adding, setAdding] = useState(false);

  const load = useCallback(async () => {
    const r = await get("/support-tickets");
    setLoading(false);
    if (r.success) {
      setError(null);
      setTickets(r.tickets ?? []);
    } else setError(r.error || "Could not load tickets");
  }, []);
  useEffect(() => {
    load();
    // "New ticket" from a closed ticket's chat.
    if (sessionStorage.getItem("support_new") === "1") {
      sessionStorage.removeItem("support_new");
      setAdding(true);
    }
  }, [load]);

  const shown = isParticipant || filter === "all" ? tickets : tickets.filter((t) => statusOf(t) === filter);
  const count = (key: string) => (key === "all" ? tickets.length : tickets.filter((t) => statusOf(t) === key).length);

  const card = (t: any) => {
    const cat = categoryOf(t.category);
    const last = t.lastMessage && typeof t.lastMessage === "object" ? t.lastMessage : null;
    const when = fmt(t.lastMessageAt);
    const replies = (Number(t.messageCount) || 1) - 1;
    const lastFromParticipant = last?.senderType === "participant";
    return (
      <button
        key={idOf(t)}
        onClick={() => navigate(`/support/${idOf(t)}`)}
        className="mb-3 block w-full rounded-[14px] border bg-card p-3.5 text-left active:bg-white/[0.03]"
        style={{ borderColor: `${cat.color}59` }}
      >
        <span className="flex items-center">
          <span
            className="inline-flex items-center gap-[5px] rounded-full px-[9px] py-1 text-[11px] font-bold"
            style={{ background: `${cat.color}26`, color: cat.color }}
          >
            <Icon name={cat.icon} outline={cat.outline} size={13} color={cat.color} />
            {cat.label}
          </span>
          {t.status === "closed" && (
            <span className="ml-1.5 inline-flex items-center gap-1 rounded-full bg-white/[0.08] px-2 py-1 text-[11px] font-bold text-muted">
              <Icon name="lock" size={11} color="#9CA3AF" />
              Closed
            </span>
          )}
          <span className="flex-1" />
          {when && <span className="text-[11px] text-muted">{when}</span>}
        </span>
        {!isParticipant && (
          <span className="mt-2 flex items-center gap-[5px] text-[12.5px] font-bold text-[#60A5FA]">
            <Icon name="person" size={15} color="#60A5FA" />
            {t.participantName || "Participant"}
          </span>
        )}
        <span className="mt-2 line-clamp-2 block text-sm font-semibold leading-[1.35]">{t.description}</span>
        <span className="mt-2.5 flex items-center gap-1.5">
          <Icon name="chat_bubble" outline size={14} color={replies > 0 ? "#22C55E" : "#9CA3AF"} />
          <span className={`min-w-0 flex-1 truncate text-xs ${replies > 0 ? "text-white/75" : "text-muted"}`}>
            {replies <= 0
              ? isParticipant
                ? "Waiting for a reply"
                : "No reply yet"
              : `${lastFromParticipant ? (isParticipant ? "You" : "Participant") : "Support"}: ${last?.text ?? ""}`}
          </span>
          <Icon name="chevron_right" color="#9CA3AF" />
        </span>
      </button>
    );
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title={isParticipant ? "Help & Support" : "Support Tickets"} outfit />
      {loading ? (
        <AppSpinner />
      ) : (
        <div className="px-4 pb-24 pt-2">
          {!isParticipant && !error && (
            <div className="-mx-4 mb-3 flex h-10 gap-2 overflow-x-auto px-4 [scrollbar-width:none]">
              {FILTERS.map((f) => {
                const on = filter === f.key;
                return (
                  <button
                    key={f.key}
                    onClick={() => setFilter(f.key)}
                    className="flex shrink-0 items-center gap-1.5 rounded-full border px-3"
                    style={{ background: on ? f.color : "#14141F", borderColor: on ? f.color : "rgba(255,255,255,0.1)" }}
                  >
                    <Icon name={f.icon} outline={f.key === "closed"} size={16} color={on ? "#fff" : f.color} />
                    <span className={`text-[12.5px] font-bold ${on ? "text-white" : "text-white/80"}`}>{f.label}</span>
                    <span
                      className="rounded-[10px] px-[7px] py-px text-[11px] font-bold"
                      style={{ background: on ? "rgba(255,255,255,0.25)" : `${f.color}26`, color: on ? "#fff" : f.color }}
                    >
                      {count(f.key)}
                    </span>
                  </button>
                );
              })}
            </div>
          )}
          {error || shown.length === 0 ? (
            <div className="flex flex-col items-center py-20 text-center">
              <Icon name={error ? "error" : "support_agent"} outline={!!error} size={44} color="rgba(156,163,175,0.7)" />
              <div className="mt-2.5 whitespace-pre-line text-[13.5px] text-muted">
                {error ??
                  (isParticipant
                    ? 'No tickets yet.\nTap "Add" if you need help.'
                    : filter === "all"
                      ? "No support tickets yet"
                      : `No ${filter} tickets`)}
              </div>
            </div>
          ) : (
            shown.map(card)
          )}
        </div>
      )}
      {isParticipant && <AppFab icon="add" label="Add" onClick={() => setAdding(true)} />}
      {adding && (
        <TicketFormSheet
          onClose={() => setAdding(false)}
          onSaved={(t) => {
            setAdding(false);
            navigate(`/support/${idOf(t)}`);
          }}
        />
      )}
    </div>
  );
}

const roleLabel = (t: any) => (t === "staff" ? "Event Staff" : t === "admin" ? "Admin" : "Participant");
const roleColor = (t: any) => (t === "staff" ? "#2DD4BF" : t === "admin" || t === "support" ? "#FBBF24" : "#60A5FA");

/** A ticket's chat at phone width — the app's TicketChatPage (polls every 5 s). */
export function TicketChatApp() {
  const { id = "" } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [ticket, setTicket] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [closing, setClosing] = useState(false);
  const [menu, setMenu] = useState(false);
  const [editingTicket, setEditingTicket] = useState(false);
  const [editingMsg, setEditingMsg] = useState<{ id: string; text: string; original: string } | null>(null);
  const bottom = useRef<HTMLDivElement>(null);
  const count = useRef(-1);
  const press = useRef<number | undefined>(undefined);

  const load = useCallback(async () => {
    const r = await get(`/support-tickets/${id}`);
    if (r.success && r.ticket) {
      setError(null);
      setTicket(r.ticket);
    } else setError((e) => e ?? (r.error || "Could not load chat"));
  }, [id]);
  useEffect(() => {
    load();
    const t = setInterval(load, 5000);
    return () => clearInterval(t);
  }, [load]);

  const messages: any[] = ticket?.messages ?? [];
  useEffect(() => {
    if (messages.length !== count.current) {
      count.current = messages.length;
      bottom.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages.length]);

  const send = async () => {
    const t = text.trim();
    if (!t || sending) return;
    setSending(true);
    const r = await post(`/support-tickets/${id}/messages`, { text: t });
    setSending(false);
    if (r.success && r.ticket) {
      setText("");
      setTicket(r.ticket);
    } else if (!r.success) toast(r.error || "Could not send");
  };
  const close = async () => {
    const ok = await confirm({
      title: "Close this ticket?",
      message:
        "The participant will no longer be able to send messages here. They can still read it or create a new ticket.",
      confirm: "Close ticket",
      danger: true,
    });
    if (!ok) return;
    setClosing(true);
    const r = await post(`/support-tickets/${id}/close`);
    setClosing(false);
    if (r.success && r.ticket) setTicket(r.ticket);
    if (!r.success) toast(r.error || "Could not close");
  };
  const deleteTicket = async () => {
    const ok = await confirm({
      title: "Delete this ticket?",
      message: "The ticket and all its messages will be removed permanently.",
      confirm: "Delete",
      danger: true,
    });
    if (!ok) return;
    const r = await del(`/support-tickets/${id}`);
    if (r.success) {
      toast("Ticket deleted");
      navigate("/support", { replace: true });
    } else toast(r.error || "Could not delete the ticket");
  };
  const saveMessage = async () => {
    if (!editingMsg) return;
    const t = editingMsg.text.trim();
    setEditingMsg(null);
    if (!t || t === editingMsg.original) return;
    const r = await put(`/support-tickets/${id}/messages/${editingMsg.id}`, { text: t });
    if (r.success && r.ticket) setTicket(r.ticket);
    else toast(r.error || "Could not edit the message");
  };

  const cat = categoryOf(ticket?.category);
  const participant = String(ticket?.participantName ?? "").trim();
  // Sent to staff/admin only, so participants never see a call button.
  const mobile = String(ticket?.participantMobile ?? "").trim();
  const closed = ticket?.status === "closed";
  const canReply = ticket?.canReply !== false;
  const canClose = ticket?.canClose === true;
  const canEdit = ticket?.canEdit === true;
  const canDelete = ticket?.canDelete === true;
  const closedDetails = [
    String(ticket?.closedByName ?? "").trim() && `by ${String(ticket.closedByName).trim()}`,
    fmt(ticket?.closedAt),
  ]
    .filter(Boolean)
    .join(" · ");

  // Long-press your own message to edit it.
  const holdStart = (m: any) => {
    if (m.canEdit !== true) return;
    press.current = window.setTimeout(
      () => setEditingMsg({ id: String(m.id), text: String(m.text ?? ""), original: String(m.text ?? "") }),
      500,
    );
  };
  const holdEnd = () => window.clearTimeout(press.current);

  return (
    <div className="flex h-[100dvh] flex-col bg-bg">
      <AppBar
        titleClassName="!text-left"
        title={
          <span className="flex items-center gap-2.5">
            <span
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full"
              style={{ background: `${cat.color}2e` }}
            >
              <Icon name={cat.icon} outline={cat.outline} size={19} color={cat.color} />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate font-outfit text-base font-bold">{cat.label}</span>
              {participant && <span className="block truncate text-[11.5px] text-muted">{participant}</span>}
            </span>
          </span>
        }
        actions={
          canClose || canEdit || canDelete ? (
            <>
              {canClose && (
                <button
                  onClick={closing ? undefined : close}
                  className="mr-2 inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium text-[#F87171]"
                >
                  {closing ? <Spinner size={14} color="#F87171" /> : <Icon name="lock" outline size={18} color="#F87171" />}
                  Close ticket
                </button>
              )}
              {(canEdit || canDelete) && (
                <div className="relative">
                  <button
                    onClick={() => setMenu((v) => !v)}
                    className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
                  >
                    <Icon name="more_vert" />
                  </button>
                  {menu && (
                    <>
                      <div className="fixed inset-0 z-40" onClick={() => setMenu(false)} />
                      <div className="absolute right-1 top-11 z-50 min-w-[180px] rounded bg-field py-2 shadow-lg">
                        {canEdit && (
                          <button
                            onClick={() => {
                              setMenu(false);
                              setEditingTicket(true);
                            }}
                            className="flex w-full items-center gap-4 px-4 py-2.5 text-left text-sm active:bg-white/10"
                          >
                            <Icon name="edit" outline size={22} />
                            Edit ticket
                          </button>
                        )}
                        {canDelete && (
                          <button
                            onClick={() => {
                              setMenu(false);
                              deleteTicket();
                            }}
                            className="flex w-full items-center gap-4 px-4 py-2.5 text-left text-sm text-[#F87171] active:bg-white/10"
                          >
                            <Icon name="delete" outline size={22} color="#F87171" />
                            Delete ticket
                          </button>
                        )}
                      </div>
                    </>
                  )}
                </div>
              )}
            </>
          ) : undefined
        }
      />
      {mobile && (
        <div className="mx-3 mb-1 mt-2 flex items-center rounded-[14px] border border-line bg-card py-2 pl-3 pr-2">
          <Icon name="person" size={20} color="#60A5FA" />
          <div className="ml-2.5 min-w-0 flex-1">
            {participant && <div className="truncate text-[13px] font-bold">{participant}</div>}
            <div className="text-[13px] font-semibold tracking-[0.3px] text-muted">{mobile}</div>
          </div>
          <a
            href={`tel:${mobile}`}
            className="inline-flex h-10 items-center gap-2 rounded-xl bg-[#16A34A] px-3.5 text-sm font-medium"
          >
            <Icon name="call" size={18} />
            Call
          </a>
        </div>
      )}
      {closed && (
        <div className="flex items-center gap-2 bg-[#2A2A33] px-4 py-2.5">
          <Icon name="lock" size={16} color="#9CA3AF" />
          <span className="text-[12.5px] font-semibold text-white/80">
            {closedDetails ? `This ticket is closed ${closedDetails}` : "This ticket is closed"}
          </span>
        </div>
      )}
      <div className="min-h-0 flex-1 overflow-y-auto p-3">
        {!ticket ? (
          error ? (
            <div className="flex h-full items-center justify-center text-muted">{error}</div>
          ) : (
            <div className="flex h-full items-center justify-center">
              <Spinner size={36} />
            </div>
          )
        ) : (
          messages.map((m, i) => {
            const mine = m.mine === true;
            const name = String(m.senderName ?? "").trim();
            // Participants see replies as the support team (no staff/admin name).
            const label =
              m.senderType === "support" ? name : name ? `${name} · ${roleLabel(m.senderType)}` : roleLabel(m.senderType);
            const when = fmt(m.createdAt);
            return (
              <div key={m.id ?? i} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                <div
                  onPointerDown={() => holdStart(m)}
                  onPointerUp={holdEnd}
                  onPointerLeave={holdEnd}
                  onContextMenu={(e) => m.canEdit === true && e.preventDefault()}
                  className={`mb-2 max-w-[78%] select-none px-3 pb-1.5 pt-2 ${mine ? "bg-accent" : "border border-line bg-card"}`}
                  style={{
                    borderRadius: mine ? "14px 14px 4px 14px" : "14px 14px 14px 4px",
                  }}
                >
                  {!mine && (
                    <div className="mb-[3px] text-[11px] font-bold" style={{ color: roleColor(m.senderType) }}>
                      {label}
                    </div>
                  )}
                  <div className="whitespace-pre-wrap break-words text-sm leading-[1.35]">{m.text}</div>
                  {when && (
                    <div className="mt-[3px] text-right text-[10px] text-white/60">
                      {m.edited === true ? "edited · " : ""}
                      {when}
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
        <div ref={bottom} />
      </div>
      {!ticket || canReply ? (
        <div className="flex items-end gap-1.5 border-t border-line bg-card py-2 pl-3 pr-2">
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            disabled={!ticket}
            rows={1}
            placeholder="Type a message"
            onInput={(e) => {
              const el = e.currentTarget;
              el.style.height = "auto";
              el.style.height = `${Math.min(el.scrollHeight, 100)}px`;
            }}
            className="block min-h-[44px] flex-1 resize-none rounded-[22px] bg-field px-3.5 py-2.5 text-sm text-white outline-none placeholder:text-muted"
          />
          <button
            onClick={send}
            disabled={sending || !ticket}
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-accent disabled:opacity-60"
            aria-label="Send"
          >
            {sending ? <Spinner size={18} color="#fff" /> : <Icon name="send" />}
          </button>
        </div>
      ) : (
        <div className="flex items-center gap-2 border-t border-line bg-card py-3 pl-4 pr-3">
          <span className="flex-1 text-[12.5px] text-muted">
            This ticket is closed. Need more help? Create a new ticket.
          </span>
          <button
            onClick={() => {
              sessionStorage.setItem("support_new", "1");
              navigate("/support", { replace: true });
            }}
            className="h-10 rounded-full bg-accent px-6 text-sm font-medium"
          >
            New ticket
          </button>
        </div>
      )}
      {editingTicket && ticket && (
        <TicketFormSheet
          ticket={ticket}
          onClose={() => setEditingTicket(false)}
          onSaved={(t) => {
            setEditingTicket(false);
            setTicket(t);
            load();
            toast("Ticket updated");
          }}
        />
      )}
      {editingMsg && (
        <div className="animate-fade fixed inset-0 z-[95] flex items-center justify-center px-10" onClick={() => setEditingMsg(null)}>
          <div className="absolute inset-0 bg-black/55" />
          <div className="relative w-full max-w-[400px] rounded-[28px] bg-card p-6" onClick={(e) => e.stopPropagation()}>
            <div className="text-2xl">Edit message</div>
            <textarea
              autoFocus
              value={editingMsg.text}
              onChange={(e) => setEditingMsg({ ...editingMsg, text: e.target.value.slice(0, 2000) })}
              rows={3}
              className="mt-4 block w-full resize-none rounded-xl bg-field px-3 py-3 text-sm text-white outline-none"
            />
            <div className="mt-6 flex justify-end gap-2">
              <button onClick={() => setEditingMsg(null)} className="h-10 rounded-full px-3 text-sm font-medium text-accent">
                Cancel
              </button>
              <button onClick={saveMessage} className="h-10 rounded-full px-3 text-sm font-medium text-accent">
                Save
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
