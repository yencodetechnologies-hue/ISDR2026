/* eslint-disable @typescript-eslint/no-explicit-any */
export const API_BASE: string =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, "") ||
  "https://isdr2026.yencodetechnologies.in/api";

/** Public register link host used by the app for managed events. */
export const EVENT_WEB_BASE = "https://www.maccess.online";

const TOKEN_KEY = "auth_token";

export type Json = Record<string, any>;
export type ApiResult = Json & { success: boolean; error?: string; status?: number };

export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function saveToken(token: string) {
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    /* storage unavailable */
  }
}

export function clearToken() {
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* storage unavailable */
  }
}

/**
 * One API call. Returns the response body plus `success`, or
 * `{success:false, error}` when the request fails — the same shape the app's
 * ApiService methods return.
 */
export async function api(
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE",
  path: string,
  body?: Json | FormData,
  headers: Record<string, string> = {},
): Promise<ApiResult> {
  const h: Record<string, string> = { ...headers };
  const token = getToken();
  if (token) h.Authorization = `Bearer ${token}`;
  let payload: BodyInit | undefined;
  if (body instanceof FormData) payload = body;
  else if (body !== undefined) {
    h["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  try {
    const res = await fetch(`${API_BASE}${path}`, { method, headers: h, body: payload });
    let data: Json = {};
    try {
      const parsed = await res.json();
      data = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : { data: parsed };
    } catch {
      /* empty body */
    }
    if (!res.ok) {
      if (res.status === 401 && path.startsWith("/auth/me")) clearToken();
      return {
        ...data,
        success: false,
        status: res.status,
        error: data.error || data.message || `Request failed (${res.status})`,
      };
    }
    return { ...data, success: data.success !== false, status: res.status };
  } catch {
    return {
      success: false,
      error: "Unable to connect to server. Please check your internet connection.",
    };
  }
}

export const get = (path: string, headers?: Record<string, string>) => api("GET", path, undefined, headers);
export const post = (path: string, body?: Json | FormData, headers?: Record<string, string>) =>
  api("POST", path, body ?? {}, headers);
export const put = (path: string, body?: Json | FormData, headers?: Record<string, string>) =>
  api("PUT", path, body ?? {}, headers);
export const patch = (path: string, body?: Json | FormData, headers?: Record<string, string>) =>
  api("PATCH", path, body ?? {}, headers);
export const del = (path: string, headers?: Record<string, string>) => api("DELETE", path, undefined, headers);

/** Multipart form data, skipping null/undefined values; objects are JSON-encoded. */
export function formData(fields: Json, files?: Record<string, File | Blob | null | undefined>) {
  const fd = new FormData();
  for (const [k, v] of Object.entries(fields)) {
    if (v === undefined || v === null) continue;
    fd.append(k, typeof v === "object" ? JSON.stringify(v) : String(v));
  }
  for (const [k, f] of Object.entries(files ?? {})) if (f) fd.append(k, f);
  return fd;
}

/** Query string from an object, skipping empty values. */
export function qs(params: Json) {
  const s = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== "") s.set(k, String(v));
  const out = s.toString();
  return out ? `?${out}` : "";
}

/** Asset from public/assets. */
export const asset = (name: string) => `/assets/${encodeURI(name)}`;
