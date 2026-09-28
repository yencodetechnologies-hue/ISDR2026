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
import { ChangePassword, ParticipantProfile, QrPass } from "./pages/common/Profile";
import ScheduleDetail from "./pages/common/ScheduleDetail";
import { HelpTickets, TicketChat } from "./pages/common/Support";
import ParticipantCertificate from "./pages/participant/Certificate";
import ParticipantExhibitors from "./pages/participant/Exhibitors";
import ParticipantHome from "./pages/participant/Home";
import { AboutIsdr, Accommodation, Committee, StudentConference } from "./pages/participant/Info";
import { AllSessions, Favorites, ParticipantMore, Speakers, UpcomingSchedules } from "./pages/participant/Lists";
import { AskSpeaker, MyQuestions, ParticipantPolls, ParticipantQa } from "./pages/participant/QaPolls";
/* Speaker */
import { SpeakerHome, SpeakerSessionPicker, SpeakerSessionQuestions, SpeakerSessionPolls, SpeakerPollEditor, SpeakerParticipantQuestions, SpeakerMore } from "./pages/speaker/Speaker";
/* Admin */
import AdminHome from "./pages/admin/Home";
import { EventList, EventEditor, EventDetail } from "./pages/admin/Events";
import { ScheduleList, EventSchedules, ScheduleEditor } from "./pages/admin/Schedules";
import ManageSpeakers from "./pages/admin/Speakers";
import ManageExhibitors from "./pages/admin/Exhibitors";
import ManageBanner from "./pages/admin/Banner";
import { ManageTicker, ManageYoutubeLive, SendNotification, EngagementOverview, ManageCertificates, ManagementTeam, AdminProfile, AdminMore } from "./pages/admin/Settings";
/* Staff */
import { StaffHome, StaffEventList, StaffEventDetail, StaffMore } from "./pages/staff/Staff";

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

        {/* Any signed-in role */}
        <Route element={<Guard />}>
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/schedule" element={<ScheduleDetail />} />
          <Route path="/qr-pass" element={<QrPass />} />
          <Route path="/my-profile" element={<QrPass />} />
          <Route path="/change-password" element={<ChangePassword />} />
          <Route path="/brochure" element={<Brochure />} />
          <Route path="/awards" element={<Awards />} />
          <Route path="/feed" element={<Feed />} />
          <Route path="/support" element={<HelpTickets />} />
          <Route path="/support/:id" element={<TicketChat />} />
        </Route>

        {/* Participant */}
        <Route element={<Guard roles={["participant"]} />}>
          <Route path="/participant" element={<ParticipantHome />} />
          <Route path="/participant/schedules" element={<UpcomingSchedules />} />
          <Route path="/participant/sessions" element={<AllSessions />} />
          <Route path="/participant/favorites" element={<Favorites />} />
          <Route path="/participant/speakers" element={<Speakers />} />
          <Route path="/participant/more" element={<ParticipantMore />} />
          <Route path="/participant/feed" element={<Feed />} />
          <Route path="/feed/camera" element={<SelfieCamera />} />
          <Route path="/participant/committee" element={<Committee />} />
          <Route path="/participant/about" element={<AboutIsdr />} />
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
          <Route path="/admin/schedules/event/:eventId" element={<EventSchedules />} />
          <Route path="/admin/schedules/new" element={<ScheduleEditor />} />
          <Route path="/admin/speakers" element={<ManageSpeakers />} />
          <Route path="/admin/exhibitors" element={<ManageExhibitors />} />
          <Route path="/admin/banner" element={<ManageBanner />} />
          <Route path="/admin/ticker" element={<ManageTicker />} />
          <Route path="/admin/youtube" element={<ManageYoutubeLive />} />
          <Route path="/admin/send-notification" element={<SendNotification />} />
          <Route path="/admin/engagement" element={<EngagementOverview />} />
          <Route path="/admin/certificates" element={<ManageCertificates />} />
          <Route path="/admin/team" element={<ManagementTeam />} />
          <Route path="/admin/profile" element={<AdminProfile />} />
          <Route path="/admin/more" element={<AdminMore />} />
        </Route>

        {/* Staff (Event Staff / User / Tenant) */}
        <Route element={<Guard roles={["user"]} />}>
          <Route path="/staff" element={<StaffHome />} />
          <Route path="/staff/events" element={<StaffEventList />} />
          <Route path="/staff/events/:id" element={<StaffEventDetail />} />
          <Route path="/staff/more" element={<StaffMore />} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  );
}
