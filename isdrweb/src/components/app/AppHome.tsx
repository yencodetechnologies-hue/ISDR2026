/* eslint-disable react-refresh/only-export-components */
import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { asset, get } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLiveNotifications, useUnreadCount } from "@/lib/notifications";
import { fmtTimeStr, sameDay } from "@/lib/format";
import { loadAllSchedules, scheduleHref, type ScheduleItem } from "@/lib/schedules";
import { useLogout } from "@/pages/common/Profile";
import { Icon } from "../ui";

/* ------------------------------------------------------------------ */
/* Home header — logo, "ISDR 2026", "Indian Division • IADR", bell,     */
/* logout, profile avatar (the app's _buildHomeHeader)                  */
/* ------------------------------------------------------------------ */

export { useUnreadCount };

export function AppHomeHeader({ profilePath }: { profilePath: string }) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const logout = useLogout();
  const unread = useUnreadCount();
  const { askPermission } = useLiveNotifications();
  const name = String(user?.name ?? "");
  const photo = String(user?.profilePic ?? "");
  return (
    <div className="flex items-center pb-2 pl-3 pr-2 pt-2">
      <img src={asset("ISDR 2026 Logo.png")} alt="" className="h-[58px] w-[58px] shrink-0 object-contain" />
      <div className="ml-2.5 min-w-0 flex-1">
        <div className="truncate font-outfit text-[17px] font-bold leading-tight">
          ISDR <span className="text-[#60A5FA]">2026</span>
        </div>
        <div className="truncate text-[10.5px] font-medium text-white/60">
          Indian Division&nbsp;&nbsp;•&nbsp;&nbsp;IADR
        </div>
      </div>
      <button
        onClick={() => {
          askPermission();
          navigate("/notifications");
        }}
        aria-label="Notifications"
        className="relative flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
      >
        <Icon name="notifications" outline size={24} />
        {unread > 0 && (
          <span className="absolute right-2 top-2 flex h-4 min-w-4 items-center justify-center rounded-full bg-[#EF4444] px-[3px] text-[9px] font-bold">
            {unread > 99 ? "99+" : unread}
          </span>
        )}
      </button>
      <button
        onClick={logout}
        aria-label="Logout"
        className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
      >
        <Icon name="logout" size={24} />
      </button>
      <button
        onClick={() => navigate(profilePath)}
        aria-label="Profile"
        className="ml-0.5 mr-1 flex h-[34px] w-[34px] shrink-0 items-center justify-center overflow-hidden rounded-full bg-white/15"
      >
        {photo ? (
          <img src={photo} alt="" className="h-full w-full object-cover" />
        ) : (
          <span className="font-outfit text-sm font-bold">{name ? name[0].toUpperCase() : "M"}</span>
        )}
      </button>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Banner carousel — full width, 170px, auto-advance every 3s, swipe,  */
/* dots at the bottom (the app's AutoScrollBanner)                      */
/* ------------------------------------------------------------------ */

export const DEFAULT_BANNERS = [
  asset("isdr-slider.webp"),
  asset("Gemini_Generated_Image_bg38yfbg38yfbg38.png"),
  asset("Gemini_Generated_Image_avabulavabulavab.png"),
];

export function AppBannerCarousel({ images, height = 170 }: { images: string[]; height?: number }) {
  const ref = useRef<HTMLDivElement>(null);
  const [page, setPage] = useState(0);

  useEffect(() => {
    if (images.length < 2) return;
    const t = setInterval(() => {
      const el = ref.current;
      if (!el) return;
      const next = (Math.round(el.scrollLeft / el.clientWidth) + 1) % images.length;
      el.scrollTo({ left: next * el.clientWidth, behavior: "smooth" });
    }, 3000);
    return () => clearInterval(t);
  }, [images.length]);

  if (!images.length) return null;
  return (
    <div className="relative" style={{ height }}>
      <div
        ref={ref}
        onScroll={(e) => {
          const el = e.currentTarget;
          setPage(Math.round(el.scrollLeft / Math.max(el.clientWidth, 1)));
        }}
        className="flex h-full snap-x snap-mandatory overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {images.map((src, i) => (
          <img key={i} src={src} alt="" className="h-full w-full shrink-0 snap-center object-cover" />
        ))}
      </div>
      {images.length > 1 && (
        <div className="pointer-events-none absolute inset-x-0 bottom-2 flex justify-center">
          {images.map((_, i) => (
            <span
              key={i}
              className="mx-[3px] h-1.5 rounded-[3px] transition-all duration-300"
              style={{ width: i === page ? 16 : 6, background: `rgba(255,255,255,${i === page ? 0.95 : 0.5})` }}
            />
          ))}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Live show card — the app's LiveShowCard                             */
/* ------------------------------------------------------------------ */

function GlowingDot() {
  return (
    <span className="relative flex h-4 w-4 items-center justify-center">
      <span className="absolute h-4 w-4 animate-ping rounded-full bg-white/50" />
      <span className="h-[7px] w-[7px] rounded-full bg-white shadow-[0_0_4px_rgba(255,255,255,0.8)]" />
    </span>
  );
}

export function AppLiveShowCard() {
  const navigate = useNavigate();
  const [items, setItems] = useState<ScheduleItem[]>([]);
  const [now, setNow] = useState(() => new Date());
  const [cycle, setCycle] = useState(0);
  const touchX = useRef<number | null>(null);

  const load = useCallback(async () => {
    const r = await loadAllSchedules();
    if (!r.error) setItems(r.items);
  }, []);
  useEffect(() => {
    load();
    const t = setInterval(() => {
      setNow(new Date());
      load();
    }, 30000);
    return () => clearInterval(t);
  }, [load]);

  const today = items
    .filter((it) => sameDay(it.start, now) && it.end > now)
    .sort((a, b) => a.start.getTime() - b.start.getTime());
  useEffect(() => {
    if (today.length < 2) return;
    const t = setInterval(() => setCycle((c) => c + 1), 5000);
    return () => clearInterval(t);
  }, [today.length]);

  if (!today.length)
    return (
      <div className="flex items-center bg-white px-4 py-3.5">
        <span className="rounded-[10px] bg-[#F1F5F9] p-2">
          <Icon name="podcasts" size={20} color="#94A3B8" />
        </span>
        <div className="ml-3 flex-1">
          <div className="font-outfit text-[15px] font-bold text-[#334155]">No Live Program</div>
          <div className="mt-0.5 text-[11.5px] text-[#64748B]">No live program is currently active</div>
        </div>
        <span className="rounded-lg bg-[#F1F5F9] px-2 py-1 text-[10px] font-bold tracking-[0.5px] text-[#94A3B8]">
          OFFLINE
        </span>
      </div>
    );

  const index = ((cycle % today.length) + today.length) % today.length;
  const item = today[index];
  const s = item.schedule ?? {};
  const isLive = now >= item.start && now < item.end;
  const speakerPhoto = String(s.speakerPhoto ?? "");
  return (
    <div>
      <div
        onClick={() => navigate(scheduleHref(item))}
        onTouchStart={(e) => (touchX.current = e.touches[0].clientX)}
        onTouchEnd={(e) => {
          const start = touchX.current;
          touchX.current = null;
          if (start == null || today.length < 2) return;
          const dx = e.changedTouches[0].clientX - start;
          if (Math.abs(dx) > 40) setCycle((c) => c + (dx < 0 ? 1 : -1));
        }}
        className="relative cursor-pointer overflow-hidden rounded-[18px] shadow-[0_5px_12px_rgba(30,58,138,0.3)]"
      >
        <img src={asset("live banner-clean.png")} alt="" className="absolute inset-0 h-full w-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-r from-[#0A0E1A]/[0.92] to-[#0A0E1A]/[0.55]" />
        <div className="relative px-3.5 py-[7px]">
          <span
            className="inline-flex items-center gap-1 rounded-full px-[7px] py-0.5"
            style={{ background: isLive ? "#DC2626" : "#6366F1" }}
          >
            {isLive ? <GlowingDot /> : <Icon name="campaign" size={10} />}
            <span className="text-[10.5px] font-extrabold tracking-[0.3px]">
              {isLive ? "LIVE NOW" : "Next Session"}
            </span>
          </span>
          <div className="mt-1 truncate font-outfit text-[14.5px] font-extrabold leading-[1.1]">{s.scheduleName}</div>
          {s.speakerName && (
            <div className="relative mt-1 h-4">
              <div
                className="truncate text-[11.5px] font-semibold text-white/85"
                style={{ paddingRight: speakerPhoto ? 52 : 0 }}
              >
                {s.speakerName}
              </div>
              {speakerPhoto && (
                <img
                  src={speakerPhoto}
                  alt=""
                  className="absolute -top-3.5 right-0 h-11 w-11 rounded-full border-[1.5px] border-white/40 object-cover"
                />
              )}
            </div>
          )}
          {(s.fromTime || s.hall) && (
            <div className="mt-[3px] flex items-center text-[10.5px] font-medium text-white/85">
              {s.fromTime && s.toTime && (
                <>
                  <Icon name="schedule" size={12} />
                  <span className="ml-1">
                    {fmtTimeStr(s.fromTime)} - {fmtTimeStr(s.toTime)}
                  </span>
                </>
              )}
              {s.hall && (
                <>
                  <span className="ml-2.5">
                    <Icon name="location_on" size={12} />
                  </span>
                  <span className="ml-1 truncate">{s.hall}</span>
                </>
              )}
            </div>
          )}
          <span className="mt-1.5 inline-flex items-center gap-[3px] rounded-full bg-[#2563EB] px-2.5 py-[5px] text-[11.5px] font-bold">
            View Details
            <Icon name="arrow_forward" size={13} />
          </span>
        </div>
      </div>
      {today.length > 1 && (
        <div className="mt-2.5 flex justify-center">
          {today.map((_, i) => (
            <span
              key={i}
              className="mx-[3px] h-1.5 rounded-[3px] transition-all duration-200"
              style={{ width: i === index ? 18 : 6, background: i === index ? "#60A5FA" : "rgba(255,255,255,0.25)" }}
            />
          ))}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Module grid — the app's boxed 4-column grid with solid icon squares; */
/* 8 slots on the home, the 8th is "More" when there are more modules   */
/* ------------------------------------------------------------------ */

export type AppModule = { label: string; icon: string; color: string; to?: string; onClick?: () => void };

export const HOME_SLOTS = 8;

function ModuleTile({ m, onTap }: { m: AppModule; onTap: () => void }) {
  return (
    <button onClick={onTap} className="flex flex-col items-center pt-0.5 transition active:scale-95">
      <span
        className="flex h-[46px] w-[46px] items-center justify-center rounded-[13px]"
        style={{ background: m.color }}
      >
        <Icon name={m.icon} size={22} />
      </span>
      <span className="mt-1 line-clamp-2 h-6 px-0.5 text-center text-[10.5px] font-semibold leading-[1.15] text-white/90">
        {m.label}
      </span>
    </button>
  );
}

/** Title ("ADMIN MODULES") + boxed grid. With [moreTo], shows 7 + a "More" tile linking there. */
export function AppModuleGrid({ title, modules, moreTo }: { title: string; modules: AppModule[]; moreTo?: string }) {
  const navigate = useNavigate();
  const overflow = !!moreTo && modules.length > HOME_SLOTS;
  const shown = overflow ? modules.slice(0, HOME_SLOTS - 1) : modules;
  const go = (m: AppModule) => (m.onClick ? m.onClick() : m.to && navigate(m.to));
  return (
    <div>
      <div className="mb-2 ml-0.5 mt-2.5 text-[11px] font-bold tracking-[0.5px] text-muted">{title}</div>
      <div className="grid grid-cols-4 gap-x-0.5 gap-y-1.5 rounded-2xl border border-white/[0.06] bg-card px-1 py-2">
        {shown.map((m) => (
          <ModuleTile key={m.label} m={m} onTap={() => go(m)} />
        ))}
        {overflow && (
          <ModuleTile m={{ label: "More", icon: "grid_view", color: "#64748B" }} onTap={() => navigate(moreTo!)} />
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* News ticker strip — the app's NewsTickerStrap (34px, blue, scrolling) */
/* ------------------------------------------------------------------ */

export function AppTickerStrap({ text }: { text: string }) {
  const secs = Math.max(10, text.length * 0.16);
  return (
    <div className="flex h-[34px] items-center overflow-hidden rounded-[14px] border border-white/[0.08] bg-[#2563EB]">
      <div className="flex w-max whitespace-nowrap" style={{ animation: `ticker ${secs}s linear infinite` }}>
        {[0, 1].map((i) => (
          <span key={i} className="pr-10 text-[12.5px] font-semibold tracking-[0.2px]">
            {text}
          </span>
        ))}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* "Get your live photos" — the app's GetLivePhotoButton                */
/* ------------------------------------------------------------------ */

export function AppLivePhotoButton() {
  const [url, setUrl] = useState("");
  useEffect(() => {
    get("/live-photo").then((r) => r.success && setUrl(String(r.url ?? "").trim()));
  }, []);
  if (!url) return null;
  return (
    <a
      href={url}
      target="_blank"
      rel="noreferrer"
      className="mb-3 flex items-center rounded-2xl bg-gradient-to-br from-[#E11D48] via-[#BE123C] to-[#9333EA] px-4 py-[13px] shadow-[0_4px_12px_rgba(225,29,72,0.35)]"
    >
      <span className="flex h-[38px] w-[38px] items-center justify-center rounded-xl bg-white/20">
        <Icon name="photo_camera" size={22} />
      </span>
      <span className="ml-3.5 flex-1">
        <span className="flex items-center gap-1.5 text-[10px] font-extrabold tracking-[0.8px] text-white/70">
          <span className="h-[7px] w-[7px] animate-pulse rounded-full bg-[#4ADE80]" />
          LIVE GALLERY
        </span>
        <span className="mt-0.5 block font-outfit text-base font-bold">Get your live photos</span>
      </span>
      <span className="rounded-full bg-white/15 p-2">
        <Icon name="arrow_forward" size={18} />
      </span>
    </a>
  );
}
