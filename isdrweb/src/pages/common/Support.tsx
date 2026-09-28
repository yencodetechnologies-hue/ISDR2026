/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Button, Empty, ErrorState, Icon, IconButton, Loading, Modal, Page, Select, Spinner, TextArea, useConfirm, useToast } from "@/components/ui";
import { get, post } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { fmtShortDateTime, idOf, parseDate, timeAgo } from "@/lib/format";

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

/** Participants: their tickets + Add (Help & Support). Staff / admin: every ticket with filters (Support Tickets). */
export function HelpTickets() {
  const { user } = useAuth();
  const isParticipant = user?.userType === "participant";
  const navigate = useNavigate();
  const toast = useToast();
  const [tickets, setTickets] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState("all");
  const [adding, setAdding] = useState(false);
  const [category, setCategory] = useState("");
  const [description, setDescription] = useState("");
  const [saving, setSaving] = useState(false);

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

  const add = async () => {
    if (!category) return toast("Choose a category", "error");
    if (!description.trim()) return toast("Describe the problem", "error");
    setSaving(true);
    const res = await post("/support-tickets", { category, description: description.trim() });
    setSaving(false);
    if (!res.success || !res.ticket) return toast(res.error || "Could not add the ticket", "error");
    setAdding(false);
    setCategory("");
    setDescription("");
    navigate(`/support/${idOf(res.ticket)}`);
  };

  const shown = isParticipant || filter === "all" ? (tickets ?? []) : (tickets ?? []).filter((t) => statusOf(t) === filter);

  return (
    <Page title={isParticipant ? "Help & Support" : "Support Tickets"}>
      {!isParticipant && !error && (
        <div className="mb-3 flex gap-2 overflow-x-auto pb-1">
          {FILTERS.map((f) => {
            const count = f.key === "all" ? (tickets ?? []).length : (tickets ?? []).filter((t) => statusOf(t) === f.key).length;
            const active = filter === f.key;
            return (
              <button
                key={f.key}
                onClick={() => setFilter(f.key)}
                className="flex shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm font-semibold"
                style={{ borderColor: active ? f.color : "rgba(255,255,255,0.1)", background: active ? `${f.color}26` : undefined, color: active ? f.color : "#9CA3AF" }}
              >
                <Icon name={f.icon} size={16} />
                {f.label} ({count})
              </button>
            );
          })}
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
          subtitle={isParticipant ? "Tap Add to ask the support team for help." : undefined}
        />
      ) : (
        <div className="space-y-2.5">
          {shown.map((t) => {
            const cat = categoryOf(t.category);
            const last = t.lastMessage && typeof t.lastMessage === "object" ? t.lastMessage : null;
            const replies = (Number(t.messageCount) || 1) - 1;
            const lastFromParticipant = last ? last.senderType === "participant" || last.mine === true : false;
            return (
              <button key={idOf(t)} onClick={() => navigate(`/support/${idOf(t)}`)} className="card flex w-full gap-3 p-3.5 text-left hover:bg-[#191926]">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full" style={{ background: `${cat.color}2e` }}>
                  <Icon name={cat.icon} size={20} color={cat.color} />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <span className="flex-1 truncate font-bold">{cat.label}</span>
                    {t.status === "closed" && (
                      <span className="flex items-center gap-0.5 rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-bold text-muted">
                        <Icon name="lock" size={11} />
                        Closed
                      </span>
                    )}
                    <span className="text-[11px] text-muted">{timeAgo(t.lastMessageAt ?? t.createdAt)}</span>
                  </span>
                  {!isParticipant && <span className="block text-xs font-semibold text-[#60A5FA]">{t.participantName || "Participant"}</span>}
                  <span className="mt-0.5 line-clamp-2 block text-sm text-white/80">{t.description}</span>
                  <span className="mt-1 block truncate text-xs text-muted">
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
      {isParticipant && (
        <button
          onClick={() => setAdding(true)}
          className="fixed bottom-6 right-6 z-30 flex items-center gap-2 rounded-2xl bg-accent px-5 py-3.5 font-semibold shadow-xl"
        >
          <Icon name="add" />
          Add
        </button>
      )}
      <Modal open={adding} onClose={() => setAdding(false)} title="New Ticket">
        <div className="space-y-3">
          <div>
            <label className="label">Category</label>
            <Select value={category} onChange={setCategory} placeholder="Select a category" options={HELP_CATEGORIES.map((c) => ({ value: c.value, label: c.label }))} />
          </div>
          <div>
            <label className="label">Description</label>
            <TextArea rows={5} value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Describe the problem" />
          </div>
          <Button full loading={saving} icon="add" onClick={add}>
            Add Ticket
          </Button>
        </div>
      </Modal>
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
      message: "The participant will no longer be able to send messages here. They can still read it or create a new ticket.",
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

  const cat = categoryOf(ticket?.category);
  const participant = String(ticket?.participantName ?? "").trim();
  const mobile = String(ticket?.participantMobile ?? "").trim();
  const closed = ticket?.status === "closed";
  const canReply = ticket?.canReply !== false;
  const canClose = ticket?.canClose === true;
  const closedAt = parseDate(ticket?.closedAt);
  const closedBy = String(ticket?.closedByName ?? "").trim();
  const closedDetails = [closedBy && `by ${closedBy}`, closedAt && fmtShortDateTime(closedAt)].filter(Boolean).join(" · ");

  return (
    <Page
      title={
        <span className="flex items-center gap-2.5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full" style={{ background: `${cat.color}2e` }}>
            <Icon name={cat.icon} size={19} color={cat.color} />
          </span>
          <span className="min-w-0">
            <span className="block truncate text-base">{cat.label}</span>
            {participant && <span className="block truncate text-[11.5px] font-normal text-muted">{participant}</span>}
          </span>
        </span>
      }
      actions={
        canClose && (
          <Button variant="ghost" small icon="lock" loading={closing} className="!text-[#F87171]" onClick={close}>
            Close ticket
          </Button>
        )
      }
      noPad
    >
      <div className="flex min-h-[calc(100vh-56px)] flex-col">
        {mobile && (
          <div className="card mx-3 mt-2 flex items-center gap-3 py-2 pl-3 pr-2">
            <Icon name="person" size={20} color="#60A5FA" />
            <div className="min-w-0 flex-1">
              {participant && <div className="truncate text-[13px] font-bold">{participant}</div>}
              <div className="text-[13px] font-semibold text-muted">{mobile}</div>
            </div>
            <a href={`tel:${mobile}`} className="flex items-center gap-1.5 rounded-xl bg-[#16A34A] px-3.5 py-2 text-sm font-semibold">
              <Icon name="call" size={18} />
              Call
            </a>
          </div>
        )}
        {closed && (
          <div className="mt-2 flex items-center gap-2 bg-[#2A2A33] px-4 py-2.5 text-[12.5px] font-semibold text-white/80">
            <Icon name="lock" size={16} color="#9CA3AF" />
            {closedDetails ? `This ticket is closed ${closedDetails}` : "This ticket is closed"}
          </div>
        )}
        <div className="flex-1 space-y-2 p-3">
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
              const label = m.senderType === "support" ? name : name ? `${name} · ${roleLabel(m.senderType)}` : roleLabel(m.senderType);
              return (
                <div key={i} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                  <div className={`max-w-[78%] rounded-2xl px-3 pb-1.5 pt-2 ${mine ? "rounded-br-sm bg-accent" : "rounded-bl-sm border border-line bg-card"}`}>
                    {!mine && label && (
                      <div className="mb-0.5 text-[11px] font-bold" style={{ color: roleColor(m.senderType) }}>
                        {label}
                      </div>
                    )}
                    <div className="whitespace-pre-wrap text-sm">{m.text}</div>
                    <div className="mt-0.5 text-right text-[10px] text-white/60">{fmtShortDateTime(parseDate(m.createdAt))}</div>
                  </div>
                </div>
              );
            })
          )}
          <div ref={bottom} />
        </div>
        {!ticket || canReply ? (
          <div className="sticky bottom-0 flex items-end gap-2 border-t border-line bg-bg p-3">
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
              placeholder={closed ? "This ticket is closed" : "Type a message"}
              disabled={!ticket}
              className="input max-h-32 flex-1 resize-none"
            />
            {sending ? (
              <span className="flex h-10 w-10 items-center justify-center">
                <Spinner size={20} />
              </span>
            ) : (
              <IconButton icon="send" title="Send" color="#3B82F6" disabled={!text.trim()} onClick={send} />
            )}
          </div>
        ) : (
          <div className="sticky bottom-0 border-t border-line bg-bg p-4 text-center">
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
    </Page>
  );
}
