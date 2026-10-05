/**
 * Replaces the ISDR 2026 scientific programme.
 *
 * One EventSchedule row per talk, lunch, oration, symposium, and free-paper
 * block for 9–11 October 2026. Speaker names are stored on the row (joined
 * with " · " when a slot has several). No speaker logins are created.
 * Rows with no printed speaker use "—" so the field stays valid.
 *
 * Usage: node scripts/seedScientificProgram.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const connectDB = require('../config/database');
const ManagedEvent = require('../models/ManagedEvent');
const EventSchedule = require('../models/EventSchedule');

const KANNAPPAN = 'Dr J G Kannappan Hall';
const RAHMATULLAH = 'Dr M Rahmatullah Hall';
const SUBBARAO = 'Dr C V Subbarao Hall';

const D1 = '2026-10-09';
const D2 = '2026-10-10';
const D3 = '2026-10-11';

const NONE = '—';
const TITLE_MISSING = 'Talk title not listed';

const panel = (...names) => names.join(' · ');

/** [date, from, to, hall, title, speaker, description] */
const PROGRAMME = [
  // Day 1 — Dr J G Kannappan Hall
  [D1, '09:00', '09:20', KANNAPPAN, 'Artificial Intelligence in Dentistry', 'Dr. Ajay Kubavat', 'Session 1'],
  [
    D1,
    '09:20',
    '09:40',
    KANNAPPAN,
    'Must Incorporate Facts in Dentistry, for a Fully Satisfying Career',
    'Dr. Tatu Joy',
    'Session 1',
  ],
  [
    D1,
    '09:40',
    '10:10',
    KANNAPPAN,
    'Immunological Considerations in Gene Therapy for Craniofacial Disorders',
    'Dr. Swaminathan Sethu',
    'Session 1',
  ],
  [
    D1,
    '10:10',
    '10:30',
    KANNAPPAN,
    'Evidence to Decision: A Path to Clinical Practice Guidelines in Dentistry',
    'Dr. Richard Kirubakaran',
    'Session 2',
  ],
  [
    D1,
    '10:30',
    '10:50',
    KANNAPPAN,
    'Commercial Determinants of Health: The Missing Piece in Oral Disease Prevention',
    'Dr. Harsh Priya',
    'Session 2',
  ],
  [
    D1,
    '10:50',
    '11:30',
    KANNAPPAN,
    'Forensics in Dental Care',
    panel('Dr. Joe Joseph', 'Dr. Jaysankar P. Pillai', 'Dr. Ashith B Acharya', 'Dr. L. Ashok'),
    'Symposium 1',
  ],
  [
    D1,
    '11:30',
    '12:00',
    KANNAPPAN,
    TITLE_MISSING,
    'Dr. Manickam Ponniah',
    'Session 3. Talk title was not printed on the programme.',
  ],
  [
    D1,
    '12:00',
    '12:30',
    KANNAPPAN,
    'Implementing Antimicrobial Stewardship (AMS) Programme in South India',
    NONE,
    'Session 3. Speaker was not printed on the programme.',
  ],
  [
    D1,
    '12:30',
    '13:00',
    KANNAPPAN,
    'Bridging Policy and Prevention: Advancing Oral Health Through Implementation Research and the Anand Muskaan Model',
    'Dr. Nitika Monga',
    'Session 3',
  ],
  [D1, '13:00', '14:00', KANNAPPAN, 'Lunch Break', NONE, ''],
  [
    D1,
    '14:00',
    '15:00',
    KANNAPPAN,
    'Tumour Board Multidisciplinary Cancer Care by Management Team',
    panel('Dr. Naveen Hedne', 'Dr. Sapna Nangia', 'Dr. Sujith Mulappaly', 'Dr. Arunan Murali'),
    'Symposium 2',
  ],
  [
    D1,
    '15:00',
    '16:00',
    KANNAPPAN,
    'Aligners versus Conventional Orthodontics: Efficiency, Effectiveness and Scope; an Evidence Based Current Practice',
    panel(
      'Dr. Vinod Krishnan',
      'Dr. Rekha Bharadwaj',
      'Dr. Sumanth Kumar',
      'Dr. Srirengalakshmi',
      'Dr. Thulasiram E',
      'Dr. Bharathi Chaturvedula',
      'Dr. Manoj Prathap'
    ),
    'Symposium 3',
  ],
  [D1, '16:00', '16:40', KANNAPPAN, 'Dr J G Kannappan Oration', 'Dr. Jennifer Gallagher', 'Dr J G Kannappan Oration'],
  [
    D1,
    '17:00',
    '19:00',
    KANNAPPAN,
    'Inauguration of the ISDR Conference',
    'Dr. Aarthi Bhuvaraghan',
    'From 5:00 PM onwards. End time was not printed on the programme; listed until 7:00 PM.',
  ],

  // Day 1 — Dr M Rahmatullah Hall
  [
    D1,
    '09:00',
    '09:20',
    RAHMATULLAH,
    'The Future of Periodontal Research: Innovation Shaping Next Generation Clinical Practice',
    'Dr. Prabhu Natarajan',
    'Session 1',
  ],
  [
    D1,
    '09:20',
    '09:40',
    RAHMATULLAH,
    'From Research Question to Statistical Analysis: Planning Statistics Before We Start',
    'Dr. Sangeetha Duraisamy',
    'Session 1',
  ],
  [
    D1,
    '09:40',
    '10:00',
    RAHMATULLAH,
    'AI Research and Transformative Interventions for Childhood Anxiety',
    'Dr. Vishnu Rekha',
    'Session 1',
  ],
  [D1, '10:00', '10:20', RAHMATULLAH, 'How Can Audits Improve Patient Care?', 'Dr. Vijay Adith C', 'Session 2'],
  [D1, '10:20', '10:40', RAHMATULLAH, 'Protocols for Painless Root Canal Treatment', 'Dr. Venkatesh Babu', 'Session 2'],
  [
    D1,
    '11:30',
    '11:50',
    RAHMATULLAH,
    'How to Successfully Execute a Multicentric RCT',
    'Dr. Jonathan Sandler',
    'Session 3',
  ],
  [
    D1,
    '11:50',
    '12:10',
    RAHMATULLAH,
    'Evidence versus Clinical Acceptability on Orthognathic Surgery',
    'Dr. Bala Guhan',
    'Session 3',
  ],
  [D1, '13:00', '14:00', RAHMATULLAH, 'Lunch Break', NONE, ''],
  [
    D1,
    '14:00',
    '17:00',
    RAHMATULLAH,
    'Free Papers / e-Posters',
    NONE,
    'Chairpersons: Dr. J Sri Nisha, Dr. Deepak Nallasamy. Moderators: Dr Anil Kohli, Dr. SM Balaji. Listed topics: Periodontal Ligament Cell Behavior under Unconventional Orthodontic Forces – The HIPPO Pathway’s Role Explored; Developing a Periodontal Vaccine – Current Approaches and Hurdles.',
  ],

  // Day 1 — Dr C V Subbarao Hall
  [D1, '09:00', '17:00', SUBBARAO, 'Free Papers / e-Posters', NONE, ''],

  // Day 2 — Dr J G Kannappan Hall
  [
    D2,
    '09:00',
    '09:20',
    KANNAPPAN,
    'Oral Frailty: Redefining Oral Health Care in Older Adults',
    'Dr. Keerthika Natarajan',
    'Session 4',
  ],
  [
    D2,
    '09:20',
    '09:40',
    KANNAPPAN,
    'Key Priorities for Oral Health Management in India',
    'Dr. Kavitha Sanjeev',
    'Session 4',
  ],
  [
    D2,
    '09:40',
    '10:10',
    KANNAPPAN,
    TITLE_MISSING,
    'Dr. Narayanan Ramasubbu',
    'Session 4. Talk title was not printed on the programme.',
  ],
  [D2, '10:10', '10:30', KANNAPPAN, 'Importance of Dental Accreditation', 'Dr. Eesha Arora Narang', 'Session 5'],
  [
    D2,
    '10:30',
    '11:00',
    KANNAPPAN,
    'Translating Stem Cell and Nanotechnology Innovations into Regenerative Dentistry',
    'Prof. Hiroshi Egusa',
    'Session 5',
  ],
  [D2, '11:00', '11:40', KANNAPPAN, 'Dr Hari Prakash Oration', 'Prof. Dr. Mithra N Hegde', 'Dr Hari Prakash Oration'],
  [
    D2,
    '11:40',
    '12:10',
    KANNAPPAN,
    TITLE_MISSING,
    'Dr. Vinod Krishnan',
    'Session 6. Talk title was not printed on the programme.',
  ],
  [
    D2,
    '12:10',
    '12:40',
    KANNAPPAN,
    'From Proposal to Completion: The Journey of a Funded Project',
    'Prof. Mahalaxmi S',
    'Session 6',
  ],
  [
    D2,
    '12:40',
    '13:00',
    KANNAPPAN,
    TITLE_MISSING,
    'Dr. Murugabaskar Balan',
    'Session 6. Talk title was not printed on the programme.',
  ],
  [D2, '13:00', '14:00', KANNAPPAN, 'Lunch Break', NONE, ''],
  [
    D2,
    '14:00',
    '15:30',
    KANNAPPAN,
    'From Curiosity to Discovery: Integrating Research into the Mainstream Dental Curriculum',
    panel(
      'Dr. Christopher Fox',
      'Dr. Ritu Duggal',
      'Dr. Mahesh Verma',
      'Dr. Nitika Monga',
      'Dr. D. Gopalakrishnan'
    ),
    'IADR National Symposium',
  ],
  [
    D2,
    '15:30',
    '16:00',
    KANNAPPAN,
    'Beyond the Clinic: Centre for Early Childhood Caries Research, Grants and Translational Oral Health',
    'Prof. Dr. MS Muthu',
    'Session 7',
  ],
  [D2, '16:00', '16:20', KANNAPPAN, 'Government Initiatives in Oral Health', 'Dr. Vijay Prakash Mathur', 'Session 7'],
  [
    D2,
    '16:20',
    '17:00',
    KANNAPPAN,
    'Digital Prediction and Interdisciplinary Management of Dentoalveolar Trauma',
    panel('Dr. Raj Kumar Verma', 'Dr. Gunjan Pruthi', 'Dr. Nishant', 'Dr. Amandeep Kaur'),
    'Symposium 5',
  ],

  // Day 2 — Dr M Rahmatullah Hall
  [
    D2,
    '09:30',
    '09:45',
    RAHMATULLAH,
    'Mentoring the Modern Dental Learner from Knowledge Transfer to Competency Development',
    'Dr. Mano Vijay',
    'Session 1',
  ],
  [
    D2,
    '09:45',
    '10:00',
    RAHMATULLAH,
    'Collaboration in Research: Who, Why and How?',
    'Dr. K. Sheela Kumari',
    'Session 1',
  ],
  [
    D2,
    '10:00',
    '10:15',
    RAHMATULLAH,
    'Soft Tissue Substitutes 2.0: Redefining Pink Esthetics',
    'Dr. Arunima',
    'Session 1',
  ],
  [
    D2,
    '10:30',
    '10:45',
    RAHMATULLAH,
    'Practical Applications of Advanced Instrumentation and Molecular Techniques in Oral and Maxillofacial Sciences',
    'Dr. Pratibha Ramani',
    'Session 2',
  ],
  [
    D2,
    '10:45',
    '11:00',
    RAHMATULLAH,
    'Comparative Exploration of Neuroplasticity, Metacognition and Precision Intelligence in Medical and Dental Education',
    'Dr. Ramya Ramadas',
    'Session 2',
  ],
  [D2, '12:00', '12:30', RAHMATULLAH, 'Circle of Cleft Dental Care', 'Dr. Madhvi Seshu', 'Session 3'],
  [
    D2,
    '12:30',
    '13:00',
    RAHMATULLAH,
    'Opportunities and Challenges in Dental Research in India',
    'Dr. Ambili',
    'Session 3',
  ],
  [D2, '13:00', '14:00', RAHMATULLAH, 'Lunch Break', NONE, ''],
  [D2, '14:00', '17:00', RAHMATULLAH, 'Free Papers / e-Posters', NONE, ''],

  // Day 2 — Dr C V Subbarao Hall
  [D2, '08:00', '10:00', SUBBARAO, 'Presentations for Hatton Awards', NONE, 'Hatton Awards'],
  [D2, '10:00', '18:00', SUBBARAO, 'Free Papers / e-Posters', NONE, ''],

  // Day 3 — Dr J G Kannappan Hall
  [
    D3,
    '09:00',
    '09:20',
    KANNAPPAN,
    'Non-Radiological Biomarkers in the Assessment of Pubertal Growth Spurt',
    'Dr. Arif Yezdani',
    'Session 8',
  ],
  [
    D3,
    '09:20',
    '09:50',
    KANNAPPAN,
    'Translating Research into Careers: Closing the Global Industry Skill Gap for the Next Generation of Dental Graduates',
    'Dr. Betsy Joseph',
    'Session 8',
  ],
  [
    D3,
    '09:50',
    '10:10',
    KANNAPPAN,
    'AI Denture in Prosthodontic Work: Evidence versus Clinical Feasibility for the Indian Scenario',
    panel('Dr. Gopi Chander', 'Dr. Siva Prakash'),
    'Session 8',
  ],
  [
    D3,
    '10:10',
    '10:50',
    KANNAPPAN,
    'Clinic to Evidence: Practice Based Clinical Dental Research for Indian Dentistry',
    panel('Dr. Sagar J Abichandani', 'Dr. S. Bhuminathan', 'Dr. Gopi Chander N', 'Dr. R. Narasimha Raghavan'),
    'Symposium 6',
  ],
  [
    D3,
    '10:50',
    '11:30',
    KANNAPPAN,
    'Perio Equity 2030: Translating Periodontal Science into Sustainable and Equitable Solutions for Low- and Middle-Income Countries',
    panel('Dr. Gopalakrishnan Dharmarajan', 'Dr. Anurag Satpathy', 'Dr. Ganesh Puttu'),
    'Symposium 7',
  ],
  [
    D3,
    '11:30',
    '12:10',
    KANNAPPAN,
    'Dr C. V. Subbarao Oration',
    NONE,
    'Speaker was not printed on the programme.',
  ],
  [
    D3,
    '12:10',
    '12:30',
    KANNAPPAN,
    'Cleft Care Treatment Protocol: Global versus Indian Scenario',
    panel('Prof. Dr. PS Thaha', 'Dr. Badri Thiruvenkatachari'),
    'Session 9',
  ],
  [
    D3,
    '12:30',
    '12:50',
    KANNAPPAN,
    'Beyond the Dental Chair: The Role of Dental Clinicians in Advancing Community Oral Health',
    'Dr. Ramanathan Ravi',
    'Session 9',
  ],
  [
    D3,
    '12:50',
    '13:30',
    KANNAPPAN,
    'One Root, Two Issues: The Regenerative Continuum in Endodontics and Periodontics',
    panel('Dr. Nandhini Suresh', 'Dr. Vamsi Lavu'),
    'Symposium 8',
  ],
  [
    D3,
    '13:30',
    '14:30',
    KANNAPPAN,
    'Lunch and Close',
    NONE,
    'End time was not printed on the programme; listed until 2:30 PM.',
  ],

  // Day 3 — Dr C V Subbarao Hall
  [D3, '09:00', '14:00', SUBBARAO, 'Free Papers / e-Posters', NONE, ''],
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

  const removed = await EventSchedule.deleteMany({ eventId: event._id });
  console.log(`Removed ${removed.deletedCount} existing schedule(s).`);

  const docs = PROGRAMME.map(([date, fromTime, toTime, hall, scheduleName, speakerName, description]) => ({
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
    description,
  }));

  const created = await EventSchedule.insertMany(docs);
  const byHall = {};
  for (const row of created) {
    byHall[row.hall] = (byHall[row.hall] || 0) + 1;
  }
  console.log(`Created ${created.length} schedules.`);
  for (const [hall, count] of Object.entries(byHall)) {
    console.log(`  ${hall}: ${count}`);
  }
  process.exit(0);
})().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
