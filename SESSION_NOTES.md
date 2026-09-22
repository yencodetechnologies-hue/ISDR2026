# Session Notes — ISDR2026

Summary of work completed in this chat session.

## Profile / Event Management pages
- Added Profile, Send Notification, and Event Schedules tiles.
- Restyled Profile page (several iterations), reverted to the app's own color palette, made it compact, fixed button clipping.
- Restyled Event Management details page similarly, then reverted color changes.
- Removed "Role / Designation" field from the Add Management ID form.
- Removed "Copy Link" button and the duplicate empty-state "Add Event Staff" button on the Event Staff screen.
- Added a "Change Password" card to the Profile page; fixed duplicate "Event Management" text; made the page compact.

## Event Schedules feature
- New flow: list of events → tap → list of schedules for that event → "Add Schedule" form (photo, speaker name, schedule name, date restricted to the event's actual days, from/to time, description).
- Backend CRUD: `backend/models/EventSchedule.js`, `backend/controllers/eventScheduleController.js`, routes in `backend/routes/managedEventRoutes.js`.
- Live/upcoming/tomorrow/date status banners with a pulsing "LIVE" indicator; live items sorted first.

## Dashboard / navigation cleanup
- Removed the leftover "Users" page.
- Dashboard's "Event Staff" stat card now opens the real Event Staff screen.
- Removed 4 unused Flutter routes: `securityRegistration`, `supportChat`, `viewAds`, `addAds`.
- Removed the role-selection page entirely (`user_type_selection_page.dart` deleted); the login page is now the standard landing page for all roles; removed the "Login Type: X" capsule.
- Removed the Profile icon from the app bar.
- Stopped the dashboard from repeatedly hitting missing backend routes (`/api/notifications/unread-count`, `/api/apartments/:id`, `/api/blocks`, `/api/complaints`).

## Scan summary feature
- Ported the old project's per-inclusion Scanned / Not-scanned / Rejected scan-summary feature into ISDR2026.
- `backend/models/EventClaimAttempt.js` (copied from old project), `backend/controllers/claimSummaryController.js` (adapted `claimSummary`, uses `normalizeInclusions` exported from `managedEventController.js`).
- Route: `GET /summary` (management-protected) registered before `/:id` in `managedEventRoutes.js`.
- `event_management_details_page.dart`: added `_incStats`, `_loadIncStats()`, `_statPill()`, always-visible inclusion stat pills, reloaded after package/registration changes.

## Event Staff accounts + login
- Full staff CRUD (registration, listing, activate/deactivate, status, edit, delete) mirroring the old project.
- `backend/models/EventStaff.js`, `backend/controllers/staffController.js`.
- Staff log in via the same `/auth/login` as management, via a cascading lookup in `authController.js` / `middleware/auth.js`.
- Hid the auto-generated "@username" from the staff card.

## Participant accounts + login
- All participants given a default login password `123456`.
- `backend/models/EventRegistration.js`: added `password` field (select:false) with bcrypt pre-save hook + `comparePassword`.
- `backend/controllers/managedEventController.js`: `DEFAULT_PARTICIPANT_PASSWORD = '123456'` set on `createParticipantRegistration`.
- `backend/scripts/setDefaultParticipantPasswords.js`: migration script, already run against the live DB.
- Login cascade in `authController.js`: `loginUser` tries management → staff → participant, regardless of the `userType` sent from the app.
- `lib/core/models/user_model.dart`: added `UserType.participant`.
- New empty participant home page: `lib/features/participant/presentation/pages/participant_home_page.dart` (placeholder for now).
- `lib/core/routes/app_routes.dart`: added `participantHome` route.

## Backend config
- Backend URL switched between live (`https://isdr2026.yencodetechnologies.in/api`) and local (`10.0.2.2:7012` / `192.168.100.247:7012`) multiple times; currently set to **live**.
- `lib/core/config/api_config.dart` — local URLs point at port `7012` to match `.env`'s `PORT=7012`.

## Login page redesign
Major rebuild of `lib/features/auth/presentation/pages/login_page.dart` to match a supplied mockup:
- Single non-scrollable view that fills the screen edge-to-edge (no gaps, no stretching) using a fixed virtual canvas (`SizedBox(width: 400, height: 900)`) scaled with `FittedBox(fit: BoxFit.cover, alignment: Alignment(0, -0.4), clipBehavior: Clip.hardEdge)`.
- Hero: real supplied conference photo (`assets/WhatsApp Image 2026-09-22 at 11.46.04 AM.jpeg`) with all branding baked into the image — no overlaid logo/title text, no separate wave clip (image has its own curved edge).
- White login card: avatar with flanking lines, "Welcome Back" title/subtitle, email field, password field with show/hide, Remember-me checkbox + Forgot Password row, gradient "Login" button. No "OR" divider, no "Secure Access" box (both removed per feedback).
- Footer: blue gradient wavy strip (`_FooterWave`) with a lighter wave accent layered along the top edge, "IADR • INDIAN DIVISION" text, and a small white pill/line beneath it — replacing the earlier dark-navy version.
- Card position/size and hero crop alignment tuned several rounds based on screenshots (card moved up/down, size increased, hero top-crop fixed, footer-visibility regression fixed by reducing canvas height 960→900 and softening `FittedBox` alignment from `topCenter` to `(0, -0.4)`).
- Removed unused `AutoScrollBanner` usage from the login page (widget file still exists with 3 real images wired in, but is no longer referenced).

## Known follow-ups (not yet done)
- Participant home page is intentionally still empty.
- "Remember me" checkbox is visual only — not wired to persistence.
- Other previously-flagged backend 404 routes beyond the ones explicitly fixed may still exist.
