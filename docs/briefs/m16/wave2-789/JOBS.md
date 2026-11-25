# wave2-789: what wave1-789 left unbuilt from items 7-9 (Nov 24, measured tune2 batch)

Owner decisions applied (plan789/QUESTIONS.md "Owner answers"): Q1-Q7 accept merged recommendations. Q3 A (marks to everyone: a missing saved key means show), Q4 A (no auto-join switch; failure goes to Home), Q5 B (no first-time-host flag), Q6 B (400 lines, no 9f), Q7 A (pad only when the last host is found live within the discovery wait, which `reconnectToLastHost` already does; otherwise Home). Item 7 is done (wave1-789, bugs4). Design from docs/briefs/m16/ux-review/APP-START.md (roles Join a Game / Play here / Display here, marks 1-3, states table minus auto-join).

Item 8 contract (decided here, held in n8a): root stays ControllerScreen; an unpaired launch pushes Home (not Connect); Back on a launch Home exits the app; Home reached from the pad's menu returns to the pad; Join a Game opens the Connect screen (list + code); Play here = host onPhone, Display here = host onDevice, no sheet; one saved key `showTips` (missing = true; finishing or Skip sets false; the Settings switch sets it); marks run only while Home is idle (consent answered, nothing connecting, no dialog); consent: one ask function, two entry points (Home, pad); a failed connect on the pad returns to Home.

| Job | Wave | Model | What |
|---|---|---|---|
| n8a | 1 | haiku | contract: HomeRole, HomeAnchors, highlight rule, showTips provider, HomeText |
| n9b1 | 1 | sonnet | 48 dp measuring test, controller_app, recorded offender list |
| n9e | 1 | haiku | Resume on the host pause card in `good` |
| n8b0 | 2 | haiku | extract host start into a function, behaviour-free |
| n8c | 2 | sonnet | coach marks overlay widget |
| n9sr | 2 | haiku | Shape Race HUD "Round N of M" |
| later waves | 3-7 | | briefs written at each pause: n8b1 Home widget (sonnet); n9b2 fix offenders; n9b3 party_host 48 dp; n8b2 HomeScreen wiring; n8d1 marks wiring; n8d2 Show-tips switch; n8b3 launch routing, failure to Home, repins; n8e inventory then sweeps per text file; TV-word guard test last; fix jobs f<n> from wave reviews |

Owner question (not blocking): 9e on the phone pad. The pad has no Resume button; during a pause the Start pill is relabelled "Resume" and filled with the player's colour (pad_widgets.dart SmallButton, PadFill). Making it `good` loses the player colour there. Applied: host card only; the phone pill job (n9e2) waits for the owner.
Known failing on the base: the pad top bar overflows 12 px at 568x320 in the TV look (controller_top_bar.dart:89).
