import { useState } from "react";
import { AppBar, Icon } from "@/components/ui";
import { asset } from "@/lib/api";

/* ------------------------------------------------------------------ */
/* 1. CommitteeApp                                                    */
/* ------------------------------------------------------------------ */

interface CommitteeLead {
  name: string;
  role: string;
  imagePath: string;
}

interface SubCommittee {
  title: string;
  icon: string;
  members: string[];
}

const LEADS: CommitteeLead[] = [
  { name: "DR. S. JAGATHRAKSHAKAN", role: "Founder Chairman", imagePath: "DR.-S.-JAGATHRAKSHAKAN.webp" },
  { name: "DR. J. SRI NISHA", role: "Conference Organising Chairman", imagePath: "DR-J.-SRI-NISHA.webp" },
  { name: "ER. N. ELAMARAN", role: "Managing Director", imagePath: "ER.-N.-ELAMARAN.webp" },
  { name: "DR. S. M. BALAJI", role: "Conference Executive Advisor", imagePath: "DR.-S.-M.-BALAJI-2.webp" },
  { name: "DR. MAHESH VERMA", role: "Conference Secretary", imagePath: "DR.-MAHESH-VERMA-2.webp" },
  { name: "DR. S. BHUMINATHAN", role: "Organising Secretary", imagePath: "DR.-S.-BHUMINATHAN.webp" },
  { name: "DR. M.S. KANNAN", role: "Organising Co-Chairman", imagePath: "DR.-M.S.-KANNAN.webp" },
  { name: "DR. K. GNANA SHANMUGHAM", role: "Chairman, Scientific Committee", imagePath: "DR.-K.-GNANA-SHANMUGHAM.webp" },
  { name: "DR. RAGAVENDRA JAYESH", role: "Conference Advisor", imagePath: "DR.-RAGAVENDRA-JAYESH-1.webp" },
  { name: "DR. PONNUDURAI ARANGANNAL", role: "Conference Advisor", imagePath: "DR.-PONNUDURAI-ARANGANNAL-1.webp" },
  { name: "DR. BADRI THIRUVENKATACHARI", role: "Co-Chairman, Scientific Committee", imagePath: "DR.-BADRI-THIRUVENKATACHARI-1.webp" },
  { name: "DR. S. KISHORE KUMAR", role: "Joint Secretary", imagePath: "DR.-S.-KISHORE-KUMAR-Organising-Committee.jpg-1.webp" },
  { name: "DR. N. ARAVINDHA BABU", role: "Treasurer", imagePath: "DR.N.-ARAVINDHA-BABU.webp" },
  { name: "DR. A. VENKATESH", role: "Convener, Preconference Courses", imagePath: "DR.-A.-VENKATESH.webp" },
  { name: "DR. NALINI ASWATH", role: "Convener Pre Conference Course Committee", imagePath: "DR.-NALINI-ASWATH-1.webp" },
  { name: "DR. M. N. PRABHU", role: "Convener, International Relations", imagePath: "DR.-M.-N-PRABHU.webp" },
  { name: "DR. VIJAY EBENEZER", role: "Convener Banquet and Cultural Night", imagePath: "DR.-VIJAY-EBENEZER-1.webp" },
  { name: "DR. ANITHA BALAJI", role: "Convener Reception Committee", imagePath: "DR.-ANITHA-BALAJI-2.jpg.webp" },
  { name: "DR. M. ANITA", role: "Convener Souvenir Committee", imagePath: "DR.-M.-ANITA-1.webp" },
  { name: "DR. MANIKANDAN", role: "Convener Trade", imagePath: "DR.-MANIKANDAN-1.webp" },
  { name: "DR. SREE DEVI V", role: "Convener Hospitality Committee", imagePath: "DR.-SREE-DEVI-V-1.webp" },
  { name: "DR. GOLD PEARLIN MARY", role: "Co-Convener Student Conference", imagePath: "DR.-GOLD-PEARLIN-MARY-1.webp" },
  { name: "DR. N. GEETHA PRIYA", role: "Convener Awards Committee", imagePath: "DR.-N.-GEETHA-PRIYA-1.webp" },
];

const SUB_COMMITTEES: SubCommittee[] = [
  {
    title: "Scientific Committee",
    icon: "biotech",
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
    icon: "medical_services",
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
    icon: "how_to_reg",
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
  {
    title: "Reception & Hospitality Committee",
    icon: "sentiment_satisfied",
    members: ["Dr. Anitha Balaji", "Dr. Sree Devi V", "Dr. Tamil selvi"],
  },
  {
    title: "Student Committee",
    icon: "school",
    members: ["Dr. Gold Pearlin Mary", "Dr. E. Tulasi Ram", "Dr. Geeta Priya", "Dr. D. Ramya"],
  },
  {
    title: "Banquet and Cultural Night",
    icon: "celebration",
    members: ["Dr. Vijay Ebenezer", "Dr. Balakrishnan", "Dr. Saravana Kumar", "Dr. Prakash"],
  },
  {
    title: "Awards Committee",
    icon: "emoji_events",
    members: ["Dr. N. Geetha priya", "Dr. Seetha lakshmi", "Dr. Amudha", "Dr. Mathangi"],
  },
  {
    title: "Website & Media",
    icon: "language",
    members: ["Dr. Janani Balachandran", "Dr. Abarna J"],
  },
  {
    title: "Student Conference",
    icon: "assignment_ind",
    members: ["Dr. Sumathi Jones", "Dr. N. Gold Pearlin Mary", "Dr. Malathy", "Dr. Kavya", "Dr. Durga Devi"],
  },
  {
    title: "Publications & Souvenir",
    icon: "menu_book",
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
    icon: "hotel",
    members: ["Dr. T. Puhazhendi", "Dr. Rajasekar K.V", "Dr. Gowri Shankar", "Dr. Abirami", "Dr. Aravind Vishnu"],
  },
  {
    title: "Trade Committee",
    icon: "storefront",
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
    icon: "engineering",
    members: ["Dr. Siva Kumar", "Dr. Savitha", "Dr. Rajasekar", "Dr. Manoj", "Dr. Sadhana", "Mr. Vijay"],
  },
];

const CHAIR_MESSAGE =
  "It gives me immense pleasure to extend a warm and cordial welcome to all the distinguished delegates, eminent researchers, clinicians, academicians, students participating in the 36th ISDR International Conference. This conference represents a significant milestone in our collective pursuit of excellence in dental, oral, and craniofacial research. It provides a unique platform for the exchange of scientific knowledge, innovative ideas, and transformative research that will shape the future of oral healthcare. Bringing together experts from diverse disciplines fosters collaboration, inspires innovation, and strengthens our commitment to evidence-based practice and translational research. At Bharath Institute of Higher Education and Research (BIHER), we are committed to nurturing a culture of academic excellence, scientific inquiry, and innovation. Hosting the 36th ISDR International Conference reflects our dedication to advancing research that addresses contemporary healthcare challenges and improves the quality of life of people across the globe. The theme of this conference, “Translational Dental Research: Bridging Science and Care,” aptly emphasizes the importance of transforming scientific discoveries into meaningful clinical applications. I am confident that the scientific deliberations, keynote lectures, workshops, and interactive sessions will stimulate new ideas, encourage interdisciplinary collaborations, and inspire future research endeavors. Once again it gives me immense pleasure to welcome you all to this spectacular scientific extravaganza.";

export function CommitteeApp() {
  const [chairExpanded, setChairExpanded] = useState(false);
  const [expandedCommittees, setExpandedCommittees] = useState<Set<string>>(new Set());

  const toggleCommittee = (title: string) => {
    setExpandedCommittees((prev) => {
      const next = new Set(prev);
      if (next.has(title)) next.delete(title);
      else next.add(title);
      return next;
    });
  };

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Organising Committee" outfit />
      <div className="px-4 pb-8 pt-4">
        {/* Title Banner */}
        <div className="flex flex-col items-center text-center">
          <h1 className="font-serif text-[22px] font-bold tracking-[0.5px] text-[#FBBF24]">
            Conference Organising Committee
          </h1>
          <div className="mt-1.5 h-[3px] w-[50px] rounded-full bg-[#D97706]" />
        </div>

        {/* Chairperson Welcome Message Card */}
        <div className="mt-[18px] overflow-hidden rounded-[18px] bg-gradient-to-br from-[#0F172A] to-[#1E3A8A] shadow-[0_5px_12px_rgba(30,58,138,0.25)]">
          <button
            onClick={() => setChairExpanded((v) => !v)}
            className="flex w-full items-center p-4 text-left transition hover:bg-white/[0.02]"
          >
            <div className="h-[52px] w-[52px] shrink-0 overflow-hidden rounded-[12px] border-[1.5px] border-[#FBBF24]/60">
              <img
                src={asset("DR-J.-SRI-NISHA.webp")}
                alt="Dr. J. Sri Nisha"
                className="h-full w-full object-cover object-top"
              />
            </div>
            <div className="ml-3.5 min-w-0 flex-1">
              <div className="font-outfit text-[15.5px] font-bold text-white">
                From the Organising Chairperson
              </div>
              <div className="mt-0.5 text-[11.5px] font-bold tracking-[0.6px] text-[#FBBF24]">
                DR. J. SRI NISHA
              </div>
              <div className="text-[10.5px] font-medium text-[#93C5FD]">
                Organising Chairman - 36th ISDR
              </div>
            </div>
            <span
              className="ml-2 text-[#FBBF24] transition-transform duration-200"
              style={{ transform: chairExpanded ? "rotate(180deg)" : undefined }}
            >
              <Icon name="expand_more" color="#FBBF24" />
            </span>
          </button>

          {chairExpanded && (
            <div className="border-t border-white/10 pt-3.5">
              {/* Gold Header Tag */}
              <div className="px-4.5">
                <span className="inline-block rounded-md border border-[#FBBF24]/35 bg-[#FBBF24]/15 px-2.5 py-1 text-[10.5px] font-extrabold tracking-[1.2px] text-[#FBBF24]">
                  DEAR COLLEAGUES,
                </span>
              </div>

              {/* Full Photo Banner */}
              <div className="mt-3 px-4.5">
                <div className="h-[180px] w-full overflow-hidden rounded-[14px] border border-white/20">
                  <img
                    src={asset("DR-J.-SRI-NISHA.webp")}
                    alt="Dr. J. Sri Nisha"
                    className="h-full w-full object-cover object-top"
                  />
                </div>
              </div>

              {/* Message Body */}
              <p className="mt-3.5 px-4.5 text-[13px] leading-[1.55] text-white/90">
                {CHAIR_MESSAGE}
              </p>

              {/* Sign-off Credentials */}
              <div className="mt-4 rounded-b-[18px] bg-black/25 px-4.5 py-3.5">
                <div className="font-outfit text-[15px] font-bold tracking-[0.5px] text-white">
                  DR. J. SRI NISHA
                </div>
                <div className="mt-0.5 whitespace-pre-line text-[11.5px] font-medium leading-[1.4] text-[#93C5FD]">
                  {"Vice President, BIHER\nChairperson - Sree Balaji Group of Institutions\nOrganising Chairman - 36th ISDR"}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Section Header: Committee Leadership */}
        <div className="mb-2 mt-5 text-[12px] font-bold tracking-[0.6px] text-[#9CA3AF]">
          ORGANISING LEADERSHIP &amp; CONVENERS
        </div>

        {/* Leadership Cards */}
        <div className="space-y-3.5">
          {LEADS.map((lead) => (
            <div
              key={lead.name}
              className="flex items-center rounded-[16px] border border-white/10 bg-[#14141F] p-3 shadow-sm"
            >
              <div className="h-[80px] w-[95px] shrink-0 overflow-hidden rounded-[12px] border border-white/10 bg-[#1E1E2A]">
                <img
                  src={asset(lead.imagePath)}
                  alt={lead.name}
                  className="h-full w-full object-cover"
                />
              </div>
              <div className="ml-3.5 min-w-0 flex-1">
                <span className="inline-block rounded-md bg-gradient-to-r from-[#1D4ED8] to-[#1E3A8A] px-2 py-0.5 text-[10.5px] font-bold tracking-[0.3px] text-white">
                  {lead.role}
                </span>
                <div className="mt-1.5 font-outfit text-[14.5px] font-bold leading-snug text-white">
                  {lead.name}
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Section Header: Sub-Teams */}
        <div className="mb-2 mt-6 text-[12px] font-bold tracking-[0.6px] text-[#9CA3AF]">
          COMMITTEES &amp; SUB-TEAMS
        </div>

        {/* Sub-Committees Expandable Accordions */}
        <div className="space-y-3">
          {SUB_COMMITTEES.map((sub) => {
            const open = expandedCommittees.has(sub.title);
            return (
              <div
                key={sub.title}
                className="overflow-hidden rounded-[16px] border border-white/10 bg-[#14141F] shadow-sm"
              >
                <button
                  onClick={() => toggleCommittee(sub.title)}
                  className="flex w-full items-center px-4 py-3.5 text-left transition hover:bg-white/[0.02]"
                >
                  <div className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-[10px] bg-[#2563EB]/10 text-[#2563EB]">
                    <Icon name={sub.icon} size={20} color="#2563EB" />
                  </div>
                  <div className="ml-3.5 min-w-0 flex-1">
                    <div className="font-outfit text-[15.5px] font-bold text-white">
                      {sub.title}
                    </div>
                    <div className="text-[12px] font-medium text-[#9CA3AF]">
                      {sub.members.length} Members
                    </div>
                  </div>
                  <span
                    className="ml-2 text-[#9CA3AF] transition-transform duration-200"
                    style={{ transform: open ? "rotate(180deg)" : undefined }}
                  >
                    <Icon name="expand_more" color="#9CA3AF" />
                  </span>
                </button>

                {open && (
                  <div className="border-t border-white/10 px-4 pb-4 pt-2">
                    <div className="divide-y divide-[#1E1E2A]">
                      {sub.members.map((name, i) => (
                        <div key={name} className="flex items-center py-2">
                          <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-md bg-[#1E1E2A] text-[10.5px] font-bold text-[#9CA3AF]">
                            {String(i + 1).padStart(2, "0")}
                          </span>
                          <span className="ml-3 text-[13px] font-semibold text-[#E2E8F0]">
                            {name}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 2. AboutIsdrApp                                                    */
/* ------------------------------------------------------------------ */

interface OfficeBearer {
  name: string;
  role: string;
  imagePath: string;
  designation: string;
}

const OFFICE_BEARERS: OfficeBearer[] = [
  {
    name: "DR. RITU DUGGAL",
    role: "President",
    imagePath: "DR.-RITU-DUGGAL.webp",
    designation: "Chief & Professor, Department of Orthodontics, CDER, AIIMS, New Delhi",
  },
  {
    name: "DR. MAHESH VERMA",
    role: "President Elect",
    imagePath: "DR.-MAHESH-VERMA.webp",
    designation: "Vice Chancellor, Guru Gobind Singh, Indraprastha University, New Delhi",
  },
  {
    name: "DR. VIJAY MATHUR",
    role: "Vice President",
    imagePath: "DR.-VIJAY-MATHUR.webp",
    designation: "Professor & Head, Division of Pedodontics & Preventive Dentistry, CDER, AIIMS, New Delhi",
  },
  {
    name: "DR. DEEPAK CHANDRA",
    role: "Vice President",
    imagePath: "DR.-DEEPAK-CHANDRA.webp",
    designation: "Professor & Head, Department of Orthodontics & Dentofacial Orthopedics, SRM Kattankulathur Dental College & Hospital, Chennai",
  },
  {
    name: "DR. NAMITA SHANBHAG",
    role: "Vice President",
    imagePath: "DR.-NAMITA-SHANBHAG.webp",
    designation: "Associate Professor, Public Health Dentistry, Government Dental College & Research Institute, Bangalore",
  },
  {
    name: "DR. S. M. BALAJI",
    role: "Secretary General",
    imagePath: "DR.-S.-M.-BALAJI.webp",
    designation: "Director, Cranio-Maxillofacial Surgeon, Balaji Dental & Craniofacial Hospital, Chennai",
  },
  {
    name: "DR. PREETHA BALAJI",
    role: "Joint Secretary",
    imagePath: "DR.-PREETHA-BALAJI.webp",
    designation: "Department of Oral & Maxillofacial Surgery, Balaji Dental & Craniofacial Hospital, Chennai",
  },
  {
    name: "DR. ANIL KOHLI",
    role: "Editor-In-Chief - IJDR",
    imagePath: "DR.-ANIL-KOHLI.webp",
    designation: "Former President, DCI, New Delhi",
  },
  {
    name: "DR. S. KISHORE KUMAR",
    role: "Treasurer",
    imagePath: "DR.-S.-KISHORE-KUMAR.webp",
    designation: "Vice Principal, Sree Balaji Dental College & Hospital, Chennai",
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

const ABOUT_PARAGRAPHS = [
  "The Indian Society for Dental Research (ISDR) is India’s premier scientific organization dedicated to advancing dental, oral, and craniofacial research. As the Indian Division of the International Association for Dental, Oral and Craniofacial Research (IADR), ISDR has, since its establishment in 1986, remained committed to promoting excellence in scientific research, innovation, and evidence-based clinical practice.",
  "The Society traces its origins to the vision of Dr. M. Rahmatulla, who conceived the idea of establishing an Indian division of the IADR after attending the 64th IADR Annual Session in Dallas, Texas, USA, in March 1984. Following two years of dedicated efforts, the inaugural convention was held in July 1986 at Hotel Connemara, Madras (Chennai), where Dr. Rahmatulla was unanimously elected as the Founder President of the IADR Indian Division. Dr. J. G. Kannapan and Dr. P. K. Baskar also played instrumental roles in establishing the organization. Initially named the Indian Association for Dental Research, the organization was subsequently renamed the Indian Society for Dental Research (ISDR) on the recommendation of its parent body, while continuing as the official Indian Division of the IADR.",
  "Over nearly four decades, the ISDR Annual Conference has evolved into one of the country’s most prestigious scientific gatherings, attracting eminent national and international experts who present pioneering research, technological innovations, and advances in clinical practice. Through keynote lectures, scientific sessions, workshops, panel discussions, free paper presentations, and poster sessions, the conference fosters meaningful academic interactions, encourages collaborative research, and inspires the next generation of clinician-scientists.",
];

const CONF_THEME_PARAGRAPHS = [
  "Hosted by Sree Balaji Dental College & Hospital, Bharath Institute of Higher Education and Research (BIHER), Chennai, marks another significant milestone in this remarkable journey. Bringing together distinguished scientists, clinicians, educators, industry leaders, and students from across the world.",
  "This theme highlights the critical importance of transforming laboratory discoveries into innovative clinical solutions that improve patient outcomes and advance oral healthcare. The conference aims to promote interdisciplinary collaboration and showcase cutting-edge developments in biomaterials, regenerative dentistry, artificial intelligence, precision dentistry, public health, digital technologies, and other emerging areas that are shaping the future of dental science and practice.",
];

export function AboutIsdrApp() {
  const [councilOpen, setCouncilOpen] = useState(false);

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="About ISDR" outfit />
      <div className="px-4 pb-8 pt-4">
        {/* Logo Header */}
        <div className="flex justify-center">
          <div className="inline-flex rounded-[16px] bg-[#14141F] p-3 shadow-md">
            <img src={asset("logo.png")} alt="ISDR Logo" className="h-[65px] object-contain" />
          </div>
        </div>

        {/* Main Intro Card */}
        <div className="mt-4.5 rounded-[16px] border border-white/10 bg-[#14141F] p-4.5 shadow-sm">
          <h2 className="font-outfit text-[18px] font-bold text-white">
            Indian Society for Dental Research
          </h2>
          <div className="mt-3 space-y-3 text-[13.5px] leading-[1.6] text-[#CBD5E1]">
            {ABOUT_PARAGRAPHS.map((p, i) => (
              <p key={i}>{p}</p>
            ))}
          </div>
        </div>

        {/* 36th Conference Theme Card */}
        <div className="mt-4.5 rounded-[16px] bg-gradient-to-br from-[#0F172A] to-[#1E3A8A] p-4.5 shadow-[0_5px_12px_rgba(30,58,138,0.25)]">
          <div className="flex items-center gap-2">
            <Icon name="stars" size={24} color="#FBBF24" />
            <span className="font-outfit text-[17px] font-bold text-white">
              36th ISDR International Conference 2026
            </span>
          </div>
          <div className="mt-3 rounded-[10px] border border-white/20 bg-white/12 px-3 py-2 text-[14px] font-semibold italic text-[#FBBF24]">
            “Translational Dental Research: Bridging Science and Care”
          </div>
          <div className="mt-3 space-y-3 text-[13.5px] leading-[1.55] text-white/90">
            {CONF_THEME_PARAGRAPHS.map((p, i) => (
              <p key={i}>{p}</p>
            ))}
          </div>
        </div>

        {/* ISDR Office Bearers Section Header */}
        <div className="mt-7 flex flex-col items-center text-center">
          <h2 className="font-serif text-[24px] font-bold tracking-[0.5px] text-[#FBBF24]">
            ISDR Office Bearers
          </h2>
          <div className="mt-1.5 h-[3px] w-[48px] rounded-full bg-[#D97706]" />
        </div>

        {/* Office Bearer Cards */}
        <div className="mt-4.5 space-y-4">
          {OFFICE_BEARERS.map((bearer) => (
            <div
              key={bearer.name}
              className="flex items-center rounded-[16px] border border-white/10 bg-[#14141F] p-3 shadow-sm"
            >
              <div className="h-[80px] w-[95px] shrink-0 overflow-hidden rounded-[12px] border border-white/10 bg-[#1E1E2A]">
                <img
                  src={asset(bearer.imagePath)}
                  alt={bearer.name}
                  className="h-full w-full object-cover"
                />
              </div>
              <div className="ml-3.5 min-w-0 flex-1">
                <span className="inline-block rounded-md bg-gradient-to-r from-[#1D4ED8] to-[#1E3A8A] px-2 py-0.5 text-[10.5px] font-bold tracking-[0.3px] text-white">
                  {bearer.role}
                </span>
                <div className="mt-1 font-outfit text-[14.5px] font-bold text-white">
                  {bearer.name}
                </div>
                <div className="mt-1 text-[11.5px] font-medium leading-[1.35] text-[#9CA3AF]">
                  {bearer.designation}
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Executive Council Members Accordion */}
        <div className="mt-4 overflow-hidden rounded-[16px] border border-white/10 bg-[#14141F] shadow-sm">
          <button
            onClick={() => setCouncilOpen((v) => !v)}
            className="flex w-full items-center px-4 py-3 text-left transition hover:bg-white/[0.02]"
          >
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[#2563EB]/10 text-[#2563EB]">
              <Icon name="groups" size={22} color="#2563EB" />
            </div>
            <div className="ml-3.5 min-w-0 flex-1">
              <div className="font-outfit text-[16px] font-bold text-white">
                Executive Council
              </div>
              <div className="text-[12px] font-medium text-[#9CA3AF]">
                20 Members • ISDR Indian Division
              </div>
            </div>
            <span
              className="ml-2 text-[#9CA3AF] transition-transform duration-200"
              style={{ transform: councilOpen ? "rotate(180deg)" : undefined }}
            >
              <Icon name="expand_more" color="#9CA3AF" />
            </span>
          </button>

          {councilOpen && (
            <div className="border-t border-white/10 px-4 pb-4 pt-2.5">
              <div className="divide-y divide-[#1E1E2A]">
                {EXECUTIVE_COUNCIL.map((name, i) => (
                  <div key={name} className="flex items-center py-2">
                    <span className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-md bg-[#1E1E2A] text-[11px] font-bold text-[#9CA3AF]">
                      {String(i + 1).padStart(2, "0")}
                    </span>
                    <span className="ml-3 text-[13.5px] font-semibold text-[#E2E8F0]">
                      {name}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Webmaster Section */}
        <div className="mt-4 flex items-center rounded-[16px] border border-white/10 bg-[#14141F] p-4 shadow-sm">
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[#0284C7]/12 text-[#0284C7]">
            <Icon name="language" size={24} color="#0284C7" />
          </div>
          <div className="ml-3.5 min-w-0 flex-1">
            <div className="text-[11px] font-bold tracking-[0.6px] text-[#9CA3AF]">
              WEBMASTER
            </div>
            <div className="mt-0.5 font-outfit text-[16px] font-bold text-white">
              Dr. Sri Ganesh
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 3. StudentConferenceApp                                            */
/* ------------------------------------------------------------------ */

interface SpeakerInfo {
  name: string;
  role: string;
  affiliation: string;
  imagePath: string;
}

interface CommitteePerson {
  name: string;
  role: string;
  subRole?: string;
  extraRole?: string;
  imagePath: string;
}

const KEYNOTE_SPEAKERS: SpeakerInfo[] = [
  {
    name: "DR MURUGABASKAR",
    role: "Research Scientist",
    affiliation: "Boston Children’s Hospital / Harvard Medical School",
    imagePath: "DR-MURUGABASKAR.webp",
  },
  {
    name: "DR. PAVITHRA KRISHNASWAMI",
    role: "Senior Scientist",
    affiliation: "Translational Medicine Unit, Sanofi\nGreater Boston, Cambridge, Massachusetts, USA",
    imagePath: "DR.PAVITHRA KRISHNASWAMI.webp",
  },
  {
    name: "DR. SYLVIA ANNABEL DASS",
    role: "Laboratory Manager",
    affiliation: "Allen Healthcare Products (M) Sdn. Bhd. Penang, Malaysia",
    imagePath: "DR. SYLVIA ANNABEL DASS.webp",
  },
];

const PATRONS: CommitteePerson[] = [
  {
    name: "DR. S. JAGATHRAKSHAKAN",
    role: "Founder Chairman",
    subRole: "Bharath Institute of Higher Education and Research",
    extraRole: "Chief Patron – 36th ISDR",
    imagePath: "DR.-S.-JAGATHRAKSHAKAN.webp",
  },
  {
    name: "DR. J. SRI NISHA",
    role: "Vice President",
    subRole: "Bharath Institute of Higher Education and Research\nChairperson – Sree Balaji Group of Institutions",
    extraRole: "Organising Chairman – 36th ISDR",
    imagePath: "DR-J.-SRI-NISHA.webp",
  },
  {
    name: "ER. N. ELAMARAN",
    role: "Managing Director",
    subRole: "Sree Balaji Group of Institutions",
    extraRole: "Patron – 36th ISDR",
    imagePath: "ER.-N.-ELAMARAN.webp",
  },
];

const CONF_COMMITTEE: CommitteePerson[] = [
  { name: "DR. S. M. BALAJI", role: "Conference Executive Advisor", imagePath: "DR.-S.-M.-BALAJI-2.webp" },
  { name: "DR. MAHESH VERMA", role: "Conference Secretary", imagePath: "DR.-MAHESH-VERMA-2.webp" },
  { name: "DR. S. BHUMINATHAN", role: "Organising Secretary", imagePath: "DR.-S.-BHUMINATHAN.webp" },
  { name: "DR. M. S. KANNAN", role: "Organising Co-Chairman", imagePath: "DR.-M.S.-KANNAN.webp" },
  { name: "DR. K. GNANA SHANMUGHAM", role: "Chairman, Scientific Committee", imagePath: "DR.-K.-GNANA-SHANMUGHAM.webp" },
];

const STUDENT_CONF_COMMITTEE: CommitteePerson[] = [
  { name: "DR. SUMATHI JONES", role: "Convenor", imagePath: "DR.-GOLD-PEARLIN-MARY-1.webp" },
  { name: "DR. N. GOLD PEARLIN MARY", role: "Co-Convenor", imagePath: "DR.-GOLD-PEARLIN-MARY-1.webp" },
];

const RECEPTION_HOSPITALITY = ["Dr. Malathy", "Dr. Kavya", "Dr. Durga Devi"];

export function StudentConferenceApp() {
  const [hospitalityOpen, setHospitalityOpen] = useState(true);

  const renderPersonCard = (p: CommitteePerson) => (
    <div
      key={p.name + p.role}
      className="flex items-center rounded-[16px] border border-white/10 bg-[#14141F] p-3 shadow-sm"
    >
      <div className="h-[80px] w-[95px] shrink-0 overflow-hidden rounded-[12px] border border-white/10 bg-[#1E1E2A]">
        <img src={asset(p.imagePath)} alt={p.name} className="h-full w-full object-cover" />
      </div>
      <div className="ml-3.5 min-w-0 flex-1">
        <div className="font-outfit text-[13.5px] font-bold tracking-[0.4px] text-white">
          {p.name}
        </div>
        <div className="mt-0.5 text-[12px] font-semibold text-[#2563EB]">
          {p.role}
        </div>
        {p.subRole && (
          <div className="mt-0.5 whitespace-pre-line text-[11px] leading-[1.3] text-[#9CA3AF]">
            {p.subRole}
          </div>
        )}
        {p.extraRole && (
          <div className="mt-1">
            <span className="inline-block rounded-[4px] bg-[#F59E0B]/15 px-1.5 py-0.5 text-[10px] font-bold text-[#FBBF24]">
              {p.extraRole}
            </span>
          </div>
        )}
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-bg">
      <AppBar title="Student Conference" outfit />
      <div className="px-4 pb-8 pt-3.5">
        {/* Hero Title Card */}
        <div className="rounded-[18px] bg-gradient-to-br from-[#0F172A] to-[#1E3A8A] p-5 shadow-[0_5px_12px_rgba(30,58,138,0.25)]">
          <span className="inline-block rounded-md border border-[#FBBF24]/35 bg-[#FBBF24]/15 px-2.5 py-1 text-[10px] font-extrabold tracking-[1.1px] text-[#FBBF24]">
            36TH ISDR INTERNATIONAL CONFERENCE 2026
          </span>
          <div className="mt-2.5 font-outfit text-[22px] font-bold leading-tight text-white">
            Student’s Conference
          </div>
          <div className="mt-1.5 text-[13px] font-semibold text-[#93C5FD]">
            Your Research. Your Discovery. Your Global Stage.
          </div>
          <div className="mt-3 flex items-center gap-1.5 text-[11.5px] font-medium text-white/70">
            <Icon name="location_on" size={15} color="#FBBF24" />
            <span>Sree Balaji Dental College &amp; Hospital, BIHER, Chennai</span>
          </div>
        </div>

        {/* Keynote Speakers Section */}
        <div className="mt-4 rounded-[18px] border border-white/10 bg-[#14141F] p-4 shadow-sm">
          <div className="flex items-center gap-2">
            <div className="h-4 w-1 rounded-[2px] bg-[#2563EB]" />
            <span className="font-outfit text-[14px] font-extrabold tracking-[0.8px] text-[#93C5FD]">
              KEYNOTE SPEAKERS
            </span>
          </div>

          <div className="mt-4 divide-y divide-[#1E1E2A]">
            {KEYNOTE_SPEAKERS.map((spk, i) => (
              <div key={spk.name} className={`flex items-start ${i === 0 ? "pb-3.5" : "py-3.5"}`}>
                <div className="h-[84px] w-[96px] shrink-0 overflow-hidden rounded-[12px] border border-white/10 bg-[#1E1E2A]">
                  <img
                    src={asset(spk.imagePath)}
                    alt={spk.name}
                    className="h-full w-full object-cover object-top"
                  />
                </div>
                <div className="ml-3.5 min-w-0 flex-1">
                  <div className="font-outfit text-[13.5px] font-bold tracking-[0.3px] text-[#93C5FD]">
                    {spk.name}
                  </div>
                  <div className="mt-0.5 text-[12px] font-semibold text-[#CBD5E1]">
                    {spk.role}
                  </div>
                  <div className="mt-1 whitespace-pre-line text-[11px] font-medium leading-[1.35] text-[#9CA3AF]">
                    {spk.affiliation}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Preamble & Theme Card */}
        <div className="mt-5 rounded-[18px] border border-white/10 bg-[#14141F] p-4.5 shadow-sm">
          <div className="flex items-center gap-2">
            <Icon name="auto_stories" size={18} color="#2563EB" />
            <span className="font-outfit text-[14px] font-extrabold tracking-[0.8px] text-white">
              PREAMBLE
            </span>
          </div>
          <div className="mt-2.5 space-y-2.5 text-[12.5px] leading-[1.55] text-[#CBD5E1]">
            <p>
              The 36th ISDR International Conference 2026, Student’s Conference, hosted by Sree Balaji Dental College &amp; Hospital, BIHER, Chennai, invites students to present innovative work through Oral and Poster Presentations.
            </p>
            <p>
              Organized by the Indian Society for Dental Research (ISDR), the Indian Division of the IADR, this premier scientific conference provides a platform to showcase research, interact with renowned national and international experts, receive valuable feedback, and build global collaborations.
            </p>
          </div>

          <div className="mt-3.5 rounded-[12px] border border-white/10 bg-[#1E1E2A] p-3.5">
            <div className="flex items-center gap-1.5">
              <Icon name="lightbulb" size={16} color="#F59E0B" />
              <span className="text-[11px] font-bold tracking-[0.5px] text-[#FBBF24]">
                CONFERENCE THEME
              </span>
            </div>
            <div className="mt-1.5 font-outfit text-[13px] font-bold text-white">
              “Translational Dental Research: Bridging Science and Care”
            </div>
            <div className="mt-1.5 text-[11.5px] leading-[1.45] text-[#9CA3AF]">
              Highlights advances in diagnostics, biomaterials, regenerative dentistry, precision dentistry, artificial intelligence, digital health, and public health.
            </div>
          </div>
        </div>

        {/* Patrons */}
        <div className="mb-2 mt-5 text-[12px] font-bold tracking-[0.6px] text-[#9CA3AF]">
          PATRONS
        </div>
        <div className="space-y-3">
          {PATRONS.map(renderPersonCard)}
        </div>

        {/* Conference Organising Committee */}
        <div className="mb-2 mt-5 text-[12px] font-bold tracking-[0.6px] text-[#9CA3AF]">
          CONFERENCE ORGANISING COMMITTEE
        </div>
        <div className="space-y-3">
          {CONF_COMMITTEE.map(renderPersonCard)}
        </div>

        {/* Students Conference Organising Committee */}
        <div className="mb-2 mt-5 text-[12px] font-bold tracking-[0.6px] text-[#9CA3AF]">
          STUDENTS CONFERENCE ORGANISING COMMITTEE
        </div>
        <div className="space-y-3">
          {STUDENT_CONF_COMMITTEE.map(renderPersonCard)}
        </div>

        {/* Reception & Hospitality Accordion */}
        <div className="mb-2 mt-5 text-[12px] font-bold tracking-[0.6px] text-[#9CA3AF]">
          RECEPTION &amp; HOSPITALITY
        </div>
        <div className="overflow-hidden rounded-[16px] border border-white/10 bg-[#14141F] shadow-sm">
          <button
            onClick={() => setHospitalityOpen((v) => !v)}
            className="flex w-full items-center px-4 py-3 text-left transition hover:bg-white/[0.02]"
          >
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] bg-[#3B82F6]/15 text-[#2563EB]">
              <Icon name="room_service" size={20} color="#2563EB" />
            </div>
            <div className="ml-3.5 min-w-0 flex-1">
              <div className="font-outfit text-[14.5px] font-bold text-white">
                Reception &amp; Hospitality
              </div>
              <div className="text-[11px] font-medium text-[#9CA3AF]">
                {RECEPTION_HOSPITALITY.length} Committee Members
              </div>
            </div>
            <span
              className="ml-2 text-[#9CA3AF] transition-transform duration-200"
              style={{ transform: hospitalityOpen ? "rotate(180deg)" : undefined }}
            >
              <Icon name="expand_more" color="#9CA3AF" />
            </span>
          </button>

          {hospitalityOpen && (
            <div className="border-t border-[#1E1E2A] px-4 pb-4 pt-3">
              <div className="space-y-2">
                {RECEPTION_HOSPITALITY.map((name) => (
                  <div key={name} className="flex items-center gap-2.5">
                    <span className="h-1.5 w-1.5 rounded-full bg-[#2563EB]" />
                    <span className="text-[13px] font-semibold text-[#CBD5E1]">
                      {name}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
