# Triage Nov 21 (build m16.1, 0.14.0+981)

New rows: B-032, B-033, B-034 (all Triaged, notes written to the tracker).

- B-032 Cannot select 3 or 5 rounds (Lobby/joining). Plain bug, small. Likely: night_start_screen.dart:104-107 passes onChanged null when partyNightProvider is non-null; _pick (line 63) returns early. party_night.dart:68 start() sets the night before round 1; only end() clears it, so backing out leaves the chips dead with no hint. Proof: widget test (start, pop, tap 5 rounds). Fix: clear/reset the night on leaving before round 1, or show chips disabled.
- B-033 Award info cards differ in size. Plain bug, small. Likely (screenshots not viewed): the reveal card (night_reveal_widgets.dart:93, Column min size at :151-200) has content height, so won / tie / not-won differ. Start-card AwardTiles are equal (award_tile.dart:14, night_start_screen.dart:189). Fix: one min height. Owner to confirm which screen.
- B-034 Bottom bar lacks all-round black rounded border. Plain visual change, small. Sure: host_frame_screen.dart:181-186 Border(top: edge) only. Fix: full outline, cardCorner radius, inset a few px; adjust footer tests.

Older Triaged rows (no action): B-003 and B-010 ideas saved for M16 (proposal wanted); B-022 solo-night Race dropped by owner (future); B-026 Arena waiting card redesign to match Shape Race (M16).

Overlaps: none between the three (different files). One job covers all three (~40-60 turns).
