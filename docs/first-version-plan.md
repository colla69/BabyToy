# First version — plan

**Status:** saved, not started. This is the second version of the plan. It replaces the
first one, which assumed a web page. The user changed three things: native only, sound in
the first version, and an exit by a complex key combination. The user replied "sound
good go on" to the whole plan, so the recommended answers to Questions 1, 2, 4 and 5
are taken. **Question 3 is still open:** the volume guard (item 11) changes the system
volume, which the plan says needs the user's explicit yes. Until then, treat item 11 as
not accepted and build option (a), the fixed in-app level. When development starts, run
`/change` and hand it this file.

## Plan — change: build the first version of the toddler keyboard toy as a native Swift kiosk app with visuals and sound

**Goal:** On this Mac, `make run` starts a fullscreen kiosk app. Every key press, including modifiers and auto-repeat, and every pile of presses at once, draws a shape and plays a soft synthesised tone. Ordinary mashing cannot quit, leave fullscreen or switch away. The adult leaves with one complex key combination, and it still works if drawing or sound hangs. The keys the app cannot block are written down, and the adult can test the rest with a short checklist. Check can see real frames as PNG files without any macOS permission.

### Stack and frameworks

- **Shell:** Swift 6, AppKit, Swift Package Manager.
  - A borderless window covers the main screen.
  - The kiosk is made with `NSApp.presentationOptions`: hideDock, hideMenuBar, disableProcessSwitching, disableForceQuit, disableSessionTermination, disableHideApplication, disableAppleMenu.
  - There is no main menu, and the terminate guard stays as before.
- **Drawing: Core Graphics + Core Text.** A pure function draws the scene at time t into a `CGContext`. A background queue renders each frame into a `CGImage`, and the main thread only sets it as the view layer's `contents` on each display-link tick.
  - Why this and not the others:
    - **SpriteKit:** effects would live in SKActions that unit tests cannot reach, and offscreen PNG output would need SKRenderer plus Metal.
    - **Core Animation layers:** animations run in the render server, so a mid-animation frame cannot be grabbed for Check.
    - **SwiftUI Canvas:** draws on the main thread, and adds a second UI framework next to AppKit.
    - **Metal:** far more code than v1 needs.
  - The Core Graphics design gives three things at once: the snapshot mode is nearly free, the scene logic can be tested, and a slow frame cannot block key handling (see the exit combination).
  - Cost: CPU drawing. Frames render at point resolution (scale 1), and a tick is skipped while the previous frame is still rendering.
- **Sound: AVAudioEngine** with a fixed pool of 8 `AVAudioPlayerNode`s into the main mixer.
  - All tones are synthesised once at start into `AVAudioPCMBuffer`s by a pure Swift function: sine and partials with an attack/decay envelope. There are no audio files, so nothing to license.
  - Each new sound takes the next node round-robin with `.interrupts`. So at most 8 voices sound at once, and the oldest is cut first.
  - Each buffer's peak is at most `masterLevel / 8`, so even 8 voices at full overlap cannot clip.
  - No custom audio-thread code, so there is no real-time locking to get wrong.
  - Sound per key group:
    - letters: pentatonic notes, from low on the left of the keyboard to high on the right, so mashing sounds pleasant
    - digits: bell (two partials)
    - Space / Return / Delete: soft low "boom"
    - modifiers, arrows, function keys and the rest: short high pluck
    - auto-repeat: visuals only, no sound, so a held key does not machine-gun

### Exit combination (Question 2 settles it)

A toddler presses many keys at once with a flat hand or forearm, and leans on keys for seconds. I compared three kinds of exit:

| Kind | Example | Can mashing do it? |
|---|---|---|
| Plain chord | Ctrl+Opt+Cmd+B | Yes, plausibly. Ctrl, Opt and Cmd sit next to each other at the bottom left. The edge of a palm can press exactly those three plus one letter. |
| Chord held for seconds | hold Esc + Delete for 3 s | Yes, plausibly. A leaning forearm holds keys for seconds. "Exactly these keys" helps, but two far-apart keys are within a child's reach. |
| Sequence | type `goodbye` + Return | Practically no: about 1 in 50^8 per try. But it is not a "combination", and the user asked for a key combination. |

**Recommended: a chord plus a sequence.** Hold **Control + Option + Command** (nothing else), then press **B, Y, E** one at a time, in that order.
- Rules:
  - Each letter must arrive as its own keyDown while the modifier flags are exactly {control, option, command}.
  - Any other keyDown resets the matcher. So does any change of the modifier flags (adding Shift or fn, or letting go), or a second key arriving in the same pile.
  - Auto-repeats are ignored.
- Why mashing cannot produce it:
  - Step 1, holding exactly those three modifiers with no Shift or fn, is rare but possible.
  - Step 2 then needs the next three non-modifier presses to be exactly B, Y, E, one at a time and in order, while the hold stays exact: about 1 in 50^3 per occurrence of step 1.
  - A flat-hand pile always brings an extra key, and that resets.
- Ctrl+Opt+Cmd+B/Y/E are not default macOS system shortcuts as far as the planner knows. The README checklist confirms it on this Mac.
- The matcher is event-based. It deliberately does not track "keys currently down", because macOS does not reliably deliver keyUp for keys pressed while Cmd is held.
- It keeps working if drawing or sound hangs:
  - The key monitor runs on the main thread and feeds the matcher before anything else.
  - Rendering happens on a background queue.
  - The audio engine renders on its own real-time thread, and the main thread only queues buffers.
  - Only a hang in the main-thread model code itself would block it. The escape hatches for that are below.

### Verification without Chrome and without permissions

- `make test`: Swift Testing unit tests for the exit matcher, key map, scene and cap, tone synthesis and peak, and voice pool.
- `make lint`.
- **Snapshot mode: `swift run BabyToy --snapshot <dir>`.** It runs a scripted set of key presses through the same scene and renderer, with no window, no kiosk and no sound, and writes PNG files. Check opens them with the Read tool and needs no Screen Recording or Accessibility permission. This is feasible and small, about 50 lines: the renderer already draws into a plain `CGContext`, and ImageIO writes the PNG. **It belongs in v1**, because without it Check cannot see anything at all.
- The kiosk boundary is checked in two ways: Check reads the code, and the user runs the README checklist. Old Question 4 stands.
- Sound cannot be heard by Check. Tests prove the voice cap and the peak bound, and the user listens.

### What the kiosk can and cannot guarantee (v1, no event tap)

- **Blocked:**
  - Cmd+Q, Cmd+W (no menu; terminate refused unless the exit combination matched)
  - Cmd+H, Cmd+M
  - Cmd+Tab and app switching, Mission Control/Exposé
  - Dock and menu bar
  - Force Quit (Cmd+Opt+Esc)
  - the Apple menu, log out (Shift+Cmd+Q)
  - Esc (just a key)
- **Not blocked. Each of these changes something outside the app:**
  - screenshot keys (Cmd+Shift+3/4/5) save files to the Desktop
  - **volume keys** (see Question 3), brightness, keyboard light, media keys
  - Spotlight (Cmd+Space), Siri, Dictation, the Globe/fn emoji picker, Do Not Disturb
  - VoiceOver (Cmd+F5) and other accessibility shortcuts
  - possibly lock screen (Ctrl+Cmd+Q)
  - Ctrl+Opt+Cmd+Power (quit all and shut down)
  - Touch ID / power button, closing the lid
  - other screens, if more than one is connected
- **Unsure until tested on this Mac:** Ctrl+Cmd+Q, Spotlight, trackpad swipes between Spaces, and whether any Ctrl+Opt+Cmd+letter is taken by the system.
- An event tap (old Question 3; still recommended "not in v1") would swallow most of the "not blocked" list. The power button, the lid and Touch ID can never be blocked.

### Items

1. **Package skeleton.**
   - `Package.swift`: tools 6.x, macOS 14+.
   - Library `BabyToyCore`, executable `BabyToy`, test target `BabyToyCoreTests` using Swift Testing (present in the installed Command Line Tools).
   - `.gitignore` with `.build/` and `.idea/`.
   - Done when: `swift build` succeeds with no warnings under Swift 6 language mode.
2. **Key map** in `Sources/BabyToyCore/KeyboardLayout.swift`.
   - Maps a macOS virtual key code (`NSEvent.keyCode`, independent of the keyboard layout) to a keyboard position (x 0…1, y 0…1), a key group (letter / digit / big key / other) and an optional label character.
   - Unknown codes get a valid fallback.
   - Done when these tests pass:
     - Q (12) maps to the top-left area
     - Slash (44) maps to the bottom-right
     - Space maps to the bottom middle and is a big key
     - an unknown code returns a valid result
3. **Exit matcher** in `Sources/BabyToyCore/ExitCombination.swift`.
   - Fed `.keyDown(code, isRepeat)` and `.modifiersChanged(flags)`. It implements the rule above.
   - The modifiers and letters are constants in one place.
   - Done when these tests pass:
     - the exact combination exits
     - each letter out of order resets
     - an extra key between letters resets
     - adding Shift or fn resets
     - releasing a modifier mid-way resets
     - the letters without the modifiers do nothing
     - a pile (B and Y and other keys in one burst) does not exit
     - 100,000 random mash events (seeded) with random modifier flags never exit
     - a mash followed by the clean combination exits
4. **Scene model** in `Sources/BabyToyCore/Scene.swift`.
   - Each key event adds a reaction: the position from the key map with a little seeded jitter, a bright colour, a shape by key group (circle, star, rounded square, ring), the label for letters and digits, and the spawn time.
   - Lifetime about 1.5 s, with grow and fade as a function of age.
   - At most 200 live reactions; the oldest is dropped first.
   - Expired reactions are pruned.
   - Done when these tests pass: one press adds one reaction; 10 presses in one burst add 10; 1,000 presses leave exactly 200, all of them the newest; reactions older than their lifetime are gone after pruning.
5. **Renderer** in `Sources/BabyToyCore/Renderer.swift`.
   - A pure function `render(scene, at: time, into: CGContext, size:)` draws a dark background and each reaction with Core Graphics, and labels with Core Text.
   - Done when these tests pass: in an offscreen 400x300 bitmap, an empty scene is all background colour, and a scene with one reaction for Q has non-background pixels in the top-left quarter and none in the bottom-right.
6. **Tone synthesis and voice pool** in `Sources/BabyToyCore/Tones.swift` and `VoicePool.swift`.
   - Pure functions generate the Float sample arrays per key group and pitch, as described under Sound.
   - `VoicePool(size: 8)` hands out node indices round-robin.
   - Done when these tests pass:
     - every generated tone's peak is at most `masterLevel / 8`, and it starts and ends at about zero (no click)
     - letter pitch rises from left to right
     - 200 requests in one burst use only indices 0…7, and the 9th request reuses index 0
7. **Kiosk shell** in `Sources/BabyToy/` (`main.swift`, `AppDelegate.swift`, `KioskWindow.swift`).
   - Borderless key-capable window on the main screen, cursor hidden, no main menu, the presentation options above.
   - `applicationShouldTerminate` returns `.terminateCancel` unless the exit matcher fired.
   - Key handling uses one local event monitor for `.keyDown` and `.flagsChanged`. It feeds the exit matcher first, then the scene and sound, and swallows the event so AppKit acts on nothing.
   - On exit, it restores the presentation options and terminates.
   - Done when: Check confirms by reading the code that each option, the guard, and the monitor order are present, and that the monitor returns `nil`. The user confirms with the README checklist that `make run` opens fullscreen and the exit combination closes it.
8. **Live view** in `Sources/BabyToy/ToyView.swift`.
   - A layer-backed NSView with a display link (`NSView.displayLink`, macOS 14).
   - Each tick copies the scene (a value type) to a serial background queue. That queue calls the item 5 renderer at point resolution into a `CGImage`, which goes back to `layer.contents` on main.
   - A tick is skipped while a render is in flight.
   - Done when: Check confirms by reading the code that no rendering happens on the main thread, and the user sees smooth shapes when mashing.
9. **Sound player** in `Sources/BabyToy/SoundPlayer.swift`.
   - AVAudioEngine with 8 player nodes on the mixer, buffers from item 6 built once at start, and the master level from Question 3.
   - If the engine fails to start, or its configuration changes (for example headphones plugged in), it tries to restart once and otherwise stays silent. The toy never stops for it.
   - Done when: Check confirms by reading the code that the node count is 8, that indices come from `VoicePool`, and that the buffers come from `Tones`. The user hears a different sound per key group and no crackle when mashing.
10. **Snapshot mode** in `Sources/BabyToy/Snapshot.swift`, reached from `main.swift` when `--snapshot <dir>` is passed; nothing else starts.
    - Scripted input:
      - (a) Q alone
      - (b) a burst of 10 keys across the keyboard
      - (c) 300 keys at once (cap)
      - (d) a held key with repeats
    - Frames at 0.1 s, 0.5 s and 1.4 s, 1280x800, written as `<dir>/<case>-<time>.png`.
    - It prints the render time per frame.
    - Done when: the command writes 12 PNGs. In them, Q appears top-left, 10 shapes are visible in (b), and the shapes fade by 1.4 s. The (c) frame renders in under 16 ms on this Mac.
11. **Volume guard** in `Sources/BabyToy/VolumeGuard.swift` (only if Question 3 is answered "yes").
    - At start, it reads the default output device's volume through CoreAudio, which needs no permission.
    - While the toy runs, it checks about every 0.5 s and lowers the volume back if it is above the start level. It never raises it.
    - On exit, it changes nothing back, because it only ever lowered the volume to where the adult had set it.
    - Devices without a volume control are skipped silently.
    - Done when: Check confirms by reading the code that the guard only ever writes a value at or below the start level. The user confirms with the checklist that the volume-up keys do not make the toy louder.
12. **Makefile:**
    - `make run` = `swift run BabyToy`
    - `make snapshot` = `swift run BabyToy --snapshot .build/snapshots`
    - `make test` = `swift test`
    - `make lint` = `swift format lint --strict --recursive Sources Tests`
    - Done when: `make test`, `make lint` and `make snapshot` all succeed.
13. **README.md:** how to start, the exit combination, the escape hatches if the app hangs (`pkill BabyToy` over ssh, or hold the power button), and a manual boundary checklist of about 3 minutes.
    - One row per key or combo from the "Blocked", "Not blocked" and "Unsure" lists, plus: volume keys, the exit combination itself, the exit combination with an extra key (must not exit), and a flat-hand smash on the bottom-left corner (must not exit).
    - Each row says "expected: visuals and sound only" or "known gap".
    - Done when: every key or combo named in this plan's lists has a row.

**Commands for CLAUDE.md** (to add once they exist): Stack: Swift 6, AppKit kiosk window; drawing with Core Graphics + Core Text, rendered off the main thread; sound with AVAudioEngine playing synthesised tones; Swift Package Manager; tests with Swift Testing. Run `make run`; see frames without the kiosk `make snapshot` (PNG files in `.build/snapshots/`); test `make test`; lint `make lint`; build `swift build`.

### Questions

1. **Drawing framework:** Core Graphics rendered off the main thread, with snapshot mode in v1? **Recommended: yes.**
2. **Exit combination:** hold Control + Option + Command, then press B, Y, E in order, with any other key resetting it? **Recommended: yes.** Alternatively, name other letters, but avoid Q and 8: Ctrl+Cmd+Q locks the screen, and Ctrl+Opt+Cmd+8 inverts the colours.
3. **Sound level and safety.** The child sits next to the speakers, and the volume keys are not blocked, so the child can turn the Mac to full volume.
   - **Recommended: (b).**
     - (a) A fixed, conservative in-app level, with each tone's peak at 1/8 of `masterLevel = 0.25`, so all 8 voices together peak at about −12 dBFS. Clipping is impossible by design. The adult sets the system volume before starting.
     - (b) Everything in (a), plus the volume guard (item 11). It caps the system volume at its start level while the toy runs and never raises it. This is technically the app changing something outside itself (the system volume, downward only), so it needs the user's OK.
     - (c) No sound until a later change.
   - Also: never use headphones with this toy. The README will say so.
4. **Block the remaining system keys in v1 with an event tap** (screenshots, brightness, Spotlight, VoiceOver and the rest)? It needs a `.app` bundle and a one-time Accessibility permission. **Recommended: no, make it the next `/change`.**
5. **Should Check launch the kiosk and press real keys** via `osascript`? This needs Accessibility permission for the terminal and takes over the screen. **Recommended: no.** Check uses tests and snapshot PNGs, and the user runs the checklist.

### Assumptions

- Main screen only. Other screens are left alone.
- Force Quit is disabled on purpose. Otherwise Cmd+Opt+Esc followed by a mashed Return would kill the app. The escape hatches are the exit combination, `pkill` over ssh, and the power button.
- Mouse and trackpad do nothing in v1, and the cursor is hidden.
- `swift format` (bundled with the toolchain) is the linter with its default rules. No SwiftLint.
- The toy runs from `swift run`, as a bare executable that sets itself as a regular foreground app. No `.app` bundle in v1.

### Not in this plan

- The event tap and a signed `.app` bundle (Question 4).
- Mouse/trackpad reactions, a settings screen, a choice of sounds, multi-screen support.
- `git init`. The folder is not a repo, and starting one is the user's call.
- Editing CLAUDE.md.
