/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { AppBar, Icon, useConfirm, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { AppCtaButton, AppSuccessDialog, AppTextField } from "@/components/app/AppForm";
import { del, formData, get, post, put } from "@/lib/api";
import { idOf } from "@/lib/format";

/* ------------------------------------------------------------------ */
/* Event Staff list — the app's UsersTab (events property)             */
/* ------------------------------------------------------------------ */

const initials = (name: string) => {
  const p = String(name ?? "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (!p.length) return "U";
  if (p.length === 1) return p[0][0].toUpperCase();
  return `${p[0][0]}${p[p.length - 1][0]}`.toUpperCase();
};

const STATUS: Record<string, { label: string; color: string }> = {
  approved: { label: "Approved", color: "#10B981" },
  pending: { label: "Pending", color: "#F59E0B" },
  rejected: { label: "Rejected", color: "#EF4444" },
};
const statusOf = (u: any) => STATUS[String(u.status ?? "pending")] ?? STATUS.pending;
const tel = (m: string) => `tel:${String(m).replace(/[^0-9+]/g, "")}`;

function StatCard({ icon, label, value }: { icon: string; label: string; value: number }) {
  return (
    <div className="flex-1 rounded-[14px] border border-white/[0.08] bg-card px-2 py-2.5 text-center shadow-[0_2px_6px_rgba(0,0,0,0.02)]">
      <span className="mx-auto flex h-7 w-7 items-center justify-center rounded-full bg-accent/[0.12]">
        <Icon name={icon} size={16} color="#3B82F6" />
      </span>
      <div className="mt-1.5 font-sora text-[17px] font-bold">{value}</div>
      <div className="mt-0.5 text-[10px] font-semibold text-muted">{label}</div>
    </div>
  );
}

/** Pop-up menu anchored to the card's ⋮ button. */
function CardMenu({
  items,
}: {
  items: { value: string; icon: string; label: string; color: string; onClick: () => void }[];
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent | TouchEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", close);
    document.addEventListener("touchstart", close);
    return () => {
      document.removeEventListener("mousedown", close);
      document.removeEventListener("touchstart", close);
    };
  }, [open]);
  return (
    <div ref={ref} className="relative" onClick={(e) => e.stopPropagation()}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-label="More"
        className="flex h-8 w-8 items-center justify-center rounded-full active:bg-white/10"
      >
        <Icon name="more_vert" size={20} color="#9CA3AF" />
      </button>
      {open && (
        <div className="absolute right-0 top-8 z-40 min-w-[200px] overflow-hidden rounded-xl bg-card py-2 shadow-[0_8px_24px_rgba(0,0,0,0.5)]">
          {items.map((it) => (
            <button
              key={it.value}
              onClick={() => {
                setOpen(false);
                it.onClick();
              }}
              className="flex w-full items-center gap-2.5 px-3 py-3 text-left text-[13px] active:bg-white/5"
            >
              <Icon name={it.icon} size={18} color={it.color} />
              {it.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/** Event Staff at phone width. */
export function StaffListApp() {
  const navigate = useNavigate();
  const toast = useToast();
  const confirm = useConfirm();
  const [users, setUsers] = useState<any[] | null>(null);
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState(0); // 0 Approved, 1 Pending, 2 Inactive
  const [details, setDetails] = useState<any | null>(null);

  const load = useCallback(async () => {
    const r = await get("/auth/users");
    if (r.success) setUsers(r.users ?? []);
    else setUsers((u) => u ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const all = users ?? [];
  const isApproved = (u: any) => u.status === "approved" && u.isActive !== false;
  const pending = all.filter((u) => u.status === "pending");
  const approved = all.filter(isApproved);
  const inactive = all.filter((u) => u.isActive === false);
  const tabUsers = tab === 0 ? approved : tab === 1 ? pending : inactive;
  const q = search.trim().toLowerCase();
  const matches = (u: any) =>
    !!q &&
    [u.name, u.email, u.mobileNumber, u.username].some((v) =>
      String(v ?? "")
        .toLowerCase()
        .includes(q),
    );
  const visible = q ? tabUsers.filter(matches) : tabUsers;

  const approve = async (u: any) => {
    const r = await put(`/auth/users/${idOf(u)}/status`, { status: "approved" });
    if (r.success) {
      toast("Staff approved successfully", "success");
      load();
    } else toast(r.error || "Failed to approve staff", "error");
  };
  const toggleActive = async (u: any) => {
    const r = await put(`/auth/users/${idOf(u)}/toggle-active`, {});
    if (r.success) load();
    else toast(r.error || "Failed", "error");
  };
  const remove = async (u: any) => {
    if (
      !(await confirm({
        title: "Delete User",
        message: `Are you sure you want to delete ${u.name}? This action cannot be undone.`,
        confirm: "Delete",
        danger: true,
      }))
    )
      return;
    const r = await del(`/auth/users/${idOf(u)}`);
    if (r.success) load();
    else toast(r.error || "Failed", "error");
  };
  const edit = (u: any) => navigate(`/admin/team/staff/${idOf(u)}/edit`);

  const filters = [
    { icon: "home_work", label: "Approved", count: approved.length },
    { icon: "hourglass_top", label: "Pending", count: pending.length },
    { icon: "person_off", label: "Inactive", count: inactive.length },
  ];

  return (
    <div className="flex min-h-screen flex-col bg-bg">
      <AppBar title="Event Staff" />
      {users === null ? (
        <AppSpinner />
      ) : (
        <>
          <div className="px-4 pb-4 pt-3">
            <div className="flex gap-2.5">
              <StatCard icon="hourglass_top" label="Pending" value={pending.length} />
              <StatCard icon="home_work" label="Approved" value={approved.length} />
              <StatCard icon="person_off" label="Inactive" value={inactive.length} />
            </div>
            <button
              onClick={() => navigate("/admin/team/staff/new")}
              className="mt-3.5 flex h-12 w-full items-center justify-center rounded-[14px] bg-gradient-to-br from-[#13275D] to-[#1E3A8A] text-[13.5px] font-semibold shadow-[0_6px_14px_rgba(59,130,246,0.28)]"
            >
              <span className="text-base font-bold">＋&nbsp;</span>Add Event Staff
            </button>
          </div>
          {all.length > 0 && (
            <>
              <div className="px-4 py-1">
                <div className="relative">
                  <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
                    <Icon name="search" size={20} color="#9CA3AF" />
                  </span>
                  <input
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="Search name, email, mobile, room..."
                    className="w-full rounded-[14px] border border-white/[0.08] bg-field py-[11px] pl-11 pr-10 text-sm outline-none placeholder:text-[13px] placeholder:text-muted focus:border-[1.5px] focus:border-accent"
                  />
                  {search && (
                    <button
                      onClick={() => setSearch("")}
                      aria-label="Clear"
                      className="absolute right-1 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center"
                    >
                      <Icon name="clear" size={18} color="#9CA3AF" />
                    </button>
                  )}
                </div>
              </div>
              <div className="flex gap-2 overflow-x-auto px-3 py-2.5 [scrollbar-width:none]">
                {filters.map((f, i) => {
                  const on = tab === i;
                  return (
                    <button
                      key={f.label}
                      onClick={() => setTab(i)}
                      className="flex shrink-0 items-center gap-1.5 rounded-full border px-3.5 py-2 text-xs font-bold"
                      style={{
                        background: on ? "#3B82F6" : "#14141F",
                        borderColor: on ? "#3B82F6" : "rgba(255,255,255,0.08)",
                        color: on ? "#fff" : "rgba(255,255,255,0.75)",
                        boxShadow: on ? "0 2px 4px rgba(59,130,246,0.35)" : undefined,
                      }}
                    >
                      <Icon name={f.icon} size={16} color={on ? "#fff" : "#3B82F6"} />
                      {f.label}
                      <span
                        className="rounded-[10px] px-[7px] py-0.5 text-[11px] font-bold"
                        style={{ background: on ? "rgba(255,255,255,0.25)" : "rgba(59,130,246,0.12)" }}
                      >
                        {f.count}
                      </span>
                    </button>
                  );
                })}
              </div>
            </>
          )}
          <div className="flex-1">
            {all.length === 0 ? (
              <div className="flex flex-col items-center px-8 pt-16 text-center">
                <span className="rounded-full bg-gradient-to-br from-[#13275D]/40 to-[#1E3A8A]/40 p-6">
                  <Icon name="people" outline size={56} color="rgba(59,130,246,0.5)" />
                </span>
                <div className="mt-5 text-lg font-extrabold">No users yet</div>
                <div className="mt-2 text-[13px] leading-[1.4] text-white/55">
                  Add residents or companies to start managing approvals and room assignments.
                </div>
              </div>
            ) : visible.length === 0 ? (
              <div className="flex flex-col items-center px-7 pt-16 text-center">
                <Icon name={q ? "search_off" : "filter_list_off"} size={48} color="rgba(255,255,255,0.25)" />
                <div className="mt-3.5 text-base font-bold">
                  {q ? "No matches found" : `No ${filters[tab].label} users`}
                </div>
                <div className="mt-1.5 text-[13px] text-white/50">
                  {q
                    ? `Nothing matches "${search}". Try another name, email, or room.`
                    : "Users in this category will appear here."}
                </div>
              </div>
            ) : (
              <div className="px-3 pb-4">
                {visible.map((u) => {
                  const st = statusOf(u);
                  const highlight = matches(u);
                  return (
                    <div
                      key={idOf(u)}
                      onClick={() => setDetails(u)}
                      className="mb-2.5 cursor-pointer rounded-[14px] bg-card p-3 shadow-[0_2px_8px_rgba(0,0,0,0.04)] active:bg-white/[0.03]"
                      style={{
                        border: `${highlight ? 1.5 : 1}px solid ${highlight ? "#3B82F6" : "rgba(255,255,255,0.08)"}`,
                      }}
                    >
                      <div className="flex items-start">
                        <span className="relative shrink-0">
                          <span className="flex h-[52px] w-[52px] items-center justify-center overflow-hidden rounded-full bg-accent/[0.12]">
                            {u.profilePic ? (
                              <img src={u.profilePic} alt="" className="h-full w-full object-cover" />
                            ) : (
                              <span className="font-sora text-base font-bold text-accent">{initials(u.name)}</span>
                            )}
                          </span>
                          <span
                            className="absolute -bottom-px -right-px h-[13px] w-[13px] rounded-full border-2 border-white"
                            style={{ background: u.isActive !== false ? "#10B981" : "#EF4444" }}
                          />
                        </span>
                        <div className="ml-3 min-w-0 flex-1">
                          <div className="flex items-center gap-1.5">
                            <div className="min-w-0 flex-1 truncate font-sora text-[15px] font-bold">{u.name}</div>
                            <span
                              className="rounded-md px-2 py-[3px] text-[10px] font-bold"
                              style={{ background: `${st.color}1f`, color: st.color }}
                            >
                              {st.label}
                            </span>
                          </div>
                          <div className="mt-1.5 flex items-center gap-1.5 text-xs text-white/65">
                            <Icon name="email" outline size={14} color="rgba(255,255,255,0.4)" />
                            <span className="truncate">{u.email}</span>
                          </div>
                          {u.mobileNumber && (
                            <div className="mt-1 flex items-center gap-1.5 text-xs text-white/65">
                              <Icon name="phone" outline size={14} color="rgba(255,255,255,0.4)" />
                              <span className="truncate">{u.mobileNumber}</span>
                            </div>
                          )}
                        </div>
                        {u.mobileNumber && (
                          <a
                            href={tel(u.mobileNumber)}
                            onClick={(e) => e.stopPropagation()}
                            title="Call User"
                            className="ml-1 flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[10px] bg-field"
                          >
                            <Icon name="call" size={16} color="#3B82F6" />
                          </a>
                        )}
                        <div className="ml-1">
                          <CardMenu
                            items={[
                              {
                                value: "details",
                                icon: "person",
                                label: "View details",
                                color: "#3B82F6",
                                onClick: () => setDetails(u),
                              },
                              {
                                value: "edit",
                                icon: "edit",
                                label: "Edit event staff",
                                color: "#3B82F6",
                                onClick: () => edit(u),
                              },
                              ...(u.status === "pending"
                                ? [
                                    {
                                      value: "approve",
                                      icon: "check_circle",
                                      label: "Approve",
                                      color: "#10B981",
                                      onClick: () => approve(u),
                                    },
                                  ]
                                : []),
                              {
                                value: "toggle",
                                icon: u.isActive !== false ? "toggle_on" : "toggle_off",
                                label: u.isActive !== false ? "Deactivate user" : "Activate user",
                                color: "#3B82F6",
                                onClick: () => toggleActive(u),
                              },
                              {
                                value: "delete",
                                icon: "delete",
                                label: "Delete user",
                                color: "#EF4444",
                                onClick: () => remove(u),
                              },
                            ]}
                          />
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </>
      )}
      {details && <StaffDetailsSheet user={details} onClose={() => setDetails(null)} onEdit={() => edit(details)} />}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Staff details sheet — the app's _UserDetailsSheet                    */
/* ------------------------------------------------------------------ */

function InfoTile({
  icon,
  label,
  value,
  color,
  href,
}: {
  icon: string;
  label: string;
  value: string;
  color: string;
  href?: string;
}) {
  const body = (
    <div className="flex items-start px-1 py-2">
      <span className="rounded-[10px] p-2" style={{ background: `${color}12` }}>
        <Icon name={icon} outline size={18} color={color} />
      </span>
      <div className="ml-3 min-w-0 flex-1">
        <div className="text-xs font-medium text-muted">{label}</div>
        <div className="mt-[3px] break-words font-sora text-sm font-semibold leading-[1.25]">{value}</div>
      </div>
    </div>
  );
  return href ? (
    <a href={href} className="block rounded-[10px] active:bg-white/5">
      {body}
    </a>
  ) : (
    body
  );
}

function StaffDetailsSheet({ user, onClose, onEdit }: { user: any; onClose: () => void; onEdit: () => void }) {
  const st = statusOf(user);
  const active = user.isActive !== false;
  const canCall = !!String(user.mobileNumber ?? "").trim();
  const canEmail = !!String(user.email ?? "").trim();
  const chip = (icon: string, label: string, color: string, href: string) => (
    <a
      href={href}
      className="flex flex-1 items-center justify-center rounded-2xl border border-white/[0.08] bg-card py-3 shadow-[0_3px_10px_rgba(0,0,0,0.02)]"
    >
      <span className="flex h-9 w-9 items-center justify-center rounded-[11px]" style={{ background: `${color}14` }}>
        <Icon name={icon} size={18} color={color} />
      </span>
      <span className="ml-2.5 font-sora text-[13px] font-semibold">{label}</span>
    </a>
  );
  const pill = (label: string, color: string) => (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-white/25 bg-white/15 px-2.5 py-[5px] text-[11px] font-bold">
      <span className="h-[7px] w-[7px] rounded-full" style={{ background: color }} />
      {label}
    </span>
  );
  return (
    <div className="animate-fade fixed inset-0 z-[90] flex items-end" onClick={onClose}>
      <div className="absolute inset-0 bg-black/55" />
      <div
        className="animate-sheet relative flex h-[92vh] w-full flex-col rounded-t-3xl bg-bg"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mx-auto mb-1.5 mt-2.5 h-1 w-10 rounded-sm bg-accent/[0.27]" />
        <div className="flex-1 overflow-y-auto pb-2">
          <div className="mx-4 mt-1 rounded-[22px] bg-gradient-to-br from-[#13275D] to-[#1E3A8A] px-5 pb-5 pt-3 text-center shadow-[0_8px_20px_rgba(59,130,246,0.18)]">
            <div className="flex justify-end">
              <button
                onClick={onClose}
                aria-label="Close"
                className="flex h-[34px] w-[34px] items-center justify-center rounded-full bg-white/[0.14]"
              >
                <Icon name="close" size={20} />
              </button>
            </div>
            <span className="relative mx-auto inline-block rounded-full border-[2.5px] border-white/80 p-[3px] shadow-[0_5px_14px_rgba(0,0,0,0.2)]">
              <span className="flex h-20 w-20 items-center justify-center overflow-hidden rounded-full bg-white/15">
                {user.profilePic ? (
                  <img src={user.profilePic} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="font-sora text-[28px] font-bold">{initials(user.name)}</span>
                )}
              </span>
              <span
                className="absolute bottom-0.5 right-0.5 h-4 w-4 rounded-full border-[2.5px] border-white"
                style={{ background: active ? "#10B981" : "#EF4444" }}
              />
            </span>
            <div className="mt-3 font-sora text-xl font-bold tracking-[-0.3px]">{user.name}</div>
            {user.username && <div className="mt-[3px] text-[13px] font-medium text-white/80">@{user.username}</div>}
            <div className="mt-3.5 flex flex-wrap justify-center gap-2">
              {pill(st.label, st.label === "Approved" ? "#10B981" : st.color)}
              {pill(active ? "Active" : "Inactive", active ? "#10B981" : "#EF4444")}
            </div>
          </div>
          {(canCall || canEmail) && (
            <div className={`mx-4 mt-3.5 flex gap-2.5 ${canCall && canEmail ? "" : "justify-center"}`}>
              {canCall && (
                <div className={canEmail ? "flex flex-1" : "flex w-40"}>
                  {chip("phone", "Call", "#3B82F6", tel(user.mobileNumber))}
                </div>
              )}
              {canEmail && (
                <div className={canCall ? "flex flex-1" : "flex w-40"}>
                  {chip("email", "Email", "#10B981", `mailto:${user.email}`)}
                </div>
              )}
            </div>
          )}
          <div className="mx-4 mb-4 mt-3.5">
            <div className="mb-3.5 overflow-hidden rounded-[18px] border border-white/[0.08] bg-card">
              <div className="flex items-center px-4 pb-3 pt-3.5">
                <span className="rounded-[10px] bg-accent/[0.08] p-2">
                  <Icon name="contact_mail" outline size={18} color="#3B82F6" />
                </span>
                <span className="ml-2.5 font-sora text-[15px] font-bold">Contact</span>
              </div>
              <div className="h-px bg-field" />
              <div className="px-3 pb-3 pt-2">
                <InfoTile
                  icon="email"
                  label="Email"
                  value={user.email}
                  color="#3B82F6"
                  href={canEmail ? `mailto:${user.email}` : undefined}
                />
                <InfoTile
                  icon="phone"
                  label="Mobile"
                  value={user.mobileNumber}
                  color="#10B981"
                  href={canCall ? tel(user.mobileNumber) : undefined}
                />
                {user.secondaryMobileNumber && (
                  <InfoTile icon="phone_android" label="Secondary" value={user.secondaryMobileNumber} color="#10B981" />
                )}
              </div>
            </div>
            {user.address && (
              <div className="mb-3.5 overflow-hidden rounded-[18px] border border-white/[0.08] bg-card">
                <div className="flex items-center px-4 pb-3 pt-3.5">
                  <span className="rounded-[10px] bg-accent/[0.08] p-2">
                    <Icon name="location_on" outline size={18} color="#3B82F6" />
                  </span>
                  <span className="ml-2.5 font-sora text-[15px] font-bold">Address</span>
                </div>
                <div className="h-px bg-field" />
                <div className="px-3 pb-3 pt-2">
                  <InfoTile icon="place" label="Address" value={user.address} color="#F59E0B" />
                </div>
              </div>
            )}
          </div>
        </div>
        <div className="border-t border-white/[0.07] bg-card px-4 py-3 shadow-[0_-4px_14px_rgba(0,0,0,0.05)]">
          <AppCtaButton label="Edit profile" icon="edit" onClick={onEdit} />
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Add Event Staff — the app's UserRegistrationPage (fromAdmin, events) */
/* ------------------------------------------------------------------ */

export function StaffAddApp() {
  const navigate = useNavigate();
  const toast = useToast();
  const [name, setName] = useState("");
  const [mobile, setMobile] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  const submit = async () => {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = "Please enter full name";
    if (!mobile.trim()) e.mobile = "Please enter mobile number";
    else if (mobile.trim().length !== 10) e.mobile = "Enter valid 10-digit number";
    if (!email.trim()) e.email = "Please enter email";
    else if (!email.includes("@")) e.email = "Enter valid email";
    if (!password.trim()) e.password = "Please enter password";
    else if (password.trim().length < 6) e.password = "Password must be at least 6 characters";
    setErrors(e);
    if (Object.keys(e).length) return;
    setBusy(true);
    const r = await post(
      "/auth/register",
      formData({
        name: name.trim(),
        username: name.trim(),
        email: email.trim(),
        password: password.trim(),
        mobileNumber: mobile.trim(),
        userType: "user",
      }),
    );
    setBusy(false);
    if (r.success) setDone(true);
    else toast(r.error || "Registration failed", "error");
  };

  return (
    <div className="min-h-screen bg-field">
      <AppBar title="Add Event Staff" titleClassName="font-sora text-xl font-bold" bg="#3B82F6" />
      <div className="p-5">
        <div className="rounded-[18px] border border-white/[0.08] bg-card p-[18px] shadow-[0_4px_12px_rgba(0,0,0,0.02)]">
          <div className="flex items-center">
            <span className="rounded-xl bg-accent/[0.07] p-2.5">
              <Icon name="badge" size={22} color="#3B82F6" />
            </span>
            <span className="ml-3 font-sora text-[17px] font-bold">Add Event Staff Account</span>
          </div>
          <div className="mt-[18px] space-y-4">
            <AppTextField label="Full Name *" icon="person" value={name} onChange={setName} error={errors.name} />
            <AppTextField
              label="Mobile Number *"
              icon="phone"
              inputMode="numeric"
              maxLength={10}
              value={mobile}
              onChange={(v) => setMobile(v.replace(/\D/g, ""))}
              error={errors.mobile}
            />
            <AppTextField
              label="Email"
              icon="email"
              type="email"
              value={email}
              onChange={setEmail}
              error={errors.email}
            />
            <AppTextField
              label="Password *"
              icon="lock"
              password
              value={password}
              onChange={setPassword}
              error={errors.password}
            />
          </div>
        </div>
        <div className="mt-8">
          <AppCtaButton label="Add Event Staff" icon="person_add" loading={busy} onClick={submit} />
        </div>
      </div>
      {done && (
        <AppSuccessDialog
          title="User Registered Successfully!"
          message="The user has been registered successfully."
          onOk={() => navigate("/admin", { replace: true })}
        />
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Edit Event Staff — the app's EditUserPage (events)                   */
/* ------------------------------------------------------------------ */

export function StaffEditApp() {
  const { id = "" } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const toast = useToast();
  const [user, setUser] = useState<any | null>(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [mobile, setMobile] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPw, setConfirmPw] = useState("");
  const [photo, setPhoto] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    get("/auth/users").then((r) => {
      const u = (r.users ?? []).find((x: any) => idOf(x) === id);
      if (!u) return;
      setUser(u);
      setName(u.name ?? "");
      setEmail(u.email ?? "");
      setMobile(u.mobileNumber ?? "");
    });
  }, [id]);
  useEffect(() => {
    if (!photo) return setPreview(null);
    const u = URL.createObjectURL(photo);
    setPreview(u);
    return () => URL.revokeObjectURL(u);
  }, [photo]);

  const save = async () => {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = "Full name is required";
    if (!email.trim()) e.email = "Email is required";
    else if (!/^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$/.test(email.trim())) e.email = "Enter a valid email";
    if (mobile.trim().length !== 10) e.mobile = "Enter 10-digit mobile number";
    setErrors(e);
    if (Object.keys(e).length) return;
    if (password.trim()) {
      if (password.trim().length < 6) return toast("Password must be at least 6 characters", "error");
      if (password.trim() !== confirmPw.trim()) return toast("Passwords do not match", "error");
    }
    setSaving(true);
    const r = await put(
      `/auth/users/${id}`,
      formData(
        {
          name: name.trim(),
          username: user?.username ?? name.trim(),
          email: email.trim(),
          mobileNumber: mobile.trim(),
          ...(password.trim() ? { password: password.trim() } : {}),
        },
        { profilePic: photo },
      ),
    );
    setSaving(false);
    if (r.success) {
      toast(r.message || "User updated successfully", "success");
      navigate(-1);
    } else toast(r.error || "Failed to update user", "error");
  };

  const shownPhoto = preview ?? user?.profilePic ?? null;
  const section = (icon: string, title: string, children: React.ReactNode) => (
    <div className="rounded-2xl bg-card p-4 shadow-[0_4px_10px_rgba(0,0,0,0.04)]">
      <div className="flex items-center">
        <span className="rounded-[10px] bg-accent/10 p-2">
          <Icon name={icon} size={20} color="#3B82F6" />
        </span>
        <span className="ml-2.5 text-base font-bold">{title}</span>
      </div>
      <div className="mt-4 space-y-3">{children}</div>
    </div>
  );
  const field = { fill: "#1E1E2A", outer: "#14141F", border: "rgba(255,255,255,0.08)", iconSize: 22, focus: "#3B82F6" };

  return (
    <div className="min-h-screen bg-bg pb-28">
      <div className="bg-gradient-to-br from-[#13275D] to-[#1E3A8A]">
        <div className="flex items-center pb-5 pl-2 pr-4 pt-2">
          <button
            onClick={() => !saving && navigate(-1)}
            aria-label="Back"
            className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
          >
            <Icon name="arrow_back_ios_new" size={20} />
          </button>
          <div className="min-w-0 flex-1">
            <div className="text-xl font-bold">Edit Event Staff</div>
            <div className="truncate text-[13px] text-white/85">{user?.name ?? ""}</div>
          </div>
        </div>
      </div>
      {!user ? (
        <AppSpinner />
      ) : (
        <div className="space-y-4 px-4 pt-5">
          {section(
            "badge",
            "Event Staff Information",
            <>
              <div className="flex flex-col items-center">
                <div className="text-sm font-semibold">Profile picture (optional)</div>
                <button
                  onClick={() => fileRef.current?.click()}
                  className="relative mt-3 flex h-[110px] w-[110px] items-center justify-center overflow-hidden rounded-full border-[3px] bg-field"
                  style={{ borderColor: shownPhoto ? "#3B82F6" : "rgba(255,255,255,0.2)" }}
                >
                  {shownPhoto ? (
                    <img src={shownPhoto} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <Icon name="person" size={48} color="#9E9E9E" />
                  )}
                  {photo && (
                    <span className="absolute bottom-0 right-0 rounded-full bg-[#10B981] p-1">
                      <Icon name="check_circle" size={20} />
                    </span>
                  )}
                </button>
                <button
                  onClick={() => fileRef.current?.click()}
                  className="mt-1 inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium text-accent"
                >
                  <Icon name="add_photo_alternate" size={18} />
                  {shownPhoto ? "Change profile picture" : "Add profile picture"}
                </button>
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/*"
                  hidden
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) setPhoto(f);
                    e.target.value = "";
                  }}
                />
              </div>
              <AppTextField
                {...field}
                label="Full Name *"
                icon="person"
                value={name}
                onChange={setName}
                error={errors.name}
              />
              <AppTextField
                {...field}
                label="Email *"
                icon="email"
                type="email"
                value={email}
                onChange={setEmail}
                error={errors.email}
              />
              <AppTextField
                {...field}
                label="Mobile Number *"
                icon="phone_android"
                inputMode="numeric"
                maxLength={10}
                value={mobile}
                onChange={(v) => setMobile(v.replace(/\D/g, ""))}
                error={errors.mobile}
              />
            </>,
          )}
          {section(
            "lock",
            "Security",
            <>
              <AppTextField
                {...field}
                label="New password (optional)"
                icon="lock"
                password
                value={password}
                onChange={setPassword}
              />
              <AppTextField
                {...field}
                label="Confirm new password"
                icon="lock_reset"
                password
                value={confirmPw}
                onChange={setConfirmPw}
              />
            </>,
          )}
        </div>
      )}
      <div className="fixed inset-x-0 bottom-0 bg-bg px-4 pb-4 pt-2">
        <AppCtaButton
          label={saving ? "Saving..." : "Save changes"}
          icon="save"
          height={52}
          onClick={saving || !user ? undefined : save}
        />
      </div>
    </div>
  );
}
