import { useState } from "react";
import { Icon, Page } from "@/components/ui";
import { asset } from "@/lib/api";
import { useAppLayout } from "@/lib/appLayout";
import AccommodationApp from "./AccommodationApp";
import { CommitteeApp, AboutIsdrApp, StudentConferenceApp } from "./ParticipantInfoApp";

type Person = { name: string; role: string; img?: string; lines?: string[] };

function PersonCard({ p }: { p: Person }) {
  return (
    <div className="card card-hover flex items-center gap-4 p-4">
      {p.img ? (
        <img
          src={asset(p.img)}
          alt=""
          className="h-[72px] w-[72px] shrink-0 rounded-lg bg-field object-cover object-top"
        />
      ) : (
        <div className="flex h-[72px] w-[72px] shrink-0 items-center justify-center rounded-lg bg-field">
          <Icon name="person" size={30} color="#6B7280" />
        </div>
      )}
      <div className="min-w-0">
        <div className="font-semibold">{p.name}</div>
        <div className="text-sm font-semibold text-[#60A5FA]">{p.role}</div>
        {p.lines?.map((l) => (
          <div key={l} className="mt-0.5 whitespace-pre-line text-xs text-muted">
            {l}
          </div>
        ))}
      </div>
    </div>
  );
}

function Accordion({
  title,
  subtitle,
  items,
  numbered = true,
}: {
  title: string;
  subtitle?: string;
  items: string[];
  numbered?: boolean;
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className="card overflow-hidden">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center gap-3 px-5 py-4 text-left transition hover:bg-white/[0.03]"
      >
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent/15">
          <Icon name="groups" size={20} color="#60A5FA" />
        </div>
        <div className="flex-1">
          <div className="font-semibold">{title}</div>
          <div className="text-xs text-muted">{subtitle ?? `${items.length} Members`}</div>
        </div>
        <Icon name={open ? "expand_less" : "expand_more"} color="#9CA3AF" />
      </button>
      {open && (
        <div className="grid gap-2 border-t border-line px-5 py-4 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((n, i) => (
            <div key={n} className="flex items-center gap-2 text-sm">
              {numbered && <span className="w-6 text-right text-xs font-bold text-muted">{i + 1}.</span>}
              {n}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

const Header = ({ children }: { children: React.ReactNode }) => (
  <div className="mb-4 mt-10 flex items-center gap-3">
    <h2 className="text-sm font-semibold uppercase tracking-[0.1em] text-white/85">{children}</h2>
    <div className="h-px flex-1 bg-line" />
  </div>
);

/* ------------------------------------------------------------------ */
/* Organising committee                                                */
/* ------------------------------------------------------------------ */

const LEADS: Person[] = [
  { name: "DR. S. JAGATHRAKSHAKAN", role: "Founder Chairman", img: "DR.-S.-JAGATHRAKSHAKAN.webp" },
  { name: "DR. J. SRI NISHA", role: "Conference Organising Chairman", img: "DR-J.-SRI-NISHA.webp" },
  { name: "ER. N. ELAMARAN", role: "Managing Director", img: "ER.-N.-ELAMARAN.webp" },
  { name: "DR. S. M. BALAJI", role: "Conference Executive Advisor", img: "DR.-S.-M.-BALAJI-2.webp" },
  { name: "DR. MAHESH VERMA", role: "Conference Secretary", img: "DR.-MAHESH-VERMA-2.webp" },
  { name: "DR. S. BHUMINATHAN", role: "Organising Secretary", img: "DR.-S.-BHUMINATHAN.webp" },
  { name: "DR. M.S. KANNAN", role: "Organising Co-Chairman", img: "DR.-M.S.-KANNAN.webp" },
  { name: "DR. K. GNANA SHANMUGHAM", role: "Chairman, Scientific Committee", img: "DR.-K.-GNANA-SHANMUGHAM.webp" },
  { name: "DR. RAGAVENDRA JAYESH", role: "Conference Advisor", img: "DR.-RAGAVENDRA-JAYESH-1.webp" },
  { name: "DR. PONNUDURAI ARANGANNAL", role: "Conference Advisor", img: "DR.-PONNUDURAI-ARANGANNAL-1.webp" },
  {
    name: "DR. BADRI THIRUVENKATACHARI",
    role: "Co-Chairman, Scientific Committee",
    img: "DR.-BADRI-THIRUVENKATACHARI-1.webp",
  },
  {
    name: "DR. S. KISHORE KUMAR",
    role: "Joint Secretary",
    img: "DR.-S.-KISHORE-KUMAR-Organising-Committee.jpg-1.webp",
  },
  { name: "DR. N. ARAVINDHA BABU", role: "Treasurer", img: "DR.N.-ARAVINDHA-BABU.webp" },
  { name: "DR. A. VENKATESH", role: "Convener, Preconference Courses", img: "DR.-A.-VENKATESH.webp" },
  { name: "DR. NALINI ASWATH", role: "Convener Pre Conference Course Committee", img: "DR.-NALINI-ASWATH-1.webp" },
  { name: "DR. M. N. PRABHU", role: "Convener, International Relations", img: "DR.-M.-N-PRABHU.webp" },
  { name: "DR. VIJAY EBENEZER", role: "Convener Banquet and Cultural Night", img: "DR.-VIJAY-EBENEZER-1.webp" },
  { name: "DR. ANITHA BALAJI", role: "Convener Reception Committee", img: "DR.-ANITHA-BALAJI-2.jpg.webp" },
  { name: "DR. M. ANITA", role: "Convener Souvenir Committee", img: "DR.-M.-ANITA-1.webp" },
  { name: "DR. MANIKANDAN", role: "Convener Trade", img: "DR.-MANIKANDAN-1.webp" },
  { name: "DR. SREE DEVI V", role: "Convener Hospitality Committee", img: "DR.-SREE-DEVI-V-1.webp" },
  { name: "DR. GOLD PEARLIN MARY", role: "Co-Convener Student Conference", img: "DR.-GOLD-PEARLIN-MARY-1.webp" },
  { name: "DR. N. GEETHA PRIYA", role: "Convener Awards Committee", img: "DR.-N.-GEETHA-PRIYA-1.webp" },
];

const SUB_COMMITTEES: { title: string; members: string[] }[] = [
  {
    title: "Scientific Committee",
    members: [
      "Dr. Gnana Shanmugham",
      "Dr. Thailavathy",
      "Dr. Jayasrikrupaa",
      "Dr. Balavenkata Bharathi Chaturvedula",
      "Dr. Ram Kiran K",
      "Dr. Shalini Krishnan",
      "Dr. Amutha M.V. Soorya",
      "Dr. Badri Thiruvenkatachari",
      "Dr. Leena Shankari",
      "Dr. Sadhana K.R",
      "Dr. S. Priya Dharshini",
      "Dr. R. Savitha Lakshmi",
    ],
  },
  {
    title: "PCC Committee",
    members: [
      "Dr. Nalini Aswath",
      "Dr. V. Prakash",
      "Dr. Swarna Priya",
      "Dr. Janani Vinodini N.C",
      "Dr. Revathi",
      "Dr. Jesima J",
      "Dr. Jeevarathan J",
      "Dr. J. Bhuvaneshwari",
      "Dr. Ramya Chellammal M",
      "Dr. R. Aishwarya Dhevi G.R",
      "Dr. Madhumitha M",
    ],
  },
  {
    title: "Registration Committee",
    members: [
      "Dr. Venkatesh A",
      "Dr. Ramyaa",
      "Dr. Thulasiram",
      "Dr. Hari prasanna",
      "Dr. Vanitha",
      "Dr. Sajid Hussain",
      "Dr. Preethi",
      "Dr. Ramesh K",
      "Dr. Tharun",
    ],
  },
  { title: "Reception & Hospitality Committee", members: ["Dr. Anitha Balaji", "Dr. Sree Devi V", "Dr. Tamil selvi"] },
  {
    title: "Student Committee",
    members: ["Dr. Gold Pearlin Mary", "Dr. E. Tulasi Ram", "Dr. Geeta Priya", "Dr. D. Ramya"],
  },
  {
    title: "Banquet and Cultural Night",
    members: ["Dr. Vijay Ebenezer", "Dr. Balakrishnan", "Dr. Saravana Kumar", "Dr. Prakash"],
  },
  { title: "Awards Committee", members: ["Dr. N. Geetha priya", "Dr. Seetha lakshmi", "Dr. Amudha", "Dr. Mathangi"] },
  { title: "Website & Media", members: ["Dr. Janani Balachandran", "Dr. Abarna J"] },
  {
    title: "Student Conference",
    members: ["Dr. Sumathi Jones", "Dr. N. Gold Pearlin Mary", "Dr. Malathy", "Dr. Kavya", "Dr. Durga Devi"],
  },
  {
    title: "Publications & Souvenir",
    members: [
      "Dr. M. Anita",
      "Dr. Sankar Narayanan R",
      "Dr. Rajesh E",
      "Dr. K.R. Don",
      "Dr. N. Anitha",
      "Dr. C. Ramya",
      "Dr. Charumathy",
      "Dr. Suganya",
    ],
  },
  {
    title: "Travel & Accommodation",
    members: ["Dr. T. Puhazhendi", "Dr. Rajasekar K.V", "Dr. Gowri Shankar", "Dr. Abirami", "Dr. Aravind Vishnu"],
  },
  {
    title: "Trade Committee",
    members: [
      "Dr. Manigandan",
      "Dr. V. Balakumar",
      "Dr. Vikram",
      "Dr. Mansoor",
      "Dr. A. Karthick",
      "Dr. Rajith Varma",
      "Dr. Nilofer Farzana",
    ],
  },
  {
    title: "Technical Committee",
    members: ["Dr. Siva Kumar", "Dr. Savitha", "Dr. Rajasekar", "Dr. Manoj", "Dr. Sadhana", "Mr. Vijay"],
  },
];

const CHAIR_MESSAGE =
  "It gives me immense pleasure to extend a warm and cordial welcome to all the distinguished delegates, eminent researchers, clinicians, academicians, students participating in the 36th ISDR International Conference. This conference represents a significant milestone in our collective pursuit of excellence in dental, oral, and craniofacial research. It provides a unique platform for the exchange of scientific knowledge, innovative ideas, and transformative research that will shape the future of oral healthcare. Bringing together experts from diverse disciplines fosters collaboration, inspires innovation, and strengthens our commitment to evidence-based practice and translational research. At Bharath Institute of Higher Education and Research (BIHER), we are committed to nurturing a culture of academic excellence, scientific inquiry, and innovation. Hosting the 36th ISDR International Conference reflects our dedication to advancing research that addresses contemporary healthcare challenges and improves the quality of life of people across the globe. The theme of this conference, “Translational Dental Research: Bridging Science and Care,” aptly emphasizes the importance of transforming scientific discoveries into meaningful clinical applications. I am confident that the scientific deliberations, keynote lectures, workshops, and interactive sessions will stimulate new ideas, encourage interdisciplinary collaborations, and inspire future research endeavors. Once again it gives me immense pleasure to welcome you all to this spectacular scientific extravaganza.";

export function Committee() {
  return useAppLayout() ? <CommitteeApp /> : <CommitteeWeb />;
}

function CommitteeWeb() {
  const [msgOpen, setMsgOpen] = useState(false);
  return (
    <Page title="Organising Committee" subtitle="36th ISDR International Conference 2026">
      <div className="card p-6">
        <div className="flex items-center gap-3">
          <img
            src={asset("DR-J.-SRI-NISHA.webp")}
            alt=""
            className="h-16 w-16 rounded-full bg-field object-cover object-top"
          />
          <div>
            <div className="text-xs font-bold tracking-wider text-muted">From the Organising Chairperson</div>
            <div className="font-bold">DR. J. SRI NISHA</div>
            <div className="text-xs text-[#60A5FA]">Organising Chairman - 36th ISDR</div>
          </div>
        </div>
        <div className="mt-3 text-xs font-bold tracking-wider text-white/70">DEAR COLLEAGUES,</div>
        <p className={`mt-1.5 text-sm leading-relaxed text-white/85 ${msgOpen ? "" : "line-clamp-4"}`}>
          {CHAIR_MESSAGE}
        </p>
        <button onClick={() => setMsgOpen((o) => !o)} className="mt-1 text-xs font-semibold text-accent">
          {msgOpen ? "Show less" : "Read more"}
        </button>
        {msgOpen && (
          <div className="mt-3 border-t border-line pt-3 text-sm">
            <div className="font-bold">DR. J. SRI NISHA</div>
            <div className="whitespace-pre-line text-xs text-muted">
              {
                "Vice President, BIHER\nChairperson - Sree Balaji Group of Institutions\nOrganising Chairman - 36th ISDR"
              }
            </div>
          </div>
        )}
      </div>
      <Header>ORGANISING LEADERSHIP &amp; CONVENERS</Header>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {LEADS.map((p) => (
          <PersonCard key={p.name + p.role} p={p} />
        ))}
      </div>
      <Header>COMMITTEES &amp; SUB-TEAMS</Header>
      <div className="space-y-2.5">
        {SUB_COMMITTEES.map((c) => (
          <Accordion key={c.title} title={c.title} items={c.members} />
        ))}
      </div>
    </Page>
  );
}

/* ------------------------------------------------------------------ */
/* About ISDR                                                          */
/* ------------------------------------------------------------------ */

const OFFICE_BEARERS: Person[] = [
  {
    name: "DR. RITU DUGGAL",
    role: "President",
    img: "DR.-RITU-DUGGAL.webp",
    lines: ["Chief & Professor, Department of Orthodontics, CDER, AIIMS, New Delhi"],
  },
  {
    name: "DR. MAHESH VERMA",
    role: "President-Elect",
    img: "DR.-MAHESH-VERMA.webp",
    lines: ["Vice Chancellor, Guru Gobind Singh, Indraprastha University, New Delhi"],
  },
  {
    name: "DR. VIJAY MATHUR",
    role: "Vice President",
    img: "DR.-VIJAY-MATHUR.webp",
    lines: ["Professor & Head, Division of Pedodontics & Preventive Dentistry, CDER, AIIMS, New Delhi"],
  },
  {
    name: "DR. DEEPAK CHANDRA",
    role: "Vice President",
    img: "DR.-DEEPAK-CHANDRA.webp",
    lines: [
      "Professor & Head, Department of Orthodontics & Dentofacial Orthopedics, SRM Kattankulathur Dental College & Hospital, Chennai",
    ],
  },
  {
    name: "DR. NAMITA SHANBHAG",
    role: "Vice President",
    img: "DR.-NAMITA-SHANBHAG.webp",
    lines: ["Associate Professor, Public Health Dentistry, Government Dental College & Research Institute, Bangalore"],
  },
  {
    name: "DR. S. M. BALAJI",
    role: "Secretary General, ISDR & Secretary, IADR Asia Pacific Region",
    img: "DR.-S.-M.-BALAJI.webp",
    lines: ["Director, Cranio-Maxillofacial Surgeon, Balaji Dental & Craniofacial Hospital, Chennai"],
  },
  {
    name: "DR. PREETHA BALAJI",
    role: "Joint Secretary",
    img: "DR.-PREETHA-BALAJI.webp",
    lines: ["Department of Oral & Maxillofacial Surgery, Balaji Dental & Craniofacial Hospital, Chennai"],
  },
  {
    name: "DR. ANIL KOHLI",
    role: "Editor-in-Chief – IJDR",
    img: "DR.-ANIL-KOHLI.webp",
    lines: ["Former President, DCI, New Delhi"],
  },
  {
    name: "DR. S. KISHORE KUMAR",
    role: "Treasurer, Joint Secretary",
    img: "DR.-S.-KISHORE-KUMAR.webp",
    lines: ["Vice Principal, Sree Balaji Dental College & Hospital, Chennai"],
  },
];

const EXECUTIVE_COUNCIL = [
  "Dr. P Rajesh",
  "Dr. S. Bhuminathan",
  "Dr. S. Balagopal",
  "Dr. Cynthia Sathiasekar",
  "Dr. S. Mahalaxmi",
  "Dr. P. S. Thaha",
  "Dr. Deenadayalan .P",
  "Dr. Jacob Raja",
  "Dr. N. Gopi Chander",
  "Dr. Harsh Priya",
  "Dr. Arpit Gupta",
  "Dr. Jaideep Mahendra",
  "Dr. N. Velmurugan",
  "Dr. Puneet Batra",
  "Dr. H. Thamizhchelvan",
  "Dr. Mahesh Chawda",
  "Dr. Deepika Mishra",
  "Dr. D. Gopalakrishnan",
  "Dr. Nitika Monga",
  "Dr. Shantanu Choudhari",
];

const ABOUT_TEXT = [
  "The Indian Society for Dental Research (ISDR) is India’s premier scientific organization dedicated to advancing dental, oral, and craniofacial research. As the Indian Division of the International Association for Dental, Oral and Craniofacial Research (IADR), ISDR has, since its establishment in 1986, remained committed to promoting excellence in scientific research, innovation, and evidence-based clinical practice.",
  "The Society traces its origins to the vision of Dr. M. Rahmatulla, who conceived the idea of establishing an Indian division of the IADR after attending the 64th IADR Annual Session in Dallas, Texas, USA, in March 1984. Following two years of dedicated efforts, the inaugural convention was held in July 1986 at Hotel Connemara, Madras (Chennai), where Dr. Rahmatulla was unanimously elected as the Founder President of the IADR Indian Division. Dr. J. G. Kannapan and Dr. P. K. Baskar also played instrumental roles in establishing the organization. Initially named the Indian Association for Dental Research, the organization was subsequently renamed the Indian Society for Dental Research (ISDR) on the recommendation of its parent body, while continuing as the official Indian Division of the IADR.",
  "Over nearly four decades, the ISDR Annual Conference has evolved into one of the country’s most prestigious scientific gatherings, attracting eminent national and international experts who present pioneering research, technological innovations, and advances in clinical practice. Through keynote lectures, scientific sessions, workshops, panel discussions, free paper presentations, and poster sessions, the conference fosters meaningful academic interactions, encourages collaborative research, and inspires the next generation of clinician-scientists.",
];

const CONF_TEXT = [
  "Hosted by Sree Balaji Dental College & Hospital, Bharath Institute of Higher Education and Research (BIHER), Chennai, marks another significant milestone in this remarkable journey. Bringing together distinguished scientists, clinicians, educators, industry leaders, and students from across the world.",
  "This theme highlights the critical importance of transforming laboratory discoveries into innovative clinical solutions that improve patient outcomes and advance oral healthcare. The conference aims to promote interdisciplinary collaboration and showcase cutting-edge developments in biomaterials, regenerative dentistry, artificial intelligence, precision dentistry, public health, digital technologies, and other emerging areas that are shaping the future of dental science and practice.",
];

export function AboutIsdr() {
  return useAppLayout() ? <AboutIsdrApp /> : <AboutIsdrWeb />;
}

function AboutIsdrWeb() {
  return (
    <Page title="About ISDR" subtitle="Indian Division of the IADR since 1986">
      <div className="grid gap-5 lg:grid-cols-5">
        <div className="card p-6 lg:col-span-3">
          <div className="flex items-center gap-4">
            <img src={asset("logo.png")} alt="ISDR" className="h-16 object-contain" />
            <div className="text-lg font-semibold">Indian Society for Dental Research</div>
          </div>
          {ABOUT_TEXT.map((t) => (
            <p key={t.slice(0, 20)} className="mt-3 text-sm leading-relaxed text-white/80">
              {t}
            </p>
          ))}
        </div>
        <div className="card self-start p-6 lg:col-span-2">
          <div className="text-lg font-extrabold">36th ISDR International Conference 2026</div>
          <div className="mt-2 rounded-xl bg-accent/10 p-3 text-center text-sm font-semibold italic text-[#93C5FD]">
            “Translational Dental Research: Bridging Science and Care”
          </div>
          {CONF_TEXT.map((t) => (
            <p key={t.slice(0, 20)} className="mt-2.5 text-sm leading-relaxed text-white/85">
              {t}
            </p>
          ))}
        </div>
      </div>
      <Header>ISDR Office Bearers</Header>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {OFFICE_BEARERS.map((p) => (
          <PersonCard key={p.name} p={p} />
        ))}
      </div>
      <Header>Executive Council</Header>
      <Accordion title="Executive Council" subtitle="20 Members • ISDR Indian Division" items={EXECUTIVE_COUNCIL} />
      <div className="card mt-3 flex items-center gap-3 p-3.5">
        <Icon name="language" color="#60A5FA" />
        <div>
          <div className="text-[11px] font-bold tracking-wider text-muted">WEBMASTER</div>
          <div className="font-semibold">Dr. Sri Ganesh</div>
        </div>
      </div>
    </Page>
  );
}

/* ------------------------------------------------------------------ */
/* Student conference                                                  */
/* ------------------------------------------------------------------ */

const KEYNOTES: Person[] = [
  {
    name: "DR MURUGABASKAR",
    role: "Research Scientist",
    img: "DR-MURUGABASKAR.webp",
    lines: ["Boston Children’s Hospital / Harvard Medical School"],
  },
  {
    name: "DR. PAVITHRA KRISHNASWAMI",
    role: "Senior Scientist",
    img: "DR.PAVITHRA KRISHNASWAMI.webp",
    lines: ["Translational Medicine Unit, Sanofi\nGreater Boston, Cambridge, Massachusetts, USA"],
  },
  {
    name: "DR. SYLVIA ANNABEL DASS",
    role: "Laboratory Manager",
    img: "DR. SYLVIA ANNABEL DASS.webp",
    lines: ["Allen Healthcare Products (M) Sdn. Bhd. Penang, Malaysia"],
  },
];

const PATRONS: Person[] = [
  {
    name: "DR. S. JAGATHRAKSHAKAN",
    role: "Founder Chairman",
    img: "DR.-S.-JAGATHRAKSHAKAN.webp",
    lines: ["Bharath Institute of Higher Education and Research", "Chief Patron – 36th ISDR"],
  },
  {
    name: "DR. J. SRI NISHA",
    role: "Vice President",
    img: "DR-J.-SRI-NISHA.webp",
    lines: [
      "Bharath Institute of Higher Education and Research\nChairperson – Sree Balaji Group of Institutions",
      "Organising Chairman – 36th ISDR",
    ],
  },
  {
    name: "ER. N. ELAMARAN",
    role: "Managing Director",
    img: "ER.-N.-ELAMARAN.webp",
    lines: ["Sree Balaji Group of Institutions", "Patron – 36th ISDR"],
  },
];

const CONF_COMMITTEE: Person[] = [
  { name: "DR. S. M. BALAJI", role: "Conference Executive Advisor", img: "DR.-S.-M.-BALAJI-2.webp" },
  { name: "DR. MAHESH VERMA", role: "Conference Secretary", img: "DR.-MAHESH-VERMA-2.webp" },
  { name: "DR. S. BHUMINATHAN", role: "Organising Secretary", img: "DR.-S.-BHUMINATHAN.webp" },
  { name: "DR. M. S. KANNAN", role: "Organising Co-Chairman", img: "DR.-M.S.-KANNAN.webp" },
  { name: "DR. K. GNANA SHANMUGHAM", role: "Chairman, Scientific Committee", img: "DR.-K.-GNANA-SHANMUGHAM.webp" },
];

const STUDENT_COMMITTEE: Person[] = [
  { name: "DR. SUMATHI JONES", role: "Convenor", img: "DR.-GOLD-PEARLIN-MARY-1.webp" },
  { name: "DR. N. GOLD PEARLIN MARY", role: "Co-Convenor", img: "DR.-GOLD-PEARLIN-MARY-1.webp" },
];

export function StudentConference() {
  return useAppLayout() ? <StudentConferenceApp /> : <StudentConferenceWeb />;
}

function StudentConferenceWeb() {
  return (
    <Page title="Student Conference">
      <div className="card bg-gradient-to-br from-[#1E3A8A] to-[#14141F] px-6 py-10 text-center">
        <div className="text-[11px] font-bold tracking-widest text-[#93C5FD]">
          36TH ISDR INTERNATIONAL CONFERENCE 2026
        </div>
        <div className="mt-2 text-3xl font-extrabold">Student’s Conference</div>
        <div className="mt-1 text-sm text-white/80">Your Research. Your Discovery. Your Global Stage.</div>
        <div className="mt-3 flex items-center justify-center gap-1 text-xs text-white/70">
          <Icon name="location_on" size={14} />
          Sree Balaji Dental College &amp; Hospital, BIHER, Chennai
        </div>
      </div>
      <Header>KEYNOTE SPEAKERS</Header>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {KEYNOTES.map((p) => (
          <PersonCard key={p.name} p={p} />
        ))}
      </div>
      <Header>PREAMBLE</Header>
      <div className="card p-4 text-sm leading-relaxed text-white/85">
        <p>
          The 36th ISDR International Conference 2026, Student’s Conference, hosted by Sree Balaji Dental College &amp;
          Hospital, BIHER, Chennai, invites students to present innovative work through Oral and Poster Presentations.
        </p>
        <p className="mt-2.5">
          Organized by the Indian Society for Dental Research (ISDR), the Indian Division of the IADR, this premier
          scientific conference provides a platform to showcase research, interact with renowned national and
          international experts, receive valuable feedback, and build global collaborations.
        </p>
      </div>
      <div className="card mt-3 p-4">
        <div className="text-[11px] font-bold tracking-wider text-muted">CONFERENCE THEME</div>
        <div className="mt-1 font-semibold italic text-[#93C5FD]">
          “Translational Dental Research: Bridging Science and Care”
        </div>
        <div className="mt-1.5 text-sm text-white/80">
          Highlights advances in diagnostics, biomaterials, regenerative dentistry, precision dentistry, artificial
          intelligence, digital health, and public health.
        </div>
      </div>
      <Header>PATRONS</Header>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {PATRONS.map((p) => (
          <PersonCard key={p.name} p={p} />
        ))}
      </div>
      <Header>CONFERENCE ORGANISING COMMITTEE</Header>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {CONF_COMMITTEE.map((p) => (
          <PersonCard key={p.name} p={p} />
        ))}
      </div>
      <Header>STUDENTS CONFERENCE ORGANISING COMMITTEE</Header>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {STUDENT_COMMITTEE.map((p) => (
          <PersonCard key={p.name} p={p} />
        ))}
      </div>
      <Header>RECEPTION &amp; HOSPITALITY</Header>
      <Accordion
        title="Reception & Hospitality"
        subtitle="3 Committee Members"
        items={["Dr. Malathy", "Dr. Kavya", "Dr. Durga Devi"]}
      />
    </Page>
  );
}

/* ------------------------------------------------------------------ */
/* Accommodation                                                       */
/* ------------------------------------------------------------------ */

const RESORTS: [string, string][] = [
  ["Ideal Beach Resort", "044-24495161"],
  ["Coral Beach Resort", "9444333333"],
  ["Hotel Mahabs", "044-27442643"],
  ["Golden Sun Beach Resort", "7845732245"],
  ["Hotel Mamallaa Heritage", "044-46270563"],
  ["Landmark Pallavaa Beach Resort", "8939944400"],
  ["Four Points by Sheraton", "044-71513636"],
  ["Chariot Beach Resort", "9444992727"],
  ["Radisson Blu Resort Temple Bay", "8062210102"],
  ["Welcome Hotel by ITC Hotels", "044-26421534"],
  ["Grande Bay Resort & Spa", "044-48133853"],
  ["Shelter Beach Resort", "9840333114"],
  ["La Villa Beach Paradise", "9840032297"],
  ["IZI Beach Stay", "9940130775"],
  ["Bay Inn", "8754413030"],
  ["Sea Breeze", "9962047297"],
];

const tel = (p: string) => `tel:${p.replace(/[^0-9+]/g, "")}`;

export function Accommodation() {
  // Phone width: the mobile app's screen.
  return useAppLayout() ? <AccommodationApp /> : <AccommodationWeb />;
}

function AccommodationWeb() {
  return (
    <Page title="Accommodation" subtitle="Stay options near the conference venue">
      <div className="grid gap-5 lg:grid-cols-2">
        <div>
          <div className="card p-6">
            <div className="text-[11px] font-bold tracking-wider text-[#38BDF8]">VENUE STAY</div>
            <div className="mt-1 text-lg font-extrabold">In-House Accommodation</div>
            <div className="mt-1 flex items-center gap-1 text-sm text-white/75">
              <Icon name="location_on" size={16} />
              Kaldan Samudhra Palace Resort, Mahabalipuram
            </div>
            <div className="mt-3 grid grid-cols-2 gap-2.5">
              <div className="rounded-xl bg-field p-3">
                <div className="text-[11px] font-bold tracking-wider text-muted">FULL ROOM</div>
                <div className="text-xl font-extrabold">₹20,000/-</div>
                <div className="text-xs text-muted">per day</div>
              </div>
              <div className="rounded-xl bg-field p-3">
                <div className="text-[11px] font-bold tracking-wider text-muted">SHARED ROOM</div>
                <div className="text-xl font-extrabold">₹10,000/-</div>
                <div className="text-xs text-muted">twin sharing / day</div>
              </div>
            </div>
            <div className="mt-3 text-sm text-white/80">
              The registered delegates are requested to contact for in-house accommodation @ Kaldan Samudhra Palace.
            </div>
          </div>
          <div className="mt-5 rounded-xl border border-amber-500/30 bg-amber-500/10 p-5">
            <div className="flex items-center gap-2 text-xs font-extrabold tracking-wider text-amber-400">
              <Icon name="warning" size={18} />
              IMPORTANT PAYMENT NOTICE
            </div>
            <div className="mt-1 text-sm text-white/85">
              Please do not make accommodation payments to the registration QR code or conference bank account.
            </div>
          </div>
        </div>
        <div>
          <div className="card flex items-center gap-3 p-5">
            <div className="flex h-11 w-11 items-center justify-center rounded-full bg-accent/15">
              <Icon name="support_agent" color="#60A5FA" />
            </div>
            <div className="flex-1">
              <div className="font-bold">Ms. Radhika</div>
              <div className="text-xs text-muted">Accommodation &amp; Details</div>
              <div className="text-sm font-semibold">9940211202</div>
            </div>
            <a
              href={tel("9940211202")}
              className="flex items-center gap-1.5 rounded-xl bg-accent px-3 py-2 text-sm font-semibold"
            >
              <Icon name="call" size={18} />
              Call
            </a>
          </div>
          <div className="mt-5 grid grid-cols-2 gap-5">
            <div className="card p-5">
              <div className="text-[11px] font-bold tracking-wider text-[#22C55E]">CHECK-IN</div>
              <div className="mt-1 text-xl font-extrabold">12:00 Noon</div>
              <div className="text-xs text-muted">9 October 2026</div>
            </div>
            <div className="card p-5">
              <div className="text-[11px] font-bold tracking-wider text-[#F87171]">CHECK-OUT</div>
              <div className="mt-1 text-xl font-extrabold">12:00 Noon</div>
              <div className="text-xs text-muted">11 October 2026</div>
            </div>
          </div>
        </div>
      </div>
      <Header>OTHER NEARBY RESORTS &amp; HOTELS</Header>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {RESORTS.map(([name, phone]) => (
          <a key={name} href={tel(phone)} className="card card-hover flex items-center gap-3 p-4">
            <Icon name="hotel" color="#38BDF8" />
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-semibold">{name}</div>
              <div className="text-xs text-muted">{phone}</div>
            </div>
            <Icon name="call" size={20} color="#22C55E" />
          </a>
        ))}
      </div>
    </Page>
  );
}
