# Flick Figures: how to play on your iPhone

Send people this section (copy and paste it into a message).

---

**Flick Figures on iPhone (takes 30 seconds)**

1. On your iPhone, open this link in **Safari**:
   https://codercroft.github.io/Flick-Figures/
2. Tap the **Share** button (the square with an arrow pointing up, at the bottom of the screen).
3. Scroll down and tap **Add to Home Screen**, then tap **Add**.
4. Open **Flick Figures** from your Home Screen. It runs full screen like a normal app. Hold your phone upright.

How to play: tap one of your figures, then drag anywhere on the screen (pull back like a slingshot) and let go to flick it at the enemy figures. Knock all of them off the table to win.

Tips:
- Use Safari for the install. The Share menu in other browsers may not show "Add to Home Screen".
- It updates itself. When a new version is out, a green bar appears at the top: tap it to update (do it between runs, because it restarts the game).
- There is no vibration on iPhone.
- Android phones: ask for the APK instead.

---

# Notes for the developer (you)

**Everyday use**
- Push to `main` as usual. About 5 minutes later the same link serves the new build; there is nothing to send people again.
- Friends who already installed it get the update automatically the next time they open the app (or from the green bar if they have it open).
- Check a deploy: repo, Actions tab, the **Build** run. The `pages` job is the web deploy. The same workflow also builds the Android APK and the Latest build release.
- Your own copy of the link: https://codercroft.github.io/Flick-Figures/ . Open it on your iPhone in Safari first and check it before sharing.

**If something goes wrong**
- `pages` job fails with "Not Found" / "Ensure GitHub Pages has been enabled": Settings, Pages, Source must be **GitHub Actions**.
- The `android` job fails at the smoke test: it checks that the exported game has all its content (pools, shop, scenes). Read the line starting with `[smoke] FAIL`. Adding or removing encounters, events or content usually means updating the expected counts in `tools/smoke_test.gd`. While `android` fails, the Latest build release is not republished (but the Pages deploy still runs).
- A friend sees an old version: ask them to close the app completely and reopen it, or open the link in Safari once. If that fails, delete the Home Screen icon and add it again.
- Game progress (runs) is not saved between sessions yet, so updating mid-run loses the run.

**Limits**
- Apple only allows real App Store or TestFlight installs with a paid developer account; the Home Screen web app is the free way.
- The repo is public, so anyone can see the code and the link. Do not commit secrets (the release keystore must stay in GitHub secrets).
- Free GitHub Actions minutes for public repos are unlimited; Pages has soft limits (about 100 GB of traffic a month), which is plenty for friends.
