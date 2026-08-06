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
