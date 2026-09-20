# Decisions — Fantasy Cat League for iOS

Numbered I1… so they can't be confused with the server's D1…
(`~/projects/fantasy-cat/DECISIONS.md`).

## I1 — Why a native app, and what it is not (2026-09-20)

Ryan decided to go native after a week of the web app on real iPhones. The
ledger that tipped it (server D30, D34): a long video picked from Photos never
reaches a web page, and iOS reports the failure as a cancel; password managers
inject UI into the page and break; notifications need an installed PWA. A
native app gets PHPicker with progress and the original file, system AutoFill
and passkeys, and APNs.

It is a second client, not a second product. The web app stays (Android,
desktop, invite links, anyone who won't install an app), the server stays the
only place rules live, and both clients are generated from one OpenAPI spec.

## I2 — Provisional technical choices, made before Xcode was even installed (2026-09-20)

Made by the agent while bootstrapping, to be confirmed or overturned by Ryan
at milestone 0; none has code depending on it yet.

- **SwiftUI, iOS 18 minimum.** A handful of friends on current iPhones; no
  reason to carry older APIs. Swift 6 language mode, strict concurrency.
- **XcodeGen** (`project.yml`), generated project not checked in. An agent
  can't click through Xcode's project editor; a text file it can edit, and it
  never conflicts. Tuist would also do; XcodeGen is smaller.
- **Swift OpenAPI Generator** against the server's `openapi.json`, which
  already exists and is kept honest by a CI drift check. The spec is copied in
  by a script, not hand-edited.
- **Not React Native / Capacitor / a webview.** A wrapper keeps exactly the
  problems this app exists to escape: the web file picker and injected
  password-manager UI.
- **Bundle id `co.fantasycat.app`** (reverse of the domain). Needs Ryan's team.
- **Distribution: TestFlight**, which needs the paid Apple Developer Program.
  A free account can only put a build on Ryan's own phone for 7 days at a time
  and can't use push or associated domains (so no passkeys), which rules it
  out for anyone but him.

## I3 — What the server has to grow first (2026-09-20)

Found by reading the API as a native client would:

- **Auth.** Sessions are an HttpOnly cookie plus an Origin check. URLSession
  can carry the cookie and sends no Origin, so it works today, but a token the
  app stores in the Keychain and sends as `Authorization: Bearer` is the
  right shape (survives cookie-store resets, works in background uploads and
  the notification extension). Server change, small.
- **Passkeys and password AutoFill** need
  `/.well-known/apple-app-site-association` naming `<TeamID>.co.fantasycat.app`
  under `webcredentials`. Same file enables universal links, so an invite link
  opens the app. Needs the Team ID.
- **Google sign-in** needs an iOS OAuth client, or (simpler, no SDK) the
  existing web flow inside `ASWebAuthenticationSession` ending in a redirect
  the app catches.
- **Sign in with Apple** becomes mandatory for App Store review once Google
  is offered (guideline 4.8). New provider on the server.
- **Push** needs an APNs key, a device-token endpoint, and the reminder job
  sending to it alongside email.
- **Uploads.** The app should send the original HEVC (smaller than what Safari
  transcodes to) in a background URLSession, and can trim on the device with
  AVFoundation before uploading, so the 100 MB cap stops mattering.

## I4 — Keep a real Xcode project; XcodeGen dropped (2026-09-20, revises I2)

Ryan installed Xcode 27 and created a project from the template. Reading it
changed the plan. Projects now use **file-system-synchronized groups**: a
folder on disk *is* the group, so adding, moving or deleting a source file
never touches `project.pbxproj`. That was the whole case for XcodeGen (an
agent can't click through the project editor, and the file conflicts). What's
left that lives in the project file is settings, capabilities and package
dependencies, which change rarely. They're plain text in `project.pbxproj`
and were edited there directly at milestone 0; move them to `.xcconfig` files
if that ever gets fiddly. Against XcodeGen: Xcode manages signing and capabilities natively, Ryan
can open the project like any other, and there is no generate step to forget.
So: a normal checked-in `.xcodeproj`, `.gitignore`
updated to stop ignoring it (still ignoring `xcuserdata/`).

What the template chose that milestone 0 will change, and why:
- **Multiplatform (iPhone, iPad, Mac, Vision Pro)** -> iPhone only. Every
  extra destination is a layout to design and a review surface; PLAN.md puts
  iPad out of scope.
- **Minimum OS 27.0** -> 18.0. The template defaults to the newest OS, which
  would lock out any phone not yet updated. Confirm against Ryan's and
  Rebecca's phones.
- **Placeholder bundle id, no team** -> `co.fantasycat.app` and Ryan's team.
- **Swift 5 language mode** -> Swift 6, strict concurrency, while it's empty
  and free to do.
- **Xcode made its own git repository inside ours** (`FantasyCat/.git`, one
  automatic "Initial Commit"). It must be removed before the folder can be
  committed, or git records it as an empty submodule pointer. Left untouched
  until Ryan says so, since he made it. For next time: untick "Create Git
  repository on my Mac" in the save dialog.
- The project sits at `FantasyCat/FantasyCat.xcodeproj`; it moves to the repo
  root so the repo is the project.

## I5 — One source for the look, two clients (2026-09-20)

The web app's theme is compiled from `design/tokens.json` in the server repo,
but the compiler left the arithmetic to the browser (`hsl()` with variables,
`color-mix(in oklab)`), which Swift can't evaluate. Rather than copy hex values
by hand, that compiler now also writes `design/tokens.resolved.json` with every
token as a concrete value, and a checker there paints each CSS variable in
Chrome and compares (all 32 colors match within 1/255). `scripts/gen-tokens.py`
here only transcribes that file into `Design/Tokens.swift`. Change the accent
in one JSON file and both apps follow.

- **Fonts are bundled and registered in code** (`CTFontManagerRegisterFontsForURL`
  at launch), not listed in Info.plist, so the generated Info.plist stays
  generated. Bricolage Grotesque and Instrument Sans are variable fonts, set by
  their `wght` axis so any weight the web uses is available; Barlow Condensed is
  three static files. All SIL OFL; the licence texts ship beside them.
- **Type scales with Dynamic Type** through `UIFontMetrics`, each style tied to
  a system text style. Sizes are the web's pixel values read as points.
- **Buttons are at least 44 pt tall** where the web's are 40 px: a finger, not a
  cursor. The only deliberate departure from the web's metrics so far.
- **A gallery screen** (`-gallery` launch argument) is this app's counterpart of
  the reference page, there to be screenshotted, since an agent can't eyeball a
  SwiftUI preview.

## I6 — The API client: generated on the command line, checked in (2026-09-20)

Swift OpenAPI Generator is normally an Xcode build plugin. That needs a
"trust this plugin" click nobody is there to make in a headless build, and
wiring a plugin into `project.pbxproj` by hand is fragile. So `make api` runs
the generator from a tiny tool package (`Tools/openapi`) and the output is
committed under `FantasyCat/API/Generated`. The app then depends only on the
two small runtime packages. Cost: the generated code can go stale against the
spec; a CI drift check (regenerate, `git diff --exit-code`) is the remedy once
CI exists.

Settings this forced, both departures from Xcode 27's template:
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` removed.** With it, every
  generated type was main-actor-isolated and couldn't be decoded off the main
  thread. Views are main-actor anyway; models say `@MainActor` themselves.
- `SWIFT_APPROACHABLE_CONCURRENCY` stays on, which is why the middleware's
  `next` closure is spelled `@concurrent @Sendable`.

Session handling: `URLSession` has its cookie storage switched off, so the
Keychain token is the only credential and can't disagree with a cookie jar.
The token is stored `AfterFirstUnlockThisDeviceOnly`: readable by a
background upload while the phone is locked, never restored onto another
device.

**Dates.** Go writes RFC 3339 with however many fractional digits the time
has, or none. The generated client's default parser takes only the latter, so
the first real sign-in got a 200 from the server and an error on screen.
`ServerDateTranscoder` normalises to milliseconds before parsing. Unknown
failures now print in debug builds (`make console`) instead of vanishing into
"Something went wrong".

**Debug launch arguments** (`-api <url>`, `-autologin <user> <password>`,
`-signout`, `-gallery`) exist because an agent can't tap the Simulator. They
drive the same code a person's tap does, and are compiled out of release
builds.
