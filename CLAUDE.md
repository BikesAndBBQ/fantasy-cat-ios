# CLAUDE.md — Fantasy Cat League for iOS

> Shared conventions (work tracking, investigate→verify→fix→verify, secrets via
> `op`) live in `~/.claude/CLAUDE.md` and load automatically. This file is just
> the project-specific bootstrap. Keep it lean; don't duplicate global rules.

## What this is
The native iPhone client for Fantasy Cat League (https://fantasycat.co), the
weekly cat photo contest Ryan and Rebecca run for friends. It exists because
the web app can't do three things well on an iPhone: get a long video out of
Photos (the web picker fails silently), sign in without a password manager
fighting the page, and send notifications. It is a **client only**: the game,
its rules, accounts and media all live in the server at
`~/projects/fantasy-cat` (Go + Postgres on Railway). This repo never
re-implements a rule; it asks the API.

## Get up to speed (read first)
1. **PLAN.md** — milestones and what each must deliver.
2. **backlog.yaml** — live state: pending/blocked items + owner (ryan|agent).
3. **DECISIONS.md** — why things are the way they are (I1…).
4. `~/projects/fantasy-cat/DESIGN.md` (game rules, product surface),
   `DESIGN-SYSTEM.md` + `design/tokens.json` (the look: this app uses the same
   tokens), and `web/openapi.json` (the API contract this app is generated
   from). Decisions there are D1…; read D30 and D34 for why this app exists.
5. `git log`.

## Project specifics
- **Category: claude-managed (provisional, same as the server; Ryan to
  confirm)** — commit and push to `main`. **Always push with
  `git push origin-agent main`** (HTTPS); `origin` is Ryan's SSH remote and
  hangs without him. Nothing here deploys by itself: a TestFlight upload is
  outward-facing and needs Ryan until he says otherwise.
- **Stack:** Swift 6, SwiftUI, iOS 18+, iPhone only. A normal checked-in
  Xcode project with file-system-synchronized folders (add a file to the
  folder and it's in the target; no project-file edit) (I4). The API client is **generated** by Swift OpenAPI
  Generator from the server's `openapi.json`; never hand-write a request the
  spec already describes. Sessions are bearer tokens (server D36).
- **The server is the other half.** When the app needs something the API
  doesn't offer (token auth, an app-site-association file, a push endpoint),
  the change is made in `~/projects/fantasy-cat`, under that repo's rules, and
  the spec is regenerated. Don't work around a missing endpoint in the client.
- **Verify, don't assume:** `make build`, then run it in the Simulator and
  look: `make shot THEME=light OUT=.dev/x.png` builds, installs, launches and
  screenshots (then Read the PNG; check both themes). `make test` once there
  is a test target. The Simulator
  has no camera and an empty photo library, so anything touching Photos, the
  camera, passkeys or push must also be checked on a real phone, by Ryan, and
  the summary must say which was done.
- **Polish is not descopable**, as on the web: same tokens, both themes,
  Dynamic Type and VoiceOver from the start. **UI is built only from
  `FantasyCat/Design`**: colors from `Tokens` (generated, never edited: `make
  tokens`), type from `TypeStyle` via `.type(...)`, and the components in
  `Components.swift`, which mirror the web's `ui.tsx`. No raw colors, fonts or
  radii in a screen. New component? Add it to `GalleryView` and look at it:
  `make shot GALLERY=1 THEME=light`. The reference for how things should look
  is `design/design-system.html` in the server repo.
- Registered in agent-manager as `fantasy-cat-ios` (pending, see backlog).

## Working headless (when dispatched by GLaDOS / a peer agent)
- The dispatch Bash sandbox **rejects shell expansion** — `$(...)`, `${...}`,
  `$?`, backticks, even a bare `$VAR` — and only allows commands your checked-in
  `.claude/settings.json` allow-lists (by literal-prefix match; a dispatch cannot
  self-grant). **So any logic that touches a secret or needs shell expansion must
  live in a checked-in script that is allow-listed by path.**
- To call the agent-manager API from a dispatch, use inline `python3`. Full
  contract: **`agent-manager/AGENTS-API.md`**.

## Hard lines (never cross without Ryan's explicit buy-in)
- **No secrets in the repo, the app bundle or the build settings.** No API
  keys, no signing certificates, no `.p8`/`.p12`/`.mobileprovision` files.
  Signing is automatic through Ryan's Xcode account; anything else lives in
  the `FantasyCat` 1Password vault and is read with the project token, never
  the agent's (server repo D19).
- **Nothing ships to TestFlight or the App Store unattended.**
- **The app holds no game rules.** Scoring, deadlines, caps and who may vote
  for what come from the API. (They're product decisions made with Rebecca.)
- **Session tokens go in the Keychain**, never UserDefaults or a file.
  Full decisions + rationale live in `DECISIONS.md`; record decisions as you make
  them and mirror any new hard line here.
