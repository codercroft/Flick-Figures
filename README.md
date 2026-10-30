# Flick Figures

A one-thumb roguelike for phones: flick little plastic toy figures across a tabletop and knock every enemy figure off the board. Built with Godot 4 (GDScript).

## Play it on iPhone (or any phone browser)

**https://codercroft.github.io/Flick-Figures/**

The link never changes. Every push to `main` rebuilds and redeploys the game there automatically (about 5 minutes after a push).

### Add it to your Home Screen (feels like a real app)
1. Open the link above in **Safari** on your iPhone.
2. Tap the **Share** button (the square with an arrow, at the bottom of the screen).
3. Scroll down and tap **Add to Home Screen**, then **Add**.
4. Open **Flick Figures** from your Home Screen. It runs full screen with no browser bars. Hold the phone upright.

Notes:
- **Updates:** the game checks for a new version whenever you open it. If a newer build goes live while you are playing, a green bar appears at the top: tap it to update (this restarts your current run, so do it between runs).
- **Vibration:** iPhones do not allow web pages to vibrate, so there is no haptic feedback there (Android phones with the APK do get it).
- **Chrome on iPhone** can add it to the Home Screen too (Share, then Add to Home Screen), but Safari gives the best full-screen result.

## Play it on Android
Install the APK from the **Releases** page: see [BUILDING.md](BUILDING.md).

## For the developer
- One-time setup for the web link: in the GitHub repo go to **Settings, Pages, Build and deployment, Source** and choose **GitHub Actions**. After that, the `Build` workflow deploys the site on every push to `main`.
- The workflow is `.github/workflows/build.yml`. The web page template (Home Screen settings, safe areas, update check) is `web/shell.html`; the app manifest and icons are in `web/` (replace `web/icon-source.svg` and re-render the PNGs to change the icon).
- Each deploy renames the game files with the build number (`index-<build>.wasm` and so on) and writes `version.json`, so players never get a stale cached build.
- See [BUILDING.md](BUILDING.md) for building locally and [CLAUDE.md](CLAUDE.md) for how the game is put together.
