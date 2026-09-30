/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon, Spinner, useToast } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { AppSelectField } from "@/components/app/AppForm";
import { get, post } from "@/lib/api";
import { idOf } from "@/lib/format";
import { normalizeInclusions } from "./EventManage";

/** Send Notification at phone width — the app's SendNotificationPage (event, package, inclusion, content). */
export default function SendNotificationApp() {
  const toast = useToast();
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [eventId, setEventId] = useState("");
  const [packageId, setPackageId] = useState(""); // "" = all packages
  const [inclusion, setInclusion] = useState(""); // "" = all inclusions
  const [content, setContent] = useState("");
  const [focused, setFocused] = useState(false);
  const [sending, setSending] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    const r = await get("/managed-events");
    setLoading(false);
    if (r.success) setEvents(r.events ?? []);
    else setLoadError(r.error || "Failed to load events");
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  const event = events.find((e) => idOf(e) === eventId) ?? null;
  const packages: any[] = event?.packages ?? [];
  const inclusionNames = [
    ...new Set(
      (packageId ? packages.filter((p) => String(p.id) === packageId) : packages).flatMap((p) =>
        normalizeInclusions(p.inclusions).map((i) => i.name),
      ),
    ),
  ];

  const send = async () => {
    if (!event) return toast("Select an event");
    if (!content.trim()) return toast("Write the notification content");
    setSending(true);
    const r = await post(`/managed-events/${eventId}/notifications`, {
      message: content.trim(),
      ...(packageId ? { packageId } : {}),
      ...(inclusion ? { inclusionName: inclusion } : {}),
    });
    setSending(false);
    if (r.success) {
      const n = Number(r.recipientCount ?? 0);
      setContent("");
      toast(`Notification sent to ${n} participant${n === 1 ? "" : "s"}`);
    } else toast(r.error || "Failed to send notification");
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Send Notification" titleClassName="text-[18px] font-bold" />
      {loading ? (
        <AppSpinner />
      ) : loadError ? (
        <div className="flex flex-col items-center pt-32 text-center">
          <div>{loadError}</div>
          <button
            onClick={load}
            className="mt-2.5 h-10 rounded-full border border-[#8E8E98] px-5 text-sm font-medium text-accent"
          >
            Retry
          </button>
        </div>
      ) : (
        <div className="space-y-3 p-4">
          <AppSelectField
            label="Event *"
            icon="event"
            hint="Select event"
            value={eventId}
            onChange={(v) => {
              setEventId(v);
              setPackageId("");
              setInclusion("");
            }}
            options={events.map((e) => ({ value: idOf(e), label: e.title || "Event" }))}
          />
          <AppSelectField
            label="Package (optional)"
            icon="inventory_2"
            value={packageId}
            disabled={!event}
            onChange={(v) => {
              setPackageId(v);
              setInclusion("");
            }}
            options={[
              { value: "", label: "All packages" },
              ...packages.map((p) => ({ value: String(p.id), label: p.name })),
            ]}
          />
          <AppSelectField
            label="Inclusion (optional)"
            icon="checklist"
            value={inclusion}
            disabled={!event}
            onChange={setInclusion}
            options={[{ value: "", label: "All inclusions" }, ...inclusionNames.map((n) => ({ value: n, label: n }))]}
          />
          {/* Multi-line content with the floating label */}
          <div
            className="relative rounded-[14px] bg-field"
            style={{ boxShadow: `inset 0 0 0 ${focused ? 2 : 1}px ${focused ? "#3B82F6" : "rgba(255,255,255,0.1)"}` }}
          >
            <span className="pointer-events-none absolute left-3.5 top-4">
              <Icon name="notes" size={20} color="#3B82F6" />
            </span>
            <label
              className="pointer-events-none absolute transition-all duration-150"
              style={
                focused || content
                  ? {
                      left: 12,
                      top: -8,
                      fontSize: 12,
                      color: focused ? "#3B82F6" : "#9CA3AF",
                      padding: "0 4px",
                      background: "linear-gradient(to bottom, #0A0A12 50%, #1E1E2A 50%)",
                      lineHeight: "16px",
                    }
                  : { left: 48, top: 16, fontSize: 15, color: "#9CA3AF" }
              }
            >
              Notification content *
            </label>
            <textarea
              value={content}
              rows={4}
              onFocus={() => setFocused(true)}
              onBlur={() => setFocused(false)}
              onChange={(e) => setContent(e.target.value)}
              className="block max-h-[200px] min-h-[112px] w-full resize-y bg-transparent py-4 pl-12 pr-3.5 text-[15px] outline-none"
            />
          </div>
          <div className="pt-2">
            <button
              onClick={sending ? undefined : send}
              className="flex h-[50px] w-full items-center justify-center gap-2 rounded-[14px] bg-accent text-[15px] font-bold"
            >
              {sending ? <Spinner size={20} color="#fff" /> : <Icon name="send" size={18} />}
              Send Notification
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
