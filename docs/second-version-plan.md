# Second version — the plan

**Status:** saved, **not accepted**, not started. `change-plan` wrote it on 2026-10-22
after the user's first real run, and the user asked to save it before answering. None of
the nine Questions below is answered yet. Nothing in `Sources/`, `Tests/`, `README.md` or
`CLAUDE.md` has been changed for it.

**To pick it up:** run `/change docs/second-version-plan.md`. Say "OK" to take every
recommended answer, or name the ones that differ. **Question 4 needs a choice from the
user first:** the toy's key tap needs Accessibility permission for the app that starts
it. The plan recommends Terminal.app, not IntelliJ IDEA, and starting the toy from
Terminal.app. Then `change-do` runs Run 1, `change-check` checks it, the user commits, and
the next run follows. Do and Check never run `git`, the kiosk or an event tap.

**What the user asked for**, in their words after running `make try`: "ok it works as
intended.. i did not notice the ide was in fullscreen mode so your window was on desktop
and did not pull focus . so i missed it .. so the function keys still work .. you need to
deactivate the cmd+space hotkey as it opens a menu that allows exit from the program ..
also it is possible to use volume and change brightness, it shouldn't.. now the
visualisations are not so mesmerizing? remove the letters and make something like fire and
water", and then "oh yeah let the mouse do something to".

## Plan — change: fire and water instead of shapes and letters, the mouse and trackpad react, the window opens over a fullscreen app and takes focus, and an event tap blocks Cmd+Space, volume, brightness and the function keys

**Goal:** A key press makes fire or water at the key's place, with no letters. The mouse and the trackpad make fire and water too. The toy opens over a fullscreen IDE or terminal and gets the keyboard. While the toy is the active app, Cmd+Space (Raycast), the volume, brightness and media keys, the function-row keys, and the other system hotkeys only make visuals and sound. When the toy is not the active app, it takes no key and no mouse event from the user. The exit combination and `--exit-after` work as before. Snapshots stay deterministic and are tested in pixels. Each run leaves `swift build`, `make test` and `make lint` passing.

### What I verified before Do starts

Nothing in the project changed. Nothing opened a window, activated an app, created a tap, froze the cursor, set presentation options or played sound. The scratch package is `/private/tmp/claude-502/-Users-colara-Sandbox-visualizationForBaby/fa49acb6-98f1-44a3-aa93-8f1e9642275f/scratchpad/probe2`. Its targets `ShapesOnly` and `TapShape` were only compiled, and each one starts with `fatalError` so that it cannot run by accident.

| What | How | Result |
|---|---|---|
| Baseline | `make test`, `make lint` | 44 tests in 7 suites pass. Lint is clean. |
| Machine | `sysctl hw.model`, `system_profiler`, `sw_vers` | Mac14,10 (MacBook Pro 16-inch, 2023), 3456x2234 Retina, so 1728x1117 points. macOS 26.7.1, Swift 6.4, SDK 27.0. Its top row is Esc, F1 brightness down, F2 brightness up, F3 Mission Control, F4 Spotlight, F5 Dictation, F6 Do Not Disturb, F7 to F9 media, F10 mute, F11 and F12 volume, then Touch ID. It has no keyboard light keys. |
| Top-row mode | `defaults read -g com.apple.keyboard.fnState` (plain and `-currentHost`) | Not set, so the top row does its special functions. `AppleFnUsageType = 0`: the Globe key does nothing. |
| Who started the agents | `ps` chain from this shell | zsh, then `claude`, then zsh, then **IntelliJ IDEA**. macOS attributes this process's permissions to IntelliJ IDEA. |
| Permission state | `AXIsProcessTrusted()` and `CGPreflightListenEventAccess()`, no prompt, in the probe | Both **false**. The responsible app is IntelliJ IDEA. Nothing started from IntelliJ's terminal has Accessibility today. I did not check Terminal.app. |
| Tap API | `CGEvent.h`, `CGEventTypes.h` | Taps at `kCGHIDEventTap` need root, so the toy uses `kCGSessionEventTap`. A tap gets key events only when the process is trusted for assistive devices. Without that, the system clears those bits from the mask without an error, and it returns NULL only if the mask is then empty. So **a tap that is created does not prove the permission**: check `AXIsProcessTrusted()` first. If the tap is slow or the user disables it, the callback gets `kCGEventTapDisabledByTimeout` or `ByUserInput`. `CGEventTapEnable` turns the tap on again. Releasing the port releases the tap. The header does not give the timeout value. |
| System-defined events | `IOLLEvent.h`, `ev_keymap.h`, `NSEvent.h` | `CGEventType` has no case for them. They are type 14 (`NX_SYSDEFINED`, `NSEventTypeSystemDefined`). Media keys are subtype 8 (`NX_SUBTYPE_AUX_CONTROL_BUTTONS`). The key types are SOUND_UP 0, SOUND_DOWN 1, BRIGHTNESS_UP 2, BRIGHTNESS_DOWN 3, MUTE 7, PLAY 16, NEXT 17, PREVIOUS 18, FAST 19, REWIND 20, ILLUMINATION_UP/DOWN/TOGGLE 21/22/23. Other subtypes are power key 1, aux mouse buttons 7, eject 10, sleep 11, restart 12, shutdown 13. `NSEvent(cgEvent:)` gives `subtype` and `data1`. **The headers do not document the layout of `data1`.** The layout that common practice uses is: key type = `(data1 >> 16) & 0xFFFF`, state = `(data1 >> 8) & 0xFF` (0x0A down, 0x0B up), repeat = `data1 & 1`. |
| Swift 6 shape of the tap | compiled `TapShape` | The first attempt failed with `type 'CGEvent' does not conform to the 'Sendable' protocol`. It returned `Unmanaged<CGEvent>` from `MainActor.assumeIsolated`. The working shape: the C callback copies the event into a `Sendable` struct (type, key code, autorepeat, flags, subtype, data1), asks the main actor only "swallow?", then returns `nil` or the event outside the main actor. It builds with no warning. The tap object reaches the callback through `userInfo` with `Unmanaged.passUnretained(self)`. |
| Activation | `NSApplication.h`, `NSRunningApplication.h`, compile | `activateIgnoringOtherApps:` is marked `API_TO_BE_DEPRECATED`. It compiles with **no warning**, and its doc says that with YES "the app activates regardless". The doc for `activate()` says "The framework also does not guarantee that the app will be activated at all" and relies on the other app calling `yieldActivation`. A terminal or IDE does not do that. The `NSRunningApplication` option `ActivateIgnoringOtherApps` "will have no effect" from macOS 14. The `NSApp` method's header has no such note. |
| Window over a fullscreen app | `NSWindow.h`, compile | `.canJoinAllSpaces`, `.fullScreenAuxiliary` ("can be shown with the fullscreen window"), `.stationary` ("Unaffected by exposé") and `.ignoresCycle` are all valid together. Each comes from a different "at most one" group. `.screenSaver` level and `acceptsMouseMovedEvents` compile. |
| Cursor freeze | `CGRemoteOperation.h` | `CGAssociateMouseAndMouseCursorPosition(false)` disconnects the cursor "while an application is in the foreground". Events keep a constant location but carry deltas. **The header says nothing about what happens on exit or on a crash.** |
| Hot corners and gestures | `defaults read com.apple.dock`, `com.apple.AppleMultitouchTrackpad` | Top-left = Mission Control (2), bottom-left = Application Windows (3), bottom-right = Quick Note (14). Three- and four-finger swipes and the pinches are on. App Exposé gesture is on. |
| Render cost of the design | offscreen Core Graphics only, 1728x1117, release build, median of 5 | First sizes (particles about 3% of the short side, glow on every reaction): 120 ms for 200 reactions, so that design is rejected. **Chosen sizes** (particles about 1.2%, glow on the newest 30 only): 200 reactions at full detail take 13.5 ms (max 16.3). 200 at half detail take 7.1 ms. A pile of 100 at full detail takes 5.8 ms. Radial gradients were faster than pre-rendered sprites (181 ms against 120 ms), so there are no sprites. Painted area is the cost, not the number of draw calls. |

### Design: fire and water

- **Fire or water** (Question 1): by keyboard row. The top three rows (function row, digits, Q row) make **water**, which falls. The bottom three rows (A row, Z row, Space row) make **fire**, which rises. The rule is `y < 0.5` on the key map. Each key always makes the same element, and the two meet in the middle of the screen.
- **Fire burst**, one key press, 1.5 s. The unit `u` is the short side of the screen.
  - 12 particles start at the key's place, each with a seeded start delay of 0 to 0.3 s. Each rises at 0.12 to 0.22 u/s, speeds up a little, and sways sideways (±0.012u at 1.5 to 3 Hz).
  - The radius goes from 0.010 to 0.016u down to 30%. The colour goes white-yellow, then orange, then dark red over each particle's life, and the particle fades over the last 40%.
  - Each particle is a radial gradient drawn with `CGBlendMode.plusLighter`, so dense fire turns yellow-white.
  - Only the newest 30 reactions also get a soft orange glow (radius 0.05u) for 0.6 s.
- **Water splash**, one key press, 1.5 s.
  - 2 flat ripple rings (height 0.45 of width) grow to 0.09u with an ease-out. The second ring starts 0.2 s later. Each ring thins and fades.
  - 8 droplets are thrown up (0.15 to 0.30 u/s, ±0.10 u/s sideways) and fall under gravity 0.9 u/s².
  - Light cyan to blue, with a white core gradient, drawn with normal blending. So water stays cool and clear, and fire glows on top of it.
- **Detail rule** (keeps 16 ms at the cap): up to 100 live reactions, full detail. Above 100, half detail (6 fire particles, 4 droplets, 1 ring). The half set is the first half of the same seeded sequence, so particles do not reshuffle.
- **Pile of 100 keys:** a wall of fire across the lower half rises and saturates to yellow-white along the three bottom rows. Splashes with overlapping rings fill the upper half, and droplets rain down towards the fire. Measured at about 6 ms.
- **Background:** unchanged, so the empty-scene test stays.
- **Deterministic:** each reaction stores a seed from the scene's `SeededRandom`. The particles are a pure function of (reaction, time, detail).
- **Sound** (Question 2): unchanged. A click plays the pentatonic note for its x position.

### Design: mouse and trackpad

- Moving, dragging and two-finger scrolling leave a **trail**. A trail reaction is a small version (3 embers, or 1 ring and 2 droplets, at 0.6 times the radius), at most 30 per second, with no sound. Any button press makes a **burst** with a note at the pointer.
- The pointer is a virtual point that core moves by the event deltas (`deltaX/deltaY`, `scrollingDeltaX/Y`). It starts at the centre and is clamped to the screen. One code path works with the cursor frozen or not. The element follows the same rule: top half water, bottom half fire.
- **Monitored events:** one local monitor for `.mouseMoved` (this needs `window.acceptsMouseMovedEvents = true`), `.leftMouseDragged`, `.rightMouseDragged`, `.otherMouseDragged`, `.leftMouseDown`, `.rightMouseDown`, `.otherMouseDown` and `.scrollWheel`. It returns `nil`.
  - A local monitor sees only events that AppKit dispatches to this app.
  - It does not see the three- and four-finger swipes, the pinches, Mission Control or hot corners. The Dock handles those before any app gets them.
  - It does not see the mouse while another app is active.
- **The tap does not take mouse events.** The local monitor already gets every mouse event in the toy's window. A mouse tap would add risk to the user's own mouse and nothing for the toy.
- **Cursor freeze** (Question 6): `CGAssociateMouseAndMouseCursorPosition(false)` on become-active, `(true)` on resign-active and in `leave()` before `terminate`.
  - A frozen cursor cannot reach the three hot corners that this Mac has set.
  - It does not stop the gestures. They come from the trackpad's touch data, not from the cursor position.
  - The window has `.stationary` and `.canJoinAllSpaces`, so if a swipe changes the Space, the toy is still on top. Another app can become active then, and a click on the toy makes it active again.
  - On a crash, the header does not say whether the cursor reconnects. It says the call applies "while an application is in the foreground", and a dead process is not in the foreground. Only a real run proves it (README row).

### Design: window and activation

- `KioskWindow`: `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` and `level = .screenSaver`. The window then shows on the fullscreen IDE's Space, above the menu bar, the Dock and notification banners. The permission check (below) runs before the window exists, so no system prompt can hide under it.
- Activation: `NSApp.activate(ignoringOtherApps: true)`, and the comment says why. Its header promises activation "regardless". `activate()` promises nothing without a yield from the terminal or IDE, which they do not give. The old call compiles with no warning in this SDK. The earlier reason ("deprecated") was false and goes away.
- If the toy is not active 2 s after launch (Question 5), it stays on top, writes one line to stderr, and waits. One click on the screen activates it. A click on a window always activates its app. While it is not active, the tap passes everything.

### Design: the key tap and its safety

- A session tap with `kCGHeadInsertEventTap` and the default (filtering) option. The mask is keyDown, keyUp, flagsChanged and type 14. The source is on the **main run loop** in common modes, because the decision needs `NSApp.isActive` and the router, which are main-actor.
- **Pure decision** in `BabyToyCore` (`KeyTapPolicy`). It takes a plain input and "is the toy active?", and returns pass, swallow (with the `KeyEvent` that the toy routes itself), or re-enable.
  - Not active: pass everything.
  - Active: swallow keyDown, keyUp and flagsChanged. Route keyDown and flagsChanged to the existing `KeyRouter`.
  - Active, system-defined subtype 8: swallow. On key-down, route a keyDown with the F-key code of that key's place, so volume up makes water above F12. Brightness goes to F1 and F2, previous and rewind to F7, play to F8, next and fast to F9, mute to F10, volume down to F11, volume up to F12, and the light keys to F5 and F6. The repeat bit means no sound.
  - Other subtypes (power, mouse buttons, eject, sleep, restart, shutdown): pass.
  - Disabled by timeout: re-enable. Disabled by user input: stay off and log it.
- Swallowed events never reach AppKit, so the existing local key monitor and the tap never handle the same event. If the tap is off, keys reach the monitor as today.
- **Exit combination and `--exit-after`:** the Control, Option and Command flags changes and B, Y, E come through the tap into the same `KeyRouter`. `ExitCombination.swift` does not change. `leave()` removes the tap first, so the key releases after E reach the system normally. `--exit-after` is a timer and does not depend on keys.
- **Toy not active** (the fullscreen IDE case): every key and every system key passes. The user's keys are never taken from another app.
- **Toy hangs:** the callback runs on the main thread, so the system disables the tap by timeout. Cmd+Space, volume and the rest work again, so Raycast can quit the toy. Cmd+Tab stays blocked, because the presentation options are still in force while the hung app is in front. If the cursor is frozen, the mouse stays still. The power button still works.
- **Toy crashes:** the process's port dies and the tap with it. The presentation options end with the process. The cursor is unknown (above).
- **Accessibility missing** (Question 3): `main.swift` checks `AXIsProcessTrusted()` before it creates `NSApplication`. If the check fails, the toy prints what to do, calls the prompting variant once so macOS adds the app to the list, and exits with code 77 (`EX_NOPERM`). No window opens, so the message stays readable in the terminal. If `tapCreate` returns nil although the process is trusted, the toy prints the same kind of message and exits 77.
- **No `.app` bundle is needed.** macOS gives a command-line program the permission of its responsible app: the terminal app or the IDE that started it. The user grants Accessibility once to that app (Question 4). After the switch is on, the user quits and reopens that app.
- **Diagnostics:** the tap writes one stderr line for each system-defined event and each key code outside the key map, with its type, subtype, key type and verdict. With that line, the user can report what an unblocked key sends.

### Runs

**Recommended: three runs** (Question 9). Each run ends with `swift build`, `make test` and `make lint` passing. Do formats with `swift format format --in-place --recursive Sources Tests` before lint. Do and Check never run `git`, `make run`, `make try`, or `swift run BabyToy` without `--snapshot`.

- **Run 1, fire and water (Check can see all of it):** items 1 to 8.
- **Run 2, window, focus, mouse and cursor freeze (the user verifies):** items 9 to 12.
- **Run 3, the key tap (the user verifies):** items 13 to 16.

The order keeps the risky tap last and alone. The user can try the visuals and the mouse before any key is swallowed.

### Items

**Run 1**

1. **Element by row** in `Sources/BabyToyCore/Scene.swift` (or a new `Element.swift`). Add `enum Element { case fire, water }`, chosen by `y < 0.5` means water.
   - Done when these tests pass: Esc (53), 1 (18) and Q (12) are water. A (0), Z (6) and Space (49) are fire. A pointer at y 0.2 is water, and at y 0.8 is fire.
2. **Remove the letters.** Remove `KeyInfo.label`, the labels in `PhysicalKey`, `Reaction.label`, `LabelCache`, `labelColor`, `drawLabel` and `import CoreText` in `Renderer.swift`. `KeyGroup` stays, because `Tones` uses it.
   - Done when: `grep -rn "label\|CoreText\|CTLine" Sources` finds nothing. The test "Letters and digits carry their label and group" becomes "Letters and digits carry their group".
3. **Reaction and scene** in `Scene.swift`.
   - `Reaction` holds `x`, `y`, `element`, `strength` (`.burst` or `.trail`), `seed` and `spawnTime`. It loses `keyCode`, `shape`, `color`, `label`, `scale(at:)` and `opacity(at:)`. Remove `ReactionShape` and the palette.
   - `Scene` gets `press(keyCode:at:)`, `burst(x:y:at:)` and `trail(x:y:at:)`. All three share the 200 cap and the 1.5 s lifetime.
   - Done when these tests pass:
     - the existing tests for burst count, cap, prune and jitter, kept
     - "1,000 mixed presses, bursts and trails leave the 200 newest"
     - "each reaction gets its own seed"
     - "the same seed and the same presses give equal scenes"
   - The tests for label, shape, `keyCode` and grow-and-fade are replaced. They test things that no longer exist.
4. **Particles** in a new `Sources/BabyToyCore/Particles.swift`. A pure function from (reaction, time, detail) to `[Particle]`. A particle has an offset in units of u, a radius, an `RGBColor` and an alpha. The parameters are the ones under Design. The detail rule (full detail up to 100 live, half above) is a pure function too.
   - Done when these tests pass:
     - equal inputs give equal particles
     - fire particles' mean height at 1.0 s is above their mean at 0.2 s
     - water droplets' mean height at 1.2 s is below their mean at 0.3 s
     - every alpha is 0 at the lifetime
     - the detail is full at 100 live reactions and half at 101
     - the half set equals the first half of the full set
     - a trail has fewer and smaller particles than a burst
5. **Renderer** in `Renderer.swift`. Draw the particles: fire with radial gradients in `.plusLighter`, with the glow only for the newest 30 reactions. Water with stroked flat ellipses and gradient droplets in normal blending. Sizes come from the short side of the context, so 400x300 is a scaled copy.
   - Done when these tests pass:
     - empty scene, Q top-left and not bottom-right, Slash bottom-right and not top-left, and expired draws nothing: all kept
     - "fire is warm": A at 0.3 s has a red sum greater than twice its blue sum
     - "water is cool": Q at 0.3 s has a blue sum greater than its red sum
     - "fire rises": Space's topmost drawn row at 1.0 s is above its topmost row at 0.2 s
     - "a trail paints fewer pixels than a burst"
     - "two renders of equal scenes give identical bytes"
6. **Pointer routing** in a new `Sources/BabyToyCore/PointerRouter.swift`.
   - Input: `.moved(dx, dy)`, `.scrolled(dx, dy)` and `.pressed`, each with a time and the screen size in points. Output: `.trail(x, y)`, `.burst(x, y)` or `.nothing`. A positive `dy` means down, as in `NSEvent`.
   - Add `Tones.tone(forPointerX:)`, which returns the `.note` for that x.
   - Done when these tests pass:
     - the pointer starts at (0.5, 0.5)
     - a move of a quarter of the screen width moves x by 0.25
     - the pointer is clamped at every edge
     - 10,000 seeded random moves and scrolls never leave 0…1
     - moves less than 1/30 s apart give one trail
     - a press gives a burst at the current place
     - a scroll moves the pointer and trails
     - the pointer note rises with x and is in `Tones.allTones`
7. **Snapshot mode** in `Sources/BabyToy/Snapshot.swift`.
   - The size becomes 1728x1117, the real screen in points.
   - Cases a to d stay. New cases: (e) A alone (fire), (f) a pile of 100 keys at once, (g) a pointer swipe from bottom-left to top-right over 1 s, with a move every 16 ms and one press at 0.5 s, through `PointerRouter`.
   - The frames stay at 0.1, 0.5 and 1.4 s.
   - Done when: `make snapshot` writes 21 PNGs. In them, Q is water top-left, A is fire, (f) shows fire below and water above, and (g) shows a trail along the diagonal. Every frame of (c) and (f) prints under 16 ms. Snapshot mode still creates no `NSApplication`, window or audio engine.
8. **Docs for run 1.**
   - `README.md`: the first line describes fire and water.
   - Fix the `make try` wording: "Use `make try` until the exit combination has worked once. Do the checklist with `make run`, and leave with the exit combination." Today the README says to do the 3-minute checklist with `make try`, which closes after 60 s.
   - `CLAUDE.md`: the Stack line drops Core Text, and the Map lists particles and pointer routing.
   - Done when: no README or CLAUDE.md sentence names shapes, letters or Core Text, and the checklist no longer depends on `make try`.

**Run 2**

9. **Window** in `Sources/BabyToy/KioskWindow.swift`: the collection behaviour and the `.screenSaver` level under Design, and `acceptsMouseMovedEvents = true`.
   - Done when: Check reads the four behaviours and the level in the code. The user confirms the README rows "opens over fullscreen IntelliJ IDEA" and "opens over fullscreen Terminal".
10. **Activation** in `Sources/BabyToy/AppDelegate.swift`. Replace `app.activate()` with `activate(ignoringOtherApps: true)`, with the comment that gives the reason. Observe `didBecomeActive` and `didResignActive`. If the toy is not active after 2 s, write one stderr line.
    - Done when: Check reads the call, the comment and the observers. The user confirms "keys react at once, or after one click".
11. **Mouse** in `AppDelegate.swift` and `ToyView.swift`. Add a second local monitor for the eight event types under Design, returning `nil`. It feeds `PointerRouter`, then `ToyView` (`burst`, `trail`) and `SoundPlayer` (the pointer note on a press only).
    - Done when: Check reads that every decision comes from `PointerRouter`. The user confirms the mouse rows.
12. **Cursor freeze** in `AppDelegate.swift`, only if Question 6 is "yes". Freeze on become-active. Reconnect on resign-active, and in `leave()` before `terminate`.
    - Done when: Check reads all three calls, and that `leave()` reconnects before `terminate`. The user confirms the hot-corner rows and the "after the toy closes, the pointer moves" rows, including the crash test.
    - README and CLAUDE.md for run 2: add the rows under "Only the user can verify". The Boundaries line becomes "Any key, mouse or trackpad input only produces visuals and sound". The agent rule adds "never run code that freezes the cursor".

**Run 3**

13. **Tap policy** in a new `Sources/BabyToyCore/KeyTapPolicy.swift`: `TapInput`, `TapVerdict`, the `data1` decoding and the media-key-to-F-key table. In `KeyboardLayout.swift`, add the codes 160, 177, 176 and 178 at the places of F3, F4, F5 and F6.
    - Done when these tests pass:
      - not active: keyDown, flagsChanged and volume-up each pass
      - active: keyDown is swallowed and routed, keyUp is swallowed and not routed, flagsChanged is swallowed and routed
      - active: volume-up down (data1 `0x000A00`) routes keyDown 111 with no repeat. The up state (`0x000B00`) routes nothing. The repeat bit sets `isRepeat`.
      - subtypes 1 and 7 pass
      - timeout re-enables, and user input does not
      - every mapped key type lands in the top row of the key map
      - 160, 177, 176 and 178 land on F3 to F6
      - **the exit through the tap:** Control, Option, Command flags as raw `CGEventFlags` values with the device bits and `0x100` set, then B, Y, E, all through the policy into `KeyRouter`, give `.exit`
14. **Permission gate** in `Sources/BabyToy/main.swift`. Before `runKiosk`, check `AXIsProcessTrusted()`, as Question 3 decides. The message names the System Settings path and the app to turn on.
    - Done when: Check reads that the check runs before `NSApplication.shared`, and that `--snapshot` never reaches it. The user confirms the row "with the permission off, the toy says so and does not start".
15. **Tap adapter** in a new `Sources/BabyToy/KeyTap.swift`. It is a thin `@MainActor final class`.
    - `start()` creates the tap as under Design and adds it to the main run loop in common modes.
    - The C callback builds the `Sendable` input, asks the policy, and applies the verdict. It does not decide anything itself.
    - It writes the stderr diagnostics.
    - `stop()` disables the tap, invalidates the port and removes the source. `leave()` calls `stop()` first.
    - It never runs in snapshot mode.
    - Done when: Check reads each point. No agent runs it. The user confirms the key rows.
16. **Docs for run 3.**
    - README: move the rows below from "known gap" to "expected: visuals and sound only". Add the permission step and its one-time setup. Say what the user sees if the toy hangs (keys come back, Raycast can quit the toy, Cmd+Tab stays blocked).
    - CLAUDE.md: the Map lists the tap policy. The agent rule becomes "never create an event tap".
    - Save this plan with the user's answers as `docs/second-version-plan.md`, and list it in CLAUDE.md.
    - Done when: every row below exists in the README.

### Only the user can verify (README checklist rows)

- **Window:** started from fullscreen IntelliJ IDEA, and from fullscreen Terminal, the toy covers the screen and keys react at once. If they do not, one click starts it. Write down which case happened.
- **Keys, with the toy active.** Expected: visuals and sound only.
  - Cmd+Space (Raycast)
  - F1 and F2 (brightness)
  - F3 (Mission Control), F4 (Spotlight), F5 (Dictation), F6 (Do Not Disturb)
  - F7 to F9 (media)
  - F10 to F12 (mute and volume)
  - Cmd+Shift+3, 4 and 5
  - Control+Cmd+Q
  - Cmd+F5 (VoiceOver)
  - Control+Option+Command+8
  - Globe/fn
  - For any key that still acts, copy the stderr line it printed.
- **Exit:** the exit combination closes the toy with the tap on. `make try` closes after 60 s. After either, Cmd+Space opens Raycast again and typing works in other apps.
- **Not active:** with the toy behind (before the click), keys and the mouse work in the other app.
- **Permission:** with Accessibility off for the terminal app, the toy prints the message and does not start.
- **Crash:** `(sleep 20; pkill -9 BabyToy) & make try`. After the toy dies, keys and the pointer work.
- **Mouse:** moving, dragging and scrolling leave a trail. A click makes a burst and a note.
- **Hot corners:** top-left, bottom-left and bottom-right do nothing.
- **Gestures (unsure):** three- and four-finger swipes and the pinches. Write down what happens, and whether the toy stays on top and still reacts.
- **Smoothness and sound:** a two-hand mash and a forearm pile stay smooth. The sound is the same as before.

### Questions

1. **How a key picks fire or water.** **Recommended: by row.** The top three rows make water that falls, and the bottom three rows make fire that rises. The alternative is by hand: the left half makes fire and the right half makes water.
2. **Sounds.** **Recommended: keep the current tones**, and a click plays the note for its x. The user did not ask for new sounds, and the visuals are easier to judge when only one thing changes. A crackle for fire and a drop for water can be a later `/change`.
3. **Accessibility permission is missing.** **Recommended: refuse to start.** Print the steps, show the system prompt once, and exit with code 77. The adult then never hands over a toy whose volume keys work without knowing it. The alternative is to start without the tap and print a warning that nobody sees, because the toy covers the terminal.
4. **Which app gets Accessibility.** **Recommended: Terminal.app, and start the toy from Terminal.app.** If IntelliJ IDEA gets the permission, every program started from its terminal gets it too, and that includes the agents of this project, which run under IntelliJ IDEA. They could then create taps and control the Mac. The alternative is IntelliJ IDEA, if you accept that.
5. **The toy cannot become active at start.** **Recommended: stay on top and wait for one click**, and the README adds "press a key, and if nothing appears, click once". Until that click, a child's keys go to the app under the toy without being seen. The alternative is to leave after 2 s with a message in the terminal.
6. **Freeze the cursor.** **Recommended: yes.** This Mac has three hot corners set, one of them Quick Note. If the cursor does not come back after a crash, the README says to log out. The alternative is no freeze, and the hot corners stay a known gap.
7. **Block keys when the toy is not active.** **Recommended: no.** The tap passes everything then. Otherwise a toy left running behind a window would take the user's keyboard.
8. **Mouse design.** **Recommended:** trail on move, drag and scroll, burst with a note on any click, and no mouse events in the tap. The alternative is clicks only.
9. **Runs.** **Recommended: three runs**, as under Runs. The alternative is two runs, with run 2 and run 3 together.

### Assumptions

- The `data1` layout of media keys and the key codes 160, 177, 176 and 178 for F3 to F6 come from common practice, not from the SDK. The stderr line shows the real values on the first run.
- A brightness key on Apple silicon can be handled before a session tap sees it. That is unknown until the user runs it. If a key is not blocked, the README row records it.
- The tap's timeout value is not in the headers.
- While the toy is active, keyUp and Caps Lock events are swallowed too. Caps Lock still toggles at the hardware level.
- `ExitCombination.swift`, its rules, the 200 cap, the 1.5 s lifetime, the background colour and `Tones.masterLevel` do not change.
- No `.app` bundle. The permission belongs to the terminal app, as the responsible process. This is macOS's documented behaviour, and nobody can verify it here without granting the permission.
- Mouse-up, pressure, magnify, rotate and swipe events are not monitored.
- The number values in Design are starting values. The tests and the 16 ms limit are the contract. Do can tune the numbers within them.
- I ran the offscreen render timing, the permission read and the compile checks only in the scratch package.

### Not in this plan

- New sounds (Question 2).
- A `.app` bundle.
- Mouse events in the tap, and any try to block gestures. The local monitor cannot see gestures, and no header documents a way to block them.
- `.disableScreenCornerInteractions`, which needs macOS 27.
- More than one screen.
- The power button, the lid, Touch ID and Control+Option+Command+Power. Nothing in the app can block them.
- Half-resolution rendering. It is the fallback if the user sees stutter: the timing measured about 4.7 ms at half resolution.
- Editing `docs/first-version-plan.md` and `docs/first-version-run-plan.md`. They are records.

**Waiting for your OK.**
