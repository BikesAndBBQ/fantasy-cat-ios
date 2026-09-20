# Plan — Fantasy Cat League for iOS

Each milestone ends with something Ryan can hold. "Done" means built, run,
looked at, and (where the Simulator can't prove it) tried on his phone.

0. **Toolchain and an empty app on Ryan's phone.** Xcode, XcodeGen, project
   generated from `project.yml`, `make build|test|run|shot`, CI on a macOS
   runner. App shows the wordmark in the design system's type and colors, both
   themes. Confirms signing works end to end before anything depends on it.
1. **Design tokens in Swift.** Generated from the server repo's
   `design/tokens.json` (same source as the web), plus the core components:
   button, field, chip, card, banner, avatar, rosette.
2. **API client and sign-in.** Generated client; bearer-token sessions
   (server change, I3); password sign-in with AutoFill; passkeys (needs the
   app-site-association file); Google via ASWebAuthenticationSession.
3. **Read the league.** This week, a category feed, the submission sheet,
   standings, results. No writing yet.
4. **Post.** PHPicker with progress and the original file, camera capture,
   on-device trim, background upload that survives leaving the app. This is
   the milestone the app exists for.
5. **Vote.** Ballot with the budget, steppers, the one animation.
6. **Notifications.** APNs, device registration, the four reminders.
7. **TestFlight to the league.** Sign in with Apple, privacy labels, invite
   links opening the app.

Out of scope until asked: iPad layout, widgets, offline, Android.
