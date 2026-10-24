# BabyToy

A fullscreen toy for a small child on your lap. Keys and the mouse make fire, water,
explosions and drops, with a soft tone. Mashing the keys cannot close the toy or switch to
another app.

CAUTION: Never use headphones with this toy. The child cannot judge the volume. The toy
blocks the volume keys from its start until the exit combination, and only while the
Accessibility permission is on.

## One-time setup

The toy blocks the system keys (volume, brightness, media, Spotlight, Raycast) with an
event tap. An event tap needs the Accessibility permission. macOS gives the permission to the
app that you start the toy from, so start the toy from Terminal.app.

1. Open System Settings > Privacy & Security > Accessibility.
2. Turn on Terminal.app.
3. Quit Terminal.app and open it again.
4. Start the toy from a Terminal.app window that is not fullscreen.

The tap blocks every key from the start of the toy until the exit combination, whichever app
macOS says is in front. A toy that is left behind another window still keeps the keyboard.
The exit combination works from anywhere.

If the permission is off, the toy prints these steps, asks macOS to show the permission
prompt, and does not start.

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

If the keys make nothing on the screen, the toy did not get the keyboard. With `make try`, wait 60
seconds, and the toy closes.

## Leave the toy

1. Hold Control, Option and Command. Hold no other key.
2. While you hold them, press B, then Y, then E. Press each key once, one at a time.

The toy closes after E. Caps Lock on or off does not matter.

Any other key resets the combination. Shift or fn resets it too. If you let go of one of the
three keys, start again at step 1.

While the toy runs, the Mac cannot log out, restart or shut down from the Apple menu. Leave
the toy first.

## If the toy hangs

If the toy hangs, macOS turns its event tap off after a short time. Then the system keys act
again: Cmd+Space opens Raycast, and Raycast can quit the toy. Cmd+Tab stays blocked.

- `make try` closes the toy after 60 seconds.
- From another device, run `pkill BabyToy` over ssh. This needs Remote Login (System
  Settings, General, Sharing). Remote Login is off on this Mac today, so turn it on and test
  `ssh` before you rely on it.
- Hold the power button until the Mac turns off. This always works. Unsaved work in other
  apps is lost.

## Boundary checklist

Do this check once before the child uses the toy. It takes about 3 minutes. Use `make try`
until the exit combination has worked once. Do the checklist with `make run`, and leave
with the exit combination. Press each key or combination. Write down what happens if it is
not what the table expects.

"Expected: visuals and sound only" means that the key makes fire, water, an explosion or a
drop, and a tone, and nothing else happens. "Known gap" means that the toy cannot block the
key. The key does what it does in macOS.

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
| Volume keys (F10, F11, F12) | expected: visuals and sound only. The user confirms. |
| Brightness keys (F1, F2) | expected: visuals and sound only. The user confirms. |
| Keyboard light keys | expected: visuals and sound only. The user confirms. |
| Media keys (play, next, previous: F7, F8, F9) | expected: visuals and sound only. The user confirms. |
| Spotlight and Raycast (Cmd+Space) | expected: visuals and sound only. The user confirms. |
| Cmd+Option+Space | expected: visuals and sound only. The user confirms. |
| Control+Space | expected: visuals and sound only. The user confirms. |
| Siri | expected: visuals and sound only. The user confirms. |
| Dictation (F5) | expected: visuals and sound only. The user confirms. |
| Do Not Disturb (F6) | expected: visuals and sound only. The user confirms. |
| Globe or fn key (emoji picker) | expected: visuals and sound only. The user confirms. |
| F3 (Mission Control) and F4 (Spotlight) | expected: visuals and sound only. The user confirms. |
| Any top-row key that still does its system function | Copy the line that the toy printed in Terminal for that key, and write down the key. If the toy printed no line, use the steps in "If a key still acts". |

### If a key still acts

1. Start the toy from Terminal.app with `BABYTOY_DEBUG=1 make try`.
2. Press the key that still acts.
3. Copy all lines that the toy printed in Terminal.

With `BABYTOY_DEBUG=1` the toy prints one line for each event that the key tap receives. It
prints two lines at the start with the state "macOS reports the toy active". It skips the repeats of a held
key. The switch changes nothing else.

How to read the lines:

- If the toy printed no line for the key, the system acts before the key tap sees it.
- The start lines say "macOS reports the toy active true" or "false". This is information only.
  The tap blocks the keys in both cases.
- If a line says "swallow" and the key still acts, something beneath the tap handles it.

### The exit combination

| Key or combination | Expected |
|---|---|
| Hold Control+Option+Command, then press B, Y, E | The toy closes. |
| Hold Control+Option+Command, then press B, N, Y, E (one extra key) | expected: visuals and sound only. The toy must not close. |
| A flat-hand smash on the bottom-left corner of the keyboard | expected: visuals and sound only. The toy must not close. |
| Control+Option+Command with B, Y or E as single chords, out of order | expected: visuals and sound only. No system shortcut runs. |

### Mouse and trackpad

| Action | Expected |
|---|---|
| Move the mouse or swipe one finger | a trail of fire or water, and soft notes |
| Click any button | a burst and a note |
| Scroll with two fingers or the wheel | a trail |

### Keys the toy does not block

| Key or combination | Expected |
|---|---|
| Screenshot (Cmd+Shift+3) | known gap: saves a file to the Desktop |
| Screenshot (Cmd+Shift+4) | known gap: saves a file to the Desktop |
| Screenshot (Cmd+Shift+5) | known gap: opens the screenshot tools |
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
| Lock screen (Control+Cmd+Q) | known gap. Unsure: write down whether it locks. |
| Trackpad swipe between Spaces (three or four fingers) | known gap. Unsure: write down whether the toy stays on screen. |
| Move the pointer into a hot corner | known gap. Unsure: the option that turns hot corners off needs macOS 27, and this Mac runs 26.7.1. |
| Control+Option+Command with any key other than B, Y, E | known gap. Unsure: write down any key that runs a system shortcut. |
| Start the toy with Accessibility off for Terminal.app | The toy prints the setup steps and does not start. |
