import { useEffect, useRef, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { asset } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { activeLink, navFor, PROFILE_PATH, ROLE_TITLE, roleOf, type NavLink, type Role } from "@/lib/nav";
import { roleLabel, useLogout } from "@/pages/common/Profile";
import { Avatar, Icon, useToast } from "./ui";
import { NotificationBell } from "./widgets";
import { APP_LAYOUT_ROLES, AppLayoutContext, setAppLayoutActive } from "@/lib/appLayout";
import { useMobile } from "@/lib/useMobile";

function Brand({ role }: { role: Role }) {
  return (
    <div className="flex items-center gap-3">
      <img src={asset("ISDR 2026 Logo.png")} alt="" className="h-10 w-10 object-contain" />
      <div className="min-w-0">
        <div className="text-[17px] leading-tight font-extrabold">
          ISDR <span className="text-[#60A5FA]">2026</span>
        </div>
        <div className="truncate text-[11px] font-medium text-white/50">{ROLE_TITLE[role]}</div>
      </div>
    </div>
  );
}

function SidebarNav({ role, onNavigate }: { role: Role; onNavigate?: () => void }) {
  const location = useLocation();
  const navigate = useNavigate();
  const toast = useToast();
  const active = activeLink(role, location.pathname, location.search);

  const go = (l: NavLink) => {
    if (l.soon) toast(`${l.soon} is coming soon`);
    else if (l.to) navigate(l.to);
    onNavigate?.();
  };

  return (
    <nav className="flex-1 space-y-5 overflow-y-auto px-3 py-4">
      {navFor(role).map((section, si) => (
        <div key={section.title ?? si}>
          {section.title && <div className="eyebrow mb-1.5 px-3 text-[10px]">{section.title}</div>}
          <div className="space-y-0.5">
            {section.items.map((l) => {
              const on = active === l;
              return (
                <button
                  key={l.label}
                  onClick={() => go(l)}
                  className={`group flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-[13.5px] font-medium transition ${
                    on ? "bg-accent/15 text-white" : "text-white/65 hover:bg-white/5 hover:text-white"
                  }`}
                >
                  <span
                    className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md transition"
                    style={{ background: on ? l.color : `${l.color}1f` }}
                  >
                    <Icon name={l.icon} size={17} color={on ? "#fff" : l.color} />
                  </span>
                  <span className="flex-1 truncate">{l.label}</span>
                  {l.soon && (
                    <span className="rounded bg-white/10 px-1.5 py-0.5 text-[9px] font-bold tracking-wide text-white/50">
                      SOON
                    </span>
                  )}
                  {on && <span className="h-1.5 w-1.5 rounded-full bg-[#60A5FA]" />}
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </nav>
  );
}

function UserBlock({ role }: { role: Role }) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const logout = useLogout();
  if (!user) return null;
  return (
    <div className="border-t border-line p-3">
      <div className="flex items-center gap-2.5 rounded-lg p-2">
        <button
          onClick={() => navigate(PROFILE_PATH[role])}
          className="flex min-w-0 flex-1 items-center gap-2.5 text-left"
          title="My profile"
        >
          <Avatar src={user.profilePic} name={user.name} size={36} />
          <span className="min-w-0">
            <span className="block truncate text-sm font-semibold">{user.name}</span>
            <span className="block truncate text-[11px] text-muted">{roleLabel(user)}</span>
          </span>
        </button>
        <button
          onClick={logout}
          title="Log out"
          className="flex h-8 w-8 items-center justify-center rounded-md text-white/50 hover:bg-red-500/15 hover:text-[#F87171]"
        >
          <Icon name="logout" size={19} />
        </button>
      </div>
    </div>
  );
}

function AccountMenu({ role }: { role: Role }) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const logout = useLogout();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, [open]);
  if (!user) return null;
  const item = (icon: string, label: string, onClick: () => void, danger?: boolean) => (
    <button
      onClick={() => {
        setOpen(false);
        onClick();
      }}
      className={`flex w-full items-center gap-2.5 px-3.5 py-2 text-left text-sm hover:bg-white/5 ${danger ? "text-[#F87171]" : "text-white/85"}`}
    >
      <Icon name={icon} size={18} outline />
      {label}
    </button>
  );
  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-2 rounded-full py-1 pl-1 pr-2 hover:bg-white/5"
      >
        <Avatar src={user.profilePic} name={user.name} size={32} />
        <span className="hidden max-w-[140px] truncate text-sm font-semibold md:block">{user.name}</span>
        <Icon name="expand_more" size={18} color="#9CA3AF" />
      </button>
      {open && (
        <div className="animate-fade absolute right-0 top-12 z-50 w-56 overflow-hidden rounded-xl border border-line bg-field py-1.5 shadow-2xl">
          <div className="border-b border-line px-3.5 pb-2.5 pt-1">
            <div className="truncate text-sm font-semibold">{user.name}</div>
            <div className="truncate text-xs text-muted">{user.email || user.mobileNumber || roleLabel(user)}</div>
          </div>
          <div className="py-1">
            {item("person", "My Profile", () => navigate(PROFILE_PATH[role]))}
            {item("lock", "Change Password", () => navigate("/change-password"))}
            {item("notifications", "Notifications", () => navigate("/notifications"))}
          </div>
          <div className="border-t border-line pt-1">{item("logout", "Log out", logout, true)}</div>
        </div>
      )}
    </div>
  );
}

/** Website layout for signed-in pages: fixed sidebar (drawer on small screens) + top bar. */
export default function Shell({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const role = roleOf(user);
  const location = useLocation();
  const [drawer, setDrawer] = useState(false);
  const mobile = useMobile();

  useEffect(() => setDrawer(false), [location.pathname, location.search]);
  const isMobile = mobile || (typeof window !== "undefined" && window.innerWidth < 1024);
  const appLayout = !!role && isMobile && APP_LAYOUT_ROLES.includes(role);
  useEffect(() => {
    setAppLayoutActive(appLayout);
    return () => setAppLayoutActive(false);
  }, [appLayout]);

  if (!role) return <>{children}</>;
  // Phone width for a converted role: no website chrome — each page draws the app's own header / app bar.
  if (appLayout)
    return (
      <AppLayoutContext.Provider value={true}>
        <div className="min-h-screen bg-bg">{children}</div>
      </AppLayoutContext.Provider>
    );
  const today = new Date().toLocaleDateString("en-IN", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });

  return (
    <div className="min-h-screen bg-bg">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-40 hidden w-64 flex-col border-r border-line bg-sidebar lg:flex">
        <Link
          to={navFor(role)[0].items[0].to ?? "/"}
          className="flex h-16 shrink-0 items-center border-b border-line px-5"
        >
          <Brand role={role} />
        </Link>
        <SidebarNav role={role} />
        <UserBlock role={role} />
      </aside>

      {/* Mobile drawer */}
      {drawer && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="animate-fade absolute inset-0 bg-black/70" onClick={() => setDrawer(false)} />
          <aside className="animate-drawer relative flex h-full w-72 max-w-[85vw] flex-col border-r border-line bg-sidebar">
            <div className="flex h-16 shrink-0 items-center justify-between border-b border-line px-4">
              <Brand role={role} />
              <button
                onClick={() => setDrawer(false)}
                className="flex h-9 w-9 items-center justify-center rounded-md hover:bg-white/10"
                title="Close menu"
              >
                <Icon name="close" />
              </button>
            </div>
            <SidebarNav role={role} onNavigate={() => setDrawer(false)} />
            <UserBlock role={role} />
          </aside>
        </div>
      )}

      <div className="flex min-h-screen flex-col lg:pl-64">
        <header className="sticky top-0 z-30 border-b border-line bg-bg/85 backdrop-blur">
          <div className="flex h-16 items-center gap-2 px-4 sm:px-6 lg:px-8">
            <button
              onClick={() => setDrawer(true)}
              className="-ml-1 flex h-10 w-10 items-center justify-center rounded-md hover:bg-white/10 lg:hidden"
              title="Menu"
            >
              <Icon name="menu" />
            </button>
            <div className="lg:hidden">
              <img src={asset("ISDR 2026 Logo.png")} alt="ISDR 2026" className="h-9 w-9 object-contain" />
            </div>
            <div className="hidden items-center gap-2 text-sm text-muted lg:flex">
              <Icon name="calendar_today" size={17} outline />
              {today}
            </div>
            <div className="flex-1" />
            <NotificationBell />
            <div className="mx-1 h-6 w-px bg-line" />
            <AccountMenu role={role} />
          </div>
        </header>
        <div className="flex-1">{children}</div>
        <footer className="border-t border-line px-4 py-5 text-center text-xs text-white/35 sm:px-6 lg:px-8">
          36th ISDR International Conference 2026 · Indian Society for Dental Research — Indian Division of IADR
        </footer>
      </div>
    </div>
  );
}
