/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { Empty, ErrorState, Icon, Loading, Page } from "@/components/ui";
import { get } from "@/lib/api";
import { idOf } from "@/lib/format";

/** Read-only exhibitor list: photo, shop name, category, location. */
export default function ParticipantExhibitors() {
  const [list, setList] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    const res = await get("/exhibitors");
    if (!res.success) return setError(res.error || "Could not load exhibitors");
    setError(null);
    setList(res.exhibitors ?? []);
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  return (
    <Page title="Exhibitors">
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !list ? (
        <Loading />
      ) : list.length === 0 ? (
        <Empty icon="storefront" title="No exhibitors yet" />
      ) : (
        <div className="grid gap-2.5 sm:grid-cols-2">
          {list.map((e) => (
            <div key={idOf(e)} className="card flex items-center gap-3 p-3">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-field">
                {e.photo ? <img src={e.photo} alt="" className="h-full w-full object-cover" /> : <Icon name="storefront" color="#3B82F6" />}
              </div>
              <div className="min-w-0">
                <div className="font-bold">{e.shopName}</div>
                {e.category && <div className="text-sm text-[#60A5FA]">{e.category}</div>}
                {e.location && (
                  <div className="mt-0.5 flex items-center gap-1 text-xs text-muted">
                    <Icon name="location_on" size={14} />
                    {e.location}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </Page>
  );
}
