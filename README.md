# MicBoard 🎵

A system-wide soundboard tweak that injects audio into your mic — works in Roblox, Discord, any app.

## How to build

1. Fork this repo
2. Go to Actions tab
3. Click "Build MicBoard DEB"
4. Click "Run workflow"
5. Download the .deb from Artifacts when done

## How to install

Transfer the .deb to your phone and install via:
- Sileo / Cydia — tap the .deb file
- Or via SSH: `dpkg -i MicBoard.deb`

## How to add sounds

Put your .mp3 / .wav / .m4a files in:
```
/var/mobile/Documents/MicBoard/Sounds/
```
Use Filza or SSH to add files. Filename = button name.

## Usage

- A green 🎵 floating button appears over all apps
- Drag it anywhere on screen
- Tap to open soundboard
- Tap a sound button to play it through mic
- Use volume slider to control sound level
- Toggle switch to enable/disable

## Supported iOS

iOS 14.0 — 16.x
