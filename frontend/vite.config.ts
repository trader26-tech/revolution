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
      // "prompt" so a new deploy surfaces an in-app "Update available" dialog
      // instead of swapping silently (which left users on the old UI until they
      // happened to fully relaunch). See <UpdatePrompt/>.
      registerType: "prompt",
      includeAssets: ["favicon.svg", "apple-touch-icon.png"],
      manifest: {
        name: "Revolution — Subscription Tracker",
        short_name: "Revolution",
        description:
          "The subscription tracker that stops surprise charges. See every bill before you're charged.",
        theme_color: "#0b0320",
        /* iOS paints the status-bar / home-indicator strips (and the launch
           screen) with this when it runs the app in opaque standalone mode.
           #060010 read as pitch-black bars; deep purple matches the app's top
           tone so the system chrome blends into the scene. */
        background_color: "#0b0320",
        /* "fullscreen", NOT "standalone". On modern iOS, when a manifest with
           a display value exists it OVERRIDES the legacy
           apple-mobile-web-app-status-bar-style meta — and "standalone" maps
           to an OPAQUE system status bar: iOS shrinks the web viewport and
           paints the top/bottom strips itself, so no CSS can ever put the
           starfield there. "fullscreen" is what iOS maps to
           standalone-with-translucent-status-bar: the page truly extends
           edge-to-edge, env(safe-area-inset-*) reports real values, and our
           overshooting starfield paints behind the clock and home indicator. */
        display: "fullscreen",
        orientation: "portrait",
        scope: "/",
        start_url: "/",
        categories: ["finance", "productivity"],
        icons: [
          { src: "icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "icon-512.png", sizes: "512x512", type: "image/png" },
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
