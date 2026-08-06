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
const VERSION_FILE = path.join(DOWNLOADS, 'version.json');

// Read the release metadata the build script writes next to the APK. Falls back
// gracefully to the APK's own file stats if version.json is missing.
function releaseInfo() {
  const info = { android: fs.existsSync(APK) };
  if (!info.android) return info;

  const stat = fs.statSync(APK);
  info.sizeBytes = stat.size;
  info.sizeMb = +(stat.size / (1024 * 1024)).toFixed(1);
  // Last-updated = the APK's modified time (always accurate).
  info.updatedAt = stat.mtime.toISOString();

  // Version (+ optional build) from version.json when present.
  try {
    const v = JSON.parse(fs.readFileSync(VERSION_FILE, 'utf8'));
    if (v.version) info.version = v.version;
    if (v.build) info.build = v.build;
    // Prefer an explicit built-at timestamp if the build script recorded one.
    if (v.builtAt) info.updatedAt = v.builtAt;
  } catch (_) {
    /* no version.json — file stats above are enough */
  }
  return info;
}

// Health check (Railway pings this).
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Release info: availability + version + last-updated + size (the page shows it).
app.get('/api/availability', (_req, res) => {
  res.json(releaseInfo());
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
