# Revolution — Download Site

A polished landing page that lets anyone download the Revolution app. Android
installs directly (an APK is streamed as a download); iOS shows "Coming soon to
the App Store".

```
download-site/
├── frontend/            # the landing page (static)
│   ├── index.html
│   ├── styles.css
│   ├── app.js
│   ├── assets/          # favicon, images
│   └── downloads/
│       └── revolution.apk   ← the built Android app (served on download)
├── backend/             # Node/Express server that serves the page + APK
│   ├── server.js
│   └── package.json
├── build_apk.sh         # rebuilds the APK from ../frontend and copies it here
├── railway.json         # Railway deploy config
├── Procfile
└── package.json         # deploy root (installs + starts the backend)
```

## Run locally

```bash
cd download-site
npm install          # installs the backend deps too
npm start            # → http://localhost:3000
```

Open http://localhost:3000. The **Download for Android** button streams the APK
straight to the visitor (auto-download).

## Update / build the APK

The APK is the Flutter app in `../frontend`. To (re)build it and place it here:

```bash
./build_apk.sh
```

This runs `flutter build apk --release` and copies the result to
`frontend/downloads/revolution.apk`. Commit that file so it deploys.

> The APK is a binary (~30–60 MB). It's committed on purpose so Railway serves
> it. If you'd rather not commit large binaries, upload the APK to Railway's
> volume or object storage and point `APK` in `server.js` at it.

## Deploy to Railway

1. Push this repo to GitHub.
2. In Railway → **New Project → Deploy from GitHub repo**.
3. Set the **Root Directory** to `download-site`.
4. Railway auto-detects Node (Nixpacks). It runs `npm install` then `npm start`.
5. It injects `PORT`; the server binds to it automatically.
6. Health check: `/health` (already configured in `railway.json`).

That's it — Railway gives you a public URL. Share it, and people can download the
app from it. The iOS button stays "Coming soon" until you publish to the App
Store (then swap the disabled button in `index.html` for the store link).

## iOS note

Apple doesn't allow downloadable install files like Android's APK — apps come
from the App Store (or TestFlight for testing). So the iOS button is a
"Coming soon" state by design. When you have a TestFlight or App Store link,
replace the `#iosBtn` button in `index.html` with an `<a href="…">`.
