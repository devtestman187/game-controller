# TV test app

Test bench and connection host for the controller. One codebase runs on **Android TV 12+ (API 31)** and as a **Windows desktop app**. Store name **Thumb Party TV**, app ID `com.thumbparty.tv` (Play never allows changing it). Version 0.8.0 (Milestone 8).

It hosts the controller server and advertises it on the network (mDNS), shows the pairing code, each controller's input, ping and input delay, and has a playable test game, a haptic test panel and a latency screen. Everything works with a TV remote and in a laptop window.

## The main screen
| Area | What it shows |
| --- | --- |
| Pairing code | The 4-digit code to enter on the phone. After 5 wrong codes in a row it changes on its own. |
| Address for manual entry | `IP:port` to type on the phone if discovery doesn't find the TV |
| Discovery line | Green when phones can find the TV via mDNS. If it fails, manual entry still works. |
| Sound line | "4 of 4 event sounds loaded" once the event sounds are ready |
| Controllers | Each phone with its **player badge** (P1, P2… in its colour), state (**Connected**, **Waiting for code**, **Disconnected**), its live input (a picture of its D-pad, buttons, tilt or sticks, lit while held), the ping (now, 30 s average and highest) and the estimated **input delay** |
| Log | Recent events, newest at the bottom, including a latency line per phone every 30 s |

Buttons (arrows to move, center/OK to press):
- **New code**: shows a different code. Phones that are already paired stay paired.
- **Simulate controller**: starts a controller inside the app that pairs on its own (PRD T3) and presses every button and direction in a loop. Press again to stop.
- **Drop connections**: closes every connection as if Wi-Fi dropped, so you can watch the phones reconnect by themselves.
- **Forget phones**: forgets the pairings of phones that aren't connected, so they need the code again.
- **Save log**: writes the log with a latency summary on top to a file (see below).
- At the top: **Test game**, **Haptic test** and **Latency**.

Pairings are saved: after the TV app restarts, paired phones reconnect without the code (up to 8 phones, most recent first).

While any controller is connected the app keeps the screen on, so the TV doesn't dim, start its screensaver or go to sleep mid-game (nobody touches the remote while playing). With no controller connected the TV sleeps as usual.

## Several controllers
Every phone that connects gets a player number, kept through short drops (a minute), and shown on the TV, on its sprite and on the phone itself. In the game each phone drives its own sprite, and only the phone whose sprite caused an event feels it.

## Test game
Get your sprite from the start pad to the green goal past the grey walls and the red hazards. The first to the goal wins the round; a new, mirrored round starts after 2 s. It plays with any phone mode: the D-pad moves at full speed, tilt or the left stick by how far you push, **A** dashes (a short burst with a cooldown ring), and the right stick moves an aim cursor.

| What happens | Haptic (to that player's phone) | Sound |
| --- | --- | --- |
| Bump a wall or the edge, or a hazard touches you | hit | `hit.ogg` |
| Reach the goal | success | `success.ogg` |
| Press A while the dash is cooling down | error | `error.ogg` |
| Dash | rumble | `rumble.ogg` |

The bar on top shows the round, the timer, the best time and, per player, wins, hits, dashes and whether the dash is ready. OK (center), Enter, D or F3 shows a debug overlay with each player's connection, ping, input delay, mode, values and buttons, the last haptic event and the sounds. Back (Esc on Windows) returns to the main screen.

## Haptic test
Four big buttons, **Hit**, **Success**, **Error** and **Rumble**, each sending that haptic event to every connected phone and playing its sound. **Intensity** (10–100%) and **Duration** (natural, or 100 ms to 2 s) are set with − and +.

## Latency
For each connected phone:
- **Input delay**: how long a press or a stick movement takes from the phone to this app, one way, estimated from the heartbeats (the two clocks are compared like NTP does; the ± shows how far off the estimate can be). Average, 95th percentile and highest over the last 30 s, and the average over the whole connection. The PRD target is about 50 ms; the screen says whether the 30 s average is within it.
- **Ping**: the full round trip, now and over the last 30 s.

It doesn't include the TV's own display delay (one frame or more, depending on the TV's picture mode), which no app can measure.

### Getting the log off the device
**Save log** (main screen or Latency screen) writes `controller-test-log-<date>-<time>.txt` and shows where:
- **Android TV**: the app's folder, `/sdcard/Android/data/com.thumbparty.tv/files/`. Copy it to the PC with
  ```powershell
  adb -s <TV-IP>:5555 pull /sdcard/Android/data/com.thumbparty.tv/files/ .
  ```
- **Windows**: your Downloads folder.

The file starts with each controller's ping and input delay, then every log line (up to 3000, about half an hour of a busy session).

## Windows setup
Toolchain: see [../docs/building.md](../docs/building.md) (needs Visual Studio 2022 with **Desktop development with C++** for the Windows build). Then, from the repo root:
```powershell
flutter pub get
cd tv_test_app
flutter test
```

## Install on the physical Android TV
1. TV: Settings → System → About → click **Android TV OS build** 7 times. Then Settings → System → Developer options → turn on **USB debugging** (or **Network/ADB debugging**).
2. TV IP: Settings → Network & Internet → your network.
3. PC, same network:
```powershell
adb connect <TV-IP>:5555                       # accept the "Allow debugging" prompt on the TV
cd tv_test_app
flutter build apk --release
adb -s <TV-IP>:5555 install -r build\app\outputs\flutter-apk\app-release.apk
```
4. Open **Thumb Party TV** from the launcher (banner tile; on Google TV look under Apps → Your apps).

Remote controls: arrows move focus, center/OK selects, Back exits.

## Run as a Windows desktop app
```powershell
cd tv_test_app
flutter run -d windows                         # development
flutter build windows --release
.\build\windows\x64\runner\Release\ThumbPartyTV.exe  # release build
```
The window is resizable. Arrow keys + Enter act like the TV remote.

### Windows Firewall
The phones connect to the laptop, so Windows must allow incoming connections to the app on your **private** network:
1. Make the Wi-Fi network Private: Settings → Network & internet → Wi-Fi → *your network* → **Network profile type: Private**.
2. Start the app. When Windows Defender Firewall asks, tick **Private networks**, untick Public, and click **Allow**.
3. If you missed or cancelled the prompt: Start → "Allow an app through Windows Firewall" → **Change settings** → find `ThumbPartyTV.exe` (or click **Allow another app…** and browse to `tv_test_app\build\windows\x64\runner\Release\ThumbPartyTV.exe`; for `flutter run` builds also allow `...\runner\Debug\ThumbPartyTV.exe`) → tick **Private** → OK.
   Or, in an **administrator** PowerShell, allow the port for every build:
   ```powershell
   New-NetFirewallRule -DisplayName "Thumb Party TV (TCP 45780)" -Direction Inbound -Protocol TCP -LocalPort 45780 -Action Allow -Profile Private
   ```
4. Check from the phone: open `http://<laptop address>:45780` in the phone's browser. A one-line page means connections get through.
5. The phones and the laptop must be on the **same Wi-Fi**. Guest networks and routers with "client/AP isolation" block both discovery and connections. Use manual IP entry if discovery is blocked but connections work.

If the laptop has several network adapters (WSL, Hyper-V, VPN), the screen lists Wi-Fi first. Use that address for manual entry.
