/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { AppBar, Empty, ErrorState, Loading, Page } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get } from "@/lib/api";
import { idOf } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";

const TITLE = "PRE CONFERENCE COURSES- ISDR 2026";

/** Read-only pre-conference course table. */
export default function ParticipantPreconference() {
  return useAppLayout() ? <PreconferenceApp /> : <PreconferenceWeb />;
}

function useCourses() {
  const [list, setList] = useState<any[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    const res = await get("/preconference");
    if (res.success) {
      setError(null);
      setList(res.courses ?? []);
    } else {
      setError(res.error || "Could not load courses");
      setList([]);
    }
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  return { list, error, load };
}

function CourseTable({ list }: { list: any[] }) {
  return (
    <div className="overflow-x-auto">
      <table className="data-table min-w-[720px]">
        <thead>
          <tr>
            <th>S NO</th>
            <th>DATE</th>
            <th>PRE CONFERENCE COURSE</th>
            <th>VENUE</th>
          </tr>
        </thead>
        <tbody>
          {list.map((row) => (
            <tr key={idOf(row)}>
              <td className="whitespace-nowrap font-semibold">{row.serialNo}</td>
              <td className="whitespace-nowrap">{row.date}</td>
              <td className="min-w-[280px]">{row.course}</td>
              <td className="min-w-[180px]">{row.venue}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PreconferenceWeb() {
  const { list, error, load } = useCourses();
  return (
    <Page title={TITLE}>
      {error ? (
        <ErrorState message={error} onRetry={load} />
      ) : !list ? (
        <Loading />
      ) : list.length === 0 ? (
        <Empty icon="school" title="No pre-conference courses yet" />
      ) : (
        <div className="card overflow-hidden">
          <CourseTable list={list} />
        </div>
      )}
    </Page>
  );
}

function PreconferenceApp() {
  const { list, error, load } = useCourses();
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title={TITLE} outfit />
      {list === null && !error ? (
        <AppSpinner />
      ) : (
        <div className="px-3 pb-8 pt-3">
          {error || !list || list.length === 0 ? (
            <div className="flex flex-col items-center py-20 text-center">
              <div className="font-inter text-[13.5px] text-muted">
                {error ?? "No pre-conference courses yet"}
              </div>
              {error && (
                <button onClick={load} className="mt-3 text-sm font-semibold text-[#60A5FA]">
                  Try again
                </button>
              )}
            </div>
          ) : (
            <div className="overflow-hidden rounded-2xl border border-line bg-card">
              <CourseTable list={list} />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
