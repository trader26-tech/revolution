import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

// https://vite.dev/config/
export default defineConfig({
  // Baked in at build time and shown on the Settings screen, so any device can
  // prove which deploy it is actually running (ends the "is my change live?"
  // guessing game — a stale PWA shows a stale stamp).
  define: {
    __BUILD_TS__: JSON.stringify(new Date().toISOString()),
  },
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  // `vite preview` in production (Railway) serves behind an unknown host.
  // Allow it so it doesn't return "Blocked request. This host is not allowed."
  preview: {
    host: true,
    allowedHosts: true,
  },
  plugins: [
    react(),
    VitePWA({
      /* Renamed from the default manifest.webmanifest: iOS caches the manifest
         per-URL and can hand "Add to Home Screen" a STALE copy even after the
         app is deleted — which kept reinstalls stuck in the old opaque
         standalone mode. A new filename can never hit that cache, so installs
         are guaranteed to read the current manifest (display: fullscreen). */
      manifestFilename: "manifest-v2.webmanifest",
      // "prompt" so a new deploy surfaces an in-app "Update available" dialog
      // instead of swapping silently (which left users on the old UI until they
      // happened to fully relaunch). See <UpdatePrompt/>.
      registerType: "prompt",
      includeAssets: ["favicon.svg", "apple-touch-icon.png"],
      manifest: {
        /* Stable identity for the installed app. Without an explicit id, Chrome
           derives it from start_url; pinning it keeps the SAME installed app
           across future start_url tweaks (avoids duplicate/"new" installs). */
        id: "/?app=revolution",
        name: "Revolution — Subscription Tracker",
        short_name: "Revolution",
        description:
          "The subscription tracker that stops surprise charges. See every bill before you're charged.",
        lang: "en",
        dir: "ltr",
        theme_color: "#0b0320",
        background_color: "#0b0320",
        /* Base display MUST be "standalone" for Android. When you Add to Home
           Screen on Chrome, Android mints a Google-signed WebAPK from this
           manifest; "fullscreen" made minting fall back to an UNSIGNED shortcut
           APK, which Play Protect blocks as "unsafe app". "standalone" mints
           cleanly. iOS never had that problem — its only issue was the opaque
           status bar, which display_override below solves without breaking
           Android. */
        display: "standalone",
        /* Per-platform display negotiation. Chrome/iOS walk this list and use
           the first mode they support:
             - iOS honours "fullscreen" here → translucent status bar, the page
               extends edge-to-edge and the starfield paints behind the clock.
             - Android/Chrome fall through to "standalone" for a clean WebAPK. */
        display_override: ["fullscreen", "standalone"],
        orientation: "portrait",
        scope: "/",
        start_url: "/",
        categories: ["finance", "productivity"],
        icons: [
          {
            src: "icon-192.png",
            sizes: "192x192",
            type: "image/png",
            purpose: "any",
          },
          {
            src: "icon-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "any",
          },
          {
            src: "icon-maskable-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,svg,png,woff2}"],
        navigateFallback: "index.html",
      },
      devOptions: { enabled: false },
    }),
  ],
});
