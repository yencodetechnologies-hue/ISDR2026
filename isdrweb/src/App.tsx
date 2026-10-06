import { useEffect } from "react";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import Guard from "./components/Guard";
import ForgotPassword from "./pages/auth/ForgotPassword";
import Login from "./pages/auth/Login";
import Splash from "./pages/auth/Splash";
import WaitingApproval from "./pages/auth/WaitingApproval";
import Awards from "./pages/common/Awards";
import Brochure from "./pages/common/Brochure";
import { Feed, SelfieCamera } from "./pages/common/Feed";
import Notifications from "./pages/common/Notifications";
import { ChangePassword, ParticipantProfile, QrPass, RoleQrPass } from "./pages/common/Profile";
import ScheduleDetail from "./pages/common/ScheduleDetail";
import { HelpTickets, TicketChat } from "./pages/common/Support";
import ParticipantCertificate from "./pages/participant/Certificate";
import ParticipantExhibitors from "./pages/participant/Exhibitors";
import ParticipantHome from "./pages/participant/Home";
import { AboutIsdr, Accommodation, Committee, StudentConference } from "./pages/participant/Info";
import ParticipantPreconference from "./pages/participant/Preconference";
import { AllSessions, Favorites, ParticipantMore, Speakers, UpcomingSchedules } from "./pages/participant/Lists";
import { AskSpeaker, MyQuestions, ParticipantPolls, ParticipantQa } from "./pages/participant/QaPolls";
import { AvailableInclusionsApp, ClaimedInclusionsApp } from "./pages/participant/InclusionsApp";
/* Speaker */
import {
  SpeakerHome,
  SpeakerSessionPicker,
  SpeakerSessionQuestions,
  SpeakerSessionPolls,
  SpeakerPollEditor,
  SpeakerParticipantQuestions,
  SpeakerMore,
} from "./pages/speaker/Speaker";
/* Admin */
import AdminHome from "./pages/admin/Home";
import { AdminMoreModules } from "./pages/admin/AdminHomeApp";
import { StaffAddApp, StaffEditApp } from "./pages/admin/StaffApp";
import { SpeakerFormApp } from "./pages/admin/SpeakersApp";
import { ExhibitorFormApp } from "./pages/admin/ExhibitorsApp";
import { EventList, EventEditor, EventDetail } from "./pages/admin/Events";
import { ScheduleList, EventSchedules, ScheduleEditor } from "./pages/admin/Schedules";
import ManageSpeakers from "./pages/admin/Speakers";
import SpeakerQuestions from "./pages/admin/SpeakerQuestions";
import ManageExhibitors from "./pages/admin/Exhibitors";
import ManagePreconference from "./pages/admin/Preconference";
import ManageSchedulePdf from "./pages/admin/SchedulePdf";
import ManageUgPaperPdf from "./pages/admin/UgPaperPdf";
import ManageHallArrangementPdf from "./pages/admin/HallArrangementPdf";
import ManagePaperPosterPdf from "./pages/admin/PaperPosterPdf";
import UgPaperPdf from "./pages/common/UgPaperPdf";
import HallArrangementPdf from "./pages/common/HallArrangementPdf";
import PreconferencePdf from "./pages/common/PreconferencePdf";
import PaperPosterPdf from "./pages/common/PaperPosterPdf";
import ManageBanner from "./pages/admin/Banner";
import {
  ManageTicker,
  ManageYoutubeLive,
  ManageLivePhoto,
  SendNotification,
  EngagementOverview,
  ManageCertificates,
  ManagementTeam,
  AdminProfile,
  AdminMore,
} from "./pages/admin/Settings";
/* Staff */
import { StaffHome, StaffEventList, StaffEventDetail, StaffHistory, StaffMore } from "./pages/staff/Staff";

function ScrollToTop() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

export default function App() {
  return (
    <>
      <ScrollToTop />
      <Routes>
        <Route path="/" element={<Splash />} />
        <Route path="/login" element={<Login />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
        <Route path="/waiting-approval" element={<WaitingApproval />} />

        {/* Full-screen selfie camera (no sidebar) */}
        <Route element={<Guard roles={["participant"]} />}>
          <Route path="/feed/camera" element={<SelfieCamera />} />
        </Route>

        {/* Every signed-in page renders inside the website shell */}
        <Route element={<Guard shell />}>
          {/* Any signed-in role */}
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/schedule" element={<ScheduleDetail />} />
          <Route path="/qr-pass" element={<QrPass />} />
          <Route path="/pass" element={<RoleQrPass />} />
          <Route path="/my-profile" element={<QrPass />} />
          <Route path="/change-password" element={<ChangePassword />} />
          <Route path="/brochure" element={<Brochure />} />
          <Route path="/awards" element={<Awards />} />
          <Route path="/feed" element={<Feed />} />
          <Route path="/support" element={<HelpTickets />} />
          <Route path="/support/:id" element={<TicketChat />} />
          <Route path="/sessions" element={<AllSessions />} />
          <Route path="/speakers" element={<Speakers />} />
          <Route path="/accommodation" element={<Accommodation />} />

          {/* Participant */}
          <Route element={<Guard roles={["participant"]} />}>
            <Route path="/participant" element={<ParticipantHome />} />
            <Route path="/participant/schedules" element={<UpcomingSchedules />} />
            <Route path="/participant/sessions" element={<AllSessions />} />
            <Route path="/participant/favorites" element={<Favorites />} />
            <Route path="/participant/speakers" element={<Speakers />} />
            <Route path="/participant/more" element={<ParticipantMore />} />
            <Route path="/participant/feed" element={<Feed />} />
            <Route path="/participant/committee" element={<Committee />} />
            <Route path="/participant/about" element={<AboutIsdr />} />
            <Route path="/participant/preconference" element={<ParticipantPreconference />} />
            <Route path="/participant/preconference/pdf" element={<PreconferencePdf />} />
            <Route path="/participant/ug-paper" element={<UgPaperPdf />} />
            <Route path="/participant/hall-arrangement" element={<HallArrangementPdf />} />
            <Route path="/participant/paper-poster" element={<PaperPosterPdf />} />
            <Route path="/participant/conference" element={<StudentConference />} />
            <Route path="/participant/accommodation" element={<Accommodation />} />
            <Route path="/participant/awards" element={<Awards />} />
            <Route path="/participant/exhibitors" element={<ParticipantExhibitors />} />
            <Route path="/participant/certificate" element={<ParticipantCertificate />} />
            <Route path="/participant/qa" element={<ParticipantQa />} />
            <Route path="/participant/qa/ask" element={<AskSpeaker />} />
            <Route path="/participant/qa/mine" element={<MyQuestions />} />
            <Route path="/participant/polls" element={<ParticipantPolls />} />
            <Route path="/participant/profile" element={<ParticipantProfile />} />
            <Route path="/participant/inclusions/available" element={<AvailableInclusionsApp />} />
            <Route path="/participant/inclusions/claimed" element={<ClaimedInclusionsApp />} />
          </Route>

          {/* Speaker */}
          <Route element={<Guard roles={["speaker"]} />}>
            <Route path="/speaker" element={<SpeakerHome />} />
            <Route path="/speaker/sessions" element={<SpeakerSessionPicker />} />
            <Route path="/speaker/qa" element={<SpeakerSessionQuestions />} />
            <Route path="/speaker/polls" element={<SpeakerSessionPolls />} />
            <Route path="/speaker/polls/edit" element={<SpeakerPollEditor />} />
            <Route path="/speaker/questions" element={<SpeakerParticipantQuestions />} />
            <Route path="/speaker/more" element={<SpeakerMore />} />
          </Route>

          {/* Admin (Management / Apartment) */}
          <Route element={<Guard roles={["apartment"]} />}>
            <Route path="/admin" element={<AdminHome />} />
            <Route path="/admin/events" element={<EventList />} />
            <Route path="/admin/events/new" element={<EventEditor />} />
            <Route path="/admin/events/:id" element={<EventDetail />} />
            <Route path="/admin/schedules" element={<ScheduleList />} />
            <Route path="/admin/schedule-pdf" element={<ManageSchedulePdf />} />
            <Route path="/admin/ug-paper-pdf" element={<ManageUgPaperPdf />} />
            <Route path="/admin/hall-arrangement" element={<ManageHallArrangementPdf />} />
            <Route path="/admin/paper-poster" element={<ManagePaperPosterPdf />} />
            <Route path="/admin/schedules/event/:eventId" element={<EventSchedules />} />
            <Route path="/admin/schedules/new" element={<ScheduleEditor />} />
            <Route path="/admin/speakers" element={<ManageSpeakers />} />
            <Route path="/admin/speakers/new" element={<SpeakerFormApp />} />
            <Route path="/admin/speakers/:id/edit" element={<SpeakerFormApp />} />
            <Route path="/admin/speakers/:id/questions" element={<SpeakerQuestions />} />
            <Route path="/admin/exhibitors" element={<ManageExhibitors />} />
            <Route path="/admin/preconference" element={<ManagePreconference />} />
            <Route path="/admin/exhibitors/new" element={<ExhibitorFormApp />} />
            <Route path="/admin/banner" element={<ManageBanner />} />
            <Route path="/admin/ticker" element={<ManageTicker />} />
            <Route path="/admin/youtube" element={<ManageYoutubeLive />} />
            <Route path="/admin/live-photo" element={<ManageLivePhoto />} />
            <Route path="/admin/send-notification" element={<SendNotification />} />
            <Route path="/admin/engagement" element={<EngagementOverview />} />
            <Route path="/admin/certificates" element={<ManageCertificates />} />
            <Route path="/admin/team" element={<ManagementTeam />} />
            <Route path="/admin/team/staff/new" element={<StaffAddApp />} />
            <Route path="/admin/team/staff/:id/edit" element={<StaffEditApp />} />
            <Route path="/admin/profile" element={<AdminProfile />} />
            <Route path="/admin/more" element={<AdminMore />} />
            <Route path="/admin/modules" element={<AdminMoreModules />} />
          </Route>

          {/* Staff (Event Staff / User / Tenant) */}
          <Route element={<Guard roles={["user"]} />}>
            <Route path="/staff" element={<StaffHome />} />
            <Route path="/staff/history" element={<StaffHistory />} />
            <Route path="/staff/more" element={<StaffMore />} />
          </Route>
          {/* Event list + scanning: event staff, and admins (the app's "Scan Inclusion") */}
          <Route element={<Guard roles={["user", "apartment"]} />}>
            <Route path="/staff/events" element={<StaffEventList />} />
            <Route path="/staff/events/:id" element={<StaffEventDetail />} />
          </Route>
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  );
}
