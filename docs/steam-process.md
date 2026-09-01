# Steam process (external)

This repository does **not** claim Steam partner status, AppID ownership, or a live store page.

Offline Windows and Linux builds are the ship artifacts. There is no always-online check.

## What this repo provides

- `export_presets.cfg` — Linux, Windows Desktop, Android debug
- `.github/workflows/export-linux.yml` — headless Linux export when Godot is available
- Local Godot 4.7.2 exports (`build/linux`, `build/windows`)

## External owner

A Steamworks partner, depot upload, store copy, and age-rating packet live **outside** this repo. Hand those to the person who holds the Steamworks account.

Do not put Steamworks secrets, build tokens, or partner IDs in git.
