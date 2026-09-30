# Participant phone view: plan and execution

## Goal

When a **participant** opens the website on a phone (screen narrower than 1024 px), every screen should look and behave like the ISDR 2026 mobile app. The desktop website (1024 px and wider) must stay exactly as it is now.

This follows the same method already used for the **Admin** role, which is finished.

## Rules

- Only the React website (`isdrweb/`) changes. No Dart/Flutter files are edited; the app is only read as the reference.
- Desktop view is untouched. Each converted page renders its phone version only when `useAppLayout()` is true.
- No database writes, no backend changes, no deploys unless asked.
- Screens copy the app exactly: layout, colours, fonts (Inter / Outfit / Sora), texts, icons, empty and error states.
- Navigation bars: the participant app shows a **bottom nav bar on the Home screen only** (Home · Favorites · Speaker · QR Pass · More). Other screens have a back arrow. The website will do the same.

## How it works (already built for Admin)

| Piece | File | What it does |
|---|---|---|
| Phone check | `src/lib/useMobile.ts` | `true` below 1024 px |
| Role switch | `src/lib/appLayout.ts` → `APP_LAYOUT_ROLES` | Roles that get the app look on phones. Today: `["apartment"]` (admin) |
| Shell | `src/components/Shell.tsx` | For those roles on a phone: no sidebar/top bar, just the page |
| Page wrapper | each page file | `export function X() { return useAppLayout() ? <XApp /> : <XWeb />; }` |
| Shared app parts | `src/components/app/*` | App bar, home header, banner carousel, live card, module grid, ticker, switches, fields, chips, FAB, sheets, dialogs |

To turn the participant role on, `"participant"` is added to `APP_LAYOUT_ROLES`.

## Screen list

App reference: `lib/features/participant/presentation/…` unless noted. Web: `isdrweb/src/pages/…`.

### A. New phone screens to build

| # | Screen | App reference | Web page / route | Notes |
|---|---|---|---|---|
| 1 | **Home + bottom nav** | `participant_home_page.dart` (2,829 lines) | `participant/Home.tsx` · `/participant` | Header, banner carousel, live show card, news ticker, module grid + "More", YouTube live capsule, admin banner, schedule section, accommodation header/banner, "Get live photos", Follow Us social links, **bottom nav** |
| 2 | More (all modules) | `_openMoreModules` in home page | `participant/Lists.tsx` `ParticipantMore` · `/participant/more` | Full module grid in app order and colours |
| 3 | Upcoming schedules | `upcoming_schedules_page.dart` | `Lists.tsx` `UpcomingSchedules` | |
| 4 | All sessions | `all_sessions_page.dart` | `Lists.tsx` `AllSessions` · also `/sessions` | |
| 5 | Favorites (My Schedule) | `favorites_page.dart` | `Lists.tsx` `Favorites` | Bottom-nav target |
| 6 | Speakers | `speakers_page.dart` | `Lists.tsx` `Speakers` · also `/speakers` | Bottom-nav target |
| 7 | QR Pass | `admin/…/my_profile_page.dart` (participant branch) + `widgets/inclusions_section.dart` | `common/Profile.tsx` `QrPass` · `/qr-pass` | Navy page, delegate badge, "ID • mobile" line, inclusions; keep the screenshot guard |
| 8 | Available / claimed inclusions | `available_inclusion_page.dart`, `claimed_inclusion_page.dart` | opened from the inclusions section | |
| 9 | My Profile | `participant_profile_page.dart` | `Profile.tsx` `ParticipantProfile` · `/participant/profile` | |
| 10 | Committee | `organizing_committee_page.dart` | `Info.tsx` `Committee` | |
| 11 | About ISDR | `about_isdr_page.dart` | `Info.tsx` `AboutIsdr` | |
| 12 | Student conference | `student_conference_page.dart` | `Info.tsx` `StudentConference` | |
| 13 | Exhibitors | `participant_exhibitors_page.dart` | `participant/Exhibitors.tsx` | |
| 14 | Certificate | `certificate/…/participant_certificate_page.dart` | `participant/Certificate.tsx` | Both certificates, locked/blurred until eligible, download |
| 15 | Q&A · Ask Speaker · My Questions | `participant_qa_page.dart` (3 pages) | `QaPolls.tsx` `ParticipantQa`, `AskSpeaker`, `MyQuestions` | |
| 16 | Polls | `participant_polls_page.dart` | `QaPolls.tsx` `ParticipantPolls` | |
| 17 | Session content (files, polls, questions under a program) | `widgets/session_content_section.dart` | `components/SessionContent.tsx` | Used inside Program Details, which is already converted |

### B. Already converted for Admin: check them as a participant

These phone screens exist and are shared. Each one gets a participant pass: log in as a participant, compare against the app, and fix any differences.

| Screen | File | What differs for participants |
|---|---|---|
| Program Details | `common/ScheduleDetailApp.tsx` | "Save to My Schedule" bottom button |
| Feed | `common/FeedApp.tsx` | Selfie camera FAB, own-post delete |
| Awards | `common/AwardsApp.tsx` | Accordion view ("Conference Awards") |
| Brochure | `common/Brochure.tsx` | None expected |
| Accommodation | `participant/AccommodationApp.tsx` | None expected |
| Help & Support | `common/SupportApp.tsx` | Title "Help & Support", "Add" FAB, new-ticket sheet, edit/delete own ticket, "New ticket" after closed |
| Notifications | `common/NotificationsApp.tsx` | None expected |
| Change Password | `common/ProfileApp.tsx` | None expected |
| Selfie camera | `/feed/camera` | Already full-screen; check only |

## Execution order

Each step: read the app screen → build the `…App.tsx` phone version → wire it with the wrapper → typecheck → screenshot at 412 px → compare with the app.

1. **Setup**
   - Add a participant login to the local preview tool (mock API + fake participant session), so screenshots can be taken without the real backend.
   - Add `"participant"` to `APP_LAYOUT_ROLES` locally.
2. **Home and bottom nav** (screens 1–2). This is the biggest screen and uses the most shared parts. Build the missing pieces first: YouTube live capsule, schedule section, accommodation banner, social links, then the bottom nav bar.
3. **Bottom-nav targets** (screens 5, 6, 7, 8): Favorites, Speakers, QR Pass with inclusions.
4. **Schedules** (screens 3, 4, 17): upcoming, all sessions, session content.
5. **Engagement** (screens 15, 16): Q&A (3 pages), Polls.
6. **Info pages** (screens 10–13): Committee, About, Student Conference, Exhibitors.
7. **Certificate and profile** (screens 9, 14).
8. **Shared screens check** (section B).
9. **Finish**
   - Desktop check: open every participant page at 1280 px and confirm nothing changed.
   - Remove the preview page (`isdrweb/public/_preview.html`) and stop the local servers.
   - `npx tsc -b` and `npm run build` must pass.
   - Report what changed and any app-vs-backend mismatches found (not fixed without asking).

## Verification for every screen

- Screenshot at 412 px wide next to the app screen: same order, spacing, colours, texts, icons.
- Buttons work against the same API calls the app makes (same endpoints and field names).
- Empty, loading and error states match the app.
- Desktop (1280 px) screenshot of the same route is unchanged.

## Out of scope

- Speaker and Event Staff roles: next, after participant.
- Backend changes or deploys.
- Any change to the Flutter app. Issues found in the app are only reported, for example the old `www.maccess.online` register link copied after creating an event.
