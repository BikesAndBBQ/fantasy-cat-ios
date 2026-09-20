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
