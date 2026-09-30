import { AppBar, Icon } from "@/components/ui";

const RESORTS: { name: string; phone: string }[] = [
  { name: "Ideal Beach Resort", phone: "044-24495161" },
  { name: "Coral Beach Resort", phone: "9444333333" },
  { name: "Hotel Mahabs", phone: "044-27442643" },
  { name: "Golden Sun Beach Resort", phone: "7845732245" },
  { name: "Hotel Mamallaa Heritage", phone: "044-46270563" },
  { name: "Landmark Pallavaa Beach Resort", phone: "8939944400" },
  { name: "Four Points by Sheraton", phone: "044-71513636" },
  { name: "Chariot Beach Resort", phone: "9444992727" },
  { name: "Radisson Blu Resort Temple Bay", phone: "8062210102" },
  { name: "Welcome Hotel by ITC Hotels", phone: "044-26421534" },
  { name: "Grande Bay Resort & Spa", phone: "044-48133853" },
  { name: "Shelter Beach Resort", phone: "9840333114" },
  { name: "La Villa Beach Paradise", phone: "9840032297" },
  { name: "IZI Beach Stay", phone: "9940130775" },
  { name: "Bay Inn", phone: "8754413030" },
  { name: "Sea Breeze", phone: "9962047297" },
];

const tel = (phone: string) => `tel:${phone.replace(/[^0-9+]/g, "")}`;

function CallButton({ phone }: { phone: string }) {
  return (
    <a
      href={tel(phone)}
      className="inline-flex shrink-0 items-center gap-2 rounded-[10px] bg-[#2563EB] px-3.5 py-2 text-xs font-bold"
    >
      <Icon name="phone" size={16} />
      {phone}
    </a>
  );
}

/** Accommodation at phone width — the app's AccommodationPage. */
export default function AccommodationApp() {
  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Accommodation" outfit />
      <div className="px-4 pb-7 pt-3.5">
        {/* In-house accommodation */}
        <div className="rounded-[18px] bg-gradient-to-br from-[#0F172A] to-[#1E3A8A] p-5 shadow-[0_5px_12px_rgba(30,58,138,0.25)]">
          <div className="flex items-center">
            <span className="rounded-md border border-[#FBBF24]/35 bg-[#FBBF24]/15 px-2.5 py-1 text-[10px] font-extrabold tracking-[1.1px] text-[#FBBF24]">
              VENUE STAY
            </span>
            <span className="ml-auto">
              <Icon name="castle" size={22} color="#FBBF24" />
            </span>
          </div>
          <div className="mt-3 font-outfit text-[21px] font-bold">In-House Accommodation</div>
          <div className="mt-1 flex items-center gap-1 text-xs font-medium text-[#93C5FD]">
            <Icon name="place" size={14} color="#93C5FD" />
            Kaldan Samudhra Palace Resort, Mahabalipuram
          </div>
          <div className="mt-4 grid grid-cols-2 gap-2.5">
            {[
              { label: "FULL ROOM", color: "#FBBF24", price: "₹20,000/-", unit: "per day" },
              { label: "SHARED ROOM", color: "#67E8F9", price: "₹10,000/-", unit: "twin sharing / day" },
            ].map((r) => (
              <div key={r.label} className="rounded-xl border border-white/15 bg-white/[0.08] p-3">
                <div className="text-[10px] font-bold tracking-[0.5px]" style={{ color: r.color }}>
                  {r.label}
                </div>
                <div className="mt-1 font-outfit text-[17px] font-extrabold">{r.price}</div>
                <div className="text-[10.5px] text-white/70">{r.unit}</div>
              </div>
            ))}
          </div>
          <div className="mt-3.5 text-[11.5px] leading-[1.45] text-white/85">
            The registered delegates are requested to contact for in-house accommodation @ Kaldan Samudhra Palace.
          </div>
        </div>

        {/* Payment notice + contacts */}
        <div className="mt-3.5 rounded-2xl border-[1.2px] border-[#F59E0B]/30 bg-[#F59E0B]/10 p-4 shadow-[0_2px_8px_rgba(217,119,6,0.06)]">
          <div className="flex items-start">
            <Icon name="warning" size={24} color="#D97706" />
            <div className="ml-2.5 flex-1">
              <div className="font-outfit text-[13px] font-extrabold tracking-[0.5px] text-[#FCD34D]">
                IMPORTANT PAYMENT NOTICE
              </div>
              <div className="mt-1 text-xs font-semibold leading-[1.45] text-[#FCD34D]">
                Please do not make accommodation payments to the registration QR code or conference bank account.
              </div>
            </div>
          </div>
          <div className="my-3 h-px bg-[#F59E0B]/30" />
          <div className="flex items-center rounded-xl border border-[#FCD34D] bg-card p-3">
            <span className="rounded-lg bg-[#F59E0B]/15 p-2">
              <Icon name="support_agent" size={20} color="#FBBF24" />
            </span>
            <div className="ml-3 min-w-0 flex-1">
              <div className="font-outfit text-sm font-bold">Ms. Radhika</div>
              <div className="text-[11px] text-muted">Accommodation &amp; Details</div>
            </div>
            <CallButton phone="9940211202" />
          </div>
          <div className="mt-2.5 flex items-center rounded-xl border-[1.5px] border-[#F59E0B] bg-[#1F1C18] p-3 shadow-[0_2px_8px_rgba(245,158,11,0.15)]">
            <span className="rounded-lg bg-[#F59E0B]/20 p-2">
              <Icon name="phone_in_talk" size={20} color="#FBBF24" />
            </span>
            <div className="ml-3 min-w-0 flex-1 font-outfit text-sm font-bold">Dr. Pugazendhi</div>
            <CallButton phone="9841063742" />
          </div>
        </div>

        {/* Check-in / check-out */}
        <div className="mt-3.5 flex items-center rounded-2xl border border-white/10 bg-card p-4">
          <div className="flex flex-1 items-center">
            <span className="rounded-[10px] bg-[#3B82F6]/15 p-2">
              <Icon name="login" size={20} color="#2563EB" />
            </span>
            <div className="ml-2.5">
              <div className="text-[10px] font-bold text-[#2563EB]">CHECK-IN</div>
              <div className="font-outfit text-sm font-bold">12:00 Noon</div>
              <div className="text-[11px] text-muted">9 October 2026</div>
            </div>
          </div>
          <div className="mr-3 h-9 w-px bg-white/10" />
          <div className="flex flex-1 items-center">
            <span className="rounded-[10px] bg-[#EF4444]/15 p-2">
              <Icon name="logout" size={20} color="#DC2626" />
            </span>
            <div className="ml-2.5">
              <div className="text-[10px] font-bold text-[#DC2626]">CHECK-OUT</div>
              <div className="font-outfit text-sm font-bold">12:00 Noon</div>
              <div className="text-[11px] text-muted">11 October 2026</div>
            </div>
          </div>
        </div>

        {/* Nearby resorts */}
        <div className="mt-5 text-[11.5px] font-bold tracking-[0.6px] text-muted">
          OTHER NEARBY RESORTS &amp; HOTELS
        </div>
        <div className="mt-2.5 overflow-hidden rounded-[18px] border border-white/10 bg-card">
          {RESORTS.map((r, i) => (
            <div key={r.name}>
              <div className="flex items-center px-4 py-2">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] border border-white/10 bg-field">
                  <Icon name="hotel" outline size={18} color="#2563EB" />
                </span>
                <div className="ml-4 min-w-0 flex-1">
                  <div className="font-outfit text-sm font-semibold">{r.name}</div>
                  <div className="text-xs font-medium text-muted">{r.phone}</div>
                </div>
                <a
                  href={tel(r.phone)}
                  aria-label={`Call ${r.name}`}
                  className="flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
                >
                  <Icon name="phone_in_talk" size={20} color="#2563EB" />
                </a>
              </div>
              {i < RESORTS.length - 1 && <div className="mx-4 h-px bg-field" />}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
