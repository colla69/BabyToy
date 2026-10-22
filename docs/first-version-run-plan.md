# First version — the accepted plan for the runs

**Status:** accepted by the user ("lets go"). This is the plan `change-plan` returned when
it confirmed `docs/first-version-plan.md` against the project. Where an item below says
"as saved", the saved plan's text for that item applies, including its "done when" tests.

**The user's answers:**

1. Two runs: **yes**. Run 1 now. Run 2 only after the user has committed Run 1 and has
   answered Question 3.
2. Caps Lock and the exit combination: **ignore Caps Lock** (and the numeric-pad and help
   flags). Shift and fn still reset the matcher.
3. Sound level and safety: **option (a), no volume guard.** The user answered after Run 1:
   "this laptop can only get so loud that i wont be a problem". Item 11 (the volume guard)
   is **dropped**, not postponed. Build the fixed in-app level, `masterLevel = 0.25`, and
   do not read or change the system volume. The README still says to never use
   headphones, and its checklist keeps a row for the volume keys as a known gap.
4. First-run way out: **yes.** Add `--exit-after <seconds>` and `make try`.
5. `*.iml` in `.gitignore`: **yes.**

## Plan — change: build the first version of the toddler keyboard toy, as saved in `docs/first-version-plan.md`

**Goal:** `make run` starts a fullscreen kiosk. Every key press, including modifiers, auto-repeat and piles of keys, draws a shape and plays a soft synthesised tone. Mashing cannot quit, leave fullscreen or switch away. The adult leaves with Control + Option + Command held, then B, Y, E. Check sees real frames as PNG files with no macOS permission. The stack, the exit combination and the guarantees are the ones in the saved plan. This plan only checks them against the project as it is now, and splits the work into runs.

### What I checked before Do starts

All checks ran in a throwaway package under `/private/tmp/claude-502/-Users-colara-Sandbox-visualizationForBaby/fa49acb6-98f1-44a3-aa93-8f1e9642275f/scratchpad/probe`. Nothing in the project changed. Nothing opened a window, activated an app, set presentation options or played sound.

| What | How | Result |
|---|---|---|
| Toolchain | `swift --version`, `xcode-select -p`, `sw_vers` | Swift 6.4, Command Line Tools only (no Xcode), SDK 27.0, macOS 26.7.1 |
| Swift Testing works with the CLT | `swift test` on a package with `// swift-tools-version: 6.0`, `.macOS(.v14)`, a library, an executable and a test target | 2 tests pass, Testing library 2084. **`swift test -c release` fails** (the `TestingMacros` plugin is missing in the CLT), so tests run in debug only. |
| Warnings from `swift build` | clean build of the probe, and of an empty one-file package | Every package gets 2 or 3 lines `ld: warning: search path '/Library/Developer/CommandLineTools/Developer/...' not found`. They come from the CLT, not from code. Item 1's "no warnings" cannot hold literally (see item 1). |
| Swift 6 mode compiles the plan's shapes | compile only: a borderless `NSWindow` with `canBecomeKey`, a `@MainActor` view with `displayLink(target:selector:)`, a render on a serial queue with `CGImage` back to `layer.contents` on main, a local monitor for `.keyDown` and `.flagsChanged` that returns `nil`, the 7 presentation options as a value, 8 `AVAudioPlayerNode`s with `scheduleBuffer(_:at:options: .interrupts, ...)`, an `AVAudioEngineConfigurationChange` observer, the CoreAudio volume read | builds with no compiler warning and no error |
| `NSView.displayLink(target:selector:)` | `NSView.h` in the SDK | present, `API_AVAILABLE(macos(14.0))`, so the macOS 14 target is right |
| `.interrupts` | `AVAudioPlayerNode.h` | `AVAudioPlayerNodeBufferInterrupts`: "The buffer interrupts any buffer already playing" |
| Volume property for item 11 | `AudioHardwareService.h`, plus the compile above | `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` exists |
| Key codes | `HIToolbox/Events.h` | Q = 0x0C = 12, Slash = 0x2C = 44, Space = 0x31 = 49. Exit letters: B = 11, Y = 16, E = 14 |
| `swift format lint` | `swift format lint --help`, then a lint of the probe | exists, and `--strict` and `--recursive` exist. Default rules: **2-space indent, 100-column lines**. Code with a 4-space indent fails `make lint`. |
| Presentation option rules | `NSApplication.h` | The header does not state which combinations are valid. The plan's set includes `.hideDock` and `.hideMenuBar`, which covers the dependencies I know of. Only the user's first `make run` proves it. |
| Render cost, item 10's 16 ms | offscreen probe: 200 filled circles of 120 px with a ring and a Core Text label each | about 12.5 ms per frame at 1280x800, and about 13.2 ms at 1728x1117 (this Mac's screen in points). Debug and release are the same, because Core Graphics does the work. The first frame takes about 19 ms (font loading). The margin is about 3.5 ms, so larger grown shapes can miss 16 ms. |
| Ctrl+Opt+Cmd shortcuts | `defaults export com.apple.symbolichotkeys` | No system shortcut on this Mac uses Ctrl+Opt+Cmd. Spotlight's Cmd+Space is turned off. **Raycast is running** and its own hotkeys (probably Cmd+Space) are not visible there. |
| Escape hatch `pkill` over ssh | `nc -z localhost 22` | **Port 22 is closed. Remote Login is off**, so this escape hatch does not exist today (see Question 4). |
| Project state | `ls -la`, `git status` | `master`, no commits. Untracked: `.claude/`, `.idea/`, `CLAUDE.md`, `docs/`, and also **`visualizationForBaby.iml`** at the root (JetBrains, like `.idea/`). No code. |

### Runs

**Recommended: two runs.** Each run leaves `swift build`, `make test` and `make lint` passing, so the user can commit after each one.

- **Run 1, core and snapshot (no window, no sound):** items 1, 2, 3, 4, 5, 6, 10, and item 12 without `make run`. Everything is pure code with tests. The PNGs show the visuals before any kiosk exists. If something is wrong in the scene or the renderer, it shows up here, where Check can see it.
- **Run 2, kiosk, live view and sound:** items 7, 8, 9, 11 (only if Question 3 is "yes"), `make run` in item 12, and item 13.

One run of all 13 items also works. But Check would compare 13 items at once, and the first commit would hold both the testable core and the kiosk that only the user can test.

Rules for Do and Check in both runs:
- Do not run `git`. The user commits.
- Do not run `make run`, `swift run BabyToy` without `--snapshot`, or anything else that starts the kiosk or plays sound. Only the user does that.

### Items

1. **Package skeleton** (run 1).
   - `Package.swift` with `// swift-tools-version: 6.0` and `.macOS(.v14)`. Library `BabyToyCore`, executable `BabyToy`, test target `BabyToyCoreTests` with Swift Testing.
   - `.gitignore` with `.build/` and `.idea/`, plus `*.iml` if Question 5 is "yes".
   - Done when: `swift build` succeeds, and no warning names a file under `Sources/` or `Tests/`. The `ld: warning: search path ... not found` lines from the Command Line Tools are expected. `.gitignore` holds the lines above.
2. **Key map** in `Sources/BabyToyCore/KeyboardLayout.swift` (run 1), as saved.
   - Maps `keyCode` to a position (x 0…1, y 0…1, y = 0 at the top row), a group (letter / digit / big key / other) and an optional label. Unknown codes get a valid fallback.
   - Done when these tests pass: Q (12) is in the top-left quarter. Slash (44) is in the bottom-right quarter. Space (49) is bottom middle and a big key. An unknown code returns a valid result.
3. **Exit matcher** in `Sources/BabyToyCore/ExitCombination.swift` (run 1), as saved.
   - Input: `.keyDown(code, isRepeat)` and `.modifiersChanged(flags)`. No clock. The modifiers and the letters B (11), Y (16), E (14) are constants in one place.
   - Caps Lock is handled as Question 2 decides.
   - Done when the 9 tests from the saved plan pass: exact combination exits, letters out of order reset, an extra key between letters resets, adding Shift or fn resets, releasing a modifier resets, letters without modifiers do nothing, a pile with B, Y and other keys does not exit, 100,000 seeded random events never exit, and a mash followed by the clean combination exits. If Question 2 is "yes", one more test: the combination exits with Caps Lock on.
4. **Scene model** in `Sources/BabyToyCore/Scene.swift` (run 1), as saved.
   - The scene is a `Sendable` value type, because item 8 copies it to a background queue.
   - Done when these tests pass: 1 press adds 1 reaction. 10 presses in one burst add 10. 1,000 presses leave exactly 200, all of them the newest. Reactions older than their lifetime are gone after pruning.
5. **Renderer** in `Sources/BabyToyCore/Renderer.swift` (run 1), as saved.
   - Done when these tests pass in an offscreen 400x300 bitmap: an empty scene is all background colour. One reaction for Q has non-background pixels in the top-left quarter and none in the bottom-right quarter. "Top" means the top of the image as a PNG shows it, so the test catches a flipped y axis.
6. **Tones and voice pool** in `Sources/BabyToyCore/Tones.swift` and `Sources/BabyToyCore/VoicePool.swift` (run 1), as saved.
   - Done when these tests pass: every tone's peak is at most `masterLevel / 8` with `masterLevel = 0.25`. Every tone starts and ends at about zero. Letter pitch rises from left to right. 200 requests use only indices 0…7, and the 9th request gets index 0.
7. **Kiosk shell** in `Sources/BabyToy/` (`main.swift`, `AppDelegate.swift`, `KioskWindow.swift`) (run 2), as saved.
   - `.regular` activation policy, a strong reference to the delegate, borderless window with `canBecomeKey`, cursor hidden, no main menu, the 7 presentation options, `applicationShouldTerminate` returning `.terminateCancel` unless the matcher fired. One local monitor for `.keyDown` and `.flagsChanged` feeds the matcher first, then the scene and sound, and returns `nil`.
   - With no arguments, `main.swift` starts the kiosk. If Question 4 is "yes", `--exit-after <seconds>` also leaves through the same exit path.
   - Done when: Check confirms by reading the code that each option, the guard, the monitor order and the `nil` return are present. The user confirms with the README checklist that `make run` opens fullscreen and that the exit combination closes it.
8. **Live view** in `Sources/BabyToy/ToyView.swift` (run 2), as saved.
   - Done when: Check confirms by reading the code that no rendering happens on the main thread and that a tick is skipped while a render is in flight. The user sees smooth shapes when mashing.
9. **Sound player** in `Sources/BabyToy/SoundPlayer.swift` (run 2), as saved, with option (a) or (b) from Question 3.
   - Done when: Check confirms by reading the code that there are 8 nodes, that indices come from `VoicePool`, that buffers come from `Tones`, and that a failed start or a configuration change gets one restart and otherwise silence. The user hears a different sound for each key group and no crackle when mashing.
10. **Snapshot mode** in `Sources/BabyToy/Snapshot.swift` (run 1), as saved.
    - The snapshot path creates no `NSApplication`, no window and no audio engine. That makes it safe for Do and Check to run.
    - In run 1, any other arguments print a usage line to stderr and exit with code 64. Run 2 replaces the no-argument case with the kiosk.
    - Done when: `make snapshot` writes 12 PNGs, `<case>-<time>.png`, to `.build/snapshots/`. Q is top-left, (b) shows 10 shapes, and the shapes have faded by 1.4 s. The printed time for each (c) frame is under 16 ms.
11. **Volume guard** in `Sources/BabyToy/VolumeGuard.swift` (run 2). **Only if Question 3 is answered "yes".** As saved.
    - Done when: Check confirms by reading the code that the guard only writes a value at or below the start level. The user confirms with the checklist that the volume-up keys do not make the toy louder.
12. **Makefile.**
    - Run 1: `make test` = `swift test`, `make lint` = `swift format lint --strict --recursive Sources Tests`, `make snapshot` = `swift run BabyToy --snapshot .build/snapshots`.
    - Run 2: `make run` = `swift run BabyToy`. If Question 4 is "yes", also `make try` = `swift run BabyToy --exit-after 60`.
    - Done when: in each run, `make test`, `make lint` and `make snapshot` succeed. Do does not run `make run` or `make try`.
13. **README.md** (run 2), as saved: how to start, the exit combination, the escape hatches, never use headphones, and the manual boundary checklist with one row for each key or combo in the plan's lists. Each row says "expected: visuals and sound only" or "known gap".
    - The escape hatch says that `pkill BabyToy` over ssh needs Remote Login (System Settings, General, Sharing), and that it is off on this Mac today.
    - Done when: every key or combo named in the plan's lists has a row, and so do the extra rows under Assumptions.

### Questions

1. **Split:** two runs, as under Runs? **Recommended: yes.** If "no", Do carries out all 13 items in one run.
2. **Caps Lock and the exit combination (new).** The saved rule needs the flags to be exactly {control, option, command}. `modifierFlags` includes Caps Lock, so if the child turns Caps Lock on, the adult cannot leave until they turn it off again. **Recommended: ignore Caps Lock** (and the numeric-pad and help flags) in the comparison. Shift and fn still reset the matcher. This does not make the combination easier to mash, because Caps Lock adds no key to the sequence.
3. **Sound level and safety (still open from the saved plan).** The child sits next to the speakers, and the volume keys are not blocked.
   - (a) A fixed in-app level: each tone peaks at `0.25 / 8`, so 8 voices together peak at about -12 dBFS. The adult sets the system volume before starting.
   - (b) (a) plus the volume guard, item 11. It lowers the system volume back to its start level while the toy runs, and never raises it. This is the app changing something outside itself, downward only, so it needs your explicit yes.
   - (c) No sound in v1.
   - **Recommended: (b).** Answer "b" to accept item 11. Any other answer leaves item 11 out and builds (a) or (c).
4. **First-run way out (new).** Remote Login is off, so today the only way out of a kiosk with a broken exit is to hold the power button. **Recommended: add `--exit-after <seconds>` and `make try`**, which leave by themselves after 60 s through the normal exit path. Mashing cannot set a launch argument. About 20 lines in item 7 and one Makefile line. Use `make try` until the exit combination has worked once. Alternative: no flag. Turn on Remote Login and test `ssh` from another device before the first `make run`.
5. **`.gitignore` and `visualizationForBaby.iml` (new).** The JetBrains module file sits at the root, outside `.idea/`. **Recommended: add `*.iml`** to `.gitignore`.

### Assumptions

- Questions 1, 2, 4 and 5 of the saved plan stay settled: Core Graphics with snapshot mode, the Ctrl+Opt+Cmd then B, Y, E exit, no event tap in v1, and Check does not launch the kiosk.
- The matcher has no clock. "A second key in the same pile" works through the rule that any key other than the expected next letter resets. A pile of exactly B, Y, E in order, with the exact modifiers held, exits. That is the design the saved plan accepted.
- Do formats with `swift format format --in-place --recursive Sources Tests` before `make lint`. No `.swift-format` file, and no `make format` target.
- If a (c) frame misses 16 ms, Do reports it under "Needs a decision" and does not cut visuals on its own. The criterion applies after the warm-up frames of cases (a) and (b).
- A voice stolen by `.interrupts` stops mid-tone and can click softly. Each voice peaks at about 0.031, so the click is small. The user's listening test in item 9 decides, and any fix is a later change.
- If the default output device changes while the toy runs (item 11 only), the guard takes the new device's volume at that moment as its cap.
- The README checklist gets three rows beyond the saved lists, all documentation, with no change to what the app blocks:
  - Raycast's hotkeys (Cmd+Space and the others it registers): known gap.
  - Idle display sleep, and a lock screen on wake where the child types into the password field: known gap.
  - Moving the trackpad to a hot corner: unsure. `.disableScreenCornerInteractions` exists only from macOS 27, and this Mac runs 26.7.1.

### Not in this plan

- `git` of any kind. The user commits after each run.
- Editing CLAUDE.md. The saved plan's "Commands for CLAUDE.md" go in after run 2, as a separate step.
- The event tap, a `.app` bundle, mouse and trackpad reactions, settings, a choice of sounds, and more than one screen, as in the saved plan.
- `.disableScreenCornerInteractions`, because it needs macOS 27.
- Running the kiosk or playing sound to check anything. Only the user does that, with the README checklist.

**Waiting for your OK.**
