# visualizationForBaby

A fullscreen toy for a small child who sits on a lap and smashes the keyboard. Every
key press, and every pile of them at once, shows up on screen as a visual reaction with
a sound, so the child sees and hears what their hands do and has fun. The user is a
toddler; the adult is the one who starts and stops it.

## Stack

- Swift 6, a native macOS app that runs as a fullscreen kiosk. No web page, no browser.
- Swift Package Manager.

The plan for the first version, `docs/first-version-plan.md`, picks the frameworks for
drawing and sound.

## Boundaries

- Any key, or many at once, only produces visuals and sound. It must never close the
  app, leave fullscreen, or change anything outside the app. Leaving takes a deliberate,
  complex key combination that mashing cannot produce by accident.

## Trios

| Task | Run it with | Agents |
|---|---|---|
| change | `/change` | `change-plan`, `change-do`, `change-check` |
