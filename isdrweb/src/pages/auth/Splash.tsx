import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { asset } from "@/lib/api";
import { homeFor, useAuth } from "@/lib/auth";

/** Splash: shows the splash art, then goes to the role's home or login. */
export default function Splash() {
  const { user, ready } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!ready) return;
    const t = setTimeout(() => navigate(homeFor(user), { replace: true }), user ? 500 : 1500);
    return () => clearTimeout(t);
  }, [ready, user, navigate]);

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-[#021B4D]">
      <img src={asset("splash.png")} alt="ISDR 2026" className="h-full w-full object-contain" />
      <div className="absolute inset-x-0 bottom-10 flex justify-center">
        <div className="h-1.5 w-40 overflow-hidden rounded-full bg-white/25">
          <div className="h-full w-1/2 rounded-full bg-[#26D6FE]" style={{ animation: "ticker 1.2s linear infinite" }} />
        </div>
      </div>
    </div>
  );
}
