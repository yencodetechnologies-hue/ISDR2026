/* eslint-disable @typescript-eslint/no-explicit-any */
import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { clearToken, get, getToken, post, saveToken } from "./api";

export type User = Record<string, any> & {
  id?: string;
  _id?: string;
  name?: string;
  email?: string;
  userType?: string;
  status?: string;
  apartmentId?: string;
};

const USER_KEY = "current_user";

type AuthCtx = {
  user: User | null;
  ready: boolean;
  login: (identifier: string, password: string) => Promise<{ user?: User; error?: string }>;
  logout: () => void;
  refresh: () => Promise<User | null>;
  setUser: (u: User | null) => void;
};

const Ctx = createContext<AuthCtx>(null as unknown as AuthCtx);

function readCached(): User | null {
  try {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function writeCached(u: User | null) {
  try {
    if (u) localStorage.setItem(USER_KEY, JSON.stringify(u));
    else localStorage.removeItem(USER_KEY);
  } catch {
    /* storage unavailable */
  }
}

/** Where each role lands after login (the app's _navigateToDashboard). */
export function homeFor(user: User | null): string {
  if (!user) return "/login";
  if (user.status === "pending") return "/waiting-approval";
  switch (String(user.userType ?? "").toLowerCase()) {
    case "apartment":
      return "/admin";
    case "participant":
      return "/participant";
    case "speaker":
      return "/speaker";
    case "user":
    case "tenant":
      return "/staff";
    default:
      return "/login";
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUserState] = useState<User | null>(() => (getToken() ? readCached() : null));
  const [ready, setReady] = useState(false);

  const setUser = useCallback((u: User | null) => {
    setUserState(u);
    writeCached(u);
  }, []);

  const refresh = useCallback(async () => {
    if (!getToken()) {
      setUser(null);
      return null;
    }
    const res = await get("/auth/me");
    if (res.success && res.user) {
      setUser(res.user);
      return res.user as User;
    }
    // Offline: keep the cached user while a token exists (same as the app).
    if (!getToken()) setUser(null);
    return readCached();
  }, [setUser]);

  useEffect(() => {
    refresh().finally(() => setReady(true));
  }, [refresh]);

  const login = useCallback(
    async (identifier: string, password: string) => {
      const res = await post("/auth/login", { email: identifier, password });
      if (!res.success || !res.user) return { error: res.error || "Login failed" };
      if (res.token) saveToken(res.token);
      setUser(res.user);
      return { user: res.user as User };
    },
    [setUser],
  );

  const logout = useCallback(() => {
    clearToken();
    setUser(null);
    try {
      localStorage.removeItem("selected_apartment_id");
    } catch {
      /* storage unavailable */
    }
  }, [setUser]);

  return <Ctx.Provider value={{ user, ready, login, logout, refresh, setUser }}>{children}</Ctx.Provider>;
}

export const useAuth = () => useContext(Ctx);
