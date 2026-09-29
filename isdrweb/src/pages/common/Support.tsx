/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  Button,
  Chips,
  Empty,
  ErrorState,
  Icon,
  Loading,
  Modal,
  Page,
  Panel,
  Spinner,
  TextArea,
  useConfirm,
  useToast,
} from "@/components/ui";
import { del, get, post, put } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cap, fmtShortDateTime, idOf, parseDate, timeAgo } from "@/lib/format";

export const HELP_CATEGORIES = [
  { value: "emergency", label: "Emergency", icon: "emergency", color: "#EF4444" },
  { value: "medical", label: "Medical Issues", icon: "medical_services", color: "#EC4899" },
  { value: "others", label: "Others", icon: "help", color: "#94A3B8" },
  { value: "app", label: "App related issues", icon: "phone_android", color: "#3B82F6" },
];
const categoryOf = (v: any) => HELP_CATEGORIES.find((c) => c.value === v) ?? HELP_CATEGORIES[2];

const INACTIVE_AFTER_MS = 5 * 60 * 60 * 1000;
function statusOf(t: any) {
  if (t.status === "closed") return "closed";
  const last = parseDate(t.lastParticipantAt ?? t.createdAt);
  if (!last) return "active";
  return new Date().getTime() - last.getTime() > INACTIVE_AFTER_MS ? "inactive" : "active";
}

const FILTERS = [
  { key: "all", label: "All", icon: "all_inbox", color: "#3B82F6" },
  { key: "active", label: "Active", icon: "bolt", color: "#22C55E" },
  { key: "inactive", label: "Inactive", icon: "hourglass_bottom", color: "#F59E0B" },
  { key: "closed", label: "Closed", icon: "lock", color: "#94A3B8" },
];

/** New ticket, or (with `ticket`) edit its category + description. Calls onSaved with the saved ticket. */
function TicketFormModal({
  ticket,
  onClose,
  onSaved,
}: {
  ticket?: any;
  onClose: () => void;
  onSaved: (t: any) => void;
}) {
  const toast = useToast();
  const editing = !!ticket;
  const [category, setCategory] = useState<string>(ticket?.category ?? "");
  const [description, setDescription] = useState<string>(ticket?.description ?? "");
  const [saving, setSaving] = useState(false);

  const save = async () => {
    if (!category) return toast("Choose a category", "error");
    if (!description.trim()) return toast("Describe the problem", "error");
    setSaving(true);
    const body = { category, description: description.trim() };
    const res = editing ? await put(`/support-tickets/${idOf(ticket)}`, body) : await post("/support-tickets", body);
    setSaving(false);
    if (!res.success || !res.ticket)
      return toast(res.error || (editing ? "Could not update the ticket" : "Could not add the ticket"), "error");
    onSaved(res.ticket);
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={editing ? "Edit Ticket" : "New Ticket"}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={saving} icon={editing ? "check" : "add"} onClick={save}>
            {editing ? "Save Changes" : "Add Ticket"}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <div>
          <label className="label">Category</label>
          <div className="grid grid-cols-2 gap-2">
            {HELP_CATEGORIES.map((c) => (
              <button
                key={c.value}
                onClick={() => setCategory(c.value)}
                className="flex items-center gap-2.5 rounded-lg border px-3 py-2.5 text-left text-sm font-medium transition"
                style={{
                  borderColor: category === c.value ? c.color : "rgba(255,255,255,0.08)",
                  background: category === c.value ? `${c.color}1f` : "transparent",
                }}
              >
                <Icon name={c.icon} size={19} color={c.color} />
                {c.label}
              </button>
            ))}
          </div>
        </div>
        <div>
          <label className="label">Description</label>
          <TextArea
            rows={5}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Describe the problem"
          />
        </div>
      </div>
    </Modal>
  );
}

/** Participants: their tickets + Add (Help & Support). Staff / admin: every ticket with filters (Support Tickets). */
export function HelpTickets() {
  const { user } = useAuth();
  const isParticipant = user?.userType === "participant";
  const navigate = useNavigate();
  const [tickets, setTickets] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState("all");
  const [adding, setAdding] = useState(false);

  const load = useCallback(async () => {
    const res = await get("/support-tickets");
    if (!res.success) return setError(res.error || "Could not load tickets");
    setError(null);
    setTickets(res.tickets ?? []);
  }, []);
  useEffect(() => {
    load();
    if (sessionStorage.getItem("support_new") === "1") {
      sessionStorage.removeItem("support_new");
      setAdding(true);
    }
  }, [load]);

  const shown =
    isParticipant || filter === "all" ? (tickets ?? []) : (tickets ?? []).filter((t) => statusOf(t) === filter);

  return (
    <Page
      title={isParticipant ? "Help & Support" : "Support Tickets"}
      subtitle={isParticipant ? "Ask the support team for help" : "Tickets raised by participants"}
      back={false}
      width={1000}
      actions={
        isParticipant && (
          <Button icon="add" onClick={() => setAdding(true)}>
            New Ticket
          </Button>
        )
      }
    >
      {!isParticipant && !error && (
        <div className="mb-5">
          <Chips
            value={filter}
            onChange={setFilter}
            items={FILTERS.map((f) => ({
              value: f.key,
              label: f.label,
              icon: f.icon,
              color: f.color,
              count:
                f.key === "all" ? (tickets ?? []).length : (tickets ?? []).filter((t) => statusOf(t) === f.key).length,
            }))}
          />
        </div>
      )}
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !tickets ? (
        <Loading />
      ) : shown.length === 0 ? (
        <Empty
          icon="support_agent"
          title={isParticipant ? "No support tickets yet" : "No tickets"}
          subtitle={isParticipant ? "Click New Ticket to ask the support team for help." : undefined}
          action={
            isParticipant ? (
              <Button icon="add" onClick={() => setAdding(true)}>
                New Ticket
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className="card divide-y divide-line overflow-hidden">
          {shown.map((t) => {
            const cat = categoryOf(t.category);
            const last = t.lastMessage && typeof t.lastMessage === "object" ? t.lastMessage : null;
            const replies = (Number(t.messageCount) || 1) - 1;
            const lastFromParticipant = last ? last.senderType === "participant" || last.mine === true : false;
            const st = statusOf(t);
            const stColor = st === "closed" ? "#94A3B8" : st === "inactive" ? "#F59E0B" : "#22C55E";
            return (
              <button
                key={idOf(t)}
                onClick={() => navigate(`/support/${idOf(t)}`)}
                className="group flex w-full gap-4 px-5 py-4 text-left transition hover:bg-white/[0.03]"
              >
                <span
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg"
                  style={{ background: `${cat.color}26` }}
                >
                  <Icon name={cat.icon} size={20} color={cat.color} />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex flex-wrap items-center gap-2">
                    <span className="truncate font-semibold group-hover:text-[#93C5FD]">{cat.label}</span>
                    {!isParticipant && (
                      <span className="truncate text-sm font-medium text-[#60A5FA]">
                        · {t.participantName || "Participant"}
                      </span>
                    )}
                    <span className="flex-1" />
                    <span
                      className="flex items-center gap-1 rounded-md px-2 py-0.5 text-[10.5px] font-bold"
                      style={{ background: `${stColor}22`, color: stColor }}
                    >
                      {t.status === "closed" && <Icon name="lock" size={11} />}
                      {cap(st)}
                    </span>
                    <span className="text-xs text-muted">{timeAgo(t.lastMessageAt ?? t.createdAt)}</span>
                  </span>
                  <span className="mt-1 line-clamp-2 block text-sm text-white/75">{t.description}</span>
                  <span className="mt-1.5 flex items-center gap-1.5 truncate text-xs text-muted">
                    <Icon name="chat_bubble" size={13} outline />
                    {replies <= 0 || !last
                      ? isParticipant
                        ? "Waiting for a reply"
                        : "No reply yet"
                      : `${lastFromParticipant ? (isParticipant ? "You" : "Participant") : "Support"}: ${last.text ?? ""}`}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      )}
      {adding && (
        <TicketFormModal
          onClose={() => setAdding(false)}
          onSaved={(t) => {
            setAdding(false);
            navigate(`/support/${idOf(t)}`);
          }}
        />
      )}
    </Page>
  );
}

const roleLabel = (t: any) => (t === "staff" ? "Event Staff" : t === "admin" ? "Admin" : "Participant");
const roleColor = (t: any) => (t === "staff" ? "#2DD4BF" : t === "admin" || t === "support" ? "#FBBF24" : "#60A5FA");

/** A ticket's chat: polls every 5 s; staff/admin can call the participant and close the ticket. */
export function TicketChat() {
  const { id = "" } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [ticket, setTicket] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [closing, setClosing] = useState(false);
  const [editingTicket, setEditingTicket] = useState(false);
  const [editingMsg, setEditingMsg] = useState<{ id: string; text: string; original: string } | null>(null);
  const [savingMsg, setSavingMsg] = useState(false);
  const bottom = useRef<HTMLDivElement>(null);
  const count = useRef(-1);

  const load = useCallback(async () => {
    const res = await get(`/support-tickets/${id}`);
    if (res.success && res.ticket) {
      setError(null);
      setTicket(res.ticket);
    } else setError(res.error || "Could not load chat");
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
    if (!t) return;
    setSending(true);
    const res = await post(`/support-tickets/${id}/messages`, { text: t });
    setSending(false);
    if (res.success) {
      setText("");
      if (res.ticket) setTicket(res.ticket);
    } else toast(res.error || "Could not send", "error");
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
    const res = await post(`/support-tickets/${id}/close`);
    setClosing(false);
    if (res.success && res.ticket) setTicket(res.ticket);
    if (!res.success) toast(res.error || "Could not close", "error");
  };

  const deleteTicket = async () => {
    const ok = await confirm({
      title: "Delete this ticket?",
      message: "The ticket and all its messages will be removed permanently.",
      confirm: "Delete",
      danger: true,
    });
    if (!ok) return;
    const res = await del(`/support-tickets/${id}`);
    if (res.success) {
      toast("Ticket deleted", "success");
      navigate("/support", { replace: true });
    } else toast(res.error || "Could not delete the ticket", "error");
  };

  const saveMessage = async () => {
    if (!editingMsg) return;
    const t = editingMsg.text.trim();
    if (!t || t === editingMsg.original) return setEditingMsg(null);
    setSavingMsg(true);
    const res = await put(`/support-tickets/${id}/messages/${editingMsg.id}`, { text: t });
    setSavingMsg(false);
    if (res.success && res.ticket) {
      setTicket(res.ticket);
      setEditingMsg(null);
    } else toast(res.error || "Could not edit the message", "error");
  };

  const canEditTicket = ticket?.canEdit === true;
  const canDeleteTicket = ticket?.canDelete === true;
  const cat = categoryOf(ticket?.category);
  const participant = String(ticket?.participantName ?? "").trim();
  const mobile = String(ticket?.participantMobile ?? "").trim();
  const closed = ticket?.status === "closed";
  const canReply = ticket?.canReply !== false;
  const canClose = ticket?.canClose === true;
  const closedAt = parseDate(ticket?.closedAt);
  const closedBy = String(ticket?.closedByName ?? "").trim();
  const closedDetails = [closedBy && `by ${closedBy}`, closedAt && fmtShortDateTime(closedAt)]
    .filter(Boolean)
    .join(" · ");

  return (
    <Page
      title={
        <span className="flex items-center gap-3">
          <span
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg"
            style={{ background: `${cat.color}26` }}
          >
            <Icon name={cat.icon} size={21} color={cat.color} />
          </span>
          <span className="min-w-0 truncate">{cat.label}</span>
        </span>
      }
      subtitle={participant || undefined}
      actions={
        <>
          {canEditTicket && (
            <Button variant="outline" icon="edit" onClick={() => setEditingTicket(true)}>
              Edit ticket
            </Button>
          )}
          {canClose && (
            <Button variant="outline" icon="lock" loading={closing} className="!text-[#F87171]" onClick={close}>
              Close ticket
            </Button>
          )}
          {canDeleteTicket && (
            <Button variant="danger" icon="delete" onClick={deleteTicket}>
              Delete ticket
            </Button>
          )}
        </>
      }
      width={1100}
    >
      <div className="grid gap-5 lg:grid-cols-[1fr_300px]">
        <div className="card flex h-[calc(100vh-260px)] min-h-[440px] flex-col overflow-hidden">
          {closed && (
            <div className="flex items-center gap-2 border-b border-line bg-[#2A2A33] px-5 py-2.5 text-[12.5px] font-semibold text-white/80">
              <Icon name="lock" size={16} color="#9CA3AF" />
              {closedDetails ? `This ticket is closed ${closedDetails}` : "This ticket is closed"}
            </div>
          )}
          <div className="flex-1 space-y-3 overflow-y-auto p-5">
            {!ticket ? (
              error ? (
                <div className="py-16 text-center text-muted">{error}</div>
              ) : (
                <div className="flex justify-center py-16">
                  <Spinner />
                </div>
              )
            ) : (
              messages.map((m, i) => {
                const mine = m.mine === true;
                const name = String(m.senderName ?? "").trim();
                const label =
                  m.senderType === "support"
                    ? name
                    : name
                      ? `${name} · ${roleLabel(m.senderType)}`
                      : roleLabel(m.senderType);
                const editable = m.canEdit === true && !!m.id;
                return (
                  <div
                    key={m.id ?? i}
                    className={`group flex items-center gap-1.5 ${mine ? "justify-end" : "justify-start"}`}
                  >
                    {editable && mine && (
                      <button
                        title="Edit message"
                        onClick={() =>
                          setEditingMsg({
                            id: String(m.id),
                            text: String(m.text ?? ""),
                            original: String(m.text ?? ""),
                          })
                        }
                        className="flex h-8 w-8 items-center justify-center rounded-md text-white/40 opacity-0 transition hover:bg-white/10 hover:text-white group-hover:opacity-100"
                      >
                        <Icon name="edit" size={16} outline />
                      </button>
                    )}
                    <div
                      className={`max-w-[75%] rounded-2xl px-3.5 pb-1.5 pt-2 ${mine ? "rounded-br-sm bg-accent" : "rounded-bl-sm border border-line bg-field"}`}
                    >
                      {!mine && label && (
                        <div className="mb-0.5 text-[11px] font-bold" style={{ color: roleColor(m.senderType) }}>
                          {label}
                        </div>
                      )}
                      <div className="whitespace-pre-wrap text-sm">{m.text}</div>
                      <div className="mt-0.5 text-right text-[10px] text-white/60">
                        {m.edited ? "edited · " : ""}
                        {fmtShortDateTime(parseDate(m.createdAt))}
                      </div>
                    </div>
                    {editable && !mine && (
                      <button
                        title="Edit message"
                        onClick={() =>
                          setEditingMsg({
                            id: String(m.id),
                            text: String(m.text ?? ""),
                            original: String(m.text ?? ""),
                          })
                        }
                        className="flex h-8 w-8 items-center justify-center rounded-md text-white/40 opacity-0 transition hover:bg-white/10 hover:text-white group-hover:opacity-100"
                      >
                        <Icon name="edit" size={16} outline />
                      </button>
                    )}
                  </div>
                );
              })
            )}
            <div ref={bottom} />
          </div>
          {!ticket || canReply ? (
            <div className="flex items-end gap-2 border-t border-line bg-card p-3">
              <textarea
                rows={1}
                value={text}
                onChange={(e) => setText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    send();
                  }
                }}
                placeholder={
                  closed ? "This ticket is closed" : "Type a message — Enter to send, Shift+Enter for a new line"
                }
                disabled={!ticket}
                className="input max-h-32 flex-1 resize-none"
              />
              <Button icon="send" loading={sending} disabled={!text.trim()} onClick={send}>
                Send
              </Button>
            </div>
          ) : (
            <div className="border-t border-line bg-card p-4 text-center">
              <div className="text-sm text-white/75">This ticket is closed. Need more help? Create a new ticket.</div>
              <Button
                className="mt-2"
                icon="add"
                onClick={() => {
                  sessionStorage.setItem("support_new", "1");
                  navigate(-1);
                }}
              >
                New ticket
              </Button>
            </div>
          )}
        </div>
        <aside className="space-y-4 lg:self-start">
          <Panel title="Ticket details" icon="confirmation_number" iconColor={cat.color}>
            <dl className="space-y-3 text-sm">
              <div>
                <dt className="text-xs text-muted">Category</dt>
                <dd className="mt-0.5 font-medium">{cat.label}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted">Status</dt>
                <dd className="mt-0.5 font-medium">{ticket ? cap(statusOf(ticket)) : "—"}</dd>
              </div>
              {ticket?.createdAt && (
                <div>
                  <dt className="text-xs text-muted">Opened</dt>
                  <dd className="mt-0.5 font-medium">{fmtShortDateTime(parseDate(ticket.createdAt))}</dd>
                </div>
              )}
              <div>
                <dt className="text-xs text-muted">Messages</dt>
                <dd className="mt-0.5 font-medium">{messages.length}</dd>
              </div>
            </dl>
          </Panel>
          {mobile && (
            <Panel title="Participant" icon="person" iconColor="#60A5FA">
              {participant && <div className="font-semibold">{participant}</div>}
              <div className="text-sm text-muted">{mobile}</div>
              <a
                href={`tel:${mobile}`}
                className="mt-4 flex items-center justify-center gap-1.5 rounded-lg bg-[#16A34A] px-3.5 py-2.5 text-sm font-semibold transition hover:bg-green-500"
              >
                <Icon name="call" size={18} />
                Call
              </a>
            </Panel>
          )}
        </aside>
      </div>
      {editingTicket && ticket && (
        <TicketFormModal
          ticket={ticket}
          onClose={() => setEditingTicket(false)}
          onSaved={(t) => {
            setEditingTicket(false);
            setTicket(t);
            toast("Ticket updated", "success");
          }}
        />
      )}
      <Modal
        open={!!editingMsg}
        onClose={() => setEditingMsg(null)}
        title="Edit message"
        width={520}
        footer={
          <>
            <Button variant="outline" onClick={() => setEditingMsg(null)}>
              Cancel
            </Button>
            <Button icon="check" loading={savingMsg} disabled={!editingMsg?.text.trim()} onClick={saveMessage}>
              Save
            </Button>
          </>
        }
      >
        <TextArea
          rows={5}
          maxLength={2000}
          autoFocus
          value={editingMsg?.text ?? ""}
          onChange={(e) => setEditingMsg((m) => (m ? { ...m, text: e.target.value } : m))}
        />
      </Modal>
    </Page>
  );
}
