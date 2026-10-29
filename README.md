<div align="center">
  <img src="Lune/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="20%" style="border-radius: 22%;" />
  <br><br>
  <p align="center">
    <img src="https://img.shields.io/badge/Platform-iOS%2018%2B%20%7C%20iOS%2026-blue?style=for-the-badge&logo=apple&logoColor=white" />
    <img src="https://img.shields.io/badge/Swift-6.0%20%7C%20SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white" />
    <img src="https://img.shields.io/badge/Design-Liquid%20Glass-8B5CF6?style=for-the-badge&logo=apple&logoColor=white" />
    <br>
    <a href="https://www.paypal.com/paypalme/TommyZambrano">
      <img src="https://img.shields.io/badge/PayPal-Donate-00457C?style=for-the-badge&logo=paypal&logoColor=white"/>
    </a>
    <a href="https://ko-fi.com/mrdemonc">
      <img src="https://img.shields.io/badge/Ko--fi-Buy me a coffee-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white"/>
    </a>
    <a href="https://github.com/MrDemonc/Lune#-monero-xmr">
      <img src="https://img.shields.io/badge/Monero-Donate-FF6600?style=for-the-badge&logo=monero&logoColor=white"/>
    </a>
  </p>
  <p align="center">
    <b>Lune for iOS</b> adapts the signature aesthetic of Lune Android into a native SwiftUI experience powered by Apple's <b>Liquid Glass</b> design language.
  </p>
</div>

---

## ✨ Liquid Glass & Visual Identity

Lune for iOS faithfully preserves the visual identity of the original Android app while embracing Apple's **Liquid Glass** design:

- **Liquid Glass Materials**: Real-time specular refractions, dynamic luminance adaptation, and responsive physical interactions across navigation bars, floating tab bars, and controls.
- **Identical Color Palettes**:
  - **Lune Violet**: Material 3 purple light (`#6650a4`) & dark (`#D0BCFF`).
  - **Sunset Peach**: `#B04B38` / `#FFB4AA`.
  - **Sage Green**: `#386B52` / `#9FD3B1`.
  - **Ocean Breeze**: `#2E6580` / `#99CCEA`.
  - **Lavender Mist**: `#6E568F` / `#D6BAFF`.
  - **Warm Amber**: `#7F5700` / `#FCBC43`.
  - **AMOLED Pitch Black**: True `#000000` with subtle `#121212` frosted surfaces.
- **Quicksand Typography**: Custom typography system bundled with Quicksand Regular & Bold, with dynamic scaling (0.7x – 1.5x) and support for System, Serif, and Monospaced fonts.
- **Custom Player Modes**: Rounded cover, Square cover, and **Spinning Vinyl Record** with dynamic reflections and inertia.
- **Wavy Progress Bar**: Animated fluid sine-wave progress bar matching the Android player.

---

## 🧠 On-Device AI Core (100% Offline)

Ported directly from Lune's Kotlin AI engine:

- **Harmonic Smart Shuffle**: Reorders tracks dynamically using Markov transition probabilities, time-of-day listening habits, and acoustic profiling.
- **Discovery Mode**: Interleaves familiar favorites with unheard library gems.
- **8 Personalized AI Mixes**:
  1. **Daily Flow**: Essential tracks with harmonic transitions.
  2. **Discovery Mode**: Unheard gems tailored to your preferences.
  3. **Energy Boost**: High-tempo tracks for workouts.
  4. **Chill & Relax**: Mellow acoustic and ambient sounds.
  5. **Time-of-Day Context**: Morning, Afternoon, Evening, Night, and Weekend mixes.
  6. **Forgotten Gems**: High-scoring tracks you haven't played in a while.
  7. **Acoustic & Live**: Algorithmic detection of unplugged and live recordings.
  8. **Artist Spotlight**: Dedicated infinite mix centered on your top artist.

---

## 🎛️ Audio Features

- **AVAudioEngine Architecture**: High-fidelity local playback engine with support for MP3, AAC, FLAC, WAV, ALAC, AIFF.
- **10-Band Equalizer**: Sliders spanning 31 Hz to 16 kHz with 10 presets (Flat, Bass Boost, Rock, Pop, Jazz, Electronic, Vocal, Acoustic, Classical, Deep).
- **Audio Effects**: Extra Bass Boost, Reverb (6 room environments), Pitch Shift, Playback Speed (0.5x – 2.0x).
- **48-Band Audio Visualizer**: Real-time FFT frequency spectrum analysis powered by Apple Accelerate (vDSP).
- **Synced Lyrics**: LRC parser with auto-scrolling karaoke highlight and built-in timing editor.
- **Lock Screen Integration**: Full `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` controls.

---

## 🔒 Privacy Guarantee

- **Zero Network Permissions**: The app does not make any network requests.
- **No Trackers**: Zero telemetry, zero analytics SDKs, zero crash reporters.
- **100% Offline**: All metadata and AI telemetry are stored strictly in local on-device sandbox storage.

---

## 🚀 Building & Releasing

### GitHub Actions Workflow

This branch includes `.github/workflows/Lune_Build.yml` matching the release system used on the `main` branch:

1. Go to **Actions** → **Build Lune iOS Release**.
2. Click **Run workflow**.
3. Optional input `test_build`: set to `true` to only build and upload artifacts without creating a GitHub release.
4. The workflow will build and archive the application, package `Lune-<version>.ipa`, upload it as an artifact, and publish a GitHub Release with the corresponding tag.

### Local Build (Xcode)

```bash
git checkout IOS
open Lune.xcodeproj
```

Select your device or simulator and press **⌘ + R** to run.
