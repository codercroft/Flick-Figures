# Getting Flick Figures onto a phone

## Your own Android phone (Pixel)
1. Push to `main`. GitHub Actions builds automatically (about 5 minutes); watch it in the repo's **Actions** tab.
2. On the phone, open the repo's **Releases** page in Chrome (sign in to GitHub if the repo is private) and open **Latest build**.
3. Tap **FlickFigures.apk**. The first time, Android asks you to allow installs from Chrome ("Install unknown apps"): allow it, then tap Install.
4. Later builds install over the old one and keep working, because every build is signed with the same key.

You can also run the build by hand: Actions tab, **Build**, **Run workflow**.

## Other people
- **Android:** send them the link to the Latest build release, or the APK file itself. The same steps as above.
- **iPhone:** Apple only allows installs through TestFlight, which needs a Mac and a paid Apple Developer account. The free option is the web build: unzip `flick-figures-web.zip` from the release and upload the folder to any static host (itch.io's HTML5 upload, Netlify Drop, GitHub Pages), then send the link. It runs in the phone's browser (no vibration there).
- **Google Play** later: needs a real release keystore (kept in GitHub secrets, not in the repo) and an AAB export.

## Building locally
Install Godot 4.3 plus its export templates, Android Studio's SDK and JDK 17, set them in Editor > Editor Settings > Export > Android, then use Project > Export with the `Android` preset.
