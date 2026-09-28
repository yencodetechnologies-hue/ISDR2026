/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import LiveShowCard from "@/components/LiveShowCard";
import { Avatar, Icon, Loading } from "@/components/ui";
import { BottomNav, ModuleGrid, NewsTicker, NotificationBell, SectionTitle, YoutubeLiveCapsule, useHomeBanner, BannerCarousel } from "@/components/widgets";
import { asset, get } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { ADMIN_MODULES, adminNav } from "./modules";

export default function AdminHome() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const banner = useHomeBanner();

  const [stats, setStats] = useState<{ events: number; participants: number; staff: number; speakers: number } | null>(null);

  const load = useCallback(async () => {
    const [evts, staff, speakers] = await Promise.all([get("/managed-events"), get("/auth/users"), get("/speakers")]);
    let participants = 0;
    if (evts.success && Array.isArray(evts.events)) {
      for (const e of evts.events) participants += Number(e.bookedCount) || 0;
    }
    setStats({
      events: Array.isArray(evts.events) ? evts.events.length : 0,
      participants,
      staff: Array.isArray(staff.users) ? staff.users.length : 0,
      speakers: Array.isArray(speakers.speakers) ? speakers.speakers.length : 0,
    });
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const statCards = [
    { label: "Events", value: stats?.events ?? "–", icon: "event", color: "#3B82F6", to: "/admin/events" },
    { label: "Participants", value: stats?.participants ?? "–", icon: "group", color: "#10B981", to: "/admin/events" },
    { label: "Staff", value: stats?.staff ?? "–", icon: "badge", color: "#F59E0B", to: "/admin/team" },
    { label: "Speakers", value: stats?.speakers ?? "–", icon: "mic", color: "#A855F7", to: "/admin/speakers" },
  ];

  return (
    <div className="min-h-screen bg-bg pb-24">
      <header className="sticky top-0 z-30 border-b border-line bg-bg/90 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-[760px] items-center gap-2 px-3">
          <img src={asset("ISDR 2026 Logo.png")} alt="" className="h-11 w-11 object-contain" />
          <div className="min-w-0 flex-1">
            <div className="text-[17px] font-bold">
              ISDR <span className="text-[#60A5FA]">2026</span> <span className="text-xs font-medium text-white/50">Admin</span>
            </div>
            <div className="truncate text-[10.5px] font-medium text-white/60">Management Console</div>
          </div>
          <NotificationBell />
          <button onClick={() => navigate("/admin/profile")} title="Profile">
            <Avatar src={user?.profilePic} name={user?.name ?? "A"} size={34} />
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-[760px] px-4 py-3">
        {/* Stats */}
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          {statCards.map((s) => (
            <button
              key={s.label}
              onClick={() => navigate(s.to)}
              className="card flex flex-col items-start gap-1.5 p-3.5 text-left hover:bg-[#191926]"
            >
              <span className="flex h-9 w-9 items-center justify-center rounded-xl" style={{ background: `${s.color}22` }}>
                <Icon name={s.icon} size={20} color={s.color} />
              </span>
              <span className="text-2xl font-extrabold">{stats === null ? <Loading /> : s.value}</span>
              <span className="text-xs font-medium text-muted">{s.label}</span>
            </button>
          ))}
        </div>

        <LiveShowCard />

        <div className="mt-3">
          <NewsTicker />
        </div>

        {/* Module grid */}
        <SectionTitle>Management</SectionTitle>
        <div className="card p-2">
          <ModuleGrid items={ADMIN_MODULES} />
        </div>

        <div className="mt-5">
          <YoutubeLiveCapsule />
          <BannerCarousel urls={banner} />
        </div>
      </main>
      <BottomNav items={adminNav} active={0} />
    </div>
  );
}
