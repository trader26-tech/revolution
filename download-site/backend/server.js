// Revolution download site — serves the landing page and streams the app files.
//
// Railway sets PORT; we bind to it. The APK lives in ../frontend/downloads.
// Hitting /download/android streams it as an attachment so it auto-downloads.
const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

const FRONTEND = path.join(__dirname, '..', 'frontend');
const DOWNLOADS = path.join(FRONTEND, 'downloads');
const APK = path.join(DOWNLOADS, 'revolution.apk');

// Health check (Railway pings this).
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Whether an APK is actually present (the page can adapt if not).
app.get('/api/availability', (_req, res) => {
  res.json({ android: fs.existsSync(APK) });
});

// Android download → stream the APK as an attachment (forces a download).
app.get('/download/android', (_req, res) => {
  if (!fs.existsSync(APK)) {
    return res
      .status(404)
      .send('The Android app is being prepared — please check back shortly.');
  }
  res.setHeader(
    'Content-Type',
    'application/vnd.android.package-archive'
  );
  res.setHeader(
    'Content-Disposition',
    'attachment; filename="Revolution.apk"'
  );
  fs.createReadStream(APK).pipe(res);
});

// Everything else → the static landing site.
app.use(express.static(FRONTEND, { extensions: ['html'] }));

// SPA-ish fallback to index.html.
app.get('*', (_req, res) => {
  res.sendFile(path.join(FRONTEND, 'index.html'));
});

app.listen(PORT, () => {
  const apkOk = fs.existsSync(APK);
  console.log(`Revolution download site running on :${PORT}`);
  console.log(`APK present: ${apkOk ? 'yes' : 'NO (add frontend/downloads/revolution.apk)'}`);
});
