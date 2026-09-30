/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { Empty, ErrorState, Icon, Loading, Page } from "@/components/ui";
import { get } from "@/lib/api";
import { idOf } from "@/lib/format";

import { useAppLayout } from "@/lib/appLayout";
import ParticipantExhibitorsApp from "./ParticipantExhibitorsApp";

/** Read-only exhibitor list: photo, shop name, category, location. */
export default function ParticipantExhibitors() {
  return useAppLayout() ? <ParticipantExhibitorsApp /> : <ParticipantExhibitorsWeb />;
}

function ParticipantExhibitorsWeb() {
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
    <Page title="Exhibitors" subtitle="Visit the trade stalls at the venue">
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !list ? (
        <Loading />
      ) : list.length === 0 ? (
        <Empty icon="storefront" title="No exhibitors yet" />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {list.map((e) => (
            <div key={idOf(e)} className="card card-hover overflow-hidden">
              <div className="flex h-36 items-center justify-center overflow-hidden bg-field">
                {e.photo ? (
                  <img src={e.photo} alt="" className="h-full w-full object-cover" />
                ) : (
                  <Icon name="storefront" size={40} color="#3B82F6" />
                )}
              </div>
              <div className="min-w-0 p-4">
                <div className="truncate font-semibold">{e.shopName}</div>
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
