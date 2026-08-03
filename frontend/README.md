# Revolution Frontend (Angular PWA)

Angular 18 standalone PWA with Supabase connectivity.

## Setup

```bash
cd frontend
npm install
```

Then set your Supabase values in `src/environments/environment.ts`
(and `environment.prod.ts` for production builds).

## Run (dev)

```bash
npm start
```

Opens at http://localhost:4200. The service worker is disabled in dev and
active in production builds.

## Build (PWA)

```bash
npm run build
```

Output goes to `dist/revolution-frontend`. Serve it over HTTPS to get the
full installable-PWA behavior.

## Icons

`src/assets/icons/` ships with placeholder PWA icons
(`icon-192x192.png`, `icon-512x512.png`). Replace them with your own before
release.
