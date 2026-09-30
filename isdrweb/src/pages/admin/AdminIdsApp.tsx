/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon, Spinner, useConfirm, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { AppTextField } from "@/components/app/AppForm";
import { del, get, post, put } from "@/lib/api";
import { idOf } from "@/lib/format";

/** Admin IDs at phone width — the app's ManagementTeamPage (under the "Admin IDs" app bar). */
export default function AdminIdsApp() {
  const toast = useToast();
  const confirm = useConfirm();
  const [team, setTeam] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [busy, setBusy] = useState(false);
  const [sheet, setSheet] = useState<{ member: any | null } | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const r = await get("/auth/management-users");
    setLoading(false);
    if (r.success) setTeam(r.users ?? []);
    else setError(r.error || "Failed to load admin team");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const q = search.trim().toLowerCase();
  const filtered = !q
    ? team
    : team.filter((m) =>
        [m.name, m.email, m.roleTitle, m.mobileNumber].some((v) =>
          String(v ?? "")
            .toLowerCase()
            .includes(q),
        ),
      );

  const remove = async (id: string, name: string) => {
    if (
      !(await confirm({
        title: "Remove Admin ID",
        message: `Remove ${name} as co-admin ID? They will no longer be able to log in.`,
        confirm: "Remove ID",
        danger: true,
      }))
    )
      return;
    setBusy(true);
    const r = await del(`/auth/management-users/${id}`);
    setBusy(false);
    if (r.success) {
      load();
      toast(r.message || "Admin ID removed", "success");
    } else toast(r.error || "Failed to remove", "error");
  };

  return (
    <div className="flex min-h-screen flex-col bg-bg">
      <AppBar title="Admin IDs" />
      <div className="bg-card p-4">
        <div className="flex items-center">
          <div className="flex-1 text-base font-bold">Registered IDs ({team.length})</div>
          <button
            onClick={() => setSheet({ member: null })}
            className="inline-flex items-center gap-2 rounded-[10px] bg-accent px-3.5 py-2.5 text-xs font-semibold"
          >
            <Icon name="add" size={18} />
            Add Admin ID
          </button>
        </div>
        <div className="mt-1.5 text-xs leading-[1.35] text-muted">
          Manage registered admin accounts. Existing admin users can add or manage team IDs.
        </div>
        <div className="relative mt-3.5">
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
            <Icon name="search" size={20} color="#9CA3AF" />
          </span>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name, role, or mobile..."
            className="w-full rounded-[10px] bg-field py-2.5 pl-11 pr-10 text-sm outline-none placeholder:text-[13px] placeholder:text-[#94A3B8]"
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
      <div className="h-px bg-white/10" />
      <div className="flex-1">
        {loading ? (
          <AppSpinner />
        ) : error ? (
          <div className="flex flex-col items-center pt-24 text-center">
            <div className="text-muted">{error}</div>
            <button onClick={load} className="mt-3 rounded-full bg-accent px-5 py-2.5 text-sm font-medium">
              Retry
            </button>
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center px-6 pt-20 text-center">
            <Icon name="badge" outline size={56} color="rgba(255,255,255,0.2)" />
            <div className="mt-3 text-[15px] font-semibold text-muted">
              {q ? "No admin IDs match your search" : "No admin IDs registered yet"}
            </div>
            <div className="mt-1.5 text-[13px] text-[#9E9E9E]">
              Click &quot;+ Add Admin ID&quot; to grant access to another team member.
            </div>
          </div>
        ) : (
          <div className="p-3">
            {filtered.map((m) => {
              const id = String(idOf(m));
              const primary = id.startsWith("primary_");
              const name = m.name || "Admin Member";
              // Older IDs were saved as 'Management Member'.
              const role = String(m.roleTitle || "Admin Member").replace("Management", "Admin");
              return (
                <div
                  key={id}
                  className="mb-2.5 flex items-start rounded-xl border border-white/10 bg-card p-3.5 shadow-[0_2px_4px_rgba(0,0,0,0.02)]"
                >
                  <span className="flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-full bg-accent/15 text-base font-extrabold text-[#93C5FD]">
                    {name ? name[0].toUpperCase() : "M"}
                  </span>
                  <div className="ml-3 min-w-0 flex-1">
                    <div className="truncate text-[15px] font-bold">{name}</div>
                    <span className="mt-1 inline-block rounded-md bg-accent/15 px-[7px] py-0.5 text-[11px] font-semibold text-[#93C5FD]">
                      {role}
                    </span>
                    <div className="mt-2 flex items-center gap-1">
                      <Icon name="phone" outline size={14} color="#9CA3AF" />
                      <span className="text-[13px] font-bold">{m.mobileNumber || "—"}</span>
                    </div>
                    {m.email && (
                      <div className="mt-1 flex items-center gap-1">
                        <Icon name="email" outline size={14} color="#9CA3AF" />
                        <span className="truncate text-xs text-[#CBD5E1]">{m.email}</span>
                      </div>
                    )}
                  </div>
                  {primary ? (
                    <span className="rounded-md bg-field px-2 py-1 text-[10.5px] font-semibold text-muted">
                      Primary Owner
                    </span>
                  ) : (
                    <div className="flex flex-col items-end">
                      <button
                        disabled={busy}
                        onClick={() => setSheet({ member: m })}
                        className="rounded-full px-2 py-1 text-xs font-bold text-accent disabled:opacity-40"
                      >
                        Edit
                      </button>
                      <button
                        disabled={busy}
                        onClick={() => remove(id, name)}
                        className="rounded-full px-2 py-1 text-xs font-bold text-[#DC2626] disabled:opacity-40"
                      >
                        Remove ID
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
      {sheet && (
        <AdminIdSheet
          member={sheet.member}
          onClose={() => setSheet(null)}
          onSaved={(msg) => {
            setSheet(null);
            load();
            toast(msg, "success");
          }}
        />
      )}
    </div>
  );
}

/** Add / Edit Admin ID bottom sheet (_AddManagementIdBottomSheet / _EditManagementIdBottomSheet). */
function AdminIdSheet({
  member,
  onClose,
  onSaved,
}: {
  member: any | null;
  onClose: () => void;
  onSaved: (msg: string) => void;
}) {
  const editing = !!member;
  const [name, setName] = useState(member?.name ?? "");
  const [mobile, setMobile] = useState(member?.mobileNumber ?? "");
  const [email, setEmail] = useState(member?.email ?? "");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    setError(null);
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = "Full Name is required";
    if (!mobile.trim()) e.mobile = "Mobile number is required";
    else if (mobile.trim().length !== 10) e.mobile = "Enter a valid 10-digit mobile number";
    if (!email.trim()) e.email = "Email address is required";
    else if (!/^\S+@\S+\.\S+$/.test(email.trim())) e.email = "Enter a valid email address";
    if (!editing && !password.trim()) e.password = "Password is required";
    else if (password && password.length < 6) e.password = "Password must be at least 6 characters";
    setErrors(e);
    if (Object.keys(e).length) return;
    const body: Record<string, string> = {
      name: name.trim(),
      mobileNumber: mobile.trim(),
      email: email.trim().toLowerCase(),
      roleTitle: member?.roleTitle || "Admin Member",
    };
    if (password) body.password = password;
    setSaving(true);
    const r = editing
      ? await put(`/auth/management-users/${idOf(member)}`, body)
      : await post("/auth/management-users", body);
    setSaving(false);
    if (r.success)
      onSaved(r.message || (editing ? "Admin ID updated successfully" : "New admin ID added successfully"));
    else setError(r.error || (editing ? "Failed to update ID" : "Failed to add ID"));
  };

  const field = { fill: "#0A0A12", outer: "#14141F", border: "rgba(255,255,255,0.1)", radius: 10 };
  return (
    <div className="animate-fade fixed inset-0 z-[90] flex items-end" onClick={onClose}>
      <div className="absolute inset-0 bg-black/55" />
      <div
        className="animate-sheet relative max-h-[92vh] w-full overflow-y-auto rounded-t-[20px] bg-card px-5 pb-5 pt-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mx-auto h-1 w-9 rounded-sm bg-white/20" />
        <div className="mt-3.5 flex items-center">
          <Icon name={editing ? "edit" : "badge"} outline size={22} color="#3B82F6" />
          <span className="ml-2 text-lg font-bold">{editing ? "Edit Admin ID" : "Add Admin ID"}</span>
          <button
            onClick={onClose}
            aria-label="Close"
            className="ml-auto flex h-10 w-10 items-center justify-center rounded-full active:bg-white/10"
          >
            <Icon name="close" color="#9CA3AF" />
          </button>
        </div>
        <div className="mt-1 text-xs leading-[1.35] text-muted">
          {editing
            ? "Update this admin ID's details. Leave the password blank to keep it unchanged."
            : "This new admin ID will have full access to manage all operations for this property."}
        </div>
        <div className="mt-4 space-y-3">
          {error && (
            <div className="rounded-lg border border-[#EF4444]/30 bg-[#EF4444]/15 p-2.5 text-[13px] text-[#DC2626]">
              {error}
            </div>
          )}
          <AppTextField
            {...field}
            label="Full Name"
            icon="person"
            value={name}
            onChange={setName}
            error={errors.name}
          />
          <AppTextField
            {...field}
            label="Login Mobile Phone (10 digits)"
            icon="phone_android"
            inputMode="numeric"
            maxLength={10}
            value={mobile}
            onChange={(v) => setMobile(v.replace(/\D/g, ""))}
            error={errors.mobile}
          />
          <AppTextField
            {...field}
            label="Email Address"
            icon="email"
            type="email"
            value={email}
            onChange={setEmail}
            error={errors.email}
          />
          <AppTextField
            {...field}
            label={editing ? "New Password (optional)" : "Set Password"}
            icon="lock"
            password
            value={password}
            onChange={setPassword}
            error={errors.password}
          />
        </div>
        <button
          onClick={saving ? undefined : submit}
          className="mt-5 flex w-full items-center justify-center rounded-xl bg-accent py-3.5 text-[15px] font-bold"
        >
          {saving ? <Spinner size={20} color="#fff" /> : editing ? "Save Changes" : "Create Admin ID"}
        </button>
      </div>
    </div>
  );
}
