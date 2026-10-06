/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Icon } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get } from "@/lib/api";
import { groupExhibitors, stallCode } from "@/lib/exhibitors";
import { idOf } from "@/lib/format";

/**
 * Participant exhibitors phone screen matching participant_exhibitors_page.dart:
 * photo, shop name, category, and location.
 */
export default function ParticipantExhibitorsApp() {
  const [list, setList] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await get("/exhibitors");
    if (res.success) {
      setError(null);
      setList(res.exhibitors ?? []);
    } else {
      setError(res.error || "Could not load exhibitors");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Exhibitors" outfit />
      {list === null ? (
        <AppSpinner />
      ) : (
        <div className="px-4 pb-8 pt-4">
          {error || list.length === 0 ? (
            <div className="flex flex-col items-center py-20 text-center">
              <Icon
                name={error ? "error_outline" : "storefront"}
                size={44}
                color="rgba(156,163,175,0.7)"
              />
              <div className="mt-2.5 font-inter text-[13.5px] text-muted">
                {error ?? "No exhibitors yet"}
              </div>
            </div>
          ) : (
            <div className="space-y-5">
              {groupExhibitors(list).map((group) => (
                <section key={group.title}>
                  <div className="mb-2 flex items-center gap-2">
                    <div className="font-outfit text-[13px] font-bold uppercase tracking-wide text-muted">
                      {group.title}
                    </div>
                    <span className="text-[11px] text-muted">{group.items.length}</span>
                  </div>
                  <div className="space-y-3">
                    {group.items.map((e) => {
                      const photo = String(e.photo ?? "").trim();
                      const location = stallCode(e.location);
                      return (
                        <div
                          key={idOf(e)}
                          className="flex items-center rounded-[14px] border border-white/10 bg-[#14141F] p-3 shadow-sm"
                        >
                          <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-[12px] border-[1.5px] border-[#10B981]/40 bg-[#10B981]/15">
                            {photo ? (
                              <img
                                src={photo}
                                alt=""
                                className="h-full w-full object-cover"
                                onError={(evt) => {
                                  (evt.currentTarget as HTMLElement).style.display = "none";
                                }}
                              />
                            ) : (
                              <Icon name="storefront" size={26} color="#10B981" />
                            )}
                          </div>
                          <div className="ml-3 min-w-0 flex-1">
                            <div className="font-outfit text-[15.5px] font-extrabold text-white">
                              {e.shopName}
                            </div>
                            {e.category && (
                              <div className="mt-0.5 font-inter text-[12.5px] font-semibold text-[#34D399]">
                                {e.category}
                              </div>
                            )}
                            {location && (
                              <div className="mt-1 flex items-start gap-1 font-inter text-[12px] text-white/60">
                                <span className="mt-0.5 shrink-0">
                                  <Icon name="location_on" size={14} color="rgba(255,255,255,0.55)" />
                                </span>
                                <span className="min-w-0 flex-1 truncate">{location}</span>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </section>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
