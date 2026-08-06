// Footer year
document.getElementById('year').textContent = new Date().getFullYear();

const ua = navigator.userAgent || '';
const isAndroid = /android/i.test(ua);
const isIOS = /iphone|ipad|ipod/i.test(ua) ||
  (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

const androidBtn = document.getElementById('androidBtn');

// On the Android button, kick off the APK download immediately + give feedback.
if (androidBtn) {
  androidBtn.addEventListener('click', (e) => {
    // Let the browser follow the href (which streams the .apk); just show state.
    androidBtn.classList.add('downloading');
    const label = androidBtn.querySelector('.btn-text strong');
    const original = label ? label.textContent : '';
    if (label) label.textContent = 'Starting download…';
    setTimeout(() => {
      androidBtn.classList.remove('downloading');
      if (label) label.textContent = original;
    }, 2600);
  });
}

// Tailor the fineprint to the visitor's device so the CTA feels personal.
const fine = document.getElementById('fineprint');
if (fine) {
  if (isIOS) {
    fine.textContent = 'iOS is coming to the App Store — Android available now.';
  } else if (isAndroid) {
    fine.textContent = 'Tap “Download” — it installs right on your phone. Android 6.0+';
  }
}

// Show the app version + when it was last updated, from the backend. Reassures
// visitors they're getting the newest build.
(async () => {
  const line = document.getElementById('versionLine');
  const text = document.getElementById('versionText');
  if (!line || !text) return;
  try {
    const res = await fetch('/api/availability', { cache: 'no-store' });
    const info = await res.json();
    if (!info.android) return; // nothing to download yet → stay hidden

    const parts = [];
    if (info.version) parts.push('Version ' + info.version);
    if (info.updatedAt) parts.push('Updated ' + formatUpdated(info.updatedAt));
    if (typeof info.sizeMb === 'number') parts.push(info.sizeMb + ' MB');

    if (parts.length) {
      text.textContent = parts.join('  ·  ');
      line.hidden = false;
    }
  } catch (_) {
    /* offline or endpoint missing → just leave the line hidden */
  }
})();

// "6 Aug 2026, 6:33 PM" in the visitor's own locale/timezone.
function formatUpdated(iso) {
  const d = new Date(iso);
  if (isNaN(d)) return iso;
  const date = d.toLocaleDateString(undefined, {
    day: 'numeric', month: 'short', year: 'numeric',
  });
  const time = d.toLocaleTimeString(undefined, {
    hour: 'numeric', minute: '2-digit',
  });
  return date + ', ' + time;
}
