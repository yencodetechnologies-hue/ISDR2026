/* eslint-disable @typescript-eslint/no-explicit-any */
import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AppBar, Empty, ErrorState, Icon, Loading, Page } from "@/components/ui";
import { AppSpinner } from "@/components/app/AppControls";
import { get } from "@/lib/api";
import { idOf } from "@/lib/format";
import { useAppLayout } from "@/lib/appLayout";

/** Read-only pre-conference courses. */
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

function Hero({ count }: { count?: number }) {
  return (
    <div className="relative overflow-hidden rounded-2xl border border-[#6366F1]/35 bg-gradient-to-br from-[#312E81] via-[#1E1B4B] to-[#14141F] p-5 sm:p-7">
      <div className="absolute -right-10 -top-12 h-40 w-40 rounded-full bg-[#6366F1]/40 blur-2xl" />
      <div className="relative">
        <div className="text-[11px] font-bold tracking-[0.18em] text-[#C7D2FE]">ISDR 2026</div>
        <h2 className="mt-1 max-w-md font-outfit text-[26px] font-extrabold leading-[1.05] sm:text-[34px]">
          Pre Conference
          <br />
          Courses
        </h2>
        {count != null && (
          <div className="mt-3 flex flex-wrap items-center gap-2 text-[13px] font-semibold text-white/80">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-2.5 py-1">
              <Icon name="school" size={15} color="#C7D2FE" />
              {count} {count === 1 ? "course" : "courses"}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}

function CourseCard({ row }: { row: any }) {
  return (
    <article className="overflow-hidden rounded-[18px] border border-white/10 bg-[#14141F]">
      <div className="flex">
        <div className="w-1 shrink-0 bg-gradient-to-b from-[#A5B4FC] to-[#6366F1]" />
        <div className="min-w-0 flex-1 p-4">
          <div className="flex items-center gap-2">
            <span className="rounded-full bg-[#6366F1]/20 px-2.5 py-1 text-[11px] font-extrabold tracking-wide text-[#C7D2FE]">
              S NO {row.serialNo}
            </span>
            <span className="ml-auto inline-flex items-center gap-1 text-[12px] font-bold text-[#93C5FD]">
              <Icon name="calendar_today" size={13} color="#93C5FD" />
              {row.date}
            </span>
          </div>
          <h3 className="mt-3 font-outfit text-[15px] font-bold leading-snug text-white">{row.course}</h3>
          <div className="mt-3 flex items-start gap-1.5 rounded-xl bg-[#0A0A12] px-3 py-2.5 text-[12.5px] leading-snug text-white/75">
            <Icon name="location_on" size={16} color="#A5B4FC" />
            <span>{row.venue}</span>
          </div>
        </div>
      </div>
    </article>
  );
}

function ViewPdfButton() {
  const navigate = useNavigate();
  return (
    <button
      onClick={() => navigate("/participant/preconference/pdf")}
      className="mt-4 flex h-[50px] w-full items-center justify-center gap-2 rounded-[14px] bg-[#6366F1] text-[15px] font-bold text-white"
    >
      <Icon name="picture_as_pdf" size={20} />
      View PDF
    </button>
  );
}

function CourseList({ list }: { list: any[] }) {
  return (
    <div className="grid gap-3 lg:grid-cols-2">
      {list.map((row) => (
        <CourseCard key={idOf(row)} row={row} />
      ))}
    </div>
  );
}

function PreconferenceWeb() {
  const { list, error, load } = useCourses();
  return (
    <Page title="Preconference" subtitle="PRE CONFERENCE COURSES · ISDR 2026" width={1100}>
      <Hero count={list?.length} />
      <div className="mt-5">
        {error ? (
          <ErrorState message={error} onRetry={load} />
        ) : !list ? (
          <Loading />
        ) : list.length === 0 ? (
          <Empty icon="school" title="No pre-conference courses yet" />
        ) : (
          <CourseList list={list} />
        )}
        {list && <ViewPdfButton />}
      </div>
    </Page>
  );
}

function PreconferenceApp() {
  const { list, error, load } = useCourses();
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Preconference" outfit />
      {list === null && !error ? (
        <AppSpinner />
      ) : (
        <div className="space-y-3 px-4 pb-8 pt-2">
          <Hero count={list?.length} />
          {error || !list || list.length === 0 ? (
            <div className="flex flex-col items-center py-16 text-center">
              <Icon name={error ? "error_outline" : "school"} size={44} color="rgba(156,163,175,0.7)" />
              <div className="mt-2.5 font-inter text-[13.5px] text-muted">
                {error ?? "No pre-conference courses yet"}
              </div>
              {error && (
                <button onClick={load} className="mt-3 text-sm font-semibold text-[#60A5FA]">
                  Try again
                </button>
              )}
            </div>
          ) : (
            list.map((row) => <CourseCard key={idOf(row)} row={row} />)
          )}
          {list && <ViewPdfButton />}
        </div>
      )}
    </div>
  );
}
