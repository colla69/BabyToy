# BabyToy

A fullscreen toy for a small child on your lap. Every key press shows a bright shape and
plays a soft tone. Mashing the keys cannot close the toy or switch to another app.

CAUTION: Never use headphones with this toy. The child cannot judge the volume, and the
volume keys are not blocked.

## Start the toy

Open Terminal in this folder. Set the system volume low before you start.

The first time, run:

```
make try
```

`make try` starts the toy, and the toy closes by itself after 60 seconds. Use it until the
exit combination has worked for you once.

After that, run:

```
make run
```

`make run` starts the toy with no time limit. Only the exit combination closes it.

If the keys do not make shapes, the toy did not get the keyboard. With `make try`, wait 60
seconds, and the toy closes.

## Leave the toy

1. Hold Control, Option and Command. Hold no other key.
2. While you hold them, press B, then Y, then E. Press each letter once, one at a time.

The toy closes after E. Caps Lock on or off does not matter.

Any other key resets the combination. Shift or fn resets it too. If you let go of one of the
three keys, start again at step 1.

While the toy runs, the Mac cannot log out, restart or shut down from the Apple menu. Leave
the toy first.

## If the toy hangs

- `make try` closes the toy after 60 seconds.
- From another device, run `pkill BabyToy` over ssh. This needs Remote Login (System
  Settings, General, Sharing). Remote Login is off on this Mac today, so turn it on and test
  `ssh` before you rely on it.
- Hold the power button until the Mac turns off. This always works. Unsaved work in other
  apps is lost.

## Boundary checklist

Do this check once, with `make try`, before the child uses the toy. It takes about 3
minutes. Press each key or combination. Write down what happens if it is not what the table
expects.

"Expected: visuals and sound only" means that the key makes a shape and a tone, and nothing
else happens. "Known gap" means that the toy cannot block the key. The key does what it
does in macOS.

CAUTION: Do not press Control + Option + Command + Power. It quits all apps and shuts the
Mac down.

### Keys the toy blocks

| Key or combination | Expected |
|---|---|
| Cmd+Q (quit) | expected: visuals and sound only |
| Cmd+W (close window) | expected: visuals and sound only |
| Cmd+H (hide) | expected: visuals and sound only |
| Cmd+M (minimise) | expected: visuals and sound only |
| Cmd+Tab (switch apps) | expected: visuals and sound only |
| Mission Control (F3, or Control+Up) | expected: visuals and sound only |
| Move the pointer to the bottom edge (Dock) | expected: visuals and sound only. The Dock stays hidden. |
| Move the pointer to the top edge (menu bar) | expected: visuals and sound only. The menu bar stays hidden. |
| Force Quit (Cmd+Option+Esc) | expected: visuals and sound only |
| The Apple menu | expected: visuals and sound only. It does not show. |
| Log out (Shift+Cmd+Q) | expected: visuals and sound only |
| Esc | expected: visuals and sound only |

### The exit combination

| Key or combination | Expected |
|---|---|
| Hold Control+Option+Command, then press B, Y, E | The toy closes. |
| Hold Control+Option+Command, then press B, N, Y, E (one extra key) | expected: visuals and sound only. The toy must not close. |
| A flat-hand smash on the bottom-left corner of the keyboard | expected: visuals and sound only. The toy must not close. |
| Control+Option+Command with B, Y or E as single chords, out of order | expected: visuals and sound only. No system shortcut runs. |

### Keys the toy does not block

| Key or combination | Expected |
|---|---|
| Screenshot (Cmd+Shift+3) | known gap: saves a file to the Desktop |
| Screenshot (Cmd+Shift+4) | known gap: saves a file to the Desktop |
| Screenshot (Cmd+Shift+5) | known gap: opens the screenshot tools |
| Volume keys | known gap: they change the system volume. The toy has no volume guard. |
| Brightness keys | known gap |
| Keyboard light keys | known gap |
| Media keys (play, next, previous) | known gap |
| Spotlight (Cmd+Space) | known gap. Spotlight's Cmd+Space is off on this Mac. |
| Raycast's hotkeys (Cmd+Space and the others it registers) | known gap |
| Siri | known gap |
| Dictation | known gap |
| Globe or fn key (emoji picker) | known gap |
| Do Not Disturb key | known gap |
| VoiceOver (Cmd+F5) | known gap |
| Other accessibility shortcuts (for example Control+Option+Command+8, invert colours) | known gap |
| Lock screen (Control+Cmd+Q) | known gap. Unsure: it can lock the screen. |
| Control+Option+Command+Power | known gap: quits all apps and shuts down. Do not test it. |
| Touch ID or power button | known gap |
| Closing the lid | known gap |
| Other screens, if more than one is connected | known gap: the toy covers the main screen only |
| Idle display sleep, then the lock screen on wake (the child types into the password field) | known gap |

### Not sure until you test them on this Mac

| Key or action | Expected |
|---|---|
| Spotlight (Cmd+Space) | known gap. Unsure: write down whether it opens. |
| Lock screen (Control+Cmd+Q) | known gap. Unsure: write down whether it locks. |
| Trackpad swipe between Spaces (three or four fingers) | known gap. Unsure: write down whether the toy stays on screen. |
| Move the pointer into a hot corner | known gap. Unsure: the option that turns hot corners off needs macOS 27, and this Mac runs 26.7.1. |
| Control+Option+Command with any letter other than B, Y, E | known gap. Unsure: write down any letter that runs a system shortcut. |
