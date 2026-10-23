# visualizationForBaby

A fullscreen toy for a small child who sits on a lap and smashes the keyboard. Every
key press, and every pile of them at once, shows up on screen as a visual reaction with
a sound, so the child sees and hears what their hands do and has fun. The user is a
toddler; the adult is the one who starts and stops it.

## Stack

- Swift 6 (tools 6.0, language mode 6), a native macOS 14+ app that runs as a fullscreen
  kiosk. No web page, no browser.
- Swift Package Manager: `BabyToyCore` (library), `BabyToy` (executable) and
  `BabyToyCoreTests` (Swift Testing).
- Drawing with Core Graphics, rendered off the main thread. Sound with
  AVAudioEngine playing tones synthesised at start: no audio files.

The plans are `docs/first-version-plan.md` (the stack and its reasons) and
`docs/first-version-run-plan.md` (what was built in each run).

## Commands

| Task | Command |
|---|---|
| Build | `swift build` |
| Test | `make test` |
| Format, then lint | `swift format format --in-place --recursive Sources Tests`, then `make lint` |
| Frames as PNG files, no window | `make snapshot` (files in `.build/snapshots/`) |
| Start the kiosk | `make try` the first time (it leaves by itself after 60 s), then `make run` |

`make run` and `make try` have never been run by an agent. Only the user does that.

## Map

| Path | Responsibility | Start here |
|---|---|---|
| `Sources/BabyToyCore/` | Pure logic, with no AppKit window and no audio: key map, the effect of a key or a pointer place (`Element.swift`), exit matcher, routing of one key event, pointer routing and its glide throttle (`PointerRouter.swift`), scene, particles (`Particles.swift`), renderer, tones | `KeyRouter.swift` |
| `Sources/BabyToy/` | AppKit and AVFoundation glue: kiosk window, live view, sound player, snapshot mode | `AppDelegate.swift` |
| `Tests/BabyToyCoreTests/` | Tests of the core | `ExitCombinationTests.swift` |

## Conventions

- Decision logic goes in `BabyToyCore`, where tests reach it. `BabyToy` stays thin.
- The exit combination is Control + Option + Command held, then B, Y, E. It is defined
  in `ExitCombination.swift` only. Caps Lock, numeric-pad and help flags are ignored in
  its comparison. Shift and fn reset it.
- A key's place on screen comes from its `keyCode`, never from the character it types.
- The sound level is fixed (`Tones.masterLevel`, 0.25).

## Boundaries

- Any key, or many at once, only produces visuals and sound. It must never close the
  app, leave fullscreen, or change anything outside the app. Leaving takes a deliberate,
  complex key combination that mashing cannot produce by accident.
- The app never reads or changes the system volume. The user decided against a guard.
- Snapshot mode (`main.swift`, `Snapshot.swift`) must never create an `NSApplication`, a
  window or an audio engine. Agents run it to see frames.
- Agents never start the kiosk: not `make run`, not `make try`, not `swift run BabyToy`
  without `--snapshot`. It takes over the screen and the keyboard.
- Agents never run `git`. The user commits.

## Trios

| Task | Run it with | Agents |
|---|---|---|
| change | `/change` | `change-plan`, `change-do`, `change-check` |
