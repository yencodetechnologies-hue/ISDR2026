/**
 * Replaces the ISDR 2026 scientific programme for 9–11 October 2026.
 *
 * One EventSchedule row per talk, lunch, oration, symposium, meeting, and
 * free-paper block. Speaker names are joined with " · ". The description is
 * the designation and affiliation shown on the session screen. A panel lists
 * each name again, in the same order, with that person's details underneath.
 * Rows with no speaker use "—".
 *
 * Only 9–11 October are removed. The 7–8 October student conference is left
 * in place.
 *
 * Usage: node scripts/seedScientificProgram.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');
const { applySessionFeedbackPolls } = require('./lib/sessionFeedbackPolls');

const KANNAPPAN = 'Dr J G Kannappan Hall';
const RAHMATULLAH = 'Dr M Rahmatullah Hall';
const SUBBARAO = 'Dr C V Subbarao Hall';
const BOARD = 'Conference Board Room';

const D1 = '2026-10-09';
const D2 = '2026-10-10';
const D3 = '2026-10-11';
// 9 Oct 00:00 IST through 12 Oct 00:00 IST. 7–8 October stay untouched.
const REPLACE_FROM = new Date('2026-10-08T18:30:00.000Z');
const REPLACE_TO = new Date('2026-10-11T18:30:00.000Z');

const NONE = '—';

const names = (...list) => list.join(' · ');

const one = (designation) => designation;

const person = (name, designation) => (designation ? `${name}\n${designation}` : name);

const panel = (entries) => entries.map(([name, designation]) => person(name, designation)).join('\n\n');

/** [date, from, to, hall, title, speaker, description, hideToTime] */
const slot = (date, from, to, hall, title, speaker, description, hideToTime = false) => [
  date,
  from,
  to,
  hall,
  title,
  speaker,
  description,
  hideToTime,
];

const AJAY =
  'Professor and Head, Dept of Orthodontics, NPDCH, Sankalchand Patel University, Ahmedabad, India.';
const TATU = 'Founder and Lead Physician, TMJ Head and Neck Pain Care, Ernakulam, India.';
const SWAMINATHAN =
  'Scientist - Immunology, Grow Research Laboratory, Narayana Nethralaya Foundation, Bengaluru, India.';
const RICHARD =
  'Lead Epidemiologist at Analytics Inc. Research Scientist in Biostatistics, Cochrane, South Asia.';
const HARSH =
  'Professor and Head, Division of Public Health Dentistry, CDER, AIIMS, New Delhi, India.';
const JOE =
  'Professor and Head, Department of Public Health Dentistry, Sree Mookambika Institute of Dental Sciences, Kulasekharam, Kanyakumari District, Tamil Nadu.';
const JAYASANKAR =
  'Department of Oral Pathology, Forensic Odontology and Dental Anthropology Unit, Govt. Dental College and Hospital, Ahmedabad, Gujarat.';
const ASHITH =
  'President, Indian Association of Forensic Odontology (IAFO), Professor and Head of the Department of Forensic Odontology, SDM College of Dental Sciences & Hospital, Dharwad, Karnataka.';
const ASHOK = 'Vice Principal, Prof. and Head, Department of OMDR, Bapuji Dental College, Davangere.';
const MANICKAM = 'Scientist F (Epidemiology), ICMR National Institute of Epidemiology, Chennai.';
const AARTHI =
  'Director of ARAN, Professor, Oral Medicine and Radiology, Sree Balaji Dental College, Chennai, India.';
const NITIKA = 'Scientist and Program Officer, Indian Council of Medical Research (ICMR), New Delhi.';
const VINOD =
  'Principal and Head of Department of Orthodontics, Sri Sankara Dental College, Varkala, Trivandrum, India.';
const SUJAN =
  'Professor and PG Guide, Department of Orthodontics & Dentofacial Orthopedics, MNR Dental College and Hospital, Fasalwadi, Sangareddy, Telangana.';
const REKHA = 'Professor, Dept of Orthodontics, Ragas Dental College, Chennai.';
const THULASIRAM =
  'Associate Professor, Dept of Orthodontics, Sree Balaji Dental College and Hospital, Chennai.';
const SUMANTH = "Professor, Dept of Orthodontics, Vel's Sri Venkateshwara Dental College, Chennai.";
const BHARATHI =
  'Associate Professor, Dept of Orthodontics, Sree Balaji Dental College and Hospital, Chennai.';
const SRIRENGALAKSHMI =
  'Professor and Academic Head, Dept of Orthodontics, Saveetha Dental College and Hospital, Chennai.';
const MANOJ =
  'Associate Professor, Dept of Orthodontics, Sree Balaji Dental College and Hospital, Chennai.';
const SRI_NISHA =
  'Chairperson. Vice President, Bharath Institute of Higher Education and Research (BIHER), Chairperson, Sree Balaji Group of Institutions.';
const DEEPAK =
  'Chairperson. Director of Academics, Program Director, Department of Implantology, Professor, Department of Prosthodontics, Saveetha University, Chennai.';
const ANIL =
  'Moderator. Former President, Dental Council of India, Editor-in-Chief, Indian Journal of Dental Research.';
const SM_BALAJI =
  'Moderator. Secretary General, ISDR. Former EC Member, DCI. Director, Balaji Dental & Craniofacial Hospital, Chennai.';
const FOX = 'Speaker. Chief Executive Officer, IADR, USA.';
const RITU = 'Speaker. Chief, CDER, AIIMS, New Delhi.';
const MAHESH = 'Speaker. Vice Chancellor, Guru Gobind Singh Indraprastha University, New Delhi.';
const GOPALAKRISHNAN_DEAN = 'Speaker. Dean, Manipal College of Dental Sciences, Manipal.';
const JENNIFER =
  "IADR President, Dean for International Affairs, Faculty of Dentistry, Oral & Craniofacial Sciences, King's College London, United Kingdom.";
const KEERTHIKA = 'PhD Scholar, Faculty of Dentistry, National University of Singapore, Singapore.';
const KAVITHA =
  'Professor, Dept of Conservative Dentistry and Endodontics, SRM Dental College, Ramapuram, Chennai, India.';
const NARAYANAN =
  'Professor and Acting Chair, Oral Biology, Associate Dean for Research, Rutgers School of Dental Medicine, Newark, New Jersey, United States of America.';
const EGUSA =
  'President Elect - IADR, Asia Pacific Region, Professor Chair at Tohoku University Graduate School of Dentistry, Japan.';
const MITHRA = 'Principal, A.B. Shetty Memorial Institute of Dental Sciences, Nitte, Mangalore, India.';
const NAVEEN =
  'Clinical Lead and Senior Consultant, Head and Neck Surgery, Apollo Proton Hospital, Chennai.';
const SAPNA =
  'Director Head and Neck, Senior Consultant, Radiation Oncology, Apollo Proton Hospital, Chennai.';
const SUJITH = 'Senior Consultant, Medical Oncology, Apollo Proton Hospital, Chennai.';
const ARUNAN = 'Senior Consultant, HOD Radiology, Apollo Proton Hospital, Chennai.';
const THAHA = 'Chairman, PMS Dental College, Trivandrum.';
const MAHALAXMI = 'Professor, Conservative Dentistry & Endodontics, SRM Dental College, Chennai.';
const MUTHU =
  'Dean, Sri Ramachandra Dental College and Hospital, Additional Dean (Research), Sri Ramachandra Institute of Higher Education & Research, Prof & Head, Centre for Early Childhood Caries Research (CECCRe), Chennai, India.';
const VIJAY_MATHUR =
  'Professor and Head, Paediatric and Preventive Dentistry, CDER, AIIMS, New Delhi, India.';
const ARIF =
  'Professor and Director, Dept of Orthodontics, Sree Balaji Dental College and Hospital, BIHER, Chennai, India.';
const RAJ_VERMA = 'Additional Professor, Orthodontics, PGIMER, Chandigarh.';
const GUNJAN = 'Additional Professor, Prosthodontics, PGIMER, Chandigarh.';
const NISHANT = 'Associate Professor, Public Health Dentistry, PGIMER, Chandigarh.';
const AMANDEEP = 'Assistant Professor, Endodontics, PGIMER Sangrur Satellite Centre.';
const BETSY = 'Researcher, University of Helsinki, Finland; Director.';
const DHARMARAJAN =
  'Dean & Professor, Department of Periodontology, Manipal College of Dental Sciences, Manipal Academy of Higher Education, Manipal, Karnataka.';
const ANURAG =
  "Professor & Head, Department of Periodontics & Oral Implantology, Institute of Dental Sciences, Siksha 'O' Anusandhan University, Bhubaneswar, Odisha.";
const GANESH =
  'Professor, Department of Periodontology, Tamil Nadu Government Dental College, Chennai, India.';
const GOPI = 'Professor, Dept of Prosthodontics, SRM Dental College, Ramapuram, Chennai, India.';
const SIVA = 'Private Practitioner.';
const SAGAR = 'Prosthodontist, The Dental Hub, Mumbai.';
const BHUMINATHAN = 'Registrar - BIHER, Professor, Dept of Prosthodontics, SBDCH, Chennai.';
const RAGHAVAN =
  'Research Advisor, Bharath Institute of Higher Education and Research, Chennai.';
const BHUVANA =
  'Dentist-Clinical Scientist, Lead, Colgate Clinical Innovation Institute and Dental-Dermal Health Unit, Colgate-Palmolive, Mumbai, Maharashtra.';
const MADHVI =
  "Consultant Orthodontist, Alder Hey Children's Healthcare Hospital, Liverpool, United Kingdom.";
const BADRI =
  'Research Director, Professor, Dept of Orthodontics, Sree Balaji Dental College and Hospital, Chennai. Hon Senior Lecturer in Orthodontics, University of Manchester.';
const RAMANATHAN = 'Associate Professor, Faculty of Dentistry, Manipal University College, Malaysia.';
const NANDHINI =
  'Professor, Dept of Conservative Dentistry and Endodontics, Meenakshi Ammal Dental College and Hospital, Chennai.';
const VAMSI =
  'Professor, Dept of Periodontology, Sri Ramachandra Dental College and Hospital, SRIHER, Chennai.';
const PRABHU = 'Specialist Periodontist, College of Dentistry, Ajman University, UAE.';
const SANGEETHA =
  'Academician and Researcher, Dept of Orthodontics, SRM Dental College, Ramapuram, Tamil Nadu.';
const VISHNU =
  'Professor & Head, Department of Pediatric Dentistry, Sathyabama Dental College and Hospital, Chennai.';
const VIJAY_ADITH =
  'Professor and Head, Dept of Orthodontics, Priyadarshini Dental College and Hospital, India.';
const KSHITIJ =
  'Research Scientist Team Lead, Colgate-Palmolive (India) Ltd, Mumbai, Maharashtra.';
const SANDLER =
  'Professor in Orthodontics, University of Sheffield and Chesterfield Royal Hospital, NHS Trust, United Kingdom.';
const BALA = 'Consultant Craniomaxillofacial Surgeon, Rela Hospital, Chrompet, Chennai.';
const AMBILI =
  'Head of the Department, Department of Periodontics, Research Director, PMS College of Dental Sciences and Research, Trivandrum. PhD Guide, Member, UG Board of Studies, Kerala University of Health and Allied Sciences, Kerala.';
const MANO =
  'Professor, Dept of Periodontology, Vinayaka Missions Sankarachariyar Dental College, Salem, Tamil Nadu.';
const SHEELA =
  'Professor, Priyadarshini Dental College and Hospital, Tamil Nadu, TN Dr. M.G.R. Medical University, Chennai.';
const ARUNIMA =
  'Professor, Dept of Periodontics, PMS College of Dental Science and Research, Trivandrum, Kerala, India.';
const PRATIBHA =
  'Prof & Head, Department of Oral and Maxillofacial Pathology, Saveetha Dental College and Hospitals, Chennai.';
const RAMYA =
  'Associate Dean of Collaboration & Networking, Saveetha Institute of Medical and Technical Sciences (SIMATS), Professor & Head of Oral Biology, Saveetha Dental College, Chennai.';
const VANDANA = 'Associate Editor, Books, Medicine & Life Sciences, Springer Nature.';

const PROGRAMME = [
  // Day 1 — Dr J G Kannappan Hall
  slot(D1, '09:00', '09:20', KANNAPPAN, 'Artificial Intelligence in Dentistry', 'Dr. Ajay Kubavat', one(AJAY)),
  slot(
    D1,
    '09:20',
    '09:40',
    KANNAPPAN,
    'Must Incorporate Facts in Dentistry, for a Fully Satisfying Career',
    'Dr. Tatu Joy',
    one(TATU)
  ),
  slot(
    D1,
    '09:40',
    '10:10',
    KANNAPPAN,
    'Immunological Considerations in Gene Therapy for Craniofacial Disorders',
    'Dr. Swaminathan Sethu',
    one(SWAMINATHAN)
  ),
  slot(
    D1,
    '10:10',
    '10:30',
    KANNAPPAN,
    'Evidence to Decision: A Path to Clinical Practice Guidelines in Dentistry',
    'Dr. Richard Kirubakaran',
    one(RICHARD)
  ),
  slot(
    D1,
    '10:30',
    '10:50',
    KANNAPPAN,
    'Commercial Determinants of Health: The Missing Piece in Oral Disease Prevention',
    'Dr. Harsh Priya',
    one(HARSH)
  ),
  slot(
    D1,
    '10:50',
    '11:30',
    KANNAPPAN,
    'Forensics in Dental Care',
    names('Dr. Joe Joseph', 'Dr. Jayasankar P. Pillai', 'Dr. Ashith B Acharya', 'Dr. L. Ashok'),
    panel([
      ['Dr. Joe Joseph', JOE],
      ['Dr. Jayasankar P. Pillai', JAYASANKAR],
      ['Dr. Ashith B Acharya', ASHITH],
      ['Dr. L. Ashok', ASHOK],
    ])
  ),
  slot(
    D1,
    '11:30',
    '12:00',
    KANNAPPAN,
    'Scaling Oral Health Research through Cross-institutional Collaboration: If Not Now, When?',
    'Dr. Manickam Ponniah',
    one(MANICKAM)
  ),
  slot(
    D1,
    '12:00',
    '12:30',
    KANNAPPAN,
    'Implementing Antimicrobial Stewardship (AMS) Program in South India',
    'Dr. Aarthi Bhuvaraghan',
    one(AARTHI)
  ),
  slot(
    D1,
    '12:30',
    '13:00',
    KANNAPPAN,
    'Bridging Policy and Prevention: Advancing Oral Health through Implementation Research and the Anant Muskaan Model',
    'Dr. Nitika Monga',
    one(NITIKA)
  ),
  slot(D1, '13:00', '13:40', KANNAPPAN, 'Lunch Break', NONE, ''),
  slot(
    D1,
    '13:40',
    '14:30',
    KANNAPPAN,
    'Aligners versus Conventional Orthodontics: Efficiency, Effectiveness and Scope; an Evidence Based Current Practice',
    names(
      'Dr. Vinod Krishnan',
      'Dr. Sujan Kumar',
      'Dr. Rekha Bharadwaj',
      'Dr. Thulasiram E',
      'Dr. Sumanth Kumar R',
      'Dr. Bharathi Chaturvedula',
      'Dr. Srirengalakshmi M',
      'Dr. Manoj Prathap C'
    ),
    panel([
      ['Dr. Vinod Krishnan', VINOD],
      ['Dr. Sujan Kumar', SUJAN],
      ['Dr. Rekha Bharadwaj', REKHA],
      ['Dr. Thulasiram E', THULASIRAM],
      ['Dr. Sumanth Kumar R', SUMANTH],
      ['Dr. Bharathi Chaturvedula', BHARATHI],
      ['Dr. Srirengalakshmi M', SRIRENGALAKSHMI],
      ['Dr. Manoj Prathap C', MANOJ],
    ])
  ),
  slot(
    D1,
    '14:30',
    '16:00',
    KANNAPPAN,
    'From Curiosity to Discovery: Integrating Research into the Mainstream Dental Curriculum',
    names(
      'Dr. J. Sri Nisha',
      'Dr. Deepak Nallaswamy Veeraiyan',
      'Dr. Anil Kohli',
      'Dr. S. M. Balaji',
      'Dr. Christopher Fox',
      'Dr. Ritu Duggal',
      'Dr. Mahesh Verma',
      'Dr. Nitika Monga',
      'Dr. D. Gopalakrishnan'
    ),
    panel([
      ['Dr. J. Sri Nisha', SRI_NISHA],
      ['Dr. Deepak Nallaswamy Veeraiyan', DEEPAK],
      ['Dr. Anil Kohli', ANIL],
      ['Dr. S. M. Balaji', SM_BALAJI],
      ['Dr. Christopher Fox', FOX],
      ['Dr. Ritu Duggal', RITU],
      ['Dr. Mahesh Verma', MAHESH],
      ['Dr. Nitika Monga', `Speaker. ${NITIKA}`],
      ['Dr. D. Gopalakrishnan', GOPALAKRISHNAN_DEAN],
    ])
  ),
  slot(
    D1,
    '16:00',
    '16:40',
    KANNAPPAN,
    'Dr J G Kannappan Oration: Global Oral Health Challenges & Research-informed Action',
    'Dr. Jennifer Gallagher',
    one(JENNIFER)
  ),
  slot(
    D1,
    '17:00',
    '19:00',
    KANNAPPAN,
    'Inauguration Ceremony',
    'His Excellency Thiru. Rajendra Vishwanath Arlekar',
    'The Governor of Tamil Nadu and Kerala. Chief Guest.',
    true
  ),

  // Day 1 — Dr M Rahmatullah Hall
  slot(
    D1,
    '09:00',
    '09:20',
    RAHMATULLAH,
    'The Future of Periodontal Research: Innovation Shaping Next Generation Clinical Practice',
    'Dr. Prabhu Manickam Natarajan',
    one(PRABHU)
  ),
  slot(
    D1,
    '09:20',
    '09:40',
    RAHMATULLAH,
    'From Research Question to Statistical Analysis: Planning Statistics Before We Start',
    'Dr. Sangeetha Duraisamy',
    one(SANGEETHA)
  ),
  slot(
    D1,
    '09:40',
    '10:00',
    RAHMATULLAH,
    'AI Research and Transformative Interventions for Childhood Anxiety',
    'Dr. Vishnu Rekha',
    one(VISHNU)
  ),
  slot(D1, '10:00', '10:20', RAHMATULLAH, 'How Can Audits Improve Patient Care?', 'Dr. Vijay Adith C', one(VIJAY_ADITH)),
  slot(
    D1,
    '10:20',
    '10:40',
    RAHMATULLAH,
    'Advanced Solutions for Gum Health Protection',
    'Dr. Kshitij Satardekar',
    one(KSHITIJ)
  ),
  slot(
    D1,
    '11:30',
    '11:50',
    RAHMATULLAH,
    'How to Successfully Execute a Multicentric RCT',
    'Dr. Jonathan Sandler',
    one(SANDLER)
  ),
  slot(
    D1,
    '11:50',
    '12:10',
    RAHMATULLAH,
    'Evidence versus Clinical Acceptability on Orthognathic Surgery',
    'Dr. B. Bala Guhan',
    one(BALA)
  ),
  slot(D1, '13:00', '14:00', RAHMATULLAH, 'Lunch Break', NONE, ''),
  slot(D1, '14:00', '17:00', RAHMATULLAH, 'Scientific Papers/e-Posters Presentation by Delegates', NONE, ''),

  // Day 1 — Dr C V Subbarao Hall
  slot(D1, '09:00', '17:10', SUBBARAO, 'Scientific Papers/e-Posters Presentation by Delegates', NONE, ''),

  // Day 1 — Conference Board Room
  slot(D1, '13:30', '14:30', BOARD, 'Pre AGM EC Meeting', NONE, '', true),

  // Day 2 — Dr J G Kannappan Hall
  slot(
    D2,
    '09:00',
    '09:20',
    KANNAPPAN,
    'Oral Frailty: Redefining Oral Health Care in Older Adults',
    'Dr. Keerthika Natarajan',
    one(KEERTHIKA)
  ),
  slot(
    D2,
    '09:20',
    '09:40',
    KANNAPPAN,
    'Key Priorities for Oral Health Management in India',
    'Dr. Kavitha Sanjeev',
    one(KAVITHA)
  ),
  slot(
    D2,
    '09:40',
    '10:10',
    KANNAPPAN,
    'Developing a Periodontal Vaccine - Current Approaches and Hurdles',
    'Dr. Narayanan Ramasubbu',
    one(NARAYANAN)
  ),
  slot(
    D2,
    '10:30',
    '11:00',
    KANNAPPAN,
    'Translating Stem Cell and Nanotechnology Innovations into Regenerative Dentistry',
    'Prof. Hiroshi Egusa',
    one(EGUSA)
  ),
  slot(
    D2,
    '11:00',
    '11:40',
    KANNAPPAN,
    'Prof. Hari Parkash Oration: Predict, Prevent, Preserve: Saliva Biomarkers and the Future of Precision Dentistry',
    'Prof. Dr. Mithra N. Hegde',
    one(MITHRA)
  ),
  slot(
    D2,
    '11:40',
    '12:40',
    KANNAPPAN,
    'Tumour Board Multidisciplinary Cancer Care by Management Team',
    names('Dr. Naveen Hedne', 'Dr. Sapna Nangia', 'Dr. Sujith Mulappaly', 'Dr. Arunan Murali'),
    panel([
      ['Dr. Naveen Hedne', NAVEEN],
      ['Dr. Sapna Nangia', SAPNA],
      ['Dr. Sujith Mulappaly', SUJITH],
      ['Dr. Arunan Murali', ARUNAN],
    ])
  ),
  slot(
    D2,
    '12:40',
    '13:20',
    KANNAPPAN,
    'Prof. Dr. C.V. Subbarao Oration: Oral-Systemic Nexus: From Precision Dentistry to Precision Health',
    'Prof. Dr. P.S. Thaha',
    one(THAHA)
  ),
  slot(D2, '13:20', '14:00', KANNAPPAN, 'Lunch Break', NONE, ''),
  slot(
    D2,
    '14:00',
    '14:30',
    KANNAPPAN,
    "Periodontal Ligament Cell Behavior under Unconventional Orthodontic Forces - The HIPPO Pathway's Role Explored",
    'Dr. Vinod Krishnan',
    one(VINOD)
  ),
  slot(
    D2,
    '14:30',
    '15:00',
    KANNAPPAN,
    'From Proposal to Completion: The Journey of a Funded Project',
    'Dr. Mahalaxmi S',
    one(MAHALAXMI)
  ),
  slot(
    D2,
    '15:00',
    '15:30',
    KANNAPPAN,
    'Beyond the Clinic: Centre for Early Childhood Caries Research, Grants and Translational Oral Health',
    'Prof. Dr. MS Muthu',
    one(MUTHU)
  ),
  slot(
    D2,
    '15:30',
    '16:00',
    KANNAPPAN,
    'Government Initiatives on Oral Health in India: Evolution, Experience and the Road Ahead',
    'Dr. Vijay Prakash Mathur',
    one(VIJAY_MATHUR)
  ),
  slot(
    D2,
    '16:00',
    '16:20',
    KANNAPPAN,
    'Non-Radiological Biomarkers in the Assessment of Pubertal Growth Spurt',
    'Dr. Arif Yezdani',
    one(ARIF)
  ),
  slot(
    D2,
    '16:20',
    '17:00',
    KANNAPPAN,
    'Digital Prediction and Interdisciplinary Management of Dentoalveolar Trauma',
    names('Dr. Raj Kumar Verma', 'Dr. Gunjan Pruthi', 'Dr. Nishant', 'Dr. Amandeep Kaur'),
    panel([
      ['Dr. Raj Kumar Verma', RAJ_VERMA],
      ['Dr. Gunjan Pruthi', GUNJAN],
      ['Dr. Nishant', NISHANT],
      ['Dr. Amandeep Kaur', AMANDEEP],
    ])
  ),

  // Day 2 — Dr M Rahmatullah Hall
  slot(
    D2,
    '09:00',
    '09:30',
    RAHMATULLAH,
    'Opportunities and Challenges in Dental Research in India',
    'Dr. Ambili R',
    one(AMBILI)
  ),
  slot(
    D2,
    '09:30',
    '09:45',
    RAHMATULLAH,
    'Mentoring the Modern Dental Learner from Knowledge Transfer to Competency Development',
    'Dr. Mano Vijay',
    one(MANO)
  ),
  slot(
    D2,
    '09:45',
    '10:00',
    RAHMATULLAH,
    'Collaboration in Research: Who, Why and How?',
    'Dr. K. Sheela Kumari',
    one(SHEELA)
  ),
  slot(
    D2,
    '10:00',
    '10:15',
    RAHMATULLAH,
    'Soft Tissue Substitutes 2.0: Redefining Pink Esthetics',
    'Dr. Arunima',
    one(ARUNIMA)
  ),
  slot(
    D2,
    '10:30',
    '10:45',
    RAHMATULLAH,
    'Practical Applications of Advanced Instrumentation and Molecular Techniques in Oral and Maxillofacial Sciences',
    'Dr. Pratibha Ramani',
    one(PRATIBHA)
  ),
  slot(
    D2,
    '10:45',
    '11:00',
    RAHMATULLAH,
    'Comparative Exploration of Neuroplasticity, Metacognition and Precision Intelligence in Medical and Dental Education',
    'Dr. Ramya Ramadas',
    one(RAMYA)
  ),
  slot(D2, '13:00', '14:00', RAHMATULLAH, 'Lunch Break', NONE, ''),
  slot(D2, '14:00', '17:00', RAHMATULLAH, 'Scientific Papers/e-Posters Presentation by Delegates', NONE, ''),

  // Day 2 — Dr C V Subbarao Hall
  slot(D2, '08:00', '10:00', SUBBARAO, 'Presentations for Hatton Awards', NONE, ''),
  slot(D2, '10:00', '18:00', SUBBARAO, 'Scientific Papers/e-Posters Presentation by Delegates', NONE, ''),

  // Day 2 — Conference Board Room
  slot(
    D2,
    '09:00',
    '10:00',
    BOARD,
    "Antimicrobial Stewardship in Dentistry: What We Know, What We Don't and What We Should Do Next",
    names('Dr. Aarthi Bhuvaraghan', 'Dr. Bhuminathan S'),
    panel([
      ['Dr. Aarthi Bhuvaraghan', `Session lead. ${AARTHI}`],
      ['Dr. Bhuminathan S', `Session lead. ${BHUMINATHAN}`],
    ])
  ),
  slot(
    D2,
    '10:00',
    '11:00',
    BOARD,
    'Beyond Treatment Success: Developing an Outcome Assessment Index and Practical Guide for Dental Clinicians',
    names('Dr. Badri Thiruvenkatachari', 'Dr. Gnana Shanmugham', 'Dr. Kannan Sabapathy'),
    panel([
      ['Dr. Badri Thiruvenkatachari', `Session lead. ${BADRI}`],
      ['Dr. Gnana Shanmugham', 'Session lead.'],
      ['Dr. Kannan Sabapathy', 'Session lead.'],
    ])
  ),
  slot(D2, '14:00', '16:00', BOARD, 'Meet the Publishing Editor', 'Dr. Vandana Joshi', one(VANDANA)),

  // Day 3 — Dr J G Kannappan Hall
  slot(
    D3,
    '09:00',
    '09:20',
    KANNAPPAN,
    'Unraveling Complex Odantalgia: Indian Perspectives and Clinical Insights',
    'Dr. P. Rajesh',
    ''
  ),
  slot(
    D3,
    '09:20',
    '09:50',
    KANNAPPAN,
    'Translating Research into Careers: Closing the Global Industry Skill Gap for the Next Generation of Dental Graduates',
    'Dr. Betsy Joseph',
    one(BETSY)
  ),
  slot(
    D3,
    '09:50',
    '10:30',
    KANNAPPAN,
    'Perio Equity 2030: Translating Periodontal Science into Sustainable and Equitable Solutions for Low- and Middle-Income Countries',
    names('Dr. Gopalakrishnan Dharmarajan', 'Dr. Anurag Satpathy', 'Dr. Ganesh Puttu'),
    panel([
      ['Dr. Gopalakrishnan Dharmarajan', DHARMARAJAN],
      ['Dr. Anurag Satpathy', ANURAG],
      ['Dr. Ganesh Puttu', GANESH],
    ])
  ),
  slot(
    D3,
    '10:30',
    '10:50',
    KANNAPPAN,
    'AI Denture in Prosthodontic Work: Evidence versus Clinical Feasibility for Indian Scenario',
    names('Dr. Gopi Chander N', 'Dr. Siva Prakash'),
    panel([
      ['Dr. Gopi Chander N', GOPI],
      ['Dr. Siva Prakash', SIVA],
    ])
  ),
  slot(
    D3,
    '10:50',
    '11:30',
    KANNAPPAN,
    'Clinic to Evidence: Practice-Based Clinical Dental Research for Indian Dentistry',
    names('Dr. Sagar J. Abichandani', 'Dr. Bhuminathan S', 'Dr. R. Narasimha Raghavan', 'Dr. Gopi Chander N'),
    panel([
      ['Dr. Sagar J. Abichandani', SAGAR],
      ['Dr. Bhuminathan S', BHUMINATHAN],
      ['Dr. R. Narasimha Raghavan', RAGHAVAN],
      ['Dr. Gopi Chander N', GOPI],
    ])
  ),
  slot(
    D3,
    '11:30',
    '11:50',
    KANNAPPAN,
    'Transforming Oral Care Through R&D Innovation',
    'Dr. Bhuvana Gurumurthy',
    one(BHUVANA)
  ),
  slot(D3, '11:50', '12:10', KANNAPPAN, 'Circle of Cleft Dental Care', 'Dr. Madhvi Seshu', one(MADHVI)),
  slot(
    D3,
    '12:10',
    '12:30',
    KANNAPPAN,
    'Cleft Care Treatment Protocol: Global versus Indian Scenario',
    'Dr. Badri Thiruvenkatachari',
    one(BADRI)
  ),
  slot(
    D3,
    '12:30',
    '12:50',
    KANNAPPAN,
    'Beyond the Dental Chair: The Role of Dental Clinicians in Advancing Community Oral Health',
    'Dr. Ramanathan Ravi',
    one(RAMANATHAN)
  ),
  slot(
    D3,
    '12:50',
    '13:30',
    KANNAPPAN,
    'One Root, Two Issues: The Regenerative Continuum in Endodontics and Periodontics',
    names('Dr. Nandhini Suresh', 'Dr. Vamsi Lavu'),
    panel([
      ['Dr. Nandhini Suresh', NANDHINI],
      ['Dr. Vamsi Lavu', VAMSI],
    ])
  ),
  slot(D3, '13:30', '14:30', KANNAPPAN, 'Lunch and Valedictory Function', NONE, '', true),

  // Day 3 — Dr M Rahmatullah Hall
  slot(D3, '09:00', '14:00', RAHMATULLAH, 'Scientific Papers/e-Posters Presentation by Delegates', NONE, ''),

  // Day 3 — Dr C V Subbarao Hall
  slot(D3, '09:00', '14:00', SUBBARAO, 'Scientific Papers/e-Posters Presentation by Delegates', NONE, ''),

  // Day 3 — Conference Board Room. No clock was printed.
  slot(D3, '', '', BOARD, 'Post AGM EC Meeting', NONE, ''),
];

(async () => {
  await connectDB();

  const events = await ManagedEvent.find({ title: /isdr/i });
  const matches = events.filter((event) => /2026/.test(event.title));
  const exact = matches.filter((event) => event.title.trim().toLowerCase() === 'isdr 2026');
  const chosen = exact.length === 1 ? exact : matches;
  if (chosen.length !== 1) {
    const listed = (matches.length ? matches : events).map((event) => event.title).join(', ') || '(none)';
    throw new Error(`Expected one ISDR 2026 event, found ${matches.length}: ${listed}`);
  }
  const event = chosen[0];
  console.log(`Event: ${event.title} (${event._id})`);

  const removed = await EventSchedule.deleteMany({
    eventId: event._id,
    date: { $gte: REPLACE_FROM, $lt: REPLACE_TO },
  });
  console.log(`Removed ${removed.deletedCount} schedule(s) on 9–11 October.`);

  const orderByDate = {};
  const docs = PROGRAMME.map(([date, fromTime, toTime, hall, scheduleName, speakerName, description, hideToTime]) => {
    orderByDate[date] = (orderByDate[date] || 0) + 1;
    return {
      eventId: event._id,
      apartmentId: event.apartmentId,
      speakerName,
      speakerPhoto: '',
      scheduleName,
      packageIds: [],
      hall,
      date: new Date(`${date}T00:00:00.000Z`),
      fromTime,
      toTime,
      hideToTime: Boolean(hideToTime),
      description,
      sortOrder: orderByDate[date],
    };
  });

  const created = await EventSchedule.insertMany(docs);
  const byHall = {};
  for (const row of created) {
    byHall[row.hall] = (byHall[row.hall] || 0) + 1;
  }
  console.log(`Created ${created.length} schedules.`);
  for (const [hall, count] of Object.entries(byHall)) {
    console.log(`  ${hall}: ${count}`);
  }

  await applySessionFeedbackPolls(event);
  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
