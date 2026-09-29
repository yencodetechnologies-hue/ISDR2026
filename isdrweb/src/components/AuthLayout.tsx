import { asset } from "@/lib/api";
import { Icon } from "./ui";

/** Split-screen layout for the sign-in pages: conference branding on the left, the form on the right. */
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid min-h-screen bg-bg lg:grid-cols-2">
      <div className="relative hidden overflow-hidden border-r border-line bg-gradient-to-br from-[#021B4D] via-[#0B1739] to-bg lg:flex lg:flex-col">
        <div className="absolute -left-24 top-1/3 h-96 w-96 rounded-full bg-accent/25 blur-3xl" />
        <div className="absolute -right-24 bottom-0 h-80 w-80 rounded-full bg-[#26D6FE]/15 blur-3xl" />
        <div className="relative flex flex-1 flex-col p-12">
          <div className="flex items-center gap-3">
            <img src={asset("ISDR 2026 Logo.png")} alt="" className="h-12 w-12 object-contain" />
            <div>
              <div className="text-lg font-extrabold">
                ISDR <span className="text-[#60A5FA]">2026</span>
              </div>
              <div className="text-xs text-white/60">Indian Division • IADR</div>
            </div>
          </div>
          <div className="my-auto max-w-lg py-12">
            <div className="eyebrow text-[#93C5FD]">36th ISDR International Conference</div>
            <h1 className="mt-4 text-4xl font-extrabold leading-tight tracking-tight xl:text-5xl">
              Translational Dental Research: <span className="text-[#60A5FA]">Bridging Science and Care</span>
            </h1>
            <div className="mt-8 space-y-3 text-sm text-white/75">
              {[
                ["event_note", "Full conference schedule, sessions and speakers"],
                ["qr_code_2", "Your QR pass, inclusions and certificate"],
                ["forum", "Live Q&A, polls and session ratings"],
              ].map(([icon, text]) => (
                <div key={text} className="flex items-center gap-3">
                  <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-white/10">
                    <Icon name={icon} size={18} color="#93C5FD" />
                  </span>
                  {text}
                </div>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-1.5 text-xs text-white/50">
            <Icon name="location_on" size={15} />
            Sree Balaji Dental College &amp; Hospital, BIHER, Chennai
          </div>
        </div>
      </div>
      <div className="flex items-center justify-center px-4 py-10 sm:px-8">
        <div className="w-full max-w-[400px]">
          <div className="mb-8 flex justify-center lg:hidden">
            <img src={asset("ISDR 2026 Logo.png")} alt="ISDR 2026" className="h-20 object-contain" />
          </div>
          {children}
        </div>
      </div>
    </div>
  );
}
