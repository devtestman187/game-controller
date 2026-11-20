# Thumb Party M16 — UX proposal: the app's start screen

Status: **proposal, with the owner's decisions (Nov 17–18).** Nothing is implemented. Evidence:
`findings/`, `research/` (including `onboarding-best-practices.md`). Mockups: frames 10–15 of
`mockups/proposal-mockups.html` (`proposal-10-*.png` … `proposal-15-*.png`, Sunny + Night).

## The problem, measured

On launch the controller app paints the pad/connect screen after ~4 s: a "Connecting… · tap to
connect" pill over 11 pad inputs, with **no title, no back affordance and no navigation**
(`_gap-inventory.md` stage 1). The useful choices — "Host a game", "Try without a TV",
"Settings" — exist only inside the connect screen's **error card**, reached after the first tap
targets a stale remembered host (`DESKTOP-NSUCJ8S`) and fails after 4.0 s (`vf-2dev-lifecycle`).

## The three device roles

"TV" is the wrong word for the display, because a phone or tablet can also host, and any device
can be display-only. The app has three roles, and the start screen must make all three a visible
choice:

- **Join a Game** — this device joins a game someone else is hosting (enter the pairing code).
- **Play here** — this device hosts *and* plays; no separate screen.
- **Display here** — this device is a display-only screen while another device hosts.

Thumby (M17): the three-role home stays as is. Inside "Play here", Party night becomes the first,
highlighted card in the game picker (`games_screen.dart`); the coach marks stay controller-side and
a separate host-side first-time-host flag is added (see PROPOSAL.md "Thumby integration (M17)").

## The decided design

- **Landscape**, matching the pad.
- **Home hub** on every launch: the **nickname + avatar** row (tap the avatar to edit), the
  three role buttons in a **fixed order** — **Join a Game / Play here / Display here** — and
  **Settings**. The buttons never swap positions; only the green highlight moves with the state
  (found screen → "Join a Game" green; no screen → "Play here" green).
- **Auto-join the last game** when its host is found, with an **"Auto-join last screen"** switch
  to turn it off. **"Remember this screen" stays a separate switch.**
- **First-time help = coach marks on the real Home screen, not a wizard.** The first time a user
  opens Home, the screen is **dimmed** and a hint box with an arrow points at one button at a
  time; each tap advances:
  1. **Join a Game** → "Join a friend's game"
  2. **Play here** → "Play on this screen or host a game"
  3. **Display here** → "Create and watch the game here. Control from another screen"
  A "Skip" affordance dismisses the hints early, and a **"Show tips"** switch in Settings replays
  them. This teaches on the actual control (better for an 8-year-old than a separate
  illustration) and matches the "contextual tips: minimal disruption" finding in the onboarding
  research.
- **No screen found** → the home leads with **Play here**.
- **Stale remembered host** (the current bug) → never a raw error; fall back to Home with the
  live discovered host listed.

## The screen's states

| State | What shows |
|---|---|
| First launch | Home (no screen found) with the dimmed coach marks over Join a Game → Play here → Display here |
| Later launches | Home with no coach marks (re-enabled only via "Show tips") |
| Known host found | Home: "Found nearby" + green "Join a Game" (auto-joins) |
| No host found | Home: "No screen found" chip + green "Play here" primary |
| Auto-join off | Home: "Join a Game" waits for a tap instead of auto-joining |
| Connecting | "Connecting…" toast over the pad; on failure → back to Home (no raw error) |
| Error / drop | Home's "Join a Game" shows "search again"; no dead-end error card |
| Empty identity | Identity row shows a default worker and "Tap to add your name" |

## Decisions (owner)

1. Landscape.
2. Auto-join the last game, with a Settings toggle to disable it.
3. First-time help is coach marks on Home (not a wizard); "Show tips" replays them.
4. Nickname + avatar on top; tap the avatar to modify.
5. "Remember this screen" is a separate switch.
6. Three device roles: Join a Game / Play here / Display here, in a fixed button order.
7. Generic display-device strings use "screen", not "TV" (the app/platform names "Thumb Party TV"
   and "Android TV" stay).

## Remaining open questions

- QR pairing is future work; the code is what's implemented today.
